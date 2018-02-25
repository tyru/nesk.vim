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
  let state = {'next': function('s:KanaState_next0')}
  let mode = {'initial_state': state}

  call nesk#define_mode('skk/kana', mode)
endfunction

function! s:KanaState_next0(c) abort
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

  let next_state = {
  \ '_table': table,
  \ '_buf': '',
  \ 'next': function('s:KanaState_next1'),
  \}
  return next_state.next(a:c)
endfunction

function! s:KanaState_next1(c) abort dict
  if a:c is# "\<C-j>"
    let nesk = nesk#get_instance()
    let [str, err] = nesk.disable()
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot disable skk'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
    return [self, str]
  elseif a:c is# "\<CR>"
    let bs = repeat("\<C-h>", strchars(self._buf))
    let str = bs . a:c
    let self._buf = ''
    return [self, str]
  elseif a:c is# "\<C-h>" || a:c is# "\<BS>"
    let str = "\<C-h>"
    if self._buf isnot# ''
      let self._buf = strcharpart(self._buf, 0, strchars(self._buf)-1)
    endif
    return [self, str]
  elseif a:c =~# '^[A-Z]$'
    let [state, str] = self.next(';')
    let [state, str2] = state.next(tolower(a:c))
    return [state, str . str2]
  elseif a:c =~# ';'
    let str = '$'
    return [self, str]
  elseif a:c is# "\<C-g>"
    " TODO
  elseif a:c is# "\<Esc>"
    " TODO
  else
    let cands = self._table.search(self._buf . a:c)
    if empty(cands)
      let pair = self._table.get(self._buf, nesk#error_none())
      if pair is# nesk#error_none()
        let bs = repeat("\<C-h>", strchars(self._buf))
        let str = bs . a:c
        let self._buf = a:c
      else
        let bs = repeat("\<C-h>", strchars(self._buf))
        let str = bs . pair[0] . pair[1] . a:c
        let self._buf = pair[1] . a:c
      endif
    elseif len(cands) is# 1
      let bs = repeat("\<C-h>", strchars(self._buf))
      let pair = values(cands)[0]
      let str = bs . pair[0] . pair[1]
      let self._buf = pair[1]
    else
      let str = a:c
      let self._buf .= a:c
    endif
    return [self, str]
  endif
endfunction

" }}}

" 'ascii' mode {{{

function! s:define_ascii_mode() abort
  let state = {'next': function('s:AsciiState_next')}
  let mode = {'initial_state': state}

  call nesk#define_mode('skk/ascii', mode)
endfunction

function! s:AsciiState_next(c) abort dict
  if a:c is# "\<C-j>"
    let nesk = nesk#get_instance()
    let err = nesk.set_active_mode_name('skk/kana')
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot set mode to skk/kana'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
    let c = ''
  else
    let c = a:c
  endif
  return [self, c]
endfunction

" }}}

" 'zenei' mode {{{

function! s:define_zenei_mode() abort
  let state = {'next': function('s:ZeneiTable_next0')}
  let mode = {'initial_state': state}

  call nesk#define_mode('skk/zenei', mode)
endfunction

function! s:ZeneiTable_next0(c) abort dict
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
  return next_state.next(a:c)
endfunction

function! s:ZeneiTable_next1(c) abort dict
  if a:c is# "\<C-j>"
    let nesk = nesk#get_instance()
    let err = nesk.set_active_mode_name('skk/kana')
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot set mode to skk/kana'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
    let c = ''
  else
    let c = self._table.get(a:c, a:c)
  endif
  return [self, c]
endfunction

" }}}



call s:main()


let &cpo = s:save_cpo
unlet s:save_cpo
