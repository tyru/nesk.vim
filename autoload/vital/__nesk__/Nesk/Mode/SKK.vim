" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Nesk = a:V.import('Nesk')
  let s:Error = a:V.import('Nesk.Error')
  let s:ERROR_NO_RESULTS = a:V.import('Nesk.Table').ERROR.NO_RESULTS
  let s:StringReader = a:V.import('Nesk.IO.StringReader')

  call s:_define_tables()
endfunction

function! s:_vital_depends() abort
  return [
  \ 'Nesk',
  \ 'Nesk.Error',
  \ 'Nesk.IO.StringReader',
  \ 'Nesk.IO.MultiWriter',
  \ 'Nesk.IO.VimBufferWriter',
  \ 'Nesk.Table',
  \ 'Nesk.Table.Kana',
  \ 'Nesk.Table.Kata',
  \ 'Nesk.Table.Hankata',
  \ 'Nesk.Table.Zenei',
  \ 'Nesk.Table.SKKDict',
  \]
endfunction

" 'kana' mode {{{

" TODO: Global variable
let s:SKKDICT_TABLES = {
\ 'name': 'skkdict',
\ 'reg_dict_index': 0,
\ 'tables': [
\   {
\     'name': 'skkdict/user-dict',
\     'path': expand('~/.skkdict/user-dict'),
\     'sorted': 0,
\     'encoding': 'utf-8'
\   },
\   {
\     'name': 'skkdict/system-dict',
\     'path': expand('~/.skkdict/system-dict'),
\     'sorted': 1,
\     'encoding': 'euc-jp'
\   }
\ ]
\}
let s:PREEDITING_MARKER = "▽"
let s:OKURI_MARKER = "▼"
let s:CONVERT_MARKER = "▼"
let s:REGDICT_HEAD_MARKER = "▼"
let s:REGDICT_LEFT_MARKER = '【'
let s:REGDICT_RIGHT_MARKER = '】'


function! s:new_kana_mode() abort
  return {'name': 'skk/kana', 'next': function('s:_KanaState_next')}
endfunction

" Set up kana mode: define tables, and change state to TableNormalState.
function! s:_KanaState_next(in, out) abort dict
  let [table, err] = nesk#get_instance().get_table('kana')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load kana table')
    return s:_error(self, err)
  endif
  return s:new_table_normal_state(self.name, table).next(a:in, a:out)
endfunction

" }}}

" 'kata' mode {{{

function! s:new_kata_mode() abort
  return {'name': 'skk/kata', 'next': function('s:_KataState_next')}
endfunction

function! s:_KataState_next(in, out) abort dict
  let [table, err] = nesk#get_instance().get_table('kata')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load kata table')
    return s:_error(self, err)
  endif
  return s:new_table_normal_state(self.name, table).next(a:in, a:out)
endfunction

" }}}

" 'hankata' mode {{{

function! s:new_hankata_mode() abort
  return {'name': 'skk/hankata', 'next': function('s:_HankataState_next')}
endfunction

function! s:_HankataState_next(in, out) abort dict
  let [table, err] = nesk#get_instance().get_table('hankata')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load hankata table')
    return s:_error(self, err)
  endif

  return s:new_table_normal_state(self.name, table).next(a:in, a:out)
endfunction

" }}}

" 'ascii' mode {{{

function! s:new_ascii_mode() abort
  return {'name': 'skk/ascii', 'next': function('s:_AsciiState_next')}
endfunction

