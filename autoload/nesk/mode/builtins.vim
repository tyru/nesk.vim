" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:main() abort
  call s:define_ascii_mode()
  call s:define_zenei_mode()
endfunction

" 'ascii' mode {{{

function! s:define_ascii_mode() abort
  let state = s:new_ascii_state()
  let mode = s:new_mode_from_fixed_map_state(state)

  call nesk#define_mode('skk/ascii', mode)
endfunction

function! s:new_ascii_state() abort
  return {
  \ 'converted': '',
  \ 'next': function('s:AsciiState_next'),
  \}
endfunction

function! s:AsciiState_next(c) abort dict
  if a:c ==# "\<C-j>"
    let nesk = nesk#get_instance()
    let err = nesk.set_active_mode_name('skk/hira')
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot set mode to skk/hira'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
    let self.converted = ''
  else
    let self.converted = a:c
  endif
  return self
endfunction

" }}}

" 'zenei' mode {{{

function! s:define_zenei_mode() abort
  let state = s:new_zenei_state()
  let mode = s:new_mode_from_fixed_map_state(state)

  call nesk#define_mode('skk/zenei', mode)
endfunction

function! s:new_zenei_state() abort
  return {
  \ 'next': function('s:ZeneiTable_next0'),
  \}
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
  \ 'converted': '',
  \ 'next': function('s:ZeneiTable_next1'),
  \}
  return next_state.next(a:c)
endfunction

function! s:ZeneiTable_next1(c) abort dict
  if a:c ==# "\<C-j>"
    let nesk = nesk#get_instance()
    let err = nesk.set_active_mode_name('skk/hira')
    if err isnot# nesk#error_none()
      echohl ErrorMsg
      echomsg 'Cannot set mode to skk/hira'
      echomsg err.error(1)
      echohl None
      sleep 1
    endif
    let self.converted = ''
  else
    let self.converted = get(self._table, a:c, a:c)
  endif
  return self
endfunction

" }}}


function! s:new_mode_from_fixed_map_state(state) abort
  return {
  \ 'state': a:state,
  \ 'diff': function('s:FixedConvertMode_diff'),
  \}
endfunction

function! s:FixedConvertMode_diff(old_state) abort dict
  return self.state.converted
endfunction


call s:main()


let &cpo = s:save_cpo
unlet s:save_cpo
