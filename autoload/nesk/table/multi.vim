" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:init(V) abort
  let s:MultiTable = a:V.import('Nesk.Table.Multi')
endfunction
call s:init(vital#nesk#new())


function! nesk#table#multi#new(name, tables) abort
  return s:MultiTable.new(a:name, a:tables)
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