function! s:_AsciiState_next(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    " Change mode (must leave one character at least for ModeChangeState)
    call a:in.unread()
    return [s:Nesk.new_mode_change_state(self.name, 'skk/kana'), s:Error.NIL]
  else
    call a:out.write(c)
  endif
  return [self, s:Error.NIL]
endfunction

" }}}

" 'zenei' mode {{{

function! s:new_zenei_mode() abort
  return {'name': 'skk/zenei', 'next': function('s:_ZeneiTable_next0')}
endfunction

function! s:_ZeneiTable_next0(in, out) abort dict
  let [table, err] = nesk#get_instance().get_table('zenei')
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load zenei table')
    return s:_error(self, err)
  endif
  let next_state = {
  \ '_table': table,
  \ 'name': self.name,
  \ 'next': function('s:_ZeneiTable_next1'),
  \}
  return next_state.next(a:in, a:out)
endfunction

function! s:_ZeneiTable_next1(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    " Change mode (must leave one character at least for ModeChangeState)
    call a:in.unread()
    return [s:Nesk.new_mode_change_state(self.name, 'skk/kana'), s:Error.NIL]
  else
    let [str, err] = self._table.get(c)
    if err is# s:ERROR_NO_RESULTS
      let str = c
    elseif err isnot# s:Error.NIL
      return s:_error(self, err)
    endif
    call a:out.write(str)
  endif
  return [self, s:Error.NIL]
endfunction

" }}}


" Table registration {{{

function! s:_new_kana_table_builder() abort
  return s:_new_lazy_keymap_table_builder(
  \ 'kana', 'Nesk.Table.Kana'
  \)
endfunction

function! s:_new_kata_table_builder() abort
  return s:_new_lazy_keymap_table_builder(
  \ 'kata', 'Nesk.Table.Kata'
  \)
endfunction

function! s:_new_hankata_table_builder() abort
  return s:_new_lazy_keymap_table_builder(
  \ 'hankata', 'Nesk.Table.Hankata'
  \)
endfunction

function! s:_new_zenei_table_builder() abort
  return s:_new_lazy_keymap_table_builder(
  \ 'zenei', 'Nesk.Table.Zenei'
  \)
endfunction

function! s:_new_skkdict_table_builders() abort
  let builders = []
  let reg_table = s:Error.NIL
  for t in s:SKKDICT_TABLES.tables
    let builder = s:_new_lazy_import_builder(
    \ t.name, 'Nesk.Table.SKKDict',
    \ 'builder', [t.name, t.path, t.sorted, t.encoding]
    \)
    let builders += [builder]
  endfor
  " If no sorted dictionaries found, this table is read-only
  let multidict = s:_new_lazy_import_builder(
  \ s:SKKDICT_TABLES.name, 'Nesk.Table.SKKDict',
  \ 'builder_multi', [s:SKKDICT_TABLES.name, builders, s:SKKDICT_TABLES.reg_dict_index]
  \)
  " NOTE: Do not add multidict to builders!
  " It causes infinite recursive call because
  " multidict.build() calls each builder build()
  return builders + [multidict]
endfunction

" Delay V.import() of table module
function! s:_new_lazy_keymap_table_builder(name, module) abort
  function! s:_lazy_build() abort closure
    let table = s:V.import(a:module).new(a:name)
    return [table, s:Error.NIL]
  endfunction
  return {
  \ 'name': a:name,
  \ 'build': funcref('s:_lazy_build'),
  \}
endfunction

" Delay V.import() of table module
function! s:_new_lazy_import_builder(name, module, method, args) abort
  function! s:_lazy_build() abort closure
    let module = s:V.import(a:module)
    let builder = call(module[a:method], a:args, module)
    return builder.build()
  endfunction
  return {
  \ 'name': a:name,
  \ 'build': funcref('s:_lazy_build'),
  \}
endfunction

" NOTE: This is called at s:_vital_loaded()
function! s:_define_tables() abort
  let nesk = nesk#get_instance()
  for builder in
  \ [s:_new_kana_table_builder()] +
  \ [s:_new_kata_table_builder()] +
  \ [s:_new_hankata_table_builder()] +
  \ [s:_new_zenei_table_builder()] +
  \ s:_new_skkdict_table_builders()
    let err = nesk.define_table_builder(builder)
    if err isnot# s:Error.NIL
      " this must not be occurred
      throw string(err)
    endif
  endfor
endfunction

" }}}

" Table Normal State (kana, kata, hankata) {{{

function! s:new_table_normal_state(name, mode_table) abort
  return {
  \ '_mode_table': a:mode_table,
  \ '_key': '',
  \ '_simple_name': a:name,
  \ 'name': a:name . '/normal',
  \ 'next': function('s:_TableNormalState_next'),
  \ 'commit': function('s:_TableNormalState_commit'),
  \}
endfunction

" a:in.unread() continues nesk.rewrite() loop
" after leaving this function.
" (the loop exits when a:in becomes empty)
function! s:_TableNormalState_next(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    if self._key is# ''
      return [self, s:Error.NIL]
    endif
    " Commit self._key
    let bs = repeat("\<C-h>", strchars(self._key))
    call a:out.write(bs)
    let [pair, err] = self._mode_table.get(self._key)
    if err is# s:Error.NIL
      call a:out.write(pair[0])
    elseif err isnot# s:ERROR_NO_RESULTS
      return s:_error(self, err)
    endif
    let self._key = ''
    return [self, s:Error.NIL]
  elseif c is# "\<CR>"
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, err)
    endif
    call a:out.write("\<CR>")
    return [self, s:Error.NIL]
  elseif c is# "\<C-h>"
    if self._key isnot# ''
      let self._key = strcharpart(self._key, 0, strchars(self._key)-1)
    endif
    call a:out.write("\<C-h>")
    return [self, s:Error.NIL]
  elseif c is# "\x80"    " backspace is \x80 k b
    let str = c . a:in.read(2)
    if str is# "\<BS>"
      let in = s:StringReader.new("\<C-h>")
      return self.next(in, a:out)
    else
      call a:in.unread()
    endif
    return [self, s:Error.NIL]
  elseif c is# "\<Esc>"
    " NOTE: Vim only key: commit self._buf and escape to Vim normal mode
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, err)
    endif
    call a:out.write("\<Esc>")
    return [s:Nesk.new_black_hole_state(self.name), s:Error.NIL]
  elseif c is# "\<C-g>"
    if self._key isnot# ''
      let bs = repeat("\<C-h>", strchars(self._key))
      call a:out.write(bs)
      let self._key = ''
    endif
    return [self, s:Error.NIL]
  elseif c is# 'l'
    return s:_handle_normal_mode_key(self, 'skk/ascii', a:in, a:out)
  elseif c is# 'L'
    return s:_handle_normal_mode_key(self, 'skk/zenei', a:in, a:out)
  elseif c is# 'q'
    let mode = self.name is# 'skk/kana' ? s:new_kata_mode() : s:new_kana_mode()
    return s:_handle_normal_table_key(self, mode, a:in, a:out)
  elseif c is# "\<C-q>"
    let mode = self.name is# 'skk/kana' ? s:new_hankata_mode() : s:new_kana_mode()
    return s:_handle_normal_table_key(self, mode, a:in, a:out)
  elseif c is# 'Q'
    call a:in.unread()
    let state = s:new_table_preediting_state(
    \ self.name, self._mode_table, s:PREEDITING_MARKER
    \)
    return [state, s:Error.NIL]
  elseif c =~# '^[A-Z]$'
    let in = s:StringReader.new('Q' . tolower(c))
    let state = self
    while in.size() ># 0
      let [state, err] = state.next(in, a:out)
      if err isnot# s:Error.NIL
        return s:_error(state, err)
      endif
    endwhile
    return [state, s:Error.NIL]
  else
    let [cands, err] = self._mode_table.search(self._key . c)
    if err isnot# s:Error.NIL
      " This must not be occurred in this table object
      let err = s:Error.wrap(err, 'table.search() returned non-nil error')
      return s:_error(self, err)
    endif
    if empty(cands)
      let [pair, err] = self._mode_table.get(self._key)
      if err is# s:ERROR_NO_RESULTS
        let bs = repeat("\<C-h>", strchars(self._key))
        let str = bs . c
        let self._key = c
      else
        let bs = repeat("\<C-h>", strchars(self._key))
        let str = bs . pair[0] . pair[1] . c
        let self._key = pair[1] . c
      endif
    elseif len(cands) is# 1
      let bs = repeat("\<C-h>", strchars(self._key))
      let pair = cands[0][1]
      let str = bs . pair[0] . pair[1]
      let self._key = pair[1]
    else
      let str = c
      let self._key .= c
    endif
    call a:out.write(str)
    return [self, s:Error.NIL]
  endif
endfunction

function! s:_handle_normal_mode_key(state, mode_name, in, out) abort
  if a:state._key isnot# ''
    " Commit a:state._key and change mode
    call a:in.unread()
    return a:state.next(s:StringReader.new("\<C-j>"), a:out)
  endif
  " Change mode (must leave one character at least for ModeChangeState)
  call a:in.unread()
  let state = s:Nesk.new_mode_change_state(a:state.name, a:mode_name)
  return [state, s:Error.NIL]
endfunction

function! s:_handle_normal_table_key(state, mode, in, out) abort
  if a:state._key isnot# ''
    " Commit a:state._key and change table
    call a:in.unread()
    return a:state.next(s:StringReader.new("\<C-j>"), a:out)
  endif
  return [a:mode, s:Error.NIL]
endfunction

function! s:_TableNormalState_commit() abort dict
  return repeat("\<C-h>", strchars(self._key))
endfunction


function! s:new_table_preediting_state(simple_name, mode_table, marker) abort
  return {
  \ '_mode_table': a:mode_table,
  \ '_marker': a:marker,
  \ '_key': '',
  \ '_converted_key': [],
  \ '_buf': [],
  \ '_simple_name': a:simple_name,
  \ 'name': a:simple_name . '/preediting',
  \ 'next': function('s:_TablePreeditingState_next0'),
  \ 'commit': function('s:_TablePreeditingState_commit'),
  \}
endfunction

function! s:_TablePreeditingState_next0(in, out) abort dict
  call a:in.read_char()
  call a:out.write(self._marker)
  let state = extend(deepcopy(self), {
  \ 'next': function('s:_TablePreeditingState_next1')
  \})
  return [state, s:Error.NIL]
endfunction

function! s:_TablePreeditingState_next1(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    if self._key isnot# ''
      " Commit self._buf
      let err = s:_convert_key(self, a:in, a:out)
      if err isnot# s:Error.NIL
        return s:_error(self, err)
      endif
      let self._key = ''
    endif
    " Back to TableNormalState
    let buf = join(self._buf, '')
    let bs = repeat("\<C-h>", strchars(self._marker . buf))
    call a:out.write(bs . buf)
    let state = s:new_table_normal_state(self._mode_table)
    return [state, s:Error.NIL]
  elseif c is# "\<CR>"
    " Back to TableNormalState
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, err)
    endif
    " Handle <CR> in TableNormalState
    call a:in.unread()
    return [state, s:Error.NIL]
  elseif c is# "\<C-h>"
    if self._key isnot# ''
      " Remove last char (key)
      let self._key = strcharpart(self._key, 0, strchars(self._key)-1)
      call a:out.write("\<C-h>")
      return [self, s:Error.NIL]
    elseif !empty(self._converted_key)
      " Remove last char (buf)
      call remove(self._converted_key, -1)
      call a:out.write("\<C-h>")
      return [self, s:Error.NIL]
    endif
    " Back to TableNormalState
    let buf = join(self._buf, '')
    let bs = repeat("\<C-h>", strchars(self._marker . buf))
    call a:out.write(bs . buf)
    let state = s:new_table_normal_state(self._mode_table)
    return [state, s:Error.NIL]
  elseif c is# "\x80"    " backspace is \x80 k b
    let str = c . a:in.read(2)
    if str is# "\<BS>"
      let in = s:StringReader.new("\<C-h>")
      return self.next(in, a:out)
    else
      call a:in.unread()
    endif
    return [self, s:Error.NIL]
  elseif c is# "\<Esc>"
    " NOTE: Vim only key: commit self._buf and escape to Vim normal mode
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, err)
    endif
    call a:out.write("\<Esc>")
    return [s:Nesk.new_black_hole_state(self.name), s:Error.NIL]
  elseif c is# "\<C-g>"
    if !empty(self._buf)
      " Remove inserted string
      let n = strchars(self._marker . join(self._buf, '') . self._key)
      let bs = repeat("\<C-h>", n)
      call a:out.write(bs)
    endif
    " Back to TableNormalState
    let state = s:new_table_normal_state(self._mode_table)
    return [state, s:Error.NIL]
  elseif c is# 'l'
    " NOTE: Vim only behavior: if a:state._converted_key is not empty,
    " insert the string to buffer (e.g. "Kanjil" -> "kanji")
    return s:_send_converted_key_in_kana_state(self, a:in, a:out, 'l', "\<C-j>")
  elseif c is# 'L'
    " NOTE: Vim only behavior: if a:state._converted_key is not empty,
    " insert the string to buffer (e.g. "KanjiL" -> "ｋａｎｊｉ")
    return s:_send_converted_key_in_kana_state(self, a:in, a:out, 'L', "\<C-j>")
  elseif c is# 'q'
    " NOTE: Vim only behavior: if a:state._converted_key is not empty,
    " insert the string to buffer (e.g. "Kanjiq" -> "カンジ")
    return s:_send_converted_key_in_kana_state(self, a:in, a:out, 'q', 'q')
  elseif c is# "\<C-q>"
    " NOTE: Vim only behavior: if a:state._converted_key is not empty,
    " insert the string to buffer (e.g. "Kanjiq" -> "ｶﾝｼﾞ")
    return s:_send_converted_key_in_kana_state(self, a:in, a:out, "\<C-q>", "\<C-q>")
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
        return s:_error(state, err)
      endif
    endwhile
    return [state, s:Error.NIL]
  elseif c is# ' '
    let [dict_table, err] = nesk#get_instance().get_table(s:SKKDICT_TABLES.name)
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'Cannot load ' . s:SKKDICT_TABLES.name . ' table')
      return s:_error(self, err)
    endif
    let new_key = join(self._buf, '')
    let inserted = self._marker . join(self._buf, '')
    let bs = repeat("\<C-h>", strchars(inserted . self._key))
    call a:out.write(bs)
    let self._key = ''
    let state = s:new_kanji_convert_state(dict_table, self, inserted, new_key, s:CONVERT_MARKER, self._mode_table)
    call a:in.unread()
    return state.next(a:in, a:out)
  else
    let [cands, err] = self._mode_table.search(self._key . c)
    if err isnot# s:Error.NIL
      " This must not be occurred in this table object
      let err = s:Error.wrap(err, 'table.search() returned non-nil error')
      return s:_error(self, err)
    endif
    if empty(cands)
      let [pair, err] = self._mode_table.get(self._key)
      if err is# s:ERROR_NO_RESULTS
        let bs = repeat("\<C-h>", strchars(self._key))
        call a:out.write(bs)
        let self._key = c
        let err = s:_convert_key(self, a:in, a:out)
        if err isnot# s:Error.NIL
          return s:_error(self, err)
        endif
      else
        let err = s:_convert_key(self, a:in, a:out)
        if err isnot# s:Error.NIL
          return s:_error(self, err)
        endif
        let self._key = c
        call a:out.write(c)
      endif
    elseif len(cands) is# 1
      let pair = cands[0][1]
      let bs = repeat("\<C-h>", strchars(self._key))
      call a:out.write(bs . pair[0] . pair[1])
      let self._buf += [pair[0]]
      let self._converted_key += [self._key . c]
      let self._key = pair[1]
      let err = s:_convert_key(self, a:in, a:out)
      if err isnot# s:Error.NIL
        return s:_error(self, err)
      endif
    else
      call a:out.write(c)
      let self._key .= c
    endif
    return [self, s:Error.NIL]
  endif
