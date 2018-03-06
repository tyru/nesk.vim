" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:new(str) abort
  return {
  \ '_str': a:str,
  \ '_pos': 0,
  \ '_last_read': 0,
  \ 'read': function('s:_StringReader_read'),
  \ 'peek': function('s:_StringReader_peek'),
  \ 'read_char': function('s:_StringReader_read_char'),
  \ 'peek_char': function('s:_StringReader_peek_char'),
  \ 'unread': function('s:_StringReader_unread'),
  \ 'size': function('s:_StringReader_size'),
  \}
endfunction

function! s:_StringReader_read(n) abort dict
  let str = self.peek(a:n)
  let self._last_read = strlen(str)
  let self._pos += self._last_read
  return str
endfunction

function! s:_StringReader_peek(n) abort dict
  if a:n <=# 0
    return ''
  endif
  return self._str[self._pos : self._pos + a:n - 1]
endfunction

function! s:_StringReader_read_char() abort dict
  let c = self.peek_char()
  let self._last_read = strlen(c)
  let self._pos += self._last_read
  return c
endfunction

function! s:_StringReader_peek_char() abort dict
  return matchstr(self._str, '.', self._pos)
endfunction

" NOTE: `self._pos - self._last_read` must not be negative
function! s:_StringReader_unread() abort dict
  let self._pos -= self._last_read
  let self._last_read = 0
endfunction

" NOTE: `strlen(self._str) - self._pos` must not be negative
function! s:_StringReader_size() abort dict
  return strlen(self._str) - self._pos
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
