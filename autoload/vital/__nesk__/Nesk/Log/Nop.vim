" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:new(options) abort
  return {'log': function('s:_NopLogger_log')}
endfunction

function! s:_NopLogger_log(...) abort dict
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

