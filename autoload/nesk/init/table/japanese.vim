" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! nesk#init#table#japanese#load(nesk) abort
  let V = vital#nesk#new()
  let Error = V.import('Nesk.Error')
  let merr = Error.new_multi()
  " Add table builders
  for builder in
  \ [s:new_hiragana_builder(V)] +
  \ [s:new_katakana_builder(V)] +
  \ [s:new_hankata_builder(V)] +
  \ [s:new_zenei_builder(V)] +
  \ [s:new_hiragana_to_katakana_builder(V)] +
  \ [s:new_hiragana_to_hankata_builder(V)] +
  \ s:new_skkdict_builders(V)
    let err = a:nesk.add_table_builder(builder)
    if err isnot# Error.NIL
      let err = Error.wrap(err, 'failed to add ' . name . ' table')
      let merr = Error.append(merr, err)
    endif
  endfor
  return merr
endfunction

function! s:new_hiragana_builder(V) abort
  return {
  \ '_V': a:V,
  \ 'name': 'japanese/hiragana',
  \ '_path': 'autoload/nesk/init/table/japanese_hiragana.json',
  \ 'build': function('s:build'),
  \}
endfunction

function! s:new_katakana_builder(V) abort
  return {
  \ '_V': a:V,
  \ 'name': 'japanese/katakana',
  \ '_path': 'autoload/nesk/init/table/japanese_katakana.json',
  \ 'build': function('s:build'),
  \}
endfunction

function! s:new_hankata_builder(V) abort
  return {
  \ '_V': a:V,
  \ 'name': 'japanese/hankaku-katakana',
  \ '_path': 'autoload/nesk/init/table/japanese_hankata.json',
  \ 'build': function('s:build'),
  \}
endfunction

function! s:new_zenei_builder(V) abort
  return {
  \ '_V': a:V,
  \ 'name': 'japanese/zenei',
  \ '_path': 'autoload/nesk/init/table/japanese_zenei.json',
  \ 'build': function('s:build'),
  \}
endfunction

function! s:new_hiragana_to_katakana_builder(V) abort
  return {
  \ '_V': a:V,
  \ 'name': 'japanese/hiragana-to-katakana',
  \ '_path': 'autoload/nesk/init/table/japanese_hiragana_to_katakana.json',
  \ 'build': function('s:build'),
  \}
endfunction

function! s:new_hiragana_to_hankata_builder(V) abort
  return {
  \ '_V': a:V,
  \ 'name': 'japanese/hiragana-to-hankata',
  \ '_path': 'autoload/nesk/init/table/japanese_hiragana_to_hankata.json',
  \ 'build': function('s:build'),
  \}
endfunction

let s:SKKDICT_TABLES = {
\ 'reg_dict_index': 0,
\ 'tables': [
\   {
\     'name': 'skkdict/user-dict',
\     'path': expand('~/.skkdict/user-dict'),
\     'sorted': 0,
\     'encoding': 'utf-8'
\   },
\   {
\     'name': 'skkdict/system-dict',
\     'path': expand('~/.skkdict/system-dict'),
\     'sorted': 1,
\     'encoding': 'euc-jp'
\   }
\ ]
\}

function! s:new_skkdict_builders(V) abort
  let builders = []
  let Error = a:V.import('Nesk.Error')
  let reg_table = Error.NIL
  for t in s:SKKDICT_TABLES.tables
    let builder = s:new_lazy_import_builder(
    \ a:V, t.name, 'Nesk.Table.SKKDict',
    \ 'builder', [t.name, t.path, t.sorted, t.encoding]
    \)
    let builders += [builder]
  endfor
  " If no sorted dictionaries found, this table is read-only
  let multidict = s:new_lazy_import_builder(
  \ a:V, 'skkdict', 'Nesk.Table.SKKDict',
  \ 'builder_multi', ['skkdict', builders, s:SKKDICT_TABLES.reg_dict_index]
  \)
  " NOTE: Do not add multidict to builders!
  " It causes infinite recursive call because
  " multidict.build() calls each builder build()
  return builders + [multidict]
endfunction

" Delay V.import() of table module
function! s:new_lazy_import_builder(V, name, module, method, args) abort
  function! s:lazy_build() abort closure
    let module = a:V.import(a:module)
    let builder = call(module[a:method], a:args, module)
    return builder.build()
  endfunction
  return {
  \ 'name': a:name,
  \ 'build': funcref('s:lazy_build'),
  \}
endfunction

function! s:build() abort dict
  let Error = self._V.import('Nesk.Error')
  let path = get(globpath(&rtp, self._path, 1, 1), 0, '')
  if path is# ''
    let err = Error.new('could not lookup "' . self._path . '" from runtimepath')
    return [Error.NIL, err]
  endif
  try
    let mappings = json_decode(join(readfile(path), ''))
    let table = self._V.import('Nesk.Table.Hash').new(self.name, mappings)
    return [table, Error.NIL]
  catch
    let err = Error.new(v:exception, v:throwpoint)
    return [Error.NIL, err]
  endtry
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
