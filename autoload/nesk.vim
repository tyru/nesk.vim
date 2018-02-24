" vim:foldmethod=marker:fen:sw=4:sts=4
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:NONE = []

" TODO: Global variable?
let s:INITIAL_MODE = 'hira'

function! s:new_nesk() abort
  let nesk = {}

  let nesk._states = []
  let nesk._modes = {}
  let nesk._states = {}
  let nesk._active_mode = s:NONE

  let nesk.get_active_mode = function('Nesk_get_active_mode')
  let nesk.set_states = function('Nesk_set_states')
  let nesk.set_mode = function('Nesk_set_mode')
  let nesk.add_mode = function('Nesk_add_mode')
  let nesk.map_keys = function('Nesk_map_keys')
  let nesk.unmap_keys = function('Nesk_unmap_keys')

  return nesk
endfunction

function! s:get_instance() abort
  if s:nesk is# s:NONE
    let s:nesk = s:new_nesk()
  endif
  return s:nesk
endfunction

function! s:Nesk_get_active_mode() abort dict
  if self._active_mode is# s:NONE
    return [s:NONE, s:new_error('no active states exist')]
  endif
  return [self._active_mode, s:NONE]
endfunction

function! s:Nesk_set_states(states) abort dict
  let self._states = a:states
endfunction

function! s:Nesk_set_mode(mode) abort dict
  let self._active_mode = a:mode
endfunction

function! s:Nesk_add_mode(name, mode) abort dict
  let err = s:validate_add_mode_args(a:name, mode)
  if err isnot# s:NONE
    return s:wrap_error(err, 'nesk#define_mode()')
  endif
  let self._modes[a:name] = a:mode
  return s:NONE
endfunction

function! s:validate_add_mode_args(self, name, mode) abort
  if type(a:name) isnot# type('')
    return s:new_error('name is not String')
  endif
  if has_key(a:self._modes, a:name)
    return s:new_errorf('mode "%s" is already registered', a:name)
  endif
  return s:validate_mode(a:mode)
endfunction

function! s:validate_mode(mode) abort
  if type(a:mode) isnot# type({})
    return s:new_error('mode is not Dictionary')
  endif
  if !has_key(a:mode, 'diff') || type(a:mode.diff) isnot# type(function('function'))
    return s:new_error('mode.diff does not exist or not Funcref')
  endif
  if !has_key(a:mode, 'state')
    return s:new_error('mode.state does not exist')
  endif
  return s:validate_state(a:mode.state)
endfunction

function! s:validate_state(state) abort
  if type(a:state) isnot# type({})
    return s:new_error('mode.state is not Dictionary')
  endif
  if !has_key(a:state, 'next') || type(a:state.next) isnot# type(function('function'))
    return s:new_error('mode.state.next is not Dictionary')
  endif
  return s:NONE
endfunction

function! s:Nesk_map_keys() abort dict
  for lhs in nesk#get_default_mapped_keys()
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lmap' lhs 'nesk#filter(' . string(lhs) . ')'
  endfor
endfunction

function! s:Nesk_unmap_keys() abort dict
  for lhs in nesk#get_default_mapped_keys()
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lunmap' lhs
  endfor
endfunction

" TODO: Global variable?
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


function! nesk#enable() abort
  if nesk#enabled()
    return ''
  endif
  let nesk = s:get_instance()
  let [mode, err] = nesk.get_active_mode()
  if err isnot# s:NONE
    echohl ErrorMsg
    echomsg err.error()
    echohl None
    return ''
  endif
  call nesk.set_states([mode])
  call nesk.set_mode(s:INITIAL_MODE)
  call nesk.map_keys()
  let &iminsert = 1
endfunction

function! nesk#disable() abort
  if !nesk#enabled()
    return ''
  endif
  let nesk = s:get_instance()
  call nesk.set_states([])
  call nesk.set_mode(s:NONE)
  call nesk.unmap_keys()
  let &iminsert = 0
endfunction

function! nesk#toggle() abort
  return nesk#enabled() ? nesk#enable() : nesk#disable()
endfunction

function! nesk#enabled() abort
  let nesk = s:get_instance()
  let [_, err] = nesk.get_active_mode()
  return &iminsert isnot# 0 && err is# s:NONE
endfunction

" TODO: While word registeration
function! nesk#filter(c) abort
  let nesk = s:get_instance()
  let [mode, err] = nesk.get_active_mode()
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ''
  endif
  return s:filter(mode, c)
endfunction

function! s:filter(mode, c) abort
  let old = deepcopy(a:mode.state)
  let a:mode.state = a:mode.state.next()
  return a:mode.diff(old)
endfunction

function! nesk#define_mode(name, mode) abort
  let nesk = s:get_instance()
  let err = nesk.add_mode(a:name, a:mode)
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
  endif
endfunction


" TODO: stacktrace?
function! s:new_errorf(fmt, ...) abort
  let msg = call('printf', [a:fmt] + a:000)
  return {'error': function('s:Error_error'), 'msg': msg}
endfunction

" TODO: stacktrace?
function! s:new_error(msg) abort
  return {'error': function('s:Error_error'), 'msg': a:msg}
endfunction

" TODO: stacktrace?
function! s:wrap_error(err, msg) abort
  return {'error': function('s:Error_error'),
  \       'msg': printf('%s: %s', a:msg, a:err.error())}
endfunction

function! s:Error_error() abort dict
  return self.msg
endfunction


function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  echomsg a:msg
  echohl None
endfunction


let &cpo = s:save_cpo
