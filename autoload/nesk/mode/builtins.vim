" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:main() abort
  call s:define_kana_mode()
  call s:define_ascii_mode()
  call s:define_zenei_mode()
endfunction

" 'kana' mode {{{

function! s:define_kana_mode() abort
  let state = {'next': function('s:KanaState_next')}
  let mode = {'initial_state': state}

  call nesk#define_mode('skk/kana', mode)
endfunction

function! s:KanaState_next(in, out) abort
  call nesk#table#kana#load()

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('kana')
  if err isnot# nesk#error_none()
    return a:out.error(nesk#wrap_error(err, 'Cannot load kana table'))
  endif

  let normal_state = s:new_kana_normal_state(table)
  return normal_state.next(a:in, a:out)
endfunction

function! s:new_kana_normal_state(table) abort
  return {
  \ '_table': a:table,
  \ '_buf': '',
  \ 'commit': function('s:KanaNormalState_commit'),
  \ 'next': function('s:KanaNormalState_next'),
  \}
endfunction

function! s:KanaNormalState_commit() abort dict
  return self._buf
endfunction

function! s:KanaNormalState_next(in, out) abort dict
  let c = a:in.read(1)
  if c is# "\<C-j>"
    if self._buf is# ''
      return s:do_disable(self, a:out)
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
    return self
  elseif c is# 'L' && self._buf is# ''
    return nesk#new_mode_change_state('skk/zenei')
  elseif c is# 'l' && self._buf is# ''
    return nesk#new_mode_change_state('skk/ascii')
  elseif c =~# '^[A-Z]$'
    let rest = a:in.read(a:in.size())
    let in = nesk#new_string_reader(';' . tolower(c) . rest)
    let state = self
    while in.size() ># 0
      let state = state.next(in, a:out)
    endwhile
    return state
  elseif c =~# ';'
    let str = '$'
    call a:out.write(str)
    return self
  elseif c is# "\<Esc>"
    return s:do_escape(self, a:out)
  elseif c is# "\<C-g>"
    return s:do_cancel(self, a:out)
  else
    let cands = self._table.search(self._buf . c)
    if empty(cands)
      let pair = self._table.get(self._buf, nesk#error_none())
      if pair is# nesk#error_none()
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
      let pair = values(cands)[0]
      let str = bs . pair[0] . pair[1]
      let self._buf = pair[1]
    else
      let str = c
      let self._buf .= c
    endif
    call a:out.write(str)
    return self
  endif
endfunction

function! s:do_escape(state, out) abort
  if a:state._buf isnot# ''
    let bs = repeat("\<C-h>", strchars(a:state._buf))
    call a:out.write(bs)
    let pair = a:state._table.get(a:state._buf, nesk#error_none())
    if pair isnot# nesk#error_none()
      call a:out.write(pair[0])
    endif
    let a:state._buf = ''
  endif
  call a:out.write("\<Esc>")
  return a:state
endfunction

function! s:do_cancel(state, out) abort
  if a:state._buf isnot# ''
    let bs = repeat("\<C-h>", strchars(a:state._buf))
    call a:out.write(bs)
    let a:state._buf = ''
  endif
  return a:state
endfunction

function! s:do_backspace(state, out) abort
  let str = "\<C-h>"
  if a:state._buf isnot# ''
    let a:state._buf = strcharpart(a:state._buf, 0, strchars(a:state._buf)-1)
  endif
  call a:out.write(str)
  return a:state
endfunction

function! s:do_enter(state, out) abort
  if a:state._buf isnot# ''
    let bs = repeat("\<C-h>", strchars(a:state._buf))
    call a:out.write(bs)
    let pair = a:state._table.get(a:state._buf, nesk#error_none())
    if pair isnot# nesk#error_none()
      call a:out.write(pair[0])
    endif
    let a:state._buf = ''
  endif
  call a:out.write("\<CR>")
  return a:state
endfunction

function! s:do_commit(state, out) abort
  call a:out.write(a:state._buf)
  let a:state._buf = ''
endfunction

function! s:do_disable(state, out) abort
  let nesk = nesk#get_instance()
  let [str, err] = nesk.disable()
  if err isnot# nesk#error_none()
    return a:out.error(nesk#wrap_error(err, 'Cannot disable skk'))
  endif
  call a:out.write(str)
  return a:state
endfunction

" }}}

" 'ascii' mode {{{

function! s:define_ascii_mode() abort
  let state = {'next': function('s:AsciiState_next')}
  let mode = {'initial_state': state}

  call nesk#define_mode('skk/ascii', mode)
endfunction

function! s:AsciiState_next(in, out) abort dict
  let c = a:in.read(1)
  if c is# "\<C-j>"
    return nesk#new_mode_change_state('skk/kana')
  else
    call a:out.write(c)
  endif
  return self
endfunction

" }}}

" 'zenei' mode {{{

function! s:define_zenei_mode() abort
  let state = {'next': function('s:ZeneiTable_next0')}
  let mode = {'initial_state': state}

  call nesk#define_mode('skk/zenei', mode)
endfunction

function! s:ZeneiTable_next0(in, out) abort dict
  call nesk#table#zenei#load()

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('zenei')
  if err isnot# nesk#error_none()
    return a:out.error(nesk#wrap_error(err, 'Cannot load zenei table'))
  endif

  let next_state = {
  \ '_table': table,
  \ 'next': function('s:ZeneiTable_next1'),
  \}
  return next_state.next(a:in, a:out)
endfunction

function! s:ZeneiTable_next1(in, out) abort dict
  let c = a:in.read(1)
  if c is# "\<C-j>"
    return nesk#new_mode_change_state('skk/kana')
  else
    call a:out.write(self._table.get(c, c))
  endif
  return self
endfunction

" }}}



call s:main()


let &cpo = s:save_cpo
unlet s:save_cpo
