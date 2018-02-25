" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:NONE = []

" TODO: Global variable?
let s:INITIAL_MODE = 'skk/kana'
let s:KEEP_STATE = 1

let s:nesk = s:NONE


function! s:new_nesk() abort
  let nesk = {}

  let nesk._loaded_rtp = 0
  let nesk._states = {}
  let nesk._modes = {}
  let nesk._tables = {}
  let nesk._event_handlers = {}
  let nesk._active_mode_name = ''

  let nesk.enable = function('s:Nesk_enable')
  let nesk.disable = function('s:Nesk_disable')
  let nesk.toggle = function('s:Nesk_toggle')
  let nesk.enabled = function('s:Nesk_enabled')
  let nesk.load_modes_in_rtp = function('s:Nesk_load_modes_in_rtp')
  let nesk.init_active_mode = function('s:Nesk_init_active_mode')
  let nesk.get_active_mode_name = function('s:Nesk_get_active_mode_name')
  let nesk.set_active_mode_name = function('s:Nesk_set_active_mode_name')
  let nesk.set_states = function('s:Nesk_set_states')
  let nesk.clear_states = function('s:Nesk_clear_states')
  let nesk.get_active_states = function('s:Nesk_get_active_states')
  let nesk.get_mode = function('s:Nesk_get_mode')
  let nesk.define_mode = function('s:Nesk_define_mode')
  let nesk.get_table = function('s:Nesk_get_table')
  let nesk.define_table = function('s:Nesk_define_table')
  let nesk.send_event = function('s:Nesk_send_event')
  let nesk.map_keys = function('s:Nesk_map_keys')
  let nesk.unmap_keys = function('s:Nesk_unmap_keys')
  let nesk.filter = function('s:Nesk_filter')

  return nesk
endfunction

function! nesk#get_instance() abort
  if s:nesk is# s:NONE
    let s:nesk = s:new_nesk()
  endif
  return s:nesk
endfunction

