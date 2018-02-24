" vim:foldmethod=marker:fen:sw=4:sts=4
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

function! s:main() abort
  call s:define_hira_mode()
endfunction

function! s:define_hira_mode() abort
  let state = {'_buf': ''}
  function! state.next(c) abort
    let self._buf .= a:c
    return self.next
  endfunction

  let mode = {'state': state}
  function! mode.diff(old_state) abort
    let head_len = len(a:old_state._buf)
    return self.state._buf[head_len :]
  endfunction

  call nesk#define_mode('hira', mode)
endfunction

call s:main()

let &cpo = s:save_cpo
