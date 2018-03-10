" vim:foldmethod=marker:fen:
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

if exists('g:loaded_nesk') && g:loaded_nesk
  finish
endif
let g:loaded_nesk = 1

if v:version < 800
  echohl ErrorMsg
  echomsg 'nesk.vim: warning: Your Vim is too old.'
  \       'Please use 8.0 at least.'
  echohl None
endif


noremap! <expr> <Plug>(nesk:enable)     nesk#enable()
noremap! <expr> <Plug>(nesk:disable)    nesk#disable()
noremap! <expr> <Plug>(nesk:toggle)     nesk#toggle()


if !get(g:, 'nesk#no_default_mappings', 0)
  for mode in ['i', 'c']
    if !hasmapto('<Plug>(nesk:toggle)', mode)
      execute 'silent!' mode . 'map' '<unique> <C-j> <Plug>(nesk:toggle)'
    endif
  endfor
endif


let &cpo = s:save_cpo
