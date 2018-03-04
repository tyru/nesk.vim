" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_created(M) abort
  let s:ERROR = {}
  let a:M.ERROR = s:ERROR
  let a:M.Multi = s:Multi
  let a:M.Entry = s:Entry
  let a:M.EntryCandidate = s:EntryCandidate
endfunction

function! s:_vital_loaded(V) abort
  let s:Table = a:V.import('Nesk.Table')
  let s:Error = a:V.import('Nesk.Error')
  let s:ERROR_ALREADY_UPTODATE = s:Error.new('dictionary file is already up-to-date', '')
  let s:ERROR.ALREADY_UPTODATE = s:ERROR_ALREADY_UPTODATE
  unlet s:ERROR
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Table', 'Nesk.Error']
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
  \ 'get': function('s:_throw', ['Must call SKKDict.reload() before SKKDict.get()']),
  \ 'search': function('s:_throw', ['Must call SKKDict.reload() before SKKDict.search()']),
  \}
endfunction

function! s:_throw(msg, ...) abort
  throw a:msg . ': args =' . string(a:000)
endfunction


function! s:_SKKSortedDictTable_get(key) abort dict
  if a:key is# ''
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  let okuri = a:key =~# '^[^[:alpha:]]\+[[:alpha:]]$'
  if okuri
    let min = self._ari_index
    let max = self._nasi_index - 1
  else
    let min = self._nasi_index
    let max = len(self._lines) - 1
  endif

  let [min, max] = s:_bin_search(self._lines, a:key, okuri, 100, min, max)
  let idx = s:_match_head(self._lines, a:key . ' ', min, max)
  if idx is# -1
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  return [s:_parse_line(self._lines[idx]), s:Error.NIL]
endfunction

function! s:_SKKSortedDictTable_search(prefix, ...) abort dict
  if a:prefix is# ''
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  " If prefix has okuri, it must be one or no entry in SKK dictionary
  let okuri = a:prefix =~# '^[^[:alpha:]]\+[[:alpha:]]$'
  if okuri
    let [entry, err] = self.get(a:prefix)
    return [[entry], err]
  endif

  let lines = []
  for [okuri, min, max] in [
  \ [1, self._ari_index, self._nasi_index - 1],
  \ [0, self._nasi_index, len(self._lines) - 1],
  \]
    let [min, max] = s:_bin_search(self._lines, a:prefix, okuri, 100, min, max)
    let start = s:_match_head(self._lines, a:prefix, min, max)
    if start is# -1 || start >=# max
      continue
    endif

    " Get lines until limit
    let i = start + 1
    let len = len(self._lines)
    while i <# len && !stridx(self._lines[i], a:prefix)
      let i += 1
    endwhile
    let end = i - 1
    let limit = a:0 && type(a:1) is# v:t_number ? a:1 : -1
    if limit >= 0 && start + limit < end
      let end = start + limit
    endif
    let lines += self._lines[start : end]
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
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  let idx = s:_match_head(self._lines, a:key . ' ', 0, -1)
  if idx is# -1
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  return [s:_parse_line(self._lines[idx]), s:Error.NIL]
endfunction

function! s:_SKKUnsortedDictTable_search(prefix, ...) abort dict
  if a:prefix is# ''
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  " If prefix has okuri, it must be one or no entry in SKK dictionary
  let okuri = a:prefix =~# '^[^[:alpha:]]\+[[:alpha:]]$'
  if okuri
    let [entry, err] = self.get(a:prefix)
    return [[entry], err]
  endif

  " Get lines until limit
  let limit = a:0 && type(a:1) is# v:t_number ? a:1 : 1/0
  let lines = []
  let start = -1
  let max = len(self._lines)
  while len(lines) <# limit
    let start = s:_match_head(self._lines, a:prefix, start + 1, -1)
    if start is# -1 || start >=# max
      break
    endif
    let lines += [self._lines[start]]
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
  if a:table._encoding ==? &l:encoding
    let a:table._lines = lines
  else
    let a:table._lines = map(lines, 'iconv(v:val, a:table._encoding, &l:encoding)')
  endif
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

function! s:_match_head(lines, prefix, start, end) abort
  let re = '^' . join(map(split(a:prefix, '\zs'), {_,c -> '\%d' . char2nr(c)}), '')
  return match(a:lines[: a:end], re, a:start)
endfunction


let s:Multi = {}

function! s:_MultiSKKDictTable_get(key) abort dict
  let cands = []
  for table in self.tables
    let [entry, err] = table.get(a:key)
    if err isnot# s:Error.NIL
      if err isnot# s:Table.ERROR.NO_RESULTS
        return [s:Error.NIL, err]
      endif
    else
      let cands += s:Entry.get_candidates(entry)
    endif
  endfor
  if empty(cands)
    return [s:Error.NIL, s:Table.ERROR.NO_RESULTS]
  endif
  return [s:Entry.new(a:key, cands), s:Error.NIL]
endfunction
let s:Multi.get = function('s:_MultiSKKDictTable_get')

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


let s:Entry = {}

function! s:_Entry_new(key, cands) abort
  return [a:key] + a:cands
endfunction
let s:Entry.new = function('s:_Entry_new')

function! s:_Entry_get_key(entry) abort
  return a:entry[0]
endfunction
let s:Entry.get_key = function('s:_Entry_get_key')

function! s:_Entry_get_candidates(entry) abort
  return a:entry[1:]
endfunction
let s:Entry.get_candidates = function('s:_Entry_get_candidates')

let s:EntryCandidate = {}

function! s:_EntryCandidate_get_string(cand) abort
  return a:cand[0]
endfunction
let s:EntryCandidate.get_string = function('s:_EntryCandidate_get_string')

function! s:_EntryCandidate_get_annotation(cand) abort
  return a:cand[1]
endfunction
let s:EntryCandidate.get_annotation = function('s:_EntryCandidate_get_annotation')


let &cpo = s:save_cpo
unlet s:save_cpo
