" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! nesk#init#mode#direct#load(nesk) abort
  let V = vital#nesk#new()
  let s:Error = V.import('Nesk.Error')
  let err = a:nesk.add_mode(s:new_direct_mode())
  if err isnot# s:Error.NIL
    return s:Error.wrap(err, 'failed to define direct mode')
  endif
  return s:Error.NIL
endfunction

function! s:new_direct_mode() abort
  return {
  \ 'name': 'direct',
  \ 'next': function('s:next'),
  \}
endfunction

function! s:next(in, out) abort dict
  call a:out.write(a:in.read_char())
  return [self, s:Error.NIL]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
