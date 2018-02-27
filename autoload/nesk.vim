" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:NONE = []

" TODO: Global variable?
let s:INITIAL_MODE = 'skk/kana'
let s:KEEP_STATE = 1
let s:DO_LOG = 0
let s:LOG_FILE = expand('~/nesk.log')

let s:nesk = s:NONE


function! s:new_nesk() abort
  let nesk = {}

  let nesk._loaded_rtp = 0
  let nesk._states = {}
  let nesk._modes = {}
  let nesk._tables = {}
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
  let nesk.get_active_mode = function('s:Nesk_get_active_mode')
  let nesk.define_mode = function('s:Nesk_define_mode')
  let nesk.get_table = function('s:Nesk_get_table')
  let nesk.define_table = function('s:Nesk_define_table')
  let nesk.map_keys = function('s:Nesk_map_keys')
  let nesk.unmap_keys = function('s:Nesk_unmap_keys')
  let nesk.filter = function('s:Nesk_filter')
  if s:DO_LOG && isdirectory(fnamemodify(s:LOG_FILE, ':h'))
    let nesk.log = function('s:Nesk_log')
    let nesk.transit = function('s:Nesk_transit_log')
  else
    let nesk.log = function('s:nop')
    let nesk.transit = function('s:Nesk_transit_nolog')
  endif

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
    return ['', err]
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
  if !self.enabled()
    return nesk#error('mode is disabled')
  endif
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:NONE
    return err
  endif
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:NONE
    return err
  endif
  call self.set_states(mode_name, [mode.initial_state])
  return s:NONE
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

function! s:Nesk_get_active_mode() abort dict
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:NONE
    return [s:NONE, err]
  endif
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:NONE
    return [s:NONE, err]
  endif
  return [mode, s:NONE]
endfunction

function! s:Nesk_define_mode(mode) abort dict
  let err = s:validate_mode(self, a:mode)
  if err isnot# s:NONE
    return nesk#wrap_error(err, 'nesk#define_mode()')
  endif
  let a:mode.state = a:mode.initial_state
  let self._modes[a:mode.name] = a:mode
  return s:NONE
endfunction

function! s:validate_mode(nesk, mode) abort
  if type(a:mode) isnot# v:t_dict
    return nesk#error('mode is not Dictionary')
  endif
  " mode.name
  if type(get(a:mode, 'name', 0)) isnot# v:t_string
    return nesk#error('mode.name does not exist or is not String')
  endif
  if has_key(a:nesk._modes, a:mode.name)
    return nesk#errorf('mode "%s" is already registered', a:mode.name)
  endif
  " mode.initial_state
  if !has_key(a:mode, 'initial_state')
    return nesk#error('mode.initial_state does not exist')
  endif
  let err = s:validate_state(a:mode.initial_state, 'mode.initial_state')
  if err isnot# s:NONE
    return err
  endif
  " mode.state
  if has_key(a:mode, 'state')
    return nesk#error('mode.state must not exist')
  endif
  return s:NONE
endfunction

function! s:validate_state(state, name) abort
  if type(a:state) isnot# v:t_dict
    return nesk#error(a:name . ' is not Dictionary')
  endif
  " state.next
  if !has_key(a:state, 'next') || type(a:state.next) isnot# v:t_func
    return nesk#error(a:name . '.next is not Funcref')
  endif
  " state.commit (optional)
  if has_key(a:state, 'commit') && type(a:state.commit) isnot# v:t_func
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

function! s:Nesk_define_table(table) abort dict
  let err = s:validate_table(self, a:table)
  if err isnot# s:NONE
    return err
  endif
  let self._tables[a:table.name] = a:table
  return s:NONE
endfunction

function! s:validate_table(nesk, table) abort
  if type(a:table) isnot# v:t_dict
    return nesk#error('table is not Dictionary')
  endif
  " table.name
  if type(get(a:table, 'name', 0)) isnot# v:t_string
    return nesk#error('name is not String')
  endif
  if has_key(a:nesk._tables, a:table.name)
    return nesk#errorf('table "%s" is already registered', a:table.name)
  endif
  return s:NONE
endfunction

function! nesk#new_table(name, table) abort
  return {
  \ '_raw_table': a:table,
  \ 'name': a:name,
  \ 'get': function('s:Table_get'),
  \ 'search': function('s:Table_search'),
  \}
endfunction

function! s:is_table(table) abort
  return type(a:table) is# v:t_dict &&
  \      type(get(a:table, 'name', 0)) is# v:t_string &&
  \      type(get(a:table, 'get', 0)) is# v:t_func &&
  \      type(get(a:table, 'search', 0)) is# v:t_func
endfunction

function! s:Table_get(key, else) abort dict
  return get(self._raw_table, a:key, a:else)
endfunction

