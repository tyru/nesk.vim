" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


" vital {{{

function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Nesk = a:V.import('Nesk')
  let s:Error = a:V.import('Nesk.Error')
  let s:ERROR_NO_RESULTS = a:V.import('Nesk.Table').ERROR.NO_RESULTS
  let s:StringReader = a:V.import('Nesk.IO.StringReader')
endfunction

function! s:_vital_depends() abort
  return [
  \ 'Nesk',
  \ 'Nesk.Error',
  \ 'Nesk.IO',
  \ 'Nesk.IO.StringReader',
  \ 'Nesk.IO.MultiWriter',
  \ 'Nesk.IO.VimBufferWriter',
  \ 'Nesk.Table',
  \ 'Nesk.Table.SKKDict',
  \]
endfunction

" }}}

" 'kana' mode {{{

" TODO: Global variable
let s:PREEDITING_MARKER = "▽"
let s:OKURI_MARKER = "▼"
let s:CONVERT_MARKER = "▼"
let s:REGDICT_HEAD_MARKER = "▼"
let s:REGDICT_LEFT_MARKER = '【'
let s:REGDICT_RIGHT_MARKER = '】'


function! s:new_hira_mode(nesk) abort
  return {
  \ '_nesk': a:nesk,
  \ 'name': 'skk/kana',
  \ 'next': function('s:_HiraState_next'),
  \}
endfunction

" Set up kana mode: define tables, and change state to TableNormalState.
function! s:_HiraState_next(in, out) abort dict
  let [table, err] = self._nesk.get_table('japanese/hiragana')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load kana table')
    return s:_error(self, a:in, err)
  endif
  let state = s:new_table_normal_state(self._nesk, s:_simple_name(self.name), table)
  return state.next(a:in, a:out)
endfunction

" }}}

" 'kata' mode {{{

function! s:new_kata_mode(nesk) abort
  return {
  \ '_nesk': a:nesk,
  \ 'name': 'skk/kata',
  \ 'next': function('s:_KataState_next'),
  \}
endfunction

function! s:_KataState_next(in, out) abort dict
  let [table, err] = self._nesk.get_table('japanese/katakana')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load kata table')
    return s:_error(self, a:in, err)
  endif
  let state = s:new_table_normal_state(self._nesk, s:_simple_name(self.name), table)
  return state.next(a:in, a:out)
endfunction

" }}}

" 'hankata' mode {{{

function! s:new_hankata_mode(nesk) abort
  return {
  \ '_nesk': a:nesk,
  \ 'name': 'skk/hankata',
  \ 'next': function('s:_HankataState_next'),
  \}
endfunction

function! s:_HankataState_next(in, out) abort dict
  let [table, err] = self._nesk.get_table('japanese/hankata')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load hankata table')
    return s:_error(self, a:in, err)
  endif

  let state = s:new_table_normal_state(self._nesk, s:_simple_name(self.name), table)
  return state.next(a:in, a:out)
endfunction

" }}}

" 'ascii' mode {{{

function! s:new_ascii_mode(nesk) abort
  return {
  \ '_nesk': a:nesk,
  \ 'name': 'skk/ascii',
  \ 'next': function('s:_AsciiState_next'),
  \}
endfunction

function! s:_AsciiState_next(in, out) abort dict
  let c = s:_read_char(a:in)
  if c is# "\<C-j>"
    " Change mode (must leave one character at least for ModeChangeState)
    call a:in.unread()
    return [s:Nesk.new_mode_change_state(self.name, 'skk/kana'), s:Error.NIL]
  else
    call s:_commit(a:out, c)
  endif
  return [self, s:Error.NIL]
endfunction

" }}}

" 'zenei' mode {{{

function! s:new_zenei_mode(nesk) abort
  return {
  \ '_nesk': a:nesk,
  \ 'name': 'skk/zenei',
  \ 'next': function('s:_ZeneiTable_next0'),
  \}
endfunction

function! s:_ZeneiTable_next0(in, out) abort dict
  let [table, err] = self._nesk.get_table('japanese/zenei')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load zenei table')
    return s:_error(self, a:in, err)
  endif
  let next_state = {
  \ '_table': table,
  \ 'name': self.name,
  \ 'next': function('s:_ZeneiTable_next1'),
  \}
  return next_state.next(a:in, a:out)
endfunction

