" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:Nesk = a:V.import('Nesk')
  let s:Error = a:V.import('Nesk.Error')
  let s:StringReader = a:V.import('Nesk.StringReader')
  let s:ERROR_NO_RESULTS = a:V.import('Nesk.Table.Hash').ERROR.NO_RESULTS
endfunction

function! s:_vital_depends() abort
  return ['Nesk', 'Nesk.Error', 'Nesk.StringReader', 'Nesk.Table.Hash']
endfunction


" 'kana' mode {{{

let s:loaded_kana_and_skkdict_table = 0
" TODO: Global variable
let s:SKKDICT_TABLES = {
\ 'name': 'skkdict',
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

function! s:new_kana_mode() abort
  let state = {'next': function('s:KanaState_next')}
  let mode = {'name': 'skk/kana', 'initial_state': state}
  return mode
endfunction

" Set up kana mode: define tables, and change state to TableNormalState.
function! s:KanaState_next(in, out) abort
  let nesk = nesk#get_instance()

  if !s:loaded_kana_and_skkdict_table
    " Define kana table
    let table = nesk#table#kana#new()
    let err = nesk.define_table(table)
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'kana mode failed to register "' . table.name . '" table')
      return [s:Error.NIL, err]
    endif
    " Define skkdict table
    let tables = []
    for t in s:SKKDICT_TABLES.tables
      let table = nesk#table#skkdict#new(t.name, t.path, t.sorted, t.encoding)
      let err = nesk.define_table(table)
      if err isnot# s:Error.NIL
        let err = s:Error.wrap(err, 'kana mode failed to register "' . table.name . '" table')
        return [s:Error.NIL, err]
      endif
      let tables += [table]
    endfor
    let table = nesk#table#skkdict#new_multi(s:SKKDICT_TABLES.name, tables)
    let err = nesk.define_table(table)
    if err isnot# s:Error.NIL
      let err = s:Error.wrap(err, 'kana mode failed to register "' . table.name . '" table')
      return [s:Error.NIL, err]
    endif
    let s:loaded_kana_and_skkdict_table = 1
  endif

  let [table, err] = nesk.get_table('kana')
  if err isnot# s:Error.NIL
    return [s:Error.NIL, s:Error.wrap(err, 'Cannot load kana table')]
  endif

  return s:new_table_normal_state(table).next(a:in, a:out)
endfunction

" }}}

" 'kata' mode {{{

let s:loaded_kata_table = 0

function! s:new_kata_mode() abort
  let state = {'next': function('s:KataState_next')}
  let mode = {'name': 'skk/kata', 'initial_state': state}
  return mode
endfunction

function! s:KataState_next(in, out) abort
  if !s:loaded_kata_table
    call nesk#define_table(nesk#table#kata#new())
    let s:loaded_kata_table = 1
  endif

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('kata')
  if err isnot# s:Error.NIL
    return [s:Error.NIL, s:Error.wrap(err, 'Cannot load kata table')]
  endif

  return s:new_table_normal_state(table).next(a:in, a:out)
endfunction

" }}}

" 'hankata' mode {{{

let s:loaded_hankata_table = 0

function! s:new_hankata_mode() abort
  let state = {'next': function('s:HankataState_next')}
  let mode = {'name': 'skk/hankata', 'initial_state': state}
  return mode
endfunction

function! s:HankataState_next(in, out) abort
  if !s:loaded_hankata_table
    call nesk#define_table(nesk#table#hankata#new())
    let s:loaded_hankata_table = 1
  endif

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('hankata')
  if err isnot# s:Error.NIL
    return [s:Error.NIL, s:Error.wrap(err, 'Cannot load hankata table')]
  endif

  return s:new_table_normal_state(table).next(a:in, a:out)
endfunction

" }}}

" Table Normal State (kana, kata, hankata) {{{

function! s:new_table_normal_state(table) abort
  return {
  \ '_table': a:table,
  \ '_buf': '',
  \ 'commit': function('s:TableNormalState_commit'),
  \ 'next': function('s:TableNormalState_next'),
  \}
endfunction

function! s:TableNormalState_commit() abort dict
  return self._buf
endfunction

