" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! nesk#init#mode#skk#load(nesk) abort
  let V = vital#nesk#new()
  let SKK = V.import('Nesk.Mode.SKK')
  let Error = V.import('Nesk.Error')
  let merr = Error.new_multi()
  " Add modes
  for mode in [
  \ SKK.new_hira_mode(a:nesk),
  \ SKK.new_kata_mode(a:nesk),
  \ SKK.new_hankata_mode(a:nesk),
  \ SKK.new_ascii_mode(a:nesk),
  \ SKK.new_zenei_mode(a:nesk),
  \]
    let err = a:nesk.add_mode(mode)
    if err isnot# Error.NIL
      let name = type(a:mode) is# v:t_dict && get(a:mode, 'name', '???')
      let name = type(name) isnot# v:t_string ? '???' : name
      let err = Error.wrap(err, 'failed to add ' . name . ' mode')
      let merr = Error.append(merr, err)
    endif
  endfor
  return merr
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