function! s:_ZeneiTable_next1(in, out) abort dict
  let c = s:_read_char(a:in)
  if c is# "\<C-j>"
    " Change mode (must leave one character at least for ModeChangeState)
    call a:in.unread()
    return [s:Nesk.new_mode_change_state(self.name, 'skk/kana'), s:Error.NIL]
  else
    let [str, err] = self._table.get(c)
    if err is# s:ERROR_NO_RESULTS
      let str = c
    elseif err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    call s:_commit(a:out, str)
  endif
  return [self, s:Error.NIL]
endfunction

" }}}

" Table Normal State (kana, kata, hankata) {{{

function! s:new_table_normal_state(nesk, simple_name, mode_table) abort
  return {
  \ '_nesk': a:nesk,
  \ '_mode_table': a:mode_table,
  \ 'name': a:simple_name . '/normal',
  \ 'next': function('s:_TableNormalState_next'),
  \}
endfunction

" a:in.unread() continues nesk.rewrite() loop
" after leaving this function.
" (the loop exits when a:in becomes empty)
function! s:_TableNormalState_next(in, out) abort dict
  let c = s:_read_char(a:in)
  let key = a:out.get_preedit()
  if c is# "\<C-j>"
    if key is# ''
      return [self, s:Error.NIL]
    endif
    " Commit key
    let bs = repeat("\<C-h>", strchars(key))
    call s:_write(a:out, bs)
    let [pair, err] = self._mode_table.get(key)
    if err is# s:Error.NIL
      call s:_commit(a:out, pair[0])
    elseif err isnot# s:ERROR_NO_RESULTS
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  elseif c is# "\<CR>"
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, a:in, err)
    endif
    call s:_commit(a:out, "\<CR>")
    return [self, s:Error.NIL]
  elseif c is# "\<C-h>"
    call s:_commit(a:out, "\<C-h>")
    return [self, s:Error.NIL]
  elseif c is# "\x80"    " backspace is \x80 k b
    let [rest, err] = a:in.read(2)
    if err is# s:Error.NIL && c . rest is# "\<BS>"
      let in = s:StringReader.new("\<C-h>")
      return self.next(in, a:out)
    else
      call a:in.unread()
    endif
    return [self, err]
  elseif c is# "\<Esc>"
    " NOTE: Vim only key: commit preedit and escape to Vim normal mode
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, a:in, err)
    endif
    call s:_commit(a:out, "\<Esc>")
    return [s:Nesk.new_black_hole_state(self.name), s:Error.NIL]
  elseif c is# "\<C-g>"
    if key isnot# ''
      let bs = repeat("\<C-h>", strchars(key))
      call s:_commit(a:out, bs)
    endif
    return [self, s:Error.NIL]
  elseif c is# 'l'
    return s:_handle_normal_mode_key(self, 'skk/ascii', a:in, a:out)
  elseif c is# 'L'
    return s:_handle_normal_mode_key(self, 'skk/zenei', a:in, a:out)
  elseif c is# 'q'
    let mode = self.name is# 'skk/kana' ? s:new_kata_mode(self._nesk) : s:new_hira_mode(self._nesk)
    return s:_handle_normal_table_key(self, mode, a:in, a:out)
  elseif c is# "\<C-q>"
    let mode = self.name is# 'skk/kana' ? s:new_hankata_mode(self._nesk) : s:new_hira_mode(self._nesk)
    return s:_handle_normal_table_key(self, mode, a:in, a:out)
  elseif c is# 'Q'
    call a:in.unread()
    let state = s:new_table_preediting_state(
    \ self._nesk, s:_simple_name(self.name), self._mode_table, s:PREEDITING_MARKER
    \)
    return [state, s:Error.NIL]
  elseif c =~# '^[A-Z]$'
    let in = s:StringReader.new('Q' . tolower(c))
    let state = self
    while in.size() ># 0
      let [state, err] = state.next(in, a:out)
      if err isnot# s:Error.NIL
        return s:_error(state, a:in, err)
      endif
    endwhile
    return [state, s:Error.NIL]
  else
    let err = s:_append_char_to_preedit(a:in, a:out, self._mode_table, c)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  endif
endfunction

