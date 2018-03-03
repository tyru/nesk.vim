" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:DEFAULT_FORMATTER = {
\ options -> {lv,msg -> printf('[%s] %s', get(options.levels[0], lv, '?'), msg)}
\}

function! s:new(options) abort
  if type(get(a:options, 'file_path', 0)) isnot# v:t_string
    throw 'Nesk.Log.File: new(): options.file_path does not exist or not String'
  endif
  let l:Fmt = get(a:options, 'file_format', s:DEFAULT_FORMATTER)
  if type(l:Fmt) isnot# v:t_func
    throw 'Nesk.Log.File: new(): options.file_format is not String nor Funcref'
  endif
  let l:Fmt = l:Fmt(a:options)
  if type(l:Fmt) isnot# v:t_func
    throw 'Nesk.Log.File: new(): options.file_format is not String nor Funcref'
  endif
  return {
  \ '_fmt': l:Fmt,
  \ '_path': a:options.file_path,
  \ '_buf': [],
  \ 'log': function('s:_FileLogger_log'),
  \ 'flush': get(a:options, 'file_redir', 0) ?
  \           function('s:_FileLogger_flush_redir') :
  \           function('s:_FileLogger_flush_writefile')
  \}
endfunction

function! s:_FileLogger_log(level, msg) abort dict
  let self._buf += [[a:level, a:msg]]
endfunction

function! s:_FileLogger_flush_redir() abort dict
  try
    execute 'redir >>' self._path
    for [level, msg] in self._buf
      silent echo self._fmt(level, msg)
    endfor
    let self._buf = []
  finally
    redir END
  endtry
endfunction

function! s:_FileLogger_flush_writefile() abort dict
  for [level, msg] in self._buf
    call writefile([self._fmt(level, msg)], self._path, 'a')
  endfor
  let self._buf = []
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

