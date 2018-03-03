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
  let s:ERROR_NO_RESULTS = s:Error.new('no results', '')
  let s:ERROR.NO_RESULTS = s:ERROR_NO_RESULTS
  unlet s:ERROR
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Error']
endfunction


function! s:new(name, tables) abort
  return {
  \ '_tables': a:tables,
  \ 'name': a:name,
  \ 'get': function('s:_MultiTable_get'),
  \ 'search': function('s:_MultiTable_search'),
  \}
endfunction

function! s:_MultiTable_get(key) abort
  for table in self._tables
    let [l:Value, err] = table.get(a:key)
    if err is# s:Error.NIL
      return [l:Value, s:Error.NIL]
    endif
  endfor
  return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
endfunction

function! s:_MultiTable_search(prefix, ...) abort
  let limit = a:0 && type(a:1) is# v:t_number ? a:1 : 1/0
  let results = []
  let merr = s:Error.new_multi()
  for table in self._tables
    let [list, err] = table.search(a:prefix, limit)
    if err is# s:Error.NIL
      let results += list
      if len(results) >=# limit
        break
      endif
    else
      let merr = s:Error.append(merr, err)
    endif
  endfor
  return [results, merr]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