function! s:_append_char_to_preedit(in, out, table, c) abort
  let c = a:c
  let key = matchstr(a:out.get_preedit(), '[[:alpha:]]\+$')
  let [cands, err] = a:table.search(key . c)
  if err isnot# s:Error.NIL
    " This must not be occurred in this table object
    return s:Error.wrap(err, 'table.search() returned non-nil error')
  endif
  if empty(cands)
    let [pair, err] = a:table.get(key)
    if err is# s:ERROR_NO_RESULTS
      let bs = repeat("\<C-h>", strchars(key))
      call s:_commit(a:out, bs . c)
    else
      let bs = repeat("\<C-h>", strchars(key))
      let committed = pair[0]
      let key = pair[1] . c
      let [pair, err] = a:table.get(key)
      if err is# s:Error.NIL
        let committed .= pair[0]
        let key = pair[1]
      elseif err isnot# s:ERROR_NO_RESULTS
        return err
      endif
      call s:_commit(a:out, bs . join(result, ''))
      call s:_write(a:out, key)
    endif
  elseif len(cands) is# 1
    let bs = repeat("\<C-h>", strchars(key))
    let pair = cands[0][1]
    call s:_commit(a:out, bs . pair[0])
    call s:_write(a:out, pair[1])
  else
    call s:_write(a:out, c)
  endif
  return s:Error.NIL
endfunction

function! s:_handle_normal_mode_key(state, mode_name, in, out) abort
  if a:out.get_preedit() isnot# ''
    " Commit preedit and change mode
    call a:in.unread()
    return a:state.next(s:StringReader.new("\<C-j>"), a:out)
  endif
  " Change mode (must leave one character at least for ModeChangeState)
  call a:in.unread()
  let state = s:Nesk.new_mode_change_state(a:state.name, a:mode_name)
  return [state, s:Error.NIL]
endfunction

function! s:_handle_normal_table_key(state, mode, in, out) abort
  if a:out.get_preedit() isnot# ''
    " Commit preedit and change table
    call a:in.unread()
    return a:state.next(s:StringReader.new("\<C-j>"), a:out)
  endif
  return [a:mode, s:Error.NIL]
endfunction


function! s:new_table_preediting_state(nesk, simple_name, mode_table, marker) abort
  return {
  \ '_nesk': a:nesk,
  \ '_mode_table': a:mode_table,
  \ '_marker': a:marker,
  \ 'name': a:simple_name . '/preediting',
  \ 'next': function('s:_TablePreeditingState_next0'),
  \}
endfunction

function! s:_TablePreeditingState_next0(in, out) abort dict
  call s:_read_char(a:in)
  call s:_write(a:out, self._marker)
  let state = extend(deepcopy(self), {
  \ 'next': function('s:_TablePreeditingState_next1')
  \})
  return [state, s:Error.NIL]
endfunction

