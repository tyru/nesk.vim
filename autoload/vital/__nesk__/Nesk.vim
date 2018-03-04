" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:Error = a:V.import('Nesk.Error')
  let s:StringReader = a:V.import('Nesk.StringReader')
  let s:StringWriter = a:V.import('Nesk.StringWriter')
  let s:VimBufferWriter = a:V.import('Nesk.VimBufferWriter')
  let s:Log = a:V.import('Nesk.Log')
endfunction

function! s:_vital_depends() abort
  return ['Nesk.Error', 'Nesk.StringReader', 'Nesk.StringWriter', 'Nesk.VimBufferWriter', 'Nesk.Log']
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
  endif
  let nesk = extend(deepcopy(s:Nesk), {
  \ '_loaded_rtp': 0,
  \ '_states': {},
  \ '_modes': {},
  \ '_tables': {},
  \ '_active_mode_name': '',
  \ '_initial_mode': 'skk/kana',
  \ '_keep_state': 1,
  \ '_logger': logger,
  \})
  let nesk.transit = function('s:_Nesk_transit')
  return nesk
endfunction

let s:Nesk = {}

function! s:_Nesk_enable() abort dict
  if self.enabled()
    return ['', s:Error.new('already enabled')]
  endif
  call self.load_modes_in_rtp()
  let mode_name = self._initial_mode
  let [mode, err] = self.get_mode(mode_name)
  if err isnot# s:Error.NIL
    return ['', err]
  endif
  augroup nesk-disable-hook
    autocmd!
    if self._keep_state
      " Ignore return value of nesk.init_active_mode()
      autocmd InsertLeave <buffer> call nesk#get_instance().init_active_mode()
    else
      autocmd InsertLeave <buffer> call nesk#disable()
    endif
  augroup END
  call self.set_states(mode_name, [mode.initial_state])
  " Reset self._active_mode_name because self.set_active_mode_name() will fail
  " if self._active_mode_name == mode_name
  let self._active_mode_name = ''
  let err = self.set_active_mode_name(mode_name)
  if err isnot# s:Error.NIL
    return ['', err]
  endif
  call self.map_keys()
  if mode() =~# '^[ic]$'
    " NOTE: Vim can't enter lang-mode immediately
    " in insert-mode or commandline-mode.
    " We have to use i_CTRL-^ .
    setlocal iminsert=1 imsearch=1
    redrawstatus
    return ["\<C-^>", s:Error.NIL]
  else
    setlocal iminsert=1 imsearch=1
    redrawstatus
    return ['', s:Error.NIL]
  endif
endfunction
let s:Nesk.enable = function('s:_Nesk_enable')

function! s:_Nesk_disable() abort dict
  if !self.enabled()
    return ['', s:Error.NIL]
  endif
  let committed = ''
  let [states, err] = self.get_active_states()
  if err is# s:Error.NIL && has_key(states[-1], 'commit')
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
    return [committed . "\<C-^>", s:Error.NIL]
  else
    setlocal iminsert=0 imsearch=0
    redrawstatus
    return ['', s:Error.NIL]
  endif
endfunction
let s:Nesk.disable = function('s:_Nesk_disable')

function! s:_Nesk_toggle() abort dict
  return self.enabled() ? self.disable() : self.enable()
endfunction
let s:Nesk.toggle = function('s:_Nesk_toggle')

function! s:_Nesk_enabled() abort dict
  return &iminsert isnot# 0 && self.get_active_mode_name()[1] is# s:Error.NIL
endfunction
let s:Nesk.enabled = function('s:_Nesk_enabled')

