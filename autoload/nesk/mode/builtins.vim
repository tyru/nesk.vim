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
  runtime! autoload/nesk/table/kana.vim

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('kana')
  if err isnot# nesk#error_none()
    echohl ErrorMsg
    echomsg 'Cannot load kana table'
    echomsg err.error(1)
    echohl None
    sleep 1
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
  \ 'do_disable': function('s:KanaNormalState_do_disable'),
  \ 'do_commit': function('s:KanaNormalState_do_commit'),
  \ 'do_backspace': function('s:KanaNormalState_do_backspace'),
  \ 'do_enter': function('s:KanaNormalState_do_enter'),
  \}
endfunction

function! s:KanaNormalState_commit() abort dict
  return self._buf
endfunction

function! s:KanaNormalState_next(in, out) abort dict
  let c = a:in.read(1)
  if c is# "\<C-j>"
    return self.do_commit(a:out)
  elseif c is# "\<CR>"
    return self.do_enter(a:out)
  elseif c is# "\<C-h>"
    return self.do_backspace(a:out)
  elseif c is# "\x80"    " backspace is \x80 k b
    call a:in.unread()
    if a:in.read(3) is# "\<BS>"
      return self.do_backspace(a:out)
    endif
    return self
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
  elseif c is# "\<C-g>"
    " TODO
    return self
  elseif c is# "\<Esc>"
    " TODO
    return self
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

function! s:KanaNormalState_do_backspace(out) abort dict
  let str = "\<C-h>"
  if self._buf isnot# ''
    let self._buf = strcharpart(self._buf, 0, strchars(self._buf)-1)
  endif
  call a:out.write(str)
  return self
endfunction

function! s:KanaNormalState_do_enter(out) abort dict
  let bs = repeat("\<C-h>", strchars(self._buf))
  let str = bs . c
  let self._buf = ''
  call a:out.write(str)
  return self
endfunction

function! s:KanaNormalState_do_commit(out) abort dict
  call a:out.write(self._buf)
  let self._buf = ''
endfunction

function! s:KanaNormalState_do_disable(out) abort dict
  let nesk = nesk#get_instance()
  let [str, err] = nesk.disable()
  if err isnot# nesk#error_none()
    echohl ErrorMsg
    echomsg 'Cannot disable skk'
    echomsg err.error(1)
    echohl None
    sleep 1
  endif
  call a:out.write(str)
  return self
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
    let nesk = nesk#get_instance()
    let err = nesk.set_active_mode_name('skk/kana')
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot set mode to skk/kana'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
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
  runtime! autoload/nesk/table/zenei.vim

  let nesk = nesk#get_instance()
  let [table, err] = nesk.get_table('zenei')
  if err isnot# nesk#error_none()
    echohl ErrorMsg
    echomsg 'Cannot load zenei table'
    echomsg err.error(1)
    echohl None
    sleep 1
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
    let nesk = nesk#get_instance()
    let err = nesk.set_active_mode_name('skk/kana')
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot set mode to skk/kana'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
  else
    call a:out.write(self._table.get(c, c))
  endif
  return self
endfunction

" }}}



call s:main()


let &cpo = s:save_cpo
unlet s:save_cpo