function! s:Nesk_enable() abort dict
  if self.enabled()
    return ['', nesk#error('already enabled')]
  endif
  call self.load_modes_in_rtp()
  let mode_name = s:INITIAL_MODE
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ['', s:NONE]
  endif
  augroup nesk-disable-hook
    autocmd!
    if s:KEEP_STATE
      autocmd InsertLeave <buffer> call nesk#init_active_mode()
    else
      autocmd InsertLeave <buffer> call nesk#disable()
    endif
  augroup END
  call self.set_states(mode_name, [mode.initial_state])
  let err = self.set_active_mode_name(mode_name)
  if err isnot# s:NONE
    return ['', err]
  endif
  call self.map_keys()
  if mode() =~# '^[ic]$'
    " NOTE: Vim can't enter lang-mode immediately
    " in insert-mode or commandline-mode.
    " We have to use i_CTRL-^ .
    setlocal iminsert=1 imsearch=1
    redrawstatus
    return ["\<C-^>", s:NONE]
  else
    setlocal iminsert=1 imsearch=1
    redrawstatus
    return ['', s:NONE]
  endif
endfunction

function! s:Nesk_disable() abort dict
  if !self.enabled()
    return ['', s:NONE]
  endif
  let committed = ''
  let [states, err] = self.get_active_states()
  if err is# s:NONE && has_key(states[-1], 'commit')
    let committed = states[-1].commit()
  endif
  call self.clear_states()
  let self._active_mode_name = ''
  call self.unmap_keys()
  if mode() =~# '^[ic]$'
    " NOTE: Vim can't escape lang-mode immediately
    " in insert-mode or commandline-mode.
    " We have to use i_CTRL-^ .
    setlocal iminsert=0 imsearch=0
    redrawstatus
    return [committed . "\<C-^>", s:NONE]
  else
    setlocal iminsert=0 imsearch=0
    redrawstatus
    return ['', s:NONE]
  endif
endfunction

function! s:Nesk_toggle() abort dict
  return self.enabled() ? self.disable() : self.enable()
endfunction

function! s:Nesk_enabled() abort dict
  return &iminsert isnot# 0 && self.get_active_mode_name()[1] is# s:NONE
endfunction

function! s:Nesk_load_modes_in_rtp() abort dict
  if self._loaded_rtp
    return
  endif
  runtime! autoload/nesk/mode/*.vim
  let self._loaded_rtp = 1
endfunction

function! s:Nesk_init_active_mode() abort dict
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:NONE
    let err = nesk#wrap_error(err, 'nesk#init_active_mode()')
    call s:echomsg('ErrorMsg', err.error())
    return
  endif
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:NONE
    let err = nesk#wrap_error(err, 'nesk#init_active_mode()')
    call s:echomsg('ErrorMsg', err.error())
    return
  endif
  call self.set_states(mode_name, [mode.initial_state])
endfunction

function! s:Nesk_get_active_mode_name() abort dict
  if self._active_mode_name is# ''
    return ['', nesk#error('no active states exist')]
  endif
  return [self._active_mode_name, s:NONE]
endfunction

function! s:Nesk_set_active_mode_name(name) abort dict
  if self._active_mode_name is# a:name
    return nesk#errorf('current mode is already "%s"', a:name)
  endif
  let [mode, err] = self.get_mode(a:name)
  if err isnot# s:NONE
    return nesk#wrap_error(err, printf('no such mode (%s)', a:name))
  endif
  let old = self._active_mode_name
  let self._active_mode_name = a:name
  call self.set_states(a:name, [mode.initial_state])
  call self.send_event('mode-change', {'old': old, 'new': a:name})
  return s:NONE
endfunction

function! s:Nesk_set_states(mode_name, states) abort dict
  let self._states[a:mode_name] = a:states
endfunction

function! s:Nesk_clear_states() abort dict
  let self._states = {}
endfunction

function! s:Nesk_get_active_states() abort dict
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:NONE
    return [s:NONE, err]
  endif
  let states = get(self._states, mode_name, [])
  if empty(states)
    return [s:NONE, nesk#error('no active state')]
  endif
  return [states, s:NONE]
endfunction

function! s:Nesk_get_mode(name) abort dict
  let mode = get(self._modes, a:name, s:NONE)
  if mode is# s:NONE
    return [s:NONE, nesk#errorf('cannot load mode "%s"', a:name)]
  endif
  return [deepcopy(mode), s:NONE]
endfunction

function! s:Nesk_define_mode(name, mode) abort dict
  let err = s:validate_define_mode_args(self, a:name, a:mode)
  if err isnot# s:NONE
    return nesk#wrap_error(err, 'nesk#define_mode()')
  endif
  if !has_key(a:mode, 'state')
    let a:mode.state = a:mode.initial_state
  endif
  let self._modes[a:name] = a:mode
endfunction

function! s:validate_define_mode_args(nesk, name, mode) abort
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
  " mode.initial_state
  if !has_key(a:mode, 'initial_state')
    return nesk#error('mode.initial_state does not exist')
  endif
  let err = s:validate_state(a:mode.initial_state, 'mode.initial_state')
  if err isnot# s:NONE
    return err
  endif
  " mode.state (optional)
  if has_key(a:mode, 'state')
    return s:validate_state(a:mode.state, 'mode.state')
  endif
  return s:NONE
endfunction

function! s:validate_state(state, name) abort
  if type(a:state) isnot# type({})
    return nesk#error(a:name . ' is not Dictionary')
  endif
  " mode.next
  if !has_key(a:state, 'next') || type(a:state.next) isnot# type(function('function'))
    return nesk#error(a:name . '.next is not Funcref')
  endif
  " mode.state.commit (optional)
  if has_key(a:state, 'commit') && type(a:state.commit) isnot# type(function('function'))
    return nesk#error(a:name . '.commit is not Funcref')
  endif
  return s:NONE
endfunction

function! s:Nesk_get_table(name) abort dict
  let table = get(self._tables, a:name, s:NONE)
  if table is# s:NONE
    return [s:NONE, nesk#errorf('cannot load table "%s"', a:name)]
  endif
  return [deepcopy(table), s:NONE]
endfunction

function! s:Nesk_define_table(name, table) abort dict
  let err = s:validate_define_table_args(self, a:name, a:table)
  if err isnot# s:NONE
    let err = nesk#wrap_error(err, 'nesk#define_table()')
    call s:echomsg('ErrorMsg', err.error())
  endif
  let self._tables[a:name] = s:new_table(a:name, a:table)
endfunction

function! s:validate_define_table_args(nesk, name, table) abort
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

function! s:new_table(name, table) abort
  return {
  \ '_raw_table': a:table,
  \ 'name': a:name,
  \ 'get': function('s:Table_get'),
  \ 'search': function('s:Table_search'),
  \}
endfunction

function! s:Table_get(key, else) abort dict
  return get(self._raw_table, a:key, a:else)
endfunction

function! s:Table_search(key, ...) abort dict
  if a:0 is# 0 || a:1 <# 0
    let end = max([len(a:key) - 1, 0])
    return filter(copy(self._raw_table), 'v:key[: end] is# a:key')
  elseif a:1 is# 0
    return {}
  else
    let d = {}
    let end = max([len(a:key) - 1, 0])
    for key in keys(self._raw_table)
      if key[: end] is# a:key
        let d[key] = self._raw_table[key]
        if len(d) >=# a:1
          return d
        endif
      endif
    endfor
    return d
  endif
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
    execute 'lnoremap <expr><nowait>' lhs 'nesk#filter(' . string(lhs) . ')'
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

function! s:Nesk_filter(str) abort dict
  let [name, err] = self.get_active_mode_name()
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ''
  endif
  let [states, err] = self.get_active_states()
  if err isnot# s:NONE
    call s:echomsg('ErrorMsg', err.error())
    return ''
  endif
  let state = states[-1]
  let in = nesk#new_string_reader(a:str)
  let out = nesk#new_string_writer()
  while in.size() ># 0
    let state = state.next(in, out)
  endwhile
  let states[-1] = state
  return out.to_string()
endfunction

function! nesk#new_string_reader(str) abort
  return {
  \ '_str': a:str,
  \ '_pos': 0,
  \ '_last_read': 0,
  \ 'read': function('s:StringReader_read'),
  \ 'peek': function('s:StringReader_peek'),
  \ 'unread': function('s:StringReader_unread'),
  \ 'size': function('s:StringReader_size'),
  \}
endfunction

function! s:StringReader_read(n) abort dict
  let str = self.peek(a:n)
  let self._last_read = strlen(str)
  let self._pos += self._last_read
  return str
endfunction

function! s:StringReader_peek(n) abort dict
  if a:n <=# 0
    return ''
  endif
  return self._str[self._pos : self._pos + a:n - 1]
endfunction

" NOTE: `self._pos - self._last_read` must not be negative
function! s:StringReader_unread() abort dict
  let self._pos -= self._last_read
endfunction

" NOTE: `strlen(self._str) - self._pos` must not be negative
function! s:StringReader_size() abort dict
  return strlen(self._str) - self._pos
endfunction


function! nesk#new_string_writer(...) abort
  return {
  \ '_str': (a:0 && type(a:1) is# type('') ? a:1 : ''),
  \ 'write': function('s:StringWriter_write'),
  \ 'to_string': function('s:StringWriter_to_string'),
  \}
endfunction

function! s:StringWriter_write(str) abort dict
  let self._str .= a:str
endfunction

function! s:StringWriter_to_string() abort dict
  return self._str
endfunction


function! nesk#enable() abort
  return nesk#get_instance().enable()[0]
endfunction

function! nesk#disable() abort
  return nesk#get_instance().disable()[0]
endfunction

function! nesk#toggle() abort
  return nesk#get_instance().toggle()[0]
endfunction

function! nesk#enabled() abort
  return nesk#get_instance().enabled()
endfunction

function! nesk#init_active_mode() abort
  return nesk#get_instance().init_active_mode()
endfunction

function! nesk#filter(str) abort
  return nesk#get_instance().filter(a:str)
endfunction

function! nesk#define_mode(name, mode) abort
  return nesk#get_instance().define_mode(a:name, a:mode)
endfunction

function! nesk#define_table(name, table) abort
  return nesk#get_instance().define_table(a:name, a:table)
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
