" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_created(M) abort
  let s:ERROR = {}
  let a:M.ERROR = s:ERROR
  let a:M.Multi = s:Multi
endfunction

function! s:_vital_loaded(V) abort
  let s:Error = a:V.import('Nesk.Error')
  let s:ERROR_NO_RESULTS = s:Error.new('no results', '')
  let s:ERROR.NO_RESULTS = s:ERROR_NO_RESULTS
  let s:ERROR_ALREADY_UPTODATE = s:Error.new('dictionary file is already up-to-date', '')
  let s:ERROR.ALREADY_UPTODATE = s:ERROR_ALREADY_UPTODATE
  unlet s:ERROR
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Error']
endfunction


function! s:new(name, path, sorted, encoding) abort
  return {
  \ '_path': a:path,
  \ '_sorted': a:sorted,
  \ '_encoding': a:encoding,
  \
  \ '_lines': [],
  \ '_ari_index': -1,
  \ '_nasi_index': -1,
  \ '_lasttime': 0,
  \
  \ 'name': a:name,
  \ 'reload': function('s:_SKKDictTable_reload'),
  \}
endfunction


function! s:_SKKSortedDictTable_get(key) abort dict
  if a:key is# ''
    return [s:Error.NIL, s:ERROR_NO_RESULTS]
  endif
  let okuri = a:key =~# '^[^[:alpha:]]\+[[:alpha:]]$'
  if okuri
    let min = self._ari_index
    let max = self._nasi_index - 1
  else
    let min = self._nasi_index
    let max = len(self._lines) - 1
  endif
  let key = iconv(a:key, &l:encoding, self._encoding)
  if key is# ''
    let msg = printf('iconv(%s, %s, %s) failed',
    \                 string(a:key), &l:encoding, self._encoding)
    return [s:Error.NIL, s:Error.new(msg)]
  endif

  let [min, max] = s:_bin_search(self._lines, key, okuri, 100, min, max)
  let idx = match(self._lines[: max], '^\V' . key . ' ', min)
  if idx is# -1
    return [s:Error.NIL, s:ERROR_NO_RESULTS]
  endif

  let line = iconv(self._lines[idx], self._encoding, &l:encoding)
  if line is# ''
    let msg = printf('iconv(%s, %s, %s) failed',
    \                 string(line), self._encoding, &l:encoding)
    return [s:Error.NIL, s:Error.new(msg)]
  endif
  return [s:_parse_line(line), s:Error.NIL]
endfunction

function! s:_SKKSortedDictTable_search(prefix, ...) abort dict
  if a:prefix is# ''
    return [s:Error.NIL, s:ERROR_NO_RESULTS]
  endif
  " If prefix has okuri, it must be one or no entry in SKK dictionary
  let okuri = a:prefix =~# '^[^[:alpha:]]\+[[:alpha:]]$'
  if okuri
    let [entry, err] = self.get(a:prefix)
    return [[entry], err]
  endif
  let prefix = iconv(a:prefix, &l:encoding, self._encoding)
  if prefix is# ''
    let msg = printf('iconv(%s, %s, %s) failed',
    \                 string(a:prefix), &l:encoding, self._encoding)
    return [s:Error.NIL, s:Error.new(msg)]
  endif

  let lines = []
  for [okuri, min, max] in [
  \ [1, self._ari_index, self._nasi_index - 1],
  \ [0, self._nasi_index, len(self._lines) - 1],
  \]
    let [min, max] = s:_bin_search(self._lines, prefix, okuri, 100, min, max)
    let start = match(self._lines[: max], '^\V' . prefix, min)
    if start is# -1 || start >=# max
      continue
    endif

    " Get lines until limit
    let [head, c] = matchlist(prefix, '^\(.*\)\(.\)$')[1:2]
    let end = match(self._lines[: max], '^\V' . head . '\m[^' . c . ']', start + 1)
    let end = end is# -1 ? len(self._lines) - 1 : end
    let limit = a:0 && type(a:1) is# v:t_number ? a:1 : -1
    if limit >= 0 && start + limit < end
      let end = start + limit
    endif

    for line in self._lines[start : end]
      let line = iconv(line, self._encoding, &l:encoding)
      if line is# ''
        let msg = printf('iconv(%s, %s, %s) failed',
        \                 string(line), self._encoding, &l:encoding)
        return [s:Error.NIL, s:Error.new(msg)]
      endif
      let lines += [line]
    endfor
  endfor
  return [map(lines, {_,line -> s:_parse_line(line)}), s:Error.NIL]
endfunction

