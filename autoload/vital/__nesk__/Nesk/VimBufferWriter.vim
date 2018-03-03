" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:StringWriter = a:V.import('Nesk.StringWriter')
endfunction

function! s:_vital_depends() abort
  return ['Nesk.StringWriter']
endfunction


function! s:new() abort
  return {
  \ '_writer': s:StringWriter.new(),
  \ 'write': function('s:_VimBufferWriter_write'),
  \ 'to_string': function('s:_VimBufferWriter_to_string'),
  \}
endfunction

function! s:_VimBufferWriter_write(str) abort dict
  return self._writer.write(a:str)
endfunction

function! s:_VimBufferWriter_to_string() abort dict
  return substitute(self._writer.to_string(), '.\%(' . "\<C-h>" . '\|' . "\<BS>" . '\)', '', 'g')
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
