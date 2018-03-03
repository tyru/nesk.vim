" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


" This module does not export this. Because it is enough to write it in the
" document. And if these values are exported, it may be rewritten by extend(),
" and so on.
let s:DEFAULT_LEVELS = [['INFO', 'info'], ['WARN', 'warn'], ['ERROR', 'error']]
let s:DEFAULT_DEFAULT_LEVEL = 'INFO'
let s:DEFAULT_OPTIONS = {
\ 'levels': s:DEFAULT_LEVELS,
\ 'default_level': s:DEFAULT_DEFAULT_LEVEL,
\ 'autoflush': 0,
\}

function! s:_vital_loaded(V) abort
  " To import sub-logger
  let s:V = a:V
endfunction


" Handle this module's option here.
" The rest parameters are handled by sub-logger.
function! s:new(options) abort
  if type(a:options) isnot# v:t_dict
    throw 'Nesk.Log: new() received non-Dictionary options value'
  endif
  call extend(a:options, s:DEFAULT_OPTIONS, 'keep')
  let output = get(a:options, 'output', 0)
  if type(output) isnot# v:t_string
    throw 'Nesk.Log: new(): received non-String options.output value'
  endif
  let levels = a:options.levels
  if type(levels) isnot# v:t_list
    throw 'Nesk.Log: new(): received non-List options.levels value'
  endif
  let default_level = a:options.default_level
  if type(default_level) isnot# v:t_string
    throw 'Nesk.Log: new(): received non-Dictionary options.default_level value'
  endif
  let autoflush = a:options.autoflush
  if type(autoflush) isnot# v:t_number && type(autoflush) isnot# v:t_bool
    throw 'Nesk.Log: new(): received non-Bool options.autoflush value'
  endif
  let [levels, lv_index] = s:_validate_levels(levels, default_level)
  let name = 'Nesk.Log.' . output
  let impl = s:V.import(name).new(a:options)
  let impl = s:_validate_impl(impl, name)
  let logger = {
  \ '_impl': impl,
  \ '_current_level': lv_index,
  \ '_autoflush': autoflush,
  \ 'set_level': function('s:_Log_set_level'),
  \ 'log': function('s:_Log_log'),
  \ 'flush': function('s:_Log_flush'),
  \}
  return s:_create_level_methods(logger, levels)
endfunction

function! s:_validate_impl(impl, module_name) abort
  if type(a:impl) isnot# v:t_dict
    throw 'Nesk.Log: new(): ' . a:module_name . '.new() returned non-Dictionary value'
  endif
  if type(get(a:impl, 'log', 0)) isnot# v:t_func
    throw 'Nesk.Log: new(): ' . a:module_name . '.new().log does not exist or not Funcref'
  endif
  if type(get(a:impl, 'flush', 0)) isnot# v:t_func
    throw 'Nesk.Log: new(): ' . a:module_name . '.new().flush does not exist or not Funcref'
  endif
  return a:impl
endfunction

function! s:_validate_levels(levels, default_level) abort
  let lv_index = -1
  let label_map = {}
  let method_map = {}
  for i in range(len(a:levels))
    let l:Value = a:levels[i]
    if type(l:Value) isnot# v:t_list ||
    \ len(l:Value) isnot# 2 ||
    \ type(l:Value[0]) isnot# v:t_string ||
    \ type(l:Value[1]) isnot# v:t_string
      throw 'Nesk.Log: new(): options.levels is not List of 2 elements'
    endif
    let [label, method] = l:Value
    if label is# a:default_level
      let lv_index = i
    endif
    if has_key(label_map, label)
      throw 'Nesk.Log: new(): label ' . string(label) . ' is duplicated'
    endif
    let label_map[label] = 1
    if has_key(method_map, method)
      throw 'Nesk.Log: new(): label ' . string(method) . ' is duplicated'
    endif
    let method_map[method] = 1
  endfor
  if lv_index is# -1
    throw 'Nesk.Log: new(): options.default_level (' . a:default_level .
    \     ') does not exist in options.levels'
  endif
  return [a:levels, lv_index]
endfunction

function! s:_create_level_methods(logger, levels) abort
  for i in range(len(a:levels))
    let [label, method] = a:levels[i]
    let a:logger[method] = function(a:logger.log, [i])
    let a:logger[label] = i
  endfor
  return a:logger
endfunction

function! s:_Log_set_level(level) abort dict
  if type(a:level) isnot# v:t_number
    throw 'Nesk.Log: set_level(): received non-Number value'
  endif
  let self._current_level = a:level
endfunction

" This function does not :throw a value which is neither Funcref nor String,
" because logger.log() in error case should be tolerant!
function! s:_Log_log(level, value) abort dict
  if type(a:level) isnot# v:t_number || self._current_level ># a:level
    return
  endif
  let l:Value = a:value
  if type(l:Value) is# v:t_func
    let l:Value = l:Value()
  endif
  if type(l:Value) isnot# v:t_string
    let l:Value = string(l:Value)
  endif
  try
    call self._impl.log(a:level, l:Value)
    if self._autoflush
      call self.flush()
    endif
  catch
    call s:_echo_exception()
  endtry
endfunction

function! s:_Log_flush() abort dict
  try
    call self._impl.flush()
  catch
    call s:_echo_exception()
  endtry
endfunction

" XXX: should re-throw v:exception?
function! s:_echo_exception() abort
  echohl ErrorMsg
  echomsg 'Nesk.Log: failed to write log'
  echomsg 'v:exception:' v:exception
  echomsg 'v:throwpoint:' v:throwpoint
  echohl None
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
