" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


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
  let [str, err] = nesk#get_instance().enable()
  if err is# s:Error.NIL
    return str
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
  return ''
endfunction

function! nesk#disable() abort
  let [str, err] = nesk#get_instance().disable()
  if err is# s:Error.NIL
    return str
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
  return ''
endfunction

function! nesk#toggle() abort
  let [str, err] = nesk#get_instance().toggle()
  if err is# s:Error.NIL
    return str
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
  return ''
endfunction

function! nesk#enabled() abort
  return nesk#get_instance().enabled()
endfunction

function! nesk#init_active_mode() abort
  let err = nesk#get_instance().init_active_mode()
  if err is# s:Error.NIL
    return
  endif
  call s:echomsg('ErrorMsg', err.exception . ' at ' . err.throwpoint)
  sleep 2
endfunction

function! nesk#filter(str) abort
  let [str, err] = nesk#get_instance().filter(a:str)
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
  return nesk#get_instance().get_default_mapped_keys()
endfunction


function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  echomsg a:msg
  echohl None
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
