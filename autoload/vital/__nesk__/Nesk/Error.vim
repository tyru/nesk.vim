" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:NIL = []

function! s:_vital_created(M) abort
  let a:M.NIL = s:NIL
endfunction


function! s:new(exception, ...) abort
  return {
  \ 'exception': a:exception,
  \ 'throwpoint': a:0 && type(a:1) is# v:t_string ? a:1 : s:caller(1),
  \}
endfunction

function! s:is_error(err) abort
  return a:err is# s:NIL ||
  \      type(a:err) is# v:t_dict &&
  \      type(get(a:err, 'exception', 0)) is# v:t_string &&
  \      type(get(a:err, 'throwpoint', 0)) is# v:t_string
endfunction

" FIXME: Use hashicorp/errwrap interface
function! s:wrap(err, exception) abort
  if a:err is# s:NIL
    return s:new(a:exception, s:caller(1))
  endif
  return {
  \ 'exception': printf('%s: %s', a:exception, a:err.exception),
  \ 'throwpoint': s:caller(1),
  \}
endfunction

" FIXME: Use hashicorp/errwrap interface
function! s:wrapf(fmt, err) abort
  " TODO
endfunction


function! s:new_multi(...) abort
  if a:0 is# 0 || type(a:1) isnot# v:t_list
    return s:NIL
  endif
  let errs = s:flatten(a:1)
  if empty(errs)
    return s:NIL
  elseif len(errs) is# 1
    return errs[0]
  endif
  let [ex, tp] = [[], []]
  for err in errs
    let ex += ['* ' . err.exception]
    let tp += ['* ' . err.throwpoint]
  endfor
  return {
  \ 'exception': join(ex, "\n"),
  \ 'throwpoint': join(tp, "\n"),
  \ 'errors': errs,
  \}
endfunction

function! s:is_multi_error(err) abort
  return a:err is# s:NIL ||
  \      s:is_error(a:err) &&
  \      type(get(a:err, 'errors', 0)) is# v:t_list
endfunction

function! s:append(err, ...) abort
  return s:new_multi([a:err] + a:000)
endfunction

function! s:flatten(...) abort
  return s:_flatmap(a:000, {
  \ e -> type(e) is# v:t_list ? s:_flatmap(copy(e), function('s:flatten')) :
  \      e is# s:NIL          ? [] :
  \      s:is_multi_error(e)  ? s:flatten(e.errors) :
  \                             [e]
  \})
endfunction

function! s:caller(n) abort
  return join(split(expand('<sfile>'), '\.\.')[: -(a:n + 2)], '..')
endfunction


" This function does not changes a:list
function! s:_flatmap(list, f) abort
  let result = []
  return get(map(copy(a:list), {_,v -> extend(result, a:f(v))}), -1, [])
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
