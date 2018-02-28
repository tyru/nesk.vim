" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:init(V) abort
  let s:HashTable = a:V.import('Nesk.Table.Hash')
endfunction
call s:init(vital#nesk#new())

function! nesk#table#hash#new(...) abort
  return call(s:HashTable.new, a:000, s:HashTable)
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