" a:in.unread() continues nesk.filter() loop
" after leaving this function.
" (the loop exits when a:in becomes empty)
function! s:TableNormalState_next(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    if self._buf is# ''
      call a:in.unread()
      return [s:Nesk.new_disable_state(), s:Error.NIL]
    else
      return s:do_commit(self, a:out)
    endif
  elseif c is# "\<CR>"
    return s:do_enter(self, a:out)
  elseif c is# "\<C-h>"
    return s:do_backspace(self, a:out)
  elseif c is# "\x80"    " backspace is \x80 k b
    call a:in.unread()
    if a:in.read(3) is# "\<BS>"
      return s:do_backspace(self, a:out)
    endif
    return [self, s:Error.NIL]
  elseif c is# 'L'
    if self._buf is# ''
      call a:in.unread()
      let name = self._table.name is# 'kana' ? 'skk/zenei' : 'skk/kana'
      return [s:Nesk.new_mode_change_state(name), s:Error.NIL]
    endif
    return [self, s:Error.NIL]
  elseif c is# 'l'
    if self._buf is# ''
      call a:in.unread()
      let name = self._table.name is# 'kana' ? 'skk/ascii' : 'skk/kana'
      return [s:Nesk.new_mode_change_state(name), s:Error.NIL]
    endif
    return [self, s:Error.NIL]
  elseif c is# 'q'
    if self._buf is# ''
      call a:in.unread()
      let name = self._table.name is# 'kana' ? 'skk/kata' : 'skk/kana'
      return [s:Nesk.new_mode_change_state(name), s:Error.NIL]
    endif
    return [self, s:Error.NIL]
  elseif c is# "\<C-q>"
    if self._buf is# ''
      call a:in.unread()
      let name = self._table.name is# 'kana' ? 'skk/hankata' : 'skk/kana'
      return [s:Nesk.new_mode_change_state(name), s:Error.NIL]
    endif
    return [self, s:Error.NIL]
  elseif c =~# 'Q'
    " TODO
    let str = '$'
    call a:out.write(str)
    return [self, s:Error.NIL]
  elseif c =~# '^[A-Z]$'
    let rest = a:in.read(a:in.size())
    let in = s:StringReader.new('Q' . tolower(c) . rest)
    let nesk = nesk#get_instance()
    return nesk.transit(self, in, a:out)
  elseif c is# "\<Esc>"
    return s:do_escape(self, a:out)
  elseif c is# "\<C-g>"
    return s:do_cancel(self, a:out)
  else
    let [cands, err] = self._table.search(self._buf . c)
    if err isnot# s:Error.NIL
      " This must not be occurred in this table object
      return [s:Error.NIL, s:Error.wrap(err, 'table.search() returned non-nil error')]
    endif
    if empty(cands)
      let [pair, err] = self._table.get(self._buf)
      if err is# s:ERROR_NO_RESULTS
        let bs = repeat("\<C-h>", strchars(self._buf))
        let str = bs . c
        let self._buf = c
      else
        let bs = repeat("\<C-h>", strchars(self._buf))
        let str = bs . pair[0] . pair[1] . c
        let self._buf = pair[1] . c
      endif
    elseif len(cands) is# 1
      let bs = repeat("\<C-h>", strchars(self._buf))
      let pair = cands[0][1]
      let str = bs . pair[0] . pair[1]
      let self._buf = pair[1]
    else
      let str = c
      let self._buf .= c
    endif
    call a:out.write(str)
    return [self, s:Error.NIL]
  endif
endfunction

function! s:do_escape(state, out) abort
  if a:state._buf isnot# ''
    let bs = repeat("\<C-h>", strchars(a:state._buf))
    call a:out.write(bs)
    let [pair, err] = a:state._table.get(a:state._buf)
    if err isnot# s:ERROR_NO_RESULTS
      call a:out.write(pair[0])
    endif
    let a:state._buf = ''
  endif
  call a:out.write("\<Esc>")
  return [a:state, s:Error.NIL]
endfunction

function! s:do_cancel(state, out) abort
  if a:state._buf isnot# ''
    let bs = repeat("\<C-h>", strchars(a:state._buf))
    call a:out.write(bs)
    let a:state._buf = ''
  endif
  return [a:state, s:Error.NIL]
endfunction

function! s:do_backspace(state, out) abort
  let str = "\<C-h>"
  if a:state._buf isnot# ''
    let a:state._buf = strcharpart(a:state._buf, 0, strchars(a:state._buf)-1)
  endif
  call a:out.write(str)
  return [a:state, s:Error.NIL]
endfunction

function! s:do_enter(state, out) abort
  if a:state._buf isnot# ''
    let bs = repeat("\<C-h>", strchars(a:state._buf))
    call a:out.write(bs)
    let [pair, err] = a:state._table.get(a:state._buf)
    if err isnot# s:ERROR_NO_RESULTS
      call a:out.write(pair[0])
    endif
    let a:state._buf = ''
  endif
  call a:out.write("\<CR>")
  return [a:state, s:Error.NIL]
endfunction

function! s:do_commit(state, out) abort
  call a:out.write(a:state._buf)
  let a:state._buf = ''
  return [a:state, s:Error.NIL]
endfunction

" }}}

" 'ascii' mode {{{

function! s:new_ascii_mode() abort
  let state = {'next': function('s:AsciiState_next')}
  let mode = {'name': 'skk/ascii', 'initial_state': state}
  return mode
endfunction

function! s:AsciiState_next(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    call a:in.unread()
    return [s:Nesk.new_mode_change_state('skk/kana'), s:Error.NIL]
  else
    call a:out.write(c)
  endif
  return [self, s:Error.NIL]
endfunction

" }}}

" 'zenei' mode {{{

let s:loaded_zenei_table = 0

function! s:new_zenei_mode() abort
  let state = {'next': function('s:ZeneiTable_next0')}
  let mode = {'name': 'skk/zenei', 'initial_state': state}
  return mode
endfunction

function! s:ZeneiTable_next0(in, out) abort dict
  if !s:loaded_zenei_table
    call nesk#define_table(nesk#table#zenei#new())
    let s:loaded_zenei_table = 1
  endif

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('zenei')
  if err isnot# s:Error.NIL
    return [s:Error.NIL, s:Error.wrap(err, 'Cannot load zenei table')]
  endif

  let next_state = {
  \ '_table': table,
  \ 'next': function('s:ZeneiTable_next1'),
  \}
  return next_state.next(a:in, a:out)
endfunction

function! s:ZeneiTable_next1(in, out) abort dict
  let c = a:in.read_char()
  if c is# "\<C-j>"
    return [s:Nesk.new_mode_change_state('skk/kana'), s:Error.NIL]
  else
    let [str, err] = self._table.get(c)
    call a:out.write(err is# s:ERROR_NO_RESULTS ? c : str)
  endif
  return [self, s:Error.NIL]
endfunction

" }}}


let &cpo = s:save_cpo
unlet s:save_cpo
