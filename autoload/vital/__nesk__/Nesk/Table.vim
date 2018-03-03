" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_created(M) abort
  let s:ERROR = {}
  let a:M.ERROR = s:ERROR
endfunction

function! s:_vital_loaded(V) abort
  let s:Error = a:V.import('Nesk.Error')
  let s:ERROR.NO_RESULTS = s:Error.new('no results', '')
  unlet s:ERROR
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