" Narrow [min, max] range until max - min <= limit
function! s:_bin_search(lines, prefix, okuri, limit, min, max) abort
  let [min, max] = [a:min, a:max]
  let mid = min + (max - min) / 2
  let [v1, v2] = a:okuri ? ['max', 'min'] : ['min', 'max']
  while max - min ># a:limit
    let {a:lines[mid] <=# a:prefix ? v1 : v2} = mid
    let mid = min + (max - min) / 2
  endwhile
  return [min, max]
endfunction

function! s:_SKKUnsortedDictTable_get(key) abort dict
  if a:key is# ''
    return [s:Error.NIL, s:ERROR_NO_RESULTS]
  endif
  let key = iconv(a:key, &l:encoding, self._encoding)
  if key is# ''
    let msg = printf('iconv(%s, %s, %s) failed',
    \                 string(a:key), &l:encoding, self._encoding)
    return [s:Error.NIL, s:Error.new(msg)]
  endif
  let idx = match(self._lines, '^\V' . a:key . ' ')
  if idx is# -1
    return [s:Error.NIL, s:ERROR_NO_RESULTS]
  endif
  let line = iconv(self._lines[idx], self._encoding, &l:encoding)
  if line is# ''
    let msg = printf('iconv(%s, %s, %s) failed',
    \                 string(line), self._encoding, &l:encoding)
    return [s:Error.NIL, s:Error.new(msg)]
  endif
  return [s:_parse_line(line), s:Error.NIL]
endfunction

function! s:_SKKUnsortedDictTable_search(prefix, ...) abort dict
  if a:prefix is# ''
    return [s:Error.NIL, s:ERROR_NO_RESULTS]
  endif
  " If prefix has okuri, it must be one or no entry in SKK dictionary
  let okuri = a:prefix =~# '^[^[:alpha:]]\+[[:alpha:]]$'
  if okuri
    let [entry, err] = self.get(a:prefix)
    return [[entry], err]
  endif
  let prefix = iconv(a:prefix, &l:encoding, self._encoding)
  if prefix is# ''
    let msg = printf('iconv(%s, %s, %s) failed',
    \                 string(a:prefix), &l:encoding, self._encoding)
    return [s:Error.NIL, s:Error.new(msg)]
  endif

  " Get lines until limit
  let limit = a:0 && type(a:1) is# v:t_number ? a:1 : 1/0
  let lines = []
  let start = -1
  let max = len(self._lines)
  while len(lines) <# limit
    let start = match(self._lines, '^\V' . prefix, start + 1)
    if start is# -1 || start >=# max
      break
    endif
    let line = iconv(self._lines[start], self._encoding, &l:encoding)
    if line is# ''
      let msg = printf('iconv(%s, %s, %s) failed',
      \                 string(self._lines[start]), self._encoding, &l:encoding)
      return [s:Error.NIL, s:Error.new(msg)]
    endif
    let lines += [line]
  endwhile
  return [map(lines, {_,line -> s:_parse_line(line)}), s:Error.NIL]
endfunction

function! s:_SKKDictTable_reload() abort dict
  if self._lasttime >=# getftime(self._path)
    return s:ERROR_ALREADY_UPTODATE
  endif
  let err = s:_parse(self)
  if err isnot# s:Error.NIL
    return err
  endif
  call extend(self, self._sorted ? {
  \ 'get': function('s:_SKKSortedDictTable_get'),
  \ 'search': function('s:_SKKSortedDictTable_search'),
  \} : {
  \ 'get': function('s:_SKKUnsortedDictTable_get'),
  \ 'search': function('s:_SKKUnsortedDictTable_search'),
  \})
  return s:Error.NIL
endfunction

function! s:_parse(table) abort
  let lines = readfile(a:table._path)
  let ari = index(lines, ';; okuri-ari entries.')
  if ari is# -1
    return s:Error.new('no okuri-ari marker')
  endif
  let nasi = index(lines, ';; okuri-nasi entries.', ari + 1)
  if nasi is# -1
    return s:Error.new('no okuri-nasi marker')
  endif
  let a:table._lines = lines
  let a:table._ari_index = ari
  let a:table._nasi_index = nasi
  let a:table._lasttime = getftime(a:table._path)
  return s:Error.NIL
endfunction

function! s:_parse_line(line) abort
  let list = split(a:line, '/')
  let key = list[0][:-2]
  let candidates = list[1:]
  return [key] + map(candidates, {_,c -> split(c, ';')})
endfunction


let s:Multi = {}

function! s:_MultiSKKDictTable_reload() abort dict
  for table in self.tables
    let err = table.reload()
    if err isnot# s:Error.NIL
      return s:Error.wrap(err, table.name . ' table returned an error')
    endif
  endfor
  return s:Error.NIL
endfunction
let s:Multi.reload = function('s:_MultiSKKDictTable_reload')


let &cpo = s:save_cpo
unlet s:save_cpo
