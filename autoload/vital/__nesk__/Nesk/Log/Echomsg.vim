" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:DEFAULT_FORMATTER = {
\ options -> {lv,msg -> printf('[%s] %s', get(options.levels[0], lv, '?'), msg)}
\}

function! s:new(options) abort
  let hl = get(a:options, 'echomsg_hl', [])
  if type(hl) isnot# v:t_list
    throw 'Nesk.Log.Echomsg: new(): options.echomsg_hl is not List'
  endif
  let l:Fmt = get(a:options, 'echomsg_format', s:DEFAULT_FORMATTER)
  if type(l:Fmt) isnot# v:t_func
    throw 'Nesk.Log.Echomsg: new(): options.echomsg_format is not String nor Funcref'
  endif
  let l:Fmt = l:Fmt(a:options)
  if type(l:Fmt) isnot# v:t_func
    throw 'Nesk.Log.Echomsg: new(): options.echomsg_format is not String nor Funcref'
  endif
  return {
  \ '_hl': hl,
  \ '_fmt': l:Fmt,
  \ 'log': function('s:_EchomsgLogger_log'),
  \}
endfunction

function! s:_EchomsgLogger_log(level, msg) abort dict
  try
    execute 'echohl' get(self._hl, a:level, 'None')
    echomsg self._fmt(a:level, a:msg)
  finally
    echohl None
  endtry
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

