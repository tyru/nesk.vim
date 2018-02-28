" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:main() abort
  let SKK = vital#nesk#new().import('Nesk.Mode.SKK')
  call nesk#define_mode(SKK.new_kana_mode())
  call nesk#define_mode(SKK.new_kata_mode())
  call nesk#define_mode(SKK.new_hankata_mode())
  call nesk#define_mode(SKK.new_ascii_mode())
  call nesk#define_mode(SKK.new_zenei_mode())
endfunction
call s:main()


let &cpo = s:save_cpo
unlet s:save_cpo
