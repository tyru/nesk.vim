" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:main(V) abort
  let SKK = a:V.import('Nesk.Mode.SKK')
  let NIL = a:V.import('Nesk.Error').NIL
  let nesk = nesk#get_instance()
  for mode in [
  \ SKK.new_kana_mode(),
  \ SKK.new_kata_mode(),
  \ SKK.new_hankata_mode(),
  \ SKK.new_ascii_mode(),
  \ SKK.new_zenei_mode(),
  \]
    let err = nesk.define_mode(mode)
    if err isnot# NIL
      " this must not be occurred
      throw string(err)
    endif
  endfor
endfunction
call s:main(vital#nesk#new())


let &cpo = s:save_cpo
unlet s:save_cpo
