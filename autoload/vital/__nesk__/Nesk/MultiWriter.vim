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


function! s:new(writers) abort
  return {
  \ '_writers': a:writers,
  \ 'write': function('s:_MultiWriter_write'),
  \}
endfunction

function! s:_MultiWriter_write(str) abort dict
  let merr = s:Error.new_multi()
  for w in self._writers
    let merr = s:Error.append(merr, w.write(a:str))
  endfor
  return merr
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