function! s:_TablePreeditingState_next1(in, out) abort dict
  let c = s:_read_char(a:in)
  let no_marker = matchstr(a:out.get_preedit(), '^\V' . self._marker . '\m\zs.*')
  let buf = matchstr(a:out.get_preedit(), '^\V' . self._marker . '\m\zs.\{-}\ze[[:alpha:]]*$')
  let key = matchstr(a:out.get_preedit(), '[[:alpha:]]\+$')
  if c is# "\<C-j>"
    " Commit preedit
    let last_char = ''
    if key isnot# ''
      let [pair, err] = self._mode_table.get(key)
      if err is# s:ERROR_NO_RESULTS
        break
      endif
      if err isnot# s:Error.NIL
        return err
      endif
      let bs = repeat("\<C-h>", strchars(key))
      let last_char = pair[0]
    endif
    " Remove marker
    let bs = repeat("\<C-h>", strchars(a:out.get_preedit()))
    call s:_commit(a:out, bs . buf . last_char)
    " Back to TableNormalState
    let state = s:new_table_normal_state(
    \ self._nesk, s:_simple_name(self.name), self._mode_table
    \)
    return [state, s:Error.NIL]


    " FIXME: Get rid of:
    " * self._key
    "   let key = matchstr(a:out.get_preedit(), '[[:alpha:]]\+$')
    " * self._buf
    " * self._converted_key
    " * s:_send_converted_key_in_kana_state()


  elseif c is# "\<CR>"
    " Back to TableNormalState
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, a:in, err)
    endif
    " Handle <CR> in TableNormalState
    call a:in.unread()
    return [state, s:Error.NIL]
  elseif c is# "\<C-h>"
    " Remove last char
    if no_marker isnot# ''
      call s:_write(a:out, "\<C-h>")
      return [self, s:Error.NIL]
    endif
    " Back to TableNormalState
    let bs = repeat("\<C-h>", strchars(self._marker))
    call s:_write(a:out, bs)
    let state = s:new_table_normal_state(
    \ self._nesk, s:_simple_name(self.name), self._mode_table
    \)
    return [state, s:Error.NIL]
  elseif c is# "\x80"    " backspace is \x80 k b
    let [rest, err] = a:in.read(2)
    if err is# s:Error.NIL && c . rest is# "\<BS>"
      let in = s:StringReader.new("\<C-h>")
      return self.next(in, a:out)
    else
      call a:in.unread()
    endif
    return [self, err]
  elseif c is# "\<Esc>"
    " NOTE: Vim only key: commit preedit and escape to Vim normal mode
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, a:in, err)
    endif
    call s:_write(a:out, "\<Esc>")
    return [s:Nesk.new_black_hole_state(self.name), s:Error.NIL]
  elseif c is# "\<C-g>"
    if no_marker isnot# ''
      " Remove inserted string
      let bs = repeat("\<C-h>", strchars(a:out.get_preedit()))
      call s:_write(a:out, bs)
    endif
    " Back to TableNormalState
    let in = s:StringReader.new("\<C-h>")
    return self.next(in, a:out)
  elseif c is# 'l'
    " NOTE: nesk special behavior
    " if preedit is not empty, convert the string and insert to buffer,
    " and back to kana state. (e.g. "Kanjil" -> "kanji")
    let [table, err] = self._nesk.get_table('japanese/hiragana-to-ascii')
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'Cannot load japanese/hiragana-to-ascii table')
      return s:_error(self, a:in, err)
    endif
    let err = s:_append_char_to_preedit(a:in, a:out, table, c)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  elseif c is# 'L'
    " NOTE: nesk special behavior
    " if preedit is not empty, convert the string and insert to buffer,
    " and back to kana state. (e.g. "KanjiL" -> "ｋａｎｊｉ")
    let [table, err] = self._nesk.get_table('japanese/hiragana-to-zenei')
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'Cannot load japanese/hiragana-to-zenei table')
      return s:_error(self, a:in, err)
    endif
    let err = s:_append_char_to_preedit(a:in, a:out, table, c)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  elseif c is# 'q'
    " if preedit is not empty, convert the string and insert to buffer,
    " and back to kana state. (e.g. "Kanjiq" -> "カンジ")
    let [table, err] = self._nesk.get_table('japanese/hiragana-to-katakana')
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'Cannot load japanese/hiragana-to-katakana table')
      return s:_error(self, a:in, err)
    endif
    let err = s:_append_char_to_preedit(a:in, a:out, table, c)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  elseif c is# "\<C-q>"
    " NOTE: nesk special behavior
    " if preedit is not empty, convert the string and insert to buffer,
    " and back to kana state. (e.g. "Kanjiq" -> "ｶﾝｼﾞ")
    let [table, err] = self._nesk.get_table('japanese/hiragana-to-hankata')
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'Cannot load japanese/hiragana-to-hankata table')
      return s:_error(self, a:in, err)
    endif
    let err = s:_append_char_to_preedit(a:in, a:out, table, c)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  elseif c is# 'Q'
    " TODO
    let state = s:new_table_okuri_state(self._mode_table, s:OKURI_MARKER)
    return [state, s:Error.NIL]
  elseif c =~# '^[A-Z]$'
    let in = s:StringReader.new('Q' . tolower(c))
    let state = self
    while in.size() ># 0
      let [state, err] = state.next(in, a:out)
      if err isnot# s:Error.NIL
        return s:_error(state, a:in, err)
      endif
    endwhile
    return [state, s:Error.NIL]
  elseif c is# ' '
    let [dict_table, err] = self._nesk.get_table('skkdict')
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'Cannot load skkdict table')
      return s:_error(self, a:in, err)
    endif
    let bs = repeat("\<C-h>", strchars(a:out.get_preedit()))
    call s:_write(a:out, bs)
    let state = s:new_kanji_convert_state(
    \               self._nesk,
    \               dict_table,
    \               self,
    \               self._marker . buf,
    \               buf,
    \               s:CONVERT_MARKER,
    \               self._mode_table
    \)
    call a:in.unread()
    return state.next(a:in, a:out)
  else
    let err = s:_append_char_to_preedit(a:in, a:out, self._mode_table, c)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    return [self, s:Error.NIL]
  endif
endfunction