endfunction

function! s:_send_converted_key_in_kana_state(state, in, out, enter_char, back_char) abort
  " Remove inserted string
  let bs = repeat("\<C-h>", strchars(a:state._marker . join(a:state._buf, '') . a:state._key))
  call a:out.write(bs)

  if empty(a:state._converted_key)
    let in = s:StringReader.new(a:enter_char)
  else
    let in = s:StringReader.new(a:enter_char . join(a:state._converted_key, '') . a:back_char)
  endif

  " Send a:state._converted_key in the certain mode again
  let state = s:new_kana_mode()
  while in.size() ># 0
    let [state, err] = state.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, err)
    endif
  endwhile
  return [state, s:Error.NIL]
endfunction

" Convert self._key and append the result if succeeded
" XXX: Detect recursive table mapping?
function! s:_convert_key(state, in, out) abort
  let err = s:Error.NIL
  while a:state._key isnot# ''
    let [pair, err] = a:state._mode_table.get(a:state._key)
    if err is# s:ERROR_NO_RESULTS
      break
    endif
    if err isnot# s:Error.NIL
      return err
    endif
    let bs = repeat("\<C-h>", strchars(a:state._key))
    call a:out.write(bs . pair[0] . pair[1])
    let a:state._buf += [pair[0]]
    let a:state._converted_key += [a:state._key]
    let a:state._key = pair[1]
  endwhile
  return s:Error.NIL
