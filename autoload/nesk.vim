" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:NONE = []

" TODO: Global variable?
let s:INITIAL_MODE = 'skk/ascii'
" let s:INITIAL_MODE = 'skk/zenei'

let s:nesk = s:NONE


function! s:new_nesk() abort
  let nesk = {}

  let nesk._loaded_rtp = 0
  let nesk._states = []
  let nesk._modes = {}
  let nesk._tables = {}
  let nesk._event_handlers = {}
  let nesk._active_mode_name = ''

  let nesk.load_modes_in_rtp = function('s:Nesk_load_modes_in_rtp')
  let nesk.get_active_mode_name = function('s:Nesk_get_active_mode_name')
  let nesk.set_active_mode_name = function('s:Nesk_set_active_mode_name')
  let nesk.set_states = function('s:Nesk_set_states')
  let nesk.get_mode = function('s:Nesk_get_mode')
  let nesk.add_mode = function('s:Nesk_add_mode')
  let nesk.get_table = function('s:Nesk_get_table')
  let nesk.add_table = function('s:Nesk_add_table')
  let nesk.send_event = function('s:Nesk_send_event')
  let nesk.map_keys = function('s:Nesk_map_keys')
  let nesk.unmap_keys = function('s:Nesk_unmap_keys')

  return nesk
endfunction

function! nesk#get_instance() abort
  if s:nesk is# s:NONE
    let s:nesk = s:new_nesk()
  endif
  return s:nesk
endfunction