function! s:Table_search(prefix, ...) abort dict
  if a:0 is# 0 || a:1 <# 0
    let end = max([len(a:prefix) - 1, 0])
    return s:fold(keys(self._raw_table), {
    \ result,key ->
    \   key[: end] is# a:prefix ?
    \     result + [[key, self._raw_table[key]]] : result
    \}, [])
  elseif a:1 is# 0
    return []
  else
    let result = []
    let end = max([len(a:prefix) - 1, 0])
    for key in keys(self._raw_table)
      if key[: end] is# a:prefix
        let result += [[key, self._raw_table[key]]]
        if len(result) >=# a:1
          return result
        endif
      endif
    endfor
    return result
  endif
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
  let [states, err] = self.get_active_states()
  if err isnot# s:NONE
    return ['', err]
  endif
  let state = states[-1]
  let in = nesk#new_string_reader(a:str)
  let out = nesk#new_string_writer()
  try
    let state = self.transit(state, in, out)
    if empty(out.errs)
      let states[-1] = state
      return [out.to_string(), s:NONE]
    endif
    let errs = out.errs
  catch
    let ex = type(v:exception) is# v:t_string ? v:exception : string(v:exception)
    let errs = [nesk#error(ex, v:throwpoint)]
  endtry
  " Error handling
  let merr = nesk#multi_error(errs)
  let [str, err] = self.disable()
  let merr = nesk#error_append(merr, err)
  return [str, merr]
endfunction

function! s:Nesk_transit_log(state, in, out) abort
  let state = a:state
  call self.log(printf('transit(): input=%s',
  \                     string(a:str)))
  while a:in.size() ># 0
    call self.log(printf('  state=%s,in=%s,out=%s',
    \                     s:state_string(state),
    \                     string(a:in.peek(a:in.size())),
    \                     string(a:out.to_string())))
    let state = state.next(a:in, a:out)
  endwhile
  call self.log(printf('  state=%s,in=%s,out=%s',
  \                     s:state_string(state),
  \                     string(a:in.peek(a:in.size())),
  \                     string(a:out.to_string())))
  call self.log(printf('transit(): output=%s',
  \                     string(a:out.to_string())))
  return state
endfunction

function! s:Nesk_transit_nolog(state, in, out) abort
  let state = a:state
  while a:in.size() ># 0
    let state = state.next(a:in, a:out)
  endwhile
  return state
endfunction

" * Transform table object into '<table "{name}">'
" * Transform Funcref
function! s:state_string(obj) abort
  if type(a:obj) is# v:t_dict
    if s:is_table(a:obj)
      return '<table "' . a:obj.name . '">'
    endif
    let elems = []
    for key in keys(a:obj)
      let elems += [string(key) . ': ' . s:state_string(a:obj[key])]
    endfor
    return '{' . join(elems, ', ') . '}'
  elseif type(a:obj) is# v:t_func
    return substitute(string(a:obj), '^function(''[^'']\+''\zs, .*\ze)$', '', '')
  else
    return string(a:obj)
  endif
endfunction

function! s:Nesk_log(msg) abort dict
  call writefile([a:msg], s:LOG_FILE, 'a')
endfunction

function! nesk#new_string_reader(str) abort
  return {
  \ '_str': a:str,
  \ '_pos': 0,
  \ '_last_read': 0,
  \ 'read': function('s:StringReader_read'),
  \ 'peek': function('s:StringReader_peek'),
  \ 'read_char': function('s:StringReader_read_char'),
  \ 'peek_char': function('s:StringReader_peek_char'),
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

function! s:StringReader_read_char() abort dict
  let c = self.peek_char()
  let self._last_read = strlen(c)
  let self._pos += self._last_read
  return c
endfunction

function! s:StringReader_peek_char() abort dict
  return matchstr(self._str, '.', self._pos)
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
  \ '_str': (a:0 && type(a:1) is# v:t_string ? a:1 : ''),
  \ 'errs': [],
  \ 'write': function('s:StringWriter_write'),
  \ 'to_string': function('s:StringWriter_to_string'),
  \ 'error': function('s:StringWriter_error'),
  \}
endfunction

function! s:StringWriter_write(str) abort dict
  let self._str .= a:str
endfunction

function! s:StringWriter_to_string() abort dict
  return self._str
endfunction

function! s:StringWriter_error(err) abort dict
  let self.errs += [a:err]
  return s:ESCAPE_STATE
endfunction


function! nesk#new_mode_change_state(mode_name) abort
  return {
  \ '_mode_name': a:mode_name,
  \ 'next': function('s:ModeChangeState_next'),
  \}
endfunction

" Read one character, which is dummy to invoke this function immediately.
" Caller must leave one character in a:in at least.
function! s:ModeChangeState_next(in, out) abort dict
  call a:in.read(1)
  let nesk = nesk#get_instance()
  let err = nesk.set_active_mode_name(self._mode_name)
  if err isnot# s:NONE
    let err = nesk#wrap_error(err, 'Cannot set active mode to ' . self._mode_name)
    return a:out.error(err)
  endif
  let [mode, err] = nesk.get_active_mode()
  if err isnot# s:NONE
    let err = nesk#wrap_error(err, 'Cannot get active mode')
    return a:out.error(err)
  endif
  return mode.initial_state
endfunction

function! nesk#new_disable_state() abort
  return {
  \ 'next': function('s:DisableState_next'),
  \}
endfunction

function! s:DisableState_next(in, out) abort dict
  " Read all string to stop nesk.filter() loop
  call a:in.read(a:in.size())
  let nesk = nesk#get_instance()
  let [str, err] = nesk.disable()
  if err isnot# nesk#error_none()
    return a:out.error(nesk#wrap_error(err, 'Cannot disable skk'))
  endif
  call a:out.write(str)
  return s:ESCAPE_STATE
endfunction

let s:ESCAPE_STATE = {}

" Read all string from a:in to stop the nesk.filter()'s loop
function! s:EscapeState_next(in, out) abort dict
  call a:in.read(a:in.size())
  return self
endfunction
let s:ESCAPE_STATE.next = function('s:EscapeState_next')


function! nesk#enable() abort
  let [str, err] = nesk#get_instance().enable()
  if err is# s:NONE
    return str
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
  return ''
endfunction

function! nesk#disable() abort
  let [str, err] = nesk#get_instance().disable()
  if err is# s:NONE
    return str
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
  return ''
endfunction

function! nesk#toggle() abort
  let [str, err] = nesk#get_instance().toggle()
  if err is# s:NONE
    return str
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
  return ''
endfunction

function! nesk#enabled() abort
  return nesk#get_instance().enabled()
endfunction

function! nesk#init_active_mode() abort
  let err = nesk#get_instance().init_active_mode()
  if err is# s:NONE
    return
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
endfunction

function! nesk#filter(str) abort
  let [str, err] = nesk#get_instance().filter(a:str)
  if err is# s:NONE
    return str
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
  return ''
endfunction


function! nesk#define_mode(mode) abort
  let err = nesk#get_instance().define_mode(a:mode)
  if err is# s:NONE
    return
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
endfunction

function! nesk#define_table(table) abort
  let err = nesk#get_instance().define_table(a:table)
  if err is# s:NONE
    return
  endif
  call s:echomsg('ErrorMsg', err.error(1))
  sleep 2
endfunction


function! nesk#errorf(fmt, ...) abort
  let msg = call('printf', [a:fmt] + a:000)
  return {
  \ 'error': function('s:Error_error'),
  \ 'msg': msg,
  \ 'stacktrace': s:caller(1),
  \}
endfunction

function! nesk#error(msg, ...) abort
  return {
  \ 'error': function('s:Error_error'),
  \ 'msg': a:msg,
  \ 'stacktrace': a:0 && type(a:1) is# v:t_string ? a:1 : s:caller(1),
  \}
endfunction

function! nesk#wrap_error(err, msg) abort
  if a:err is# s:NONE
    return nesk#error(a:msg)
  endif
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
  return join(split(expand('<sfile>'), '\.\.')[: -(a:n + 2)], '..')
endfunction

function! s:Error_error(...) abort dict
  let detailed = !!get(a:000, 0, 0)
  if !detailed
    return self.msg
  endif
  if has_key(self, 'stacktrace')
    return printf('%s in %s', self.msg, self.stacktrace)
  endif
  return self.msg
endfunction

function! nesk#multi_error(errs) abort
  if type(a:errs) isnot# v:t_list || empty(a:errs)
    return s:NONE
  endif
  return {
  \ 'errs': a:errs,
  \ 'error': function('s:MultiError_error'),
  \ 'append': function('s:MultiError_append'),
  \}
endfunction

function! nesk#is_multi_error(err) abort
  return type(a:err) is# v:t_dict &&
  \      get(a:err, 'append', 0) is# function('s:MultiError_append')
endfunction

function! nesk#error_append(err, ...) abort
  let result = a:err
  for err in a:000
    if err is# s:NONE
      continue
    endif
    if result is# s:NONE
      let result = err
      continue
    endif
    if !nesk#is_multi_error(result)
      let result = nesk#multi_error([result])
    endif
    call result.append(err)
  endfor
  return result
endfunction

function! s:MultiError_error(...) abort dict
  if len(self.errs) is# 1
    let e = self.errs[0]
    return call(e.error, a:000, e)
  endif
  let args = a:000
  let result = []
  for err in self.errs
    let result += ['* ' . call(err.error, args, err)]
  endfor
  return join(result, "\n")
endfunction

" This function does not return anything,
" and changes `self.errs` statefully unlike hashicorp/go-multierror
function! s:MultiError_append(err) abort dict
  if a:err is# s:NONE
    return
  endif
  let self.errs += [a:err]
endfunction


function! s:nop(...) abort
endfunction

function! s:fold(list, f, init) abort
  let [l, end] = [a:list + [a:init], len(a:list)]
  return map(l, {i,v -> i is# end ? l[i-1] : call(a:f, [l[i-1], v])})[-1]
endfunction


function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  echomsg a:msg
  echohl None
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
