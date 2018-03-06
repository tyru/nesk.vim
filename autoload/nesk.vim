" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


" TODO: Global variable
let s:KEEP_STATE = 1


function! s:init(V) abort
  let s:Nesk = a:V.import('Nesk')
  let s:Error = a:V.import('Nesk.Error')

  let s:INSTANCE = s:Error.NIL
endfunction
call s:init(vital#nesk#new())


function! nesk#get_instance() abort
  if s:INSTANCE is# s:Error.NIL
    let s:INSTANCE = s:Nesk.new()
  endif
  return s:INSTANCE
endfunction

function! nesk#enable() abort
  let err = nesk#get_instance().enable()
  if err isnot# s:Error.NIL
    call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
    sleep 2
    return ''
  endif
  augroup nesk-disable-hook
    autocmd!
    if s:KEEP_STATE
      " The return value of nesk.init_active_mode() was ignored
      autocmd InsertLeave <buffer> call nesk#get_instance().init_active_mode()
    else
      " The return value of nesk.init_active_mode() was ignored
      " but the return string value is already inserted to buffer at
      " InsertLeave, so it is safe.
      autocmd InsertLeave <buffer> call nesk#get_instance().disable()
    endif
  augroup END
  call s:map_keys(nesk#get_default_mapped_keys())
  if mode() =~# '^[ic]$'
    " NOTE: Vim can't enter lang-mode immediately
    " in insert-mode or commandline-mode.
    " We have to use i_CTRL-^ .
    setlocal iminsert=1 imsearch=1
    redrawstatus
    return "\<C-^>"
  else
    setlocal iminsert=1 imsearch=1
    redrawstatus
    return ''
  endif
endfunction

function! nesk#disable() abort
  let [str, err] = nesk#get_instance().disable()
  if err isnot# s:Error.NIL
    call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
    sleep 2
    return ''
  endif
  call s:unmap_keys(nesk#get_default_mapped_keys())
  setlocal iminsert=0 imsearch=0
  redrawstatus
  return str
endfunction

function! nesk#toggle() abort
  return nesk#get_instance().enabled() ? nesk#disable() : nesk#enable()
endfunction

function! nesk#enabled() abort
  return &iminsert isnot# 0 && nesk#get_instance().enabled()
endfunction

function! nesk#send(str) abort
  let [str, err] = nesk#get_instance().send(a:str)
  if err is# s:Error.NIL
    return str
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
  return ''
endfunction

function! nesk#convert(str) abort
  let [str, err] = nesk#get_instance().convert(a:str)
  if err is# s:Error.NIL
    return str
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
  return ''
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


let &cpo = s:save_cpo
unlet s:save_cpo
