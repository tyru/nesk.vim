" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Error = a:V.import('Nesk.Error')
  let s:StringReader = a:V.import('Nesk.IO.StringReader')
  let s:StringWriter = a:V.import('Nesk.IO.StringWriter')
  let s:Log = a:V.import('Nesk.Log')

  " TODO: Global variable
  let s:INITIAL_MODE = 'skk/kana'
endfunction

function! s:_vital_depends() abort
  return [
  \ 'Nesk.Error',
  \ 'Nesk.IO.StringReader',
  \ 'Nesk.IO.StringWriter',
  \ 'Nesk.IO.VimBufferWriter',
  \ 'Nesk.Log',
  \]
endfunction


function! s:new() abort
  let logfile = expand('~/nesk.log')
  if 0 && isdirectory(fnamemodify(logfile, ':h'))
    let logger = s:Log.new({
    \ 'output': 'File',
    \ 'file_path': logfile,
    \ 'file_redir': 1,
    \ 'autoflush': 0,
    \})
  elseif 0
    let logger = s:Log.new({
    \ 'output': 'Echomsg',
    \ 'echomsg_hl': ['WarningMsg', 'WarningMsg', 'WarningMsg'],
    \ 'autoflush': 0,
    \})
  else
    let logger = s:Log.new({'output': 'Nop'})
    call logger.set_level(logger.NONE)
  endif
  let nesk = extend(deepcopy(s:Nesk), {
  \ '__type__': 'Nesk',
  \ '_active_mode_name': '',
  \ '_initial_mode': s:INITIAL_MODE,
  \ '_modes': {},
  \ '_states': {},
  \ '_table_builders': {},
  \ '_tables': {},
  \ '_logger': logger,
  \})
  let nesk.transit = function('s:_Nesk_transit')
  return nesk
endfunction

let s:Nesk = {}

function! s:_Nesk_enable() abort dict
  if self.is_enabled()
    return s:Error.new('already enabled')
  endif
  let mode_name = self._initial_mode
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:Error.NIL
    return err
  endif
  let self._states[mode_name] = mode
  " Reset self._active_mode_name because self.set_active_mode_name() will fail
  " if self._active_mode_name == mode_name
  let self._active_mode_name = ''
  return self.set_active_mode_name(mode_name)
endfunction
let s:Nesk.enable = function('s:_Nesk_enable')

function! s:_Nesk_disable() abort dict
  if !self.is_enabled()
    return ['', s:Error.NIL]
  endif
  let committed = ''
  let [states, err] = self.get_active_states()
  if err is# s:Error.NIL && has_key(states[-1], 'commit')
    let committed = states[-1].commit()
  endif
  let self._states = {}
  let self._active_mode_name = ''
  " NOTE: Vim can't escape lang-mode immediately
  " in insert-mode or commandline-mode.
  " We have to use i_CTRL-^ .
  return [committed . "\<C-^>", s:Error.NIL]
endfunction
let s:Nesk.disable = function('s:_Nesk_disable')

function! s:_Nesk_toggle() abort dict
  return self.is_enabled() ? self.disable() : self.enable()
endfunction
let s:Nesk.toggle = function('s:_Nesk_toggle')

function! s:_Nesk_is_enabled() abort dict
  return self.get_active_mode_name()[1] is# s:Error.NIL
endfunction
let s:Nesk.is_enabled = function('s:_Nesk_is_enabled')