function! s:_Nesk_load_modes_in_rtp() abort dict
  if self._loaded_rtp
    return
  endif
  runtime! autoload/nesk/mode/*.vim
  let self._loaded_rtp = 1
endfunction
let s:Nesk.load_modes_in_rtp = function('s:_Nesk_load_modes_in_rtp')

function! s:_Nesk_init_active_mode() abort dict
  if !self.enabled()
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
  call self.set_states(mode_name, [mode.initial_state])
  return s:Error.NIL
endfunction
let s:Nesk.init_active_mode = function('s:_Nesk_init_active_mode')

function! s:_Nesk_get_active_mode_name() abort dict
  if self._active_mode_name is# ''
    return ['', s:Error.new('no active states exist')]
  endif
  return [self._active_mode_name, s:Error.NIL]
endfunction
let s:Nesk.get_active_mode_name = function('s:_Nesk_get_active_mode_name')

function! s:_Nesk_set_active_mode_name(name) abort dict
  if self._active_mode_name is# a:name
    return s:Error.new(printf('current mode is already "%s"', a:name))
  endif
  let [mode, err] = self.get_mode(a:name)
  if err isnot# s:Error.NIL
    return s:Error.wrap(err, printf('no such mode (%s)', a:name))
  endif
  let old = self._active_mode_name
  let self._active_mode_name = a:name
  call self.set_states(a:name, [mode.initial_state])
  return s:Error.NIL
endfunction
let s:Nesk.set_active_mode_name = function('s:_Nesk_set_active_mode_name')

function! s:_Nesk_set_states(mode_name, states) abort dict
  let self._states[a:mode_name] = a:states
endfunction
let s:Nesk.set_states = function('s:_Nesk_set_states')

function! s:_Nesk_clear_states() abort dict
  let self._states = {}
endfunction
let s:Nesk.clear_states = function('s:_Nesk_clear_states')

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
  return [deepcopy(mode), s:Error.NIL]
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
  let a:mode.state = a:mode.initial_state
  let self._modes[a:mode.name] = a:mode
  return s:Error.NIL
endfunction
let s:Nesk.define_mode = function('s:_Nesk_define_mode')

function! s:_validate_mode(nesk, mode) abort
  if type(a:mode) isnot# v:t_dict
    return s:Error.new('mode is not Dictionary')
  endif
  " mode.name
  if type(get(a:mode, 'name', 0)) isnot# v:t_string
    return s:Error.new('mode.name does not exist or is not String')
  endif
  if has_key(a:nesk._modes, a:mode.name)
    return s:Error.new(printf('mode "%s" is already registered', a:mode.name))
  endif
  " mode.initial_state
  if !has_key(a:mode, 'initial_state')
    return s:Error.new('mode.initial_state does not exist')
  endif
  let err = s:_validate_state(a:mode.initial_state, 'mode.initial_state')
  if err isnot# s:Error.NIL
    return err
  endif
  " mode.state
  if has_key(a:mode, 'state')
    return s:Error.new('mode.state must not exist')
  endif
  return s:Error.NIL
endfunction

function! s:_validate_state(state, name) abort
  if type(a:state) isnot# v:t_dict
    return s:Error.new(a:name . ' is not Dictionary')
  endif
  " state.next
  if !has_key(a:state, 'next') || type(a:state.next) isnot# v:t_func
    return s:Error.new(a:name . '.next is not Funcref')
  endif
  " state.commit (optional)
  if has_key(a:state, 'commit') && type(a:state.commit) isnot# v:t_func
    return s:Error.new(a:name . '.commit is not Funcref')
  endif
  return s:Error.NIL
endfunction

function! s:_Nesk_get_table(name) abort dict
  let table = get(self._tables, a:name, s:Error.NIL)
  if table is# s:Error.NIL
    return [s:Error.NIL, s:Error.new(printf('cannot load table "%s"', a:name))]
  endif
  return [deepcopy(table), s:Error.NIL]
endfunction
let s:Nesk.get_table = function('s:_Nesk_get_table')

function! s:_Nesk_define_table(table) abort dict
  let err = s:_validate_table(self, a:table)
  if err isnot# s:Error.NIL
    return err
  endif
  let self._tables[a:table.name] = a:table
  return s:Error.NIL
endfunction
let s:Nesk.define_table = function('s:_Nesk_define_table')

function! s:_validate_table(nesk, table) abort
  if type(a:table) isnot# v:t_dict
    return s:Error.new('table is not Dictionary')
  endif
  " table.name
  if type(get(a:table, 'name', 0)) isnot# v:t_string
    return s:Error.new('name is not String')
  endif
  if has_key(a:nesk._tables, a:table.name)
    return s:Error.new(printf('table "%s" is already registered', a:table.name))
  endif
  return s:Error.NIL
endfunction

function! s:_Nesk_map_keys() abort dict
  for lhs in s:get_default_mapped_keys()
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lnoremap <expr><nowait>' lhs 'nesk#rewrite(' . string(lhs) . ')'
  endfor
endfunction
let s:Nesk.map_keys = function('s:_Nesk_map_keys')

function! s:_Nesk_unmap_keys() abort dict
  for lhs in s:get_default_mapped_keys()
    let lhs = substitute(lhs, '\V|', '<Bar>', 'g')
    execute 'lunmap' lhs
  endfor
endfunction
let s:Nesk.unmap_keys = function('s:_Nesk_unmap_keys')

" TODO: Global variable?
function! s:get_default_mapped_keys() abort
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

function! s:_Nesk_rewrite(str) abort dict
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
  " Error handling
  let [str, err2] = self.disable()
  return [str, s:Error.append(err, err2)]
endfunction
let s:Nesk.rewrite = function('s:_Nesk_rewrite')

function! s:_Nesk_filter(str) abort dict
  let [str, err] = self.rewrite(a:str)
  if err isnot# s:Error.NIL
    return ['', err]
  endif
  let reader = s:VimBufferWriter.new()
  call reader.write(str)
  return [reader.to_string(), s:Error.NIL]
endfunction
let s:Nesk.filter = function('s:_Nesk_filter')

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
    if s:_is_table(a:obj)
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

function! s:_is_table(table) abort
  return type(a:table) is# v:t_dict &&
  \      type(get(a:table, 'name', 0)) is# v:t_string &&
  \      type(get(a:table, 'get', 0)) is# v:t_func &&
  \      type(get(a:table, 'search', 0)) is# v:t_func
endfunction


function! s:new_mode_change_state(mode_name) abort
  return {
  \ '_mode_name': a:mode_name,
  \ 'next': function('s:_ModeChangeState_next'),
  \}
endfunction

" Read one character, which is dummy to invoke this function immediately.
" Caller must leave one character in a:in at least.
function! s:_ModeChangeState_next(in, out) abort dict
  call a:in.read_char()
  let nesk = nesk#get_instance()
  let err = nesk.set_active_mode_name(self._mode_name)
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot set active mode to ' . self._mode_name)
    return [s:Error.NIL, err]
  endif
  let [mode, err] = nesk.get_active_mode()
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot get active mode')
    return [s:Error.NIL, err]
  endif
  return [mode.initial_state, s:Error.NIL]
endfunction

function! s:new_disable_state() abort
  return {
  \ 'next': function('s:_DisableState_next'),
  \}
endfunction

function! s:_DisableState_next(in, out) abort dict
  " Read all string to stop nesk.rewrite() loop
  call a:in.read(a:in.size())
  let nesk = nesk#get_instance()
  let [str, err] = nesk.disable()
  if err isnot# s:Error.NIL
    let err = s:Error.wrap(err, 'Cannot disable skk')
    return [s:Error.NIL, err]
  endif
  call a:out.write(str)
  return [s:BLACK_HOLE_STATE, s:Error.NIL]
endfunction

function! s:new_black_hole_state() abort
  return s:BLACK_HOLE_STATE
endfunction

let s:BLACK_HOLE_STATE = {}

" Read all string from a:in to stop the nesk.rewrite()'s loop
function! s:_BlackHoleState_next(in, out) abort dict
  call a:in.read(a:in.size())
  return [self, s:Error.NIL]
endfunction
let s:BLACK_HOLE_STATE.next = function('s:_BlackHoleState_next')


let &cpo = s:save_cpo
unlet s:save_cpo