endfunction

function! s:_TablePreeditingState_commit() abort dict
  let buf = join(self._buf, '')
  let bs = repeat("\<C-h>", strchars(buf))
  return bs . buf
endfunction


function! s:new_kanji_convert_state(dict_table, prev_state, prev_inserted, key, marker, mode_table) abort
  return {
  \ '_dict_table': a:dict_table,
  \ '_prev_state': a:prev_state,
  \ '_prev_inserted': a:prev_inserted,
  \ '_key': a:key,
  \ '_marker': a:marker,
  \ '_mode_table': a:mode_table,
  \ '_simple_name': a:prev_state._simple_name,
  \ 'name': a:prev_state._simple_name . '/kanji',
  \ 'next': function('s:_KanjiConvertState_next0'),
  \}
endfunction

function! s:_KanjiConvertState_next0(in, out) abort dict
  call a:in.read_char()
  let [entry, err] = self._dict_table.get(self._key)
  if err isnot# s:Error.NIL
    return s:_error(self, err)
  endif
  let SKKDict = s:V.import('Nesk.Table.SKKDict')
  let candidates = SKKDict.Entry.get_candidates(entry)
  if empty(candidates)
    let err = s:Error.new('candidates of ' . string(self._key) . ' are empty')
    return s:_error(self, err)
  endif
  call a:out.write(self._marker . SKKDict.EntryCandidate.get_string(candidates[0]))
  let state = {
  \ '_dict_table': self._dict_table,
  \ '_prev_state': self._prev_state,
  \ '_prev_inserted': self._prev_inserted,
  \ '_key': self._key,
  \ '_marker': self._marker,
  \ '_mode_table': self._mode_table,
  \ '_candidates': candidates,
  \ '_cand_idx': 0,
  \ '_simple_name': self._prev_state._simple_name,
  \ 'name': self._prev_state.name,
  \ 'next': function('s:_KanjiConvertState_next1'),
  \}
  return [state, s:Error.NIL]