function! s:_Nesk_load_init() abort dict
  let loaded = {}
  for line in split(execute('scriptnames'), '\n')
    let m = matchlist(line, '^\s*\d\+: \(.*\)$')
    if empty(m)
      continue
    endif
    let path = tr(m[1], '\', '/')
    let m = matchlist(path, '/autoload/nesk/init/\(.*\).vim$')
    if empty(m)
      continue
    endif
    let loaded[m[1]] = 1
  endfor
  for file in globpath(&rtp, 'autoload/nesk/init/**/*.vim', 1, 1)
    let name = matchstr(tr(file, '\', '/'), '/autoload/nesk/init/\zs.*\ze.vim$')
    if !has_key(loaded, name)
      try
        source `=file`
      catch
        let err = s:Error.new(v:exception, v:throwpoint)
        return s:Error.wrap(err, 'failed to load ' . file)
      endtry
    endif
    let fn = 'nesk#init#' . tr(name, '/', '#') . '#load'
    if !exists('*' . fn)
      let msg = printf('%s was sourced but function %s was not defined', file, fn)
      return s:Error.new(msg)
    endif
    let err = {fn}(self)
    if err isnot# s:Error.NIL
      return s:Error.wrap(err, fn . '() returned error')
    endif
  endfor
  return s:Error.NIL
endfunction
let s:Nesk.load_init = function('s:_Nesk_load_init')

function! s:_Nesk_init_active_mode() abort dict
  if !self.is_enabled()
    return s:Error.new('mode is disabled')
  endif
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:Error.NIL
    return err
  endif
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:Error.NIL
    return err
  endif
  let self._states[mode_name] = [mode]
  return s:Error.NIL
endfunction
let s:Nesk.init_active_mode = function('s:_Nesk_init_active_mode')

function! s:_Nesk_get_active_mode_name() abort dict
  if self._active_mode_name is# ''
    return ['', s:Error.new('not active')]
  endif
  return [self._active_mode_name, s:Error.NIL]
endfunction
let s:Nesk.get_active_mode_name = function('s:_Nesk_get_active_mode_name')

function! s:_Nesk_set_active_mode_name(name) abort dict
  if a:name is# ''
    return s:Error.new('cannot changed to empty mode')
  endif
  if self._active_mode_name is# a:name
    return s:Error.new(printf('current mode is already "%s"', a:name))
  endif
  let [mode, err] = self.get_mode(a:name)
  if err isnot# s:Error.NIL
    return s:Error.wrap(err, printf('no such mode (%s)', a:name))
  endif
  let old = self._active_mode_name
  let self._active_mode_name = a:name
  let self._states[a:name] = [mode]
  return s:Error.NIL
endfunction
let s:Nesk.set_active_mode_name = function('s:_Nesk_set_active_mode_name')

function! s:_Nesk_get_active_states() abort dict
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:Error.NIL
    return [s:Error.NIL, err]
  endif
  let states = get(self._states, mode_name, [])
  if empty(states)
    return [s:Error.NIL, s:Error.new('no active state')]
  endif
  return [states, s:Error.NIL]
endfunction
let s:Nesk.get_active_states = function('s:_Nesk_get_active_states')

function! s:_Nesk_get_mode(name) abort dict
  let mode = get(self._modes, a:name, s:Error.NIL)
  if mode is# s:Error.NIL
    return [s:Error.NIL, s:Error.new(printf('cannot load mode "%s"', a:name))]
  endif
  return [mode, s:Error.NIL]
endfunction
let s:Nesk.get_mode = function('s:_Nesk_get_mode')

function! s:_Nesk_get_active_mode() abort dict
  let [mode_name, err] = self.get_active_mode_name()
  if err isnot# s:Error.NIL
    return [s:Error.NIL, err]
  endif
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:Error.NIL
    return [s:Error.NIL, err]
  endif
  return [mode, s:Error.NIL]
endfunction
let s:Nesk.get_active_mode = function('s:_Nesk_get_active_mode')

function! s:_Nesk_define_mode(mode) abort dict
  let err = s:_validate_mode(self, a:mode)
  if err isnot# s:Error.NIL
    return s:Error.wrap(err, 'nesk#define_mode()')
  endif
  let self._modes[a:mode.name] = a:mode
  return s:Error.NIL
endfunction
let s:Nesk.define_mode = function('s:_Nesk_define_mode')

function! s:_validate_mode(nesk, mode) abort
  if type(a:mode) isnot# v:t_dict
    return s:Error.new(a:name . ' is not Dictionary')
  endif
  " mode.name
  if type(get(a:mode, 'name', 0)) isnot# v:t_string
    return s:Error.new('mode.name does not exist or is not String')
  endif
  " Check if mode is registered
  if has_key(a:nesk._modes, a:mode.name)
    return s:Error.new(printf('mode "%s" is already registered', a:mode.name))
  endif
  " mode.next
  if !has_key(a:mode, 'next') || type(a:mode.next) isnot# v:t_func
    return s:Error.new(a:name . '.next is not Funcref')
  endif
  " mode.commit (optional)
  if has_key(a:mode, 'commit') && type(a:mode.commit) isnot# v:t_func
    return s:Error.new(a:name . '.commit is not Funcref')
  endif
  return s:Error.NIL
endfunction

function! s:_Nesk_get_table(name) abort dict
  let table = get(self._tables, a:name, s:Error.NIL)
  if table isnot# s:Error.NIL && (!has_key(table, 'invalidated') || !table.invalidated())
    return [table, s:Error.NIL]
  endif
  " Try creating table from builder
  let builder = get(self._table_builders, a:name, s:Error.NIL)
  if builder is# s:Error.NIL
    return [s:Error.NIL, s:Error.new(printf('cannot load table "%s"', a:name))]
  endif
  let [self._tables[a:name], err] = builder.build()
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'failed to build ' . a:name . ' table from builder')
    return [s:Error.NIL, err]
  endif
  return [self._tables[a:name], s:Error.NIL]
endfunction
let s:Nesk.get_table = function('s:_Nesk_get_table')

function! s:_Nesk_define_table_builder(builder) abort dict
  let err = s:_validate_table_builder(self, a:builder)
  if err isnot# s:Error.NIL
    return err
  endif
  let self._table_builders[a:builder.name] = a:builder
  return s:Error.NIL
endfunction
let s:Nesk.define_table_builder = function('s:_Nesk_define_table_builder')

function! s:_validate_table_builder(nesk, builder) abort
  if type(a:builder) isnot# v:t_dict
    return s:Error.new('builder is not Dictionary')
  endif
  " builder.name
  if type(get(a:builder, 'name', 0)) isnot# v:t_string
    return s:Error.new('builder.name is not String')
  endif
  if has_key(a:nesk._table_builders, a:builder.name)
    return s:Error.new(printf('builder "%s" is already registered', a:builder.name))
  endif
  return s:Error.NIL
endfunction

function! s:_Nesk_define_table(table) abort dict
  let err = s:_validate_table(self, a:table)
  if err isnot# s:Error.NIL
    return err
  endif
  let self._tables[a:table.name] = a:table
  " Also define table builder
  return self.define_table_builder(s:_default_builder(a:table))
endfunction
let s:Nesk.define_table = function('s:_Nesk_define_table')

function! s:_validate_table(nesk, table) abort
  if type(a:table) isnot# v:t_dict
    return s:Error.new('table is not Dictionary')
  endif
  " table.name
  if type(get(a:table, 'name', 0)) isnot# v:t_string
    return s:Error.new('table.name is not String')
  endif
  " table.invalidated (optional)
  if has_key(a:table, 'invalidated') && type(a:table.invalidated) isnot# v:t_func
    return s:Error.new('table.invalidated is not Funcref')
  endif
  if has_key(a:nesk._tables, a:table.name)
    return s:Error.new(printf('table "%s" is already registered', a:table.name))
  endif
  return s:Error.NIL
endfunction

function! s:_default_builder(table) abort
  return {
  \ 'name': a:table.name,
  \ 'build': {-> [a:table, s:Error.NIL]}
  \}
endfunction

function! s:_Nesk_send(str) abort dict
  let [states, err] = self.get_active_states()
  if err isnot# s:Error.NIL
    return ['', err]
  endif
  let state = states[-1]
  let in = s:StringReader.new(a:str)
  let out = s:StringWriter.new()
  try
    let [state, err] = self.transit(state, in, out)
    if err is# s:Error.NIL
      let states[-1] = state
      return [out.to_string(), s:Error.NIL]
    endif
  catch
    let ex = type(v:exception) is# v:t_string ? v:exception : string(v:exception)
    let err = s:Error.new(ex, v:throwpoint)
  endtry
  " Error
  let [str, err2] = self.disable()
  return [str, s:Error.append(err, err2)]
endfunction
let s:Nesk.send = function('s:_Nesk_send')

function! s:_Nesk_convert(str) abort dict
  let [state, err] = self.get_active_mode()
  if err isnot# s:Error.NIL
    return ['', err]
  endif
  let in = s:StringReader.new(a:str)
  let out = s:V.import('Nesk.IO.VimBufferWriter').new()
  try
    let [state, err] = self.transit(state, in, out)
    if err is# s:Error.NIL
      return [out.to_string(), s:Error.NIL]
    endif
  catch
    let ex = type(v:exception) is# v:t_string ? v:exception : string(v:exception)
    let err = s:Error.new(ex, v:throwpoint)
  endtry
  " Error
  let [str, err2] = self.disable()
  return [str, s:Error.append(err, err2)]
endfunction
let s:Nesk.convert = function('s:_Nesk_convert')

function! s:_Nesk_transit(state, in, out) abort dict
  try
    let state = a:state
    call self._logger.info('transit() {')
    while a:in.size() ># 0
      call self._logger.info({-> printf('  in=%s,out=%s,state=%s',
      \                     string(a:in.peek(a:in.size())),
      \                     string(a:out.to_string()),
      \                     s:_state_string(state),
      \)})
      let [state, err] = state.next(a:in, a:out)
      if err isnot# s:Error.NIL
        return [state, err]
      endif
    endwhile
    call self._logger.info({-> printf('  in=%s,out=%s,state=%s',
    \                     string(a:in.peek(a:in.size())),
    \                     string(a:out.to_string()),
    \                     s:_state_string(state),
    \)})
    call self._logger.info('}')
    return [state, s:Error.NIL]
  finally
    call self._logger.flush()
  endtry
endfunction

" * Transform table object into '<table "{name}">'
" * Transform Funcref
function! s:_state_string(obj, ...) abort
  let level = a:0 ? a:1 : 0
  if type(a:obj) is# v:t_dict
    if get(a:obj, '__type__', '') is# 'Nesk'
      return '<nesk object>'
    endif
    if type(get(a:obj, 'name', 0)) is# v:t_string &&
    \   type(get(a:obj, 'get', 0)) is# v:t_func &&
    \   type(get(a:obj, 'search', 0)) is# v:t_func
      return '<table "' . a:obj.name . '">'
    endif
    let list = map(items(a:obj), {_,v -> string(v[0]) . ': ' . s:_state_string(v[1], level + 1)})
    return '{' . join(list, ', ') . '}'
  elseif type(a:obj) is# v:t_func
    let value = string(a:obj)
    let m = matchlist(value, '^function(''\([^'']\+\)'', .*)$')
    return empty(m) ? value : '<func "' . m[1] . '">'
  elseif type(a:obj) is# v:t_list
    let list = map(copy(a:obj), {_,v -> s:_state_string(v, level + 1)})
    return '[' . join(list, ', ') . ']'
  else
    return string(a:obj)
  endif
endfunction


" a:name is current mode name.
" a:mode_name is the next mode name.
function! s:new_mode_change_state(name, mode_name) abort
  return {
  \ '_mode_name': a:mode_name,
  \ '_reset': 0,
  \ 'name': a:name,
  \ 'next': function('s:_ModeChangeState_next'),
  \}
endfunction

" a:name is current mode name.
" a:mode_name is the next mode name.
function! s:new_reset_mode_state(name) abort
  return {
  \ '_mode_name': a:name,
  \ '_reset': 1,
  \ 'name': a:name,
  \ 'next': function('s:_ModeChangeState_next'),
  \}
endfunction

" Read one character, which is dummy to invoke this function immediately.
" Caller must leave one character in a:in at least.
function! s:_ModeChangeState_next(in, out) abort dict
  call a:in.read_char()
  let nesk = nesk#get_instance()
  if self._reset
    " Reset self._active_mode_name because self.set_active_mode_name() will fail
    " if self._active_mode_name == self._mode_name
    let self._active_mode_name = ''
  endif
  let err = nesk.set_active_mode_name(self._mode_name)
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot set active mode to ' . self._mode_name)
    return [self, err]
  endif
  let [mode, err] = nesk.get_active_mode()
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot get active mode')
    return [self, err]
  endif
  return [mode, s:Error.NIL]
endfunction

function! s:new_disable_state(name) abort
  return {
  \ 'name': a:name,
  \ 'next': function('s:_DisableState_next'),
  \}
endfunction

function! s:_DisableState_next(in, out) abort dict
  " Read all string to stop nesk.send() loop
  let err = a:in.read(a:in.size())[1]
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'in.read() returned non-nil error')
    return [s:Error.NIL, err]
  endif
  let nesk = nesk#get_instance()
  let [str, err] = nesk.disable()
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot disable skk')
    return [s:Error.NIL, err]
  endif
  let err = a:out.write(str)
  return [s:new_black_hole_state(self.name), err]
endfunction

function! s:new_black_hole_state(name) abort
  return {
  \ 'name': a:name,
  \ 'next': function('s:_BlackHoleState_next'),
  \}
endfunction

" Read all string from a:in to stop the nesk.send()'s loop
function! s:_BlackHoleState_next(in, out) abort dict
  let err = a:in.read(a:in.size())[1]
  return [self, err]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
