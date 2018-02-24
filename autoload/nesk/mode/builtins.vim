" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

function! s:main() abort
  call s:define_ascii_mode()
  call s:define_zenei_mode()
endfunction

function! s:define_ascii_mode() abort
  let state = {'converted': ''}
  function! state.next(c) abort
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

  let mode = s:new_mode_from_fixed_map_state(state)

  call nesk#define_mode('skk/ascii', mode)
endfunction


function! s:define_zenei_mode() abort
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

  let state = {'converted': '', '_table': table}
  function! state.next(c) abort
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

  let mode = s:new_mode_from_fixed_map_state(state)

  call nesk#define_mode('skk/zenei', mode)
endfunction

function! s:new_mode_from_fixed_map_state(state) abort
  let mode = {'state': a:state}
  function! mode.diff(old_state) abort
    return self.state.converted
  endfunction
  return mode
endfunction

call s:main()

let &cpo = s:save_cpo
unlet s:save_cpo