function! s:_send_converted_key_in_kana_state(state, in, out, table) abort
  let re = '^\V' . a:state._marker . '\m\zs.\{-}\ze[[:alpha:]]*$'
  let buf = matchstr(a:out.get_preedit(), re)

  " Remove inserted string
  let bs = repeat("\<C-h>", strchars(a:state.get_preedit()))
  call s:_write(a:out, bs)

  if empty(a:state._converted_key)
    let in = s:StringReader.new(a:enter_char)
  else
    let in = s:StringReader.new(a:enter_char . join(a:state._converted_key, '') . a:back_char)
  endif

  " Send a:state._converted_key in the certain mode again
  let state = s:new_hira_mode(a:state._nesk)
  while in.size() ># 0
    let [state, err] = state.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, a:in, err)
    endif
  endwhile
  return [state, s:Error.NIL]
endfunction


function! s:new_kanji_convert_state(nesk, dict_table, prev_state, prev_preedit, key, marker, mode_table) abort
  return {
  \ '_nesk': a:nesk,
  \ '_dict_table': a:dict_table,
  \ '_prev_state': a:prev_state,
  \ '_prev_preedit': a:prev_preedit,
  \ '_key': a:key,
  \ '_marker': a:marker,
  \ '_mode_table': a:mode_table,
  \ 'name': s:_simple_name(a:prev_state.name) . '/kanji',
  \ 'next': function('s:_KanjiConvertState_next0'),
  \}
endfunction

function! s:_KanjiConvertState_next0(in, out) abort dict
  call s:_read_char(a:in)
  let [entry, err] = self._dict_table.get(self._key)
  if err isnot# s:Error.NIL
    return s:_error(self, a:in, err)
  endif
  let SKKDict = s:V.import('Nesk.Table.SKKDict')
  let candidates = SKKDict.Entry.get_candidates(entry)
  if empty(candidates)
    let err = s:Error.new('candidates of ' . string(self._key) . ' are empty')
    return s:_error(self, a:in, err)
  endif
  call s:_write(a:out, self._marker . SKKDict.EntryCandidate.get_string(candidates[0]))
  let state = {
  \ '_nesk': self._nesk,
  \ '_dict_table': self._dict_table,
  \ '_prev_state': self._prev_state,
  \ '_prev_preedit': self._prev_preedit,
  \ '_key': self._key,
  \ '_marker': self._marker,
  \ '_mode_table': self._mode_table,
  \ '_candidates': candidates,
  \ '_cand_idx': 0,
  \ 'name': self._prev_state.name,
  \ 'next': function('s:_KanjiConvertState_next1'),
  \}
  return [state, s:Error.NIL]
endfunction

function! s:_KanjiConvertState_next1(in, out) abort dict
  let c = s:_read_char(a:in)
  let EntryCandidate = s:V.import('Nesk.Table.SKKDict').EntryCandidate
  if c is# "\<C-j>"
    " Remove marker
    let cand = EntryCandidate.get_string(self._candidates[self._cand_idx])
    let bs = repeat("\<C-h>", strchars(self._marker . cand))
    call s:_write(a:out, bs . cand)
    " Back to TableNormalState
    let state = s:new_table_normal_state(
    \ self._nesk, s:_simple_name(self._prev_state.name), self._mode_table
    \)
    return [state, s:Error.NIL]
  elseif c is# "\<CR>"
    " Back to TableNormalState
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, a:in, err)
    endif
    " Handle <CR> in TableNormalState
    call a:in.unread()
    return [state, s:Error.NIL]
  elseif c is# "\<C-g>"
    return s:_restore_prev_state(self, a:out)
  elseif c is# ' '
    if self._cand_idx >=# len(self._candidates) - 1
      " Remove marker
      let cand = EntryCandidate.get_string(self._candidates[self._cand_idx])
      let bs = repeat("\<C-h>", strchars(self._marker . cand))
      call s:_write(a:out, bs . cand)
      " Change to register state
      let state = s:new_register_dict_state(
      \ self._nesk,
      \ self,
      \ self._key,
      \ s:REGDICT_HEAD_MARKER,
      \ s:REGDICT_LEFT_MARKER,
      \ s:REGDICT_RIGHT_MARKER
      \)
      call a:in.unread()
      return state.next(a:in, a:out)
    endif
    let self._cand_idx += 1
    let cand = EntryCandidate.get_string(self._candidates[self._cand_idx])
    let bs = repeat("\<C-h>", strchars(self._marker . cand))
    call s:_write(a:out, bs . self._marker . cand)
    return [self, s:Error.NIL]
  elseif c is# 'x'
    if self._cand_idx <=# 0
      return s:_restore_prev_state(self, a:out)
    endif
    let self._cand_idx -= 1
    let cand = EntryCandidate.get_string(self._candidates[self._cand_idx])
    let bs = repeat("\<C-h>", strchars(self._marker . cand))
    call s:_write(a:out, bs . self._marker . cand)
    return [self, s:Error.NIL]
  else
    " Handle in TableNormalState
    call a:in.unread()
    let in = s:StringReader.new("\<C-j>")
    return self.next(in, a:out)
  endif
