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
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Error']
endfunction


function! s:new(name, dict) abort
  return {
  \ '_dict': a:dict,
  \ 'name': a:name,
  \ 'get': function('s:_HashTable_get'),
  \ 'search': function('s:_HashTable_search'),
  \}
endfunction

function! s:_HashTable_get(key) abort dict
  if has_key(self._dict, a:key)
    return [self._dict[a:key], s:Error.NIL]
  endif
  return [s:Error.NIL, s:ERROR.NO_RESULTS]
endfunction

function! s:_HashTable_search(prefix, ...) abort dict
  if a:0 is# 0 || a:1 <# 0
    let end = max([len(a:prefix) - 1, 0])
    let result = s:_fold(keys(self._dict), {
    \ result,key ->
    \   key[: end] is# a:prefix ?
    \     result + [[key, self._dict[key]]] : result
    \}, [])
    return [result, s:Error.NIL]
  elseif a:1 is# 0
    return [[], s:Error.NIL]
  else
    let result = []
    let end = max([len(a:prefix) - 1, 0])
    for key in keys(self._dict)
      if key[: end] is# a:prefix
        let result += [[key, self._dict[key]]]
        if len(result) >=# a:1
          return [result, s:Error.NIL]
        endif
      endif
    endfor
    return [result, s:Error.NIL]
  endif
endfunction

function! s:_fold(list, f, init) abort
  let [l, end] = [a:list + [a:init], len(a:list)]
  return map(l, {i,v -> i is# end ? l[i-1] : call(a:f, [l[i-1], v])})[-1]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