endfunction

function! s:_KanjiConvertState_next1(in, out) abort dict
  let c = a:in.read_char()
  let EntryCandidate = s:V.import('Nesk.Table.SKKDict').EntryCandidate
  if c is# "\<C-j>"
    " Remove marker
    let cand = EntryCandidate.get_string(self._candidates[self._cand_idx])
    let bs = repeat("\<C-h>", strchars(self._marker . cand))
    call a:out.write(bs . cand)
    " Back to TableNormalState
    let state = s:new_table_normal_state(self._prev_state.name, self._mode_table)
    return [state, s:Error.NIL]
  elseif c is# "\<CR>"
    " Back to TableNormalState
    let in = s:StringReader.new("\<C-j>")
    let [state, err] = self.next(in, a:out)
    if err isnot# s:Error.NIL
      return s:_error(state, err)
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
      call a:out.write(bs . cand)
      " Change to register state
      let state = s:new_register_dict_state(
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
    call a:out.write(bs . self._marker . cand)
    return [self, s:Error.NIL]
  elseif c is# 'x'
    if self._cand_idx <=# 0
      return s:_restore_prev_state(self, a:out)
    endif
    let self._cand_idx -= 1
    let cand = EntryCandidate.get_string(self._candidates[self._cand_idx])
    let bs = repeat("\<C-h>", strchars(self._marker . cand))
    call a:out.write(bs . self._marker . cand)
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
  let EntryCandidate = s:V.import('Nesk.Table.SKKDict').EntryCandidate
  let cand = EntryCandidate.get_string(a:state._candidates[a:state._cand_idx])
  let bs = repeat("\<C-h>", strchars(a:state._marker . cand))
  call a:out.write(bs . a:state._prev_inserted)
  return [a:state._prev_state, s:Error.NIL]
endfunction

function! s:new_register_dict_state(prev_state, key, head_marker, left_marker, right_marker) abort
  return {
  \ '_prev_state': a:prev_state,
  \ '_key': a:key,
  \ '_head_marker': a:head_marker,
  \ '_left_marker': a:left_marker,
  \ '_right_marker': a:right_marker,
  \ '_simple_name': a:prev_state._simple_name,
  \ 'name': a:prev_state._simple_name . '/registering',
  \ 'next': function('s:_RegisterDictState_next0'),
  \}
endfunction

function! s:_RegisterDictState_next0(in, out) abort dict
  call a:in.read_char()

  " Insert markers
  call a:out.write(
  \ self._head_marker . self._key .
  \ self._left_marker . self._right_marker . "\<Left>"
  \)

  let [skkdict, err] = nesk#get_instance().get_table(s:SKKDICT_TABLES.name)
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot load ' . s:SKKDICT_TABLES.name . ' table')
    return s:_error(self, err)
  endif
  " TODO: name
  let state = {
  \ '_key': self._key,
  \ '_prev_state': self._prev_state,
  \ '_sub_state': s:new_kana_mode(),
  \ '_bw': s:V.import('Nesk.IO.VimBufferWriter').new(),
  \ '_skkdict': skkdict,
  \ 'name': self._prev_state.name,
  \ 'next': function('s:_RegisterDictState_next1'),
  \}
  return [state, s:Error.NIL]
endfunction

function! s:_RegisterDictState_next1(in, out) abort dict
  let out = s:V.import('Nesk.IO.MultiWriter').new([a:out, self._bw])
  while a:in.size() ># 0
    let [self._sub_state, err] = self._sub_state.next(a:in, out)
    if err isnot# s:Error.NIL
      return s:_error(self, err)
    endif
    " If <CR> was pressed, register the word and return to the previous state
    let word = self._bw.to_string()
    if matchstr(word, '.$') is# "\<CR>"
      let err = self._skkdict.register(self._key, word)
      if err isnot# s:Error.NIL
        return s:_error(self, err)
      endif
      return [self._prev_state, s:Error.NIL]
    endif
  endwhile
  return [self, s:Error.NIL]
endfunction

" }}}


function! s:_error(state, err) abort
  if !has_key(a:state, 'name')
    throw string(a:state)
  endif
  return [s:Nesk.new_reset_mode_state(a:state.name), a:err]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
