" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! nesk#init#mode#skk#load(nesk) abort
  let V = vital#nesk#new()
  let SKK = V.import('Nesk.Mode.SKK')
  let Error = V.import('Nesk.Error')
  " Define table builders
  for builder in
  \ [SKK.new_kana_table_builder()] +
  \ [SKK.new_kata_table_builder()] +
  \ [SKK.new_hankata_table_builder()] +
  \ [SKK.new_zenei_table_builder()] +
  \ SKK.new_skkdict_table_builders()
    let err = a:nesk.define_table_builder(builder)
    if err isnot# Error.NIL
      return Error.wrap(err, 'failed to define ' . name . ' table')
    endif
  endfor
  " Define modes
  for mode in [
  \ SKK.new_kana_mode(a:nesk),
  \ SKK.new_kata_mode(a:nesk),
  \ SKK.new_hankata_mode(a:nesk),
  \ SKK.new_ascii_mode(a:nesk),
  \ SKK.new_zenei_mode(a:nesk),
  \]
    let err = a:nesk.define_mode(mode)
    if err isnot# Error.NIL
      let name = type(a:mode) is# v:t_dict && get(a:mode, 'name', '???')
      let name = type(name) isnot# v:t_string ? '???' : name
      return Error.wrap(err, 'failed to define ' . name . ' mode')
    endif
  endfor
  return Error.NIL
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
