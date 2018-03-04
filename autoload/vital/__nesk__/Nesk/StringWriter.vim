" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:Error = a:V.import('Nesk.Error')
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Error']
endfunction


function! s:new(...) abort
  return {
  \ '_str': (a:0 && type(a:1) is# v:t_string ? a:1 : ''),
  \ '_errors': [],
  \ 'write': function('s:_StringWriter_write'),
  \ 'to_string': function('s:_StringWriter_to_string'),
  \}
endfunction


function! s:_StringWriter_write(str) abort dict
  let self._str .= a:str
  return s:Error.NIL
endfunction

function! s:_StringWriter_to_string() abort dict
  return self._str
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