function! s:Nesk_load_modes_in_rtp() abort dict
  if self._loaded_rtp
    return
  endif
  runtime! autoload/nesk/mode/*.vim
  let self._loaded_rtp = 1
endfunction

function! s:Nesk_get_active_mode_name() abort dict
  if self._active_mode_name is# ''
    return ['', nesk#error('no active states exist')]
  endif
  return [self._active_mode_name, s:NONE]
endfunction

function! s:Nesk_set_active_mode_name(name) abort dict
  let [_, err] = self.get_mode(a:name)
  if err isnot# s:NONE
    return nesk#wrap_error(err, printf('no such mode (%s)', a:name))
  endif
  let old = self._active_mode_name
  let self._active_mode_name = a:name
  call self.send_event('mode-change', {'old': old, 'new': a:name})
  return s:NONE
endfunction

function! s:Nesk_set_states(states) abort dict
  let self._states = a:states
endfunction

function! s:Nesk_get_mode(name) abort dict
  let mode = get(self._modes, a:name, s:NONE)
  if mode is# s:NONE
    return [s:NONE, nesk#errorf('cannot load mode "%s"', a:name)]
  endif
  return [mode, s:NONE]
endfunction

function! s:Nesk_add_mode(name, mode) abort dict
  let self._modes[a:name] = a:mode
endfunction

function! s:Nesk_get_table(name) abort dict
  let table = get(self._tables, a:name, s:NONE)
  if table is# s:NONE
    return [s:NONE, nesk#errorf('cannot load table "%s"', a:name)]
  endif
  return [table, s:NONE]
endfunction

function! s:Nesk_add_table(name, table) abort dict
  let self._tables[a:name] = a:table
endfunction


function! s:Nesk_send_event(name, value) abort dict
  for handler in get(self._event_handlers, a:name, [])
    if type(handler) is# type(function('function'))
      call call(handler, [a:value])
    endif
  endfor
endfunction

function! s:Nesk_map_keys() abort dict
  for lhs in nesk#get_default_mapped_keys()
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lmap <expr>' lhs 'nesk#filter(' . string(lhs) . ')'
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
  let nesk = nesk#get_instance()
  call nesk.load_modes_in_rtp()
  let mode_name = s:INITIAL_MODE
  let [mode, err] = nesk.get_mode(mode_name)
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ''
  endif
  call nesk.set_states([mode])
  call nesk.set_active_mode_name(mode_name)
  call nesk.map_keys()
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
  if !nesk#enabled()
    return ''
  endif
  let nesk = nesk#get_instance()
  call nesk.set_states([])
  call nesk.set_active_mode_name('')
  call nesk.unmap_keys()
  if mode() =~# '^[ic]$'
    " NOTE: Vim can't escape lang-mode immediately
    " in insert-mode or commandline-mode.
    " We have to use i_CTRL-^ .
    setlocal iminsert=0 imsearch=0
    redrawstatus
    let [mode, err] = nesk.get_mode(s:INITIAL_MODE)
    if err is# s:NONE &&
    \   has_key(state, 'commit') &&
    \   type(state.commit) is# type(function('function'))
      return state.commit() . "\<C-^>"
    endif
    return "\<C-^>"
  else
    setlocal iminsert=0 imsearch=0
    redrawstatus
    return ''
  endif
endfunction

function! nesk#toggle() abort
  return nesk#enabled() ? nesk#disable() : nesk#enable()
endfunction

function! nesk#enabled() abort
  let nesk = nesk#get_instance()
  let [_, err] = nesk.get_active_mode_name()
  return &iminsert isnot# 0 && err is# s:NONE
endfunction

function! nesk#filter(c) abort
  let nesk = nesk#get_instance()
  let [name, err] = nesk.get_active_mode_name()
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ''
  endif
  let [mode, err] = nesk.get_mode(name)
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ''
  endif
  return s:filter(mode, a:c)
endfunction

function! s:filter(mode, c) abort
  let old = deepcopy(a:mode.state)
  let a:mode.state = a:mode.state.next(a:c)
  return a:mode.diff(old)
endfunction

function! nesk#define_mode(name, mode) abort
  let nesk = nesk#get_instance()
  let err = s:validate_add_mode_args(nesk, a:name, a:mode)
  if err isnot# s:NONE
    return nesk#wrap_error(err, 'nesk#define_mode()')
  endif
  call nesk.add_mode(a:name, a:mode)
endfunction

function! s:validate_add_mode_args(nesk, name, mode) abort
  if type(a:name) isnot# type('')
    return nesk#error('name is not String')
  endif
  if has_key(a:nesk._modes, a:name)
    return nesk#errorf('mode "%s" is already registered', a:name)
  endif
  return s:validate_mode(a:mode)
endfunction

function! s:validate_mode(mode) abort
  if type(a:mode) isnot# type({})
    return nesk#error('mode is not Dictionary')
  endif
  if !has_key(a:mode, 'diff') || type(a:mode.diff) isnot# type(function('function'))
    return nesk#error('mode.diff does not exist or is not Funcref')
  endif
  if !has_key(a:mode, 'state')
    return nesk#error('mode.state does not exist')
  endif
  return s:validate_state(a:mode.state)
endfunction

function! s:validate_state(state) abort
  if type(a:state) isnot# type({})
    return nesk#error('mode.state is not Dictionary')
  endif
  if !has_key(a:state, 'next') || type(a:state.next) isnot# type(function('function'))
    return nesk#error('mode.state.next is not Dictionary')
  endif
  return s:NONE
endfunction

function! nesk#define_table(name, table) abort
  let nesk = nesk#get_instance()
  let err = s:validate_add_table_args(nesk, a:name, a:table)
  if err isnot# s:NONE
    let err = nesk#wrap_error(err, 'nesk#define_table()')
    call s:echomsg('ErrorMsg', err.error())
  endif
  call nesk.add_table(a:name, a:table)
endfunction

function! s:validate_add_table_args(nesk, name, table) abort
  if type(a:name) isnot# type('')
    return nesk#error('name is not String')
  endif
  if has_key(a:nesk._tables, a:name)
    return nesk#errorf('table "%s" is already registered', a:name)
  endif
  return s:validate_table(a:table)
endfunction

function! s:validate_table(table) abort
  if type(a:table) isnot# type({})
    return nesk#error('table is not Dictionary')
  endif
  return s:NONE
endfunction


function! nesk#errorf(fmt, ...) abort
  let msg = call('printf', [a:fmt] + a:000)
  return {
  \ 'error': function('s:Error_error'),
  \ 'msg': msg,
  \ 'stacktrace': s:caller(1),
  \}
endfunction

function! nesk#error(msg) abort
  return {
  \ 'error': function('s:Error_error'),
  \ 'msg': a:msg,
  \ 'stacktrace': s:caller(1),
  \}
endfunction

function! nesk#wrap_error(err, msg) abort
  return {
  \ 'error': function('s:Error_error'),
  \ 'msg': printf('%s: %s', a:msg, a:err.error()),
  \ 'stacktrace': s:caller(1),
  \}
endfunction

function! nesk#error_none() abort
  return s:NONE
endfunction

function! s:caller(n) abort
  return split(expand('<sfile>'), '\.\.')[: -(a:n + 2)]
endfunction

function! s:Error_error(...) abort dict
  let detailed = !!get(a:000, 0, 0)
  if !detailed
    return self.msg
  endif
  if has_key(self, 'stacktrace')
    return printf('%s in %s', self.msg, join(self.stacktrace, '..'))
  endif
  return self.msg
endfunction


function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  echomsg a:msg
  echohl None
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