endfunction

function! s:_restore_prev_state(state, out) abort
  " Remove marker
  let bs = repeat("\<C-h>", strchars(a:state.get_preedit()))
  call s:_write(a:out, bs . a:state._prev_preedit)
  return [a:state._prev_state, s:Error.NIL]
endfunction

function! s:new_register_dict_state(nesk, prev_state, key, head_marker, left_marker, right_marker) abort
  return {
  \ '_nesk': a:nesk,
  \ '_prev_state': a:prev_state,
  \ '_key': a:key,
  \ '_head_marker': a:head_marker,
  \ '_left_marker': a:left_marker,
  \ '_right_marker': a:right_marker,
  \ 'name': s:_simple_name(a:prev_state.name) . '/registering',
  \ 'next': function('s:_RegisterDictState_next0'),
  \}
endfunction

function! s:_RegisterDictState_next0(in, out) abort dict
  call s:_read_char(a:in)

  " Insert markers
  call s:_write(a:out,
  \ self._head_marker . self._key .
  \ self._left_marker . self._right_marker . "\<Left>"
  \)

  let [skkdict, err] = self._nesk.get_table('skkdict')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load skkdict table')
    return s:_error(self, a:in, err)
  endif
  let state = {
  \ '_key': self._key,
  \ '_prev_state': self._prev_state,
  \ '_sub_state': s:new_hira_mode(self._nesk),
  \ '_bw': s:V.import('Nesk.IO.VimBufferWriter').new(),
  \ '_skkdict': skkdict,
  \ 'name': self._prev_state.name,
  \ 'next': function('s:_RegisterDictState_next1'),
  \}
  return [state, s:Error.NIL]
endfunction

function! s:_RegisterDictState_next1(in, out) abort dict
  while a:in.size() ># 0
    let [self._sub_state, err] = self._sub_state.next(a:in, self._bw)
    if err isnot# s:Error.NIL
      return s:_error(self, a:in, err)
    endif
    " If <CR> was pressed, register the word and return to the previous state
    let word = self._bw.to_string()
    let idx = stridx(word, "\<CR>")
    if idx ># 0
      let err = self._skkdict.register(self._key, word[: idx - 1])
      if err isnot# s:Error.NIL
        return s:_error(self, a:in, err)
      endif
      return [self._prev_state, s:Error.NIL]
    elseif idx is# 0
      return [self._prev_state, s:Error.NIL]
    endif
    call s:_write(a:out, word)
  endwhile
  return [self, s:Error.NIL]
endfunction

" }}}

" Util {{{

function! s:_read_char(in) abort
  let [c, err] = a:in.read_char()
  if !s:Error.is_error(err)
    throw 'Nesk.Mode.SKK: a:in.read_char() returned non-error object: ' . string(err)
  elseif err isnot# s:Error.NIL
    throw 'Nesk.Mode.SKK: ' . err.exception . ' @ ' . err.throwpoint
  endif
  return c
endfunction

function! s:_write(out, str) abort
  let err = a:out.write(a:str)
  if !s:Error.is_error(err)
    throw 'Nesk.Mode.SKK: a:out.write() returned non-error object: ' . string(err)
  elseif err isnot# s:Error.NIL
    throw 'Nesk.Mode.SKK: ' . err.exception . ' @ ' . err.throwpoint
  endif
endfunction

function! s:_commit(out, str) abort
  call s:_write(a:out, a:str . "\<C-j>")
endfunction

function! s:_error(state, in, err) abort
  call a:in.unread()
  return [s:Nesk.new_reset_mode_state(a:state.name), a:err]
endfunction

function! s:_simple_name(name) abort
  let simple = matchstr(a:name, '^[^/]\+/[^/]\+')
  if simple is# ''
    throw 'Nesk.Mode.SKK: could not convert to simple name: ' . string(a:name)
  endif
  return simple
endfunction

" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
