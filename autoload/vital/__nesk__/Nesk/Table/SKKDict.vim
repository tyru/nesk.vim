" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_created(M) abort
  let s:ERROR = {}
  let a:M.ERROR = s:ERROR
  let a:M.Entry = s:Entry
  let a:M.EntryCandidate = s:EntryCandidate
endfunction

function! s:_vital_loaded(V) abort
  let s:Table = a:V.import('Nesk.Table')
  let s:Error = a:V.import('Nesk.Error')
  unlet s:ERROR
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Table', 'Nesk.Error']
endfunction


function! s:new(name, path, sorted, encoding) abort
  let table = {
  \ '_path': a:path,
  \ '_encoding': a:encoding,
  \
  \ '_lines': [],
  \ '_ari_index': -1,
  \ '_nasi_index': -1,
  \ '_lasttime': 0,
  \
  \ 'name': a:name,
  \ 'reload': function('s:_SKKDictTable_reload'),
  \ 'get': function('s:_SKKDictTable_get'),
  \}
  return extend(table, a:sorted ? {
  \ 'get_index': function('s:_SKKSortedDictTable_get_index'),
  \ 'search': function('s:_SKKSortedDictTable_search'),
  \} : {
  \ 'get_index': function('s:_SKKUnsortedDictTable_get_index'),
  \ 'search': function('s:_SKKUnsortedDictTable_search'),
  \})
endfunction

function! s:_throw(msg, ...) abort
  throw a:msg . ': args =' . string(a:000)
endfunction


function! s:_SKKSortedDictTable_get_index(key) abort dict
  if a:key is# ''
    return [[], -1, s:Table.ERROR.NO_RESULTS]
  endif

  " Re-read lines of dictionary if it is updated after last read
  let err = self.reload()
  if err isnot# s:Error.NIL
    return [[], -1, err]
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
    return [[], -1, s:Table.ERROR.NO_RESULTS]
  endif
  return [self._lines, idx, s:Error.NIL]
endfunction

function! s:_SKKSortedDictTable_search(prefix, ...) abort dict
  if a:prefix is# ''
    return [[], s:Error.NIL]
  endif

  " Re-read lines of dictionary if it is updated after last read
  let err = self.reload()
  if err isnot# s:Error.NIL
    return [s:Error.NIL, err]
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
  let entries = []
  for line in lines
    let [entry, err] = s:Entry.parse_line(line)
    if err isnot# s:Error.NIL
      return [[], err]
    endif
    let entries += [entry]
  endfor
  return [entries, s:Error.NIL]
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

function! s:_SKKUnsortedDictTable_get_index(key) abort dict
  if a:key is# ''
    return [[], -1, s:Table.ERROR.NO_RESULTS]
  endif

  " Re-read lines of dictionary if it is updated after last read
  let err = self.reload()
  if err isnot# s:Error.NIL
    return [[], -1, err]
  endif

  let idx = s:_match_head(self._lines, a:key . ' ', 0, -1)
  if idx is# -1
    return [[], -1, s:Table.ERROR.NO_RESULTS]
  endif
  return [self._lines, idx, s:Error.NIL]
endfunction

function! s:_SKKUnsortedDictTable_search(prefix, ...) abort dict
  if a:prefix is# ''
    return [[], s:Error.NIL]
  endif

  " Re-read lines of dictionary if it is updated after last read
  let err = self.reload()
  if err isnot# s:Error.NIL
    return [s:Error.NIL, err]
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
  let entries = []
  for line in lines
    let [entry, err] = s:Entry.parse_line(line)
    if err isnot# s:Error.NIL
      return [[], err]
    endif
    let entries += [entry]
  endfor
  return [entries, s:Error.NIL]
endfunction

function! s:_SKKDictTable_reload() abort dict
  if self._lasttime >=# getftime(self._path)
    return s:Error.NIL
  endif
  let lines = readfile(self._path)
  let ari = index(lines, ';; okuri-ari entries.')
  if ari is# -1
    return s:Error.new('no okuri-ari marker')
  endif
  let nasi = index(lines, ';; okuri-nasi entries.', ari + 1)
  if nasi is# -1
    return s:Error.new('no okuri-nasi marker')
  endif
  if self._encoding ==? &l:encoding
    let self._lines = lines
  else
    let self._lines = map(lines, 'iconv(v:val, self._encoding, &l:encoding)')
  endif
  let self._ari_index = ari
  let self._nasi_index = nasi
  let self._lasttime = getftime(self._path)
  return s:Error.NIL
endfunction

function! s:_SKKDictTable_get(key) abort dict
  let [lines, idx, err] = self.get_index(a:key)
  if err isnot# s:Error.NIL || idx is# -1
    return [s:Error.NIL, err]
  endif
  return s:Entry.parse_line(lines[idx])
endfunction


function! s:_match_head(lines, prefix, start, end) abort
  let re = '^' . join(map(split(a:prefix, '\zs'), {_,c -> '\%d' . char2nr(c)}), '')
  return match(a:lines[: a:end], re, a:start)
endfunction


" If no sorted dictionaries found, this table is read-only.
" (table.register() will always fail)
function! s:new_multi(name, tables, reg_table) abort
  return {
  \ 'name': a:name,
  \ '_tables': a:tables,
  \ '_reg_table': a:reg_table,
  \ 'get': function('s:_MultiSKKDictTable_get'),
  \ 'search': function('s:_MultiSKKDictTable_search'),
  \ 'register': function('s:_MultiSKKDictTable_register'),
  \}
endfunction

function! s:_MultiSKKDictTable_get(key) abort dict
  let cands = []
  for table in self._tables
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

function! s:_MultiSKKDictTable_search(prefix, ...) abort dict
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

" If no sorted dictionaries found, this function will always fail.
function! s:_MultiSKKDictTable_register(key, word) abort dict
  if self._reg_table is# s:Error.NIL
    return s:Error.new('skkdict is read-only because no registerable settings found')
  endif
  if type(a:key) isnot# v:t_string || a:key is# '' || a:key[0] is# ';'
    return s:Error.new('invalid key: ' . string(a:key))
  endif
  if type(a:word) isnot# v:t_string || stridx(a:word, '/') isnot# -1
    return s:Error.new('word must not contain /: ' . string(a:key))
  endif

  let err = self._reg_table.reload()
  if err isnot# s:Error.NIL
    return err
  endif

  let [lines, idx, err] = self._reg_table.get_index(a:key)
  if err isnot# s:Error.NIL && err isnot# s:Table.ERROR.NO_RESULTS
    return err
  endif

  " Create a new entry
  let semi = stridx(a:word, ';')
  if semi is# -1
    let new_cand = s:EntryCandidate.new(a:word, '')
  else
    let new_cand = s:EntryCandidate.new(a:word[: semi - 1], a:word[semi + 1 :])
  endif

  if idx is# -1
    let [line, err] = s:Entry.to_line(s:Entry.new(a:key, [new_cand]))
    if err isnot# s:Error.NIL
      return err
    endif
    call writefile([line], self._reg_table._path, 'a')
  else
    let [entry, err] = s:Entry.parse_line(lines[idx])
    let [entry, err] = s:Entry.add_candidate(entry, new_cand)
    if err isnot# s:Error.NIL
      return err
    endif
    let [line, err] = s:Entry.to_line(entry)
    if err isnot# s:Error.NIL
      return err
    endif
    let lines = copy(lines)
    let lines[idx] = line
    call writefile(lines, self._reg_table._path, '')
  endif

  return self._reg_table.reload()
endfunction


let s:Entry = {}

function! s:_Entry_new(key, cands) abort
  return [a:key] + a:cands
endfunction
let s:Entry.new = function('s:_Entry_new')

function! s:_Entry_parse_line(line) abort
  let list = split(a:line, '/')
  if len(list) <# 2
    let err = s:Error.new('SKK dictionary parse error: line = ' . string(a:line))
    return [s:Error.NIL, err]
  endif
  let key = list[0][:-2]
  let candidates = list[1:]
  let entry = [key] + map(candidates, {_,c -> add(split(c, ';'), '')})
  return [entry, s:Error.NIL]
endfunction
let s:Entry.parse_line = function('s:_Entry_parse_line')

function! s:_Entry_to_line(entry) abort
  let err = s:_validate_entry(a:entry)
  if err is# s:Error.NIL
    let cands = map(a:entry[1:], {_,c -> c[1] is# '' ? c[0] : c[0] . ';' . c[1]})
    let line = a:entry[0] . ' /' . join(cands, '/') . '/'
    return [line, s:Error.NIL]
  endif
  return ['', err]
endfunction
let s:Entry.to_line = function('s:_Entry_to_line')

function! s:_Entry_add_candidate(entry, cand) abort
  let err = s:_validate_entry(a:entry)
  let err = s:Error.append(err, s:_validate_candidate(a:cand))
  if err is# s:Error.NIL
    return [a:entry + [a:cand], s:Error.NIL]
  endif
  return [a:entry, err]
endfunction
let s:Entry.add_candidate = function('s:_Entry_add_candidate')

function! s:_Entry_get_key(entry) abort
  return a:entry[0]
endfunction
let s:Entry.get_key = function('s:_Entry_get_key')

function! s:_Entry_get_candidates(entry) abort
  return a:entry[1:]
endfunction
let s:Entry.get_candidates = function('s:_Entry_get_candidates')

function! s:_validate_entry(entry) abort
  if type(a:entry) isnot# v:t_list || len(a:entry) <# 2
    return s:Error.new('invalid entry: ' . string(a:entry))
  endif
  return s:Error.NIL
endfunction


let s:EntryCandidate = {}

function! s:_EntryCandidate_new(str, annotation) abort
  return [a:str, a:annotation]
endfunction
let s:EntryCandidate.new = function('s:_EntryCandidate_new')

function! s:_EntryCandidate_get_string(cand) abort
  return a:cand[0]
endfunction
let s:EntryCandidate.get_string = function('s:_EntryCandidate_get_string')

function! s:_EntryCandidate_get_annotation(cand) abort
  return a:cand[1]
endfunction
let s:EntryCandidate.get_annotation = function('s:_EntryCandidate_get_annotation')

function! s:_validate_candidate(cand) abort
  if type(a:cand) isnot# v:t_list || len(a:cand) < 2
    return s:Error.new('invalid candidate: ' . string(a:cand))
  endif
  return s:Error.NIL
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
