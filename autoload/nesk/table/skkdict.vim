
function! nesk#table#skkdict#new_multi(name, tables) abort
  return extend(nesk#table#multi#new(a:name, a:tables), {
  \ 'reload': function('s:MultiSKKDictTable_reload')
  \})
endfunction

function! s:MultiSKKDictTable_reload() abort dict
  " TODO
endfunction

function! nesk#table#skkdict#new(name, path, sorted, encoding) abort
  return {
  \ '_path': a:path,
  \ '_sorted': a:sorted,
  \ '_encoding': a:encoding,
  \ '_lines': [],
  \ '_lasttime': 0,
  \ 'name': a:name,
  \ 'get': function('s:SKKDictTable_get'),
  \ 'search': function('s:SKKDictTable_search'),
  \ 'reload': function('s:SKKDictTable_reload'),
  \ 'parse': function('s:SKKDictTable_parse'),
  \}
endfunction

function! s:SKKDictTable_get(key, else) abort dict
  " TODO
endfunction

function! s:SKKDictTable_search(prefix, ...) abort dict
  " TODO
  if a:0 is# 0 || a:1 <# 0
    " ...
  endif
endfunction

function! s:SKKDictTable_reload(prefix, ...) abort dict
  let self._lines  = self.parse()
  let self._lasttime = getftime(self._path)
endfunction

function! s:SKKDictTable_parse() abort dict
  " TODO
endfunction
