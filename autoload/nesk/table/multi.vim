" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! nesk#table#multi#new(name, tables) abort
  return {
  \ '_tables': a:tables,
  \ 'name': a:name,
  \ 'get': function('s:MultiTable_get'),
  \ 'search': function('s:MultiTable_search'),
  \}
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
