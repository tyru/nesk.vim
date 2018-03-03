" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:init(V) abort
  let s:SKKDictTable = a:V.import('Nesk.Table.SKKDict')
endfunction
call s:init(vital#nesk#new())


function! nesk#table#skkdict#new(name, path, sorted, encoding) abort
  return s:SKKDictTable.new(a:name, a:path, a:sorted, a:encoding)
endfunction

function! nesk#table#skkdict#new_multi(name, tables) abort
  return extend(nesk#table#multi#new(a:name, a:tables), {
  \ 'reload': s:SKKDictTable.Multi.reload
  \})
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo