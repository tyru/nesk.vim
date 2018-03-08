" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

" This script manages:
" * Nesk module instance (singleton)
" * Language mappings
" * Options
" * Auto-commands
" Nesk module does not handle the above states.


function! s:init(V) abort
  let s:Nesk = a:V.import('Nesk')
  let s:Error = a:V.import('Nesk.Error')

  let s:INSTANCE = s:Error.NIL

  " TODO: Global variable
  let s:KEEP_STATE = 1
  let s:MAP_KEYS = nesk#get_default_mapped_keys()

  let s:loaded_rtp = 0
endfunction


function! nesk#get_instance() abort
  if s:INSTANCE isnot# s:Error.NIL
    return s:INSTANCE
  endif
  let s:INSTANCE = s:Nesk.new()
  return s:INSTANCE
endfunction

function! nesk#new() abort
  return s:Nesk.new()
endfunction

function! nesk#enable() abort
  let nesk = nesk#get_instance()
  if !nesk.is_enabled()
    if !s:loaded_rtp
      let err = nesk.load_modes_in_rtp()
      if err isnot# s:Error.NIL
        call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
        return
      endif
      let s:loaded_rtp = 1
    endif
    let err = nesk.enable()
    if err isnot# s:Error.NIL
      call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
      sleep 2
      return ''
    endif
  endif

  call s:enable()
  redrawstatus

  " NOTE: Vim can't enter lang-mode immediately
  " in insert-mode or commandline-mode.
  " We have to use i_CTRL-^ .
  return &l:iminsert isnot# 1 ? "\<C-^>" : ''
endfunction

function! s:enable() abort
  augroup nesk-disable-hook
    autocmd!
    if s:KEEP_STATE
      " The return value of nesk.init_active_mode() was ignored
      autocmd InsertLeave <buffer> call s:init_if_enabled()
    else
      " The return value of nesk.init_active_mode() was ignored
      " but the return string value is already inserted to buffer at
      " InsertLeave, so it is safe.
      autocmd InsertLeave <buffer> call nesk#get_instance().disable()
    endif
  augroup END
  call s:map_keys(s:MAP_KEYS)
  " NOTE: Patch 8.0.1114 changed this default value
  setlocal imsearch=-1
endfunction

function! s:init_if_enabled() abort
  let nesk = nesk#get_instance()
  if nesk.is_enabled()
    call nesk.init_active_mode()
  endif
endfunction

function! nesk#disable() abort
  call s:disable()
  redrawstatus

  if nesk#get_instance().is_enabled()
    let [str, err] = nesk#get_instance().disable()
    if err isnot# s:Error.NIL
      call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
      sleep 2
      return ''
    endif
    return str
  endif
  return ''
endfunction

function! s:disable() abort
  augroup nesk-disable-hook
    autocmd!
  augroup END
  call s:unmap_keys(s:MAP_KEYS)
  setlocal iminsert=0 imsearch=0
endfunction

function! nesk#toggle() abort
  return nesk#is_enabled() ? nesk#disable() : nesk#enable()
endfunction

function! nesk#is_enabled() abort
  return &iminsert isnot# 0 && nesk#get_instance().is_enabled()
endfunction

function! nesk#send(str) abort
  if !nesk#is_enabled()
    call s:echomsg('ErrorMsg',
    \ 'Please run ":call nesk#enable()" before calling nesk#send()')
    return ''
  endif
  let nesk = nesk#get_instance()
  if !s:loaded_rtp
    let err = nesk.load_modes_in_rtp()
    if err isnot# s:Error.NIL
      call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
      return ''
    endif
    let s:loaded_rtp = 1
  endif
  let [str, err] = nesk.send(a:str)
  if err is# s:Error.NIL
    return str
  endif
  call s:disable()
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
  return ''
endfunction

function! nesk#convert(str) abort
  let nesk = nesk#new()
  let err = nesk.load_modes_in_rtp()
  if err isnot# s:Error.NIL
    call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
    return ''
  endif
  let err = nesk.enable()
  if err isnot# s:Error.NIL
    call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
    return ''
  endif
  let [str, err] = nesk.convert(a:str)
  if err isnot# s:Error.NIL
    call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
    return ''
  endif
  return str
endfunction

function! nesk#define_mode(mode) abort
  let err = nesk#get_instance().define_mode(a:mode)
  if err is# s:Error.NIL
    return
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
endfunction

function! nesk#define_table(table) abort
  let err = nesk#get_instance().define_table(a:table)
  if err is# s:Error.NIL
    return
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
endfunction

function! nesk#get_default_mapped_keys() abort
  let keys = split('abcdefghijklmnopqrstuvwxyz', '\zs')
  let keys += split('ABCDEFGHIJKLMNOPQRSTUVWXYZ', '\zs')
  let keys += split('1234567890', '\zs')
  let keys += split('!"#$%&''()', '\zs')
  let keys += split(',./;:]@[-^\', '\zs')
  let keys += split('>?_+*}`{=~', '\zs')
  let keys += [
  \   '<lt>',
  \   '<Bar>',
  \   '<Tab>',
  \   '<BS>',
  \   '<C-h>',
  \   '<CR>',
  \   '<Space>',
  \   '<C-q>',
  \   '<C-y>',
  \   '<C-e>',
  \   '<PageUp>',
  \   '<PageDown>',
  \   '<Up>',
  \   '<Down>',
  \   '<C-n>',
  \   '<C-p>',
  \   '<C-j>',
  \   '<C-g>',
  \   '<Esc>',
  \]
  return keys
endfunction

function! s:map_keys(keys) abort
  for lhs in a:keys
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lnoremap <expr><nowait>' lhs 'nesk#send(' . string(lhs) . ')'
  endfor
endfunction

function! s:unmap_keys(keys) abort
  for lhs in a:keys
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lunmap' lhs
  endfor
endfunction

function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  echomsg a:msg
  echohl None
endfunction


call s:init(vital#nesk#new())


let &cpo = s:save_cpo
unlet s:save_cpo
