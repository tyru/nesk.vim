" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:Error = a:V.import('Nesk.Error')
  let s:StringReader = a:V.import('Nesk.IO.StringReader')
endfunction

function! s:_vital_depends() abort
  return ['Error', 'Nesk.IO.StringReader']
endfunction


let s:CURSOR_KEYS = ["\<Left>", "\<Right>"]

" _preedit:
"   Preedit string, list of characters.
"   NOTE: Some special characters (e.g.: cursor keys) are not 1 byte.
" _inserted_preedit:
"   The previous preedit string inserted to Vim buffer
"   NOTE: Some special characters (e.g.: cursor keys) are not 1 byte.
" _committed:
"   Committed string, list of characters.
"   NOTE: Some special characters (e.g.: cursor keys) are not 1 byte.
" _char_index:
"   Index of character of `self._preedit`.
" _prev_char_index:
"   The previous value of `self._char_index` before `self.commit()` is executed.
function! s:new() abort
  return {
  \ '_preedit': [],
  \ '_inserted_preedit': [],
  \ '_committed': [],
  \ '_char_index': 0,
  \ '_prev_char_index': 0,
  \ 'write': function('s:_VimBufferWriter_write'),
  \ 'set_char_index': function('s:_VimBufferWriter_set_char_index'),
  \ 'get_preedit': function('s:_VimBufferWriter_get_preedit'),
  \ 'get_committed': function('s:_VimBufferWriter_get_committed'),
  \ 'commit': function('s:_VimBufferWriter_commit'),
  \ 'to_string': function('s:_VimBufferWriter_to_string'),
  \}
endfunction

" Rewrite `self._preedit`, `self._committed`, `self._char_index`.
"
" There are some special characters.
"
" <C-h>,<BS>:
"   Remove the previous character in committed or preedit buffer.
"   If `self._char_index <=# 0`, <C-h> key is appended to `self._preedit`.
" <Del>:
"   TODO
" <C-j>:
"   Append preedit string to committed string, and clear preedit string.
"
" Cursor keys:
"   <Left>:
"     Back one character. Ignore if already the first position.
"     NOTE: Cannot write() a non-cursor keys after writing cursor keys
"     until <C-j> key is written.
"   <Right>:
"     Forward one character. Ignore if already the last position.
"     NOTE: Cannot write() a non-cursor keys after cursor keys
"     until <C-j> key is written.
function! s:_VimBufferWriter_write(str) abort dict
  if a:str is# ''
    return s:Error.NIL
  endif
  let preedit = join(self._preedit, '')
  let before = self._char_index <=# 0 ? '' : strcharpart(preedit, 0, self._char_index)
  let after = self._char_index >=# strchars(preedit) ? '' : strcharpart(preedit, self._char_index)
  let reader = s:StringReader.new(a:str)
  while reader.size() ># 0
    let [c, err] = reader.read_char()
    if err isnot# s:Error.NIL
      return err
    endif
    let bs = 0
    if c is# "\<C-h>"
      let bs = 1
    elseif c is# "\x80"
      " NOTE: StringReader.read() does not return non-nil error
      let str = c . reader.read(2)[0]
      if str is# "\<BS>"
        let bs = 1
        let c = "\<C-h>"
      elseif str is# "\<Left>"
        let self._char_index -= 1
      elseif str is# "\<Right>"
        let self._char_index += 1
      else
        call reader.unread()
      endif
    elseif c is# "\<C-j>"
      let self._committed += self._preedit
      let self._preedit = []
      let self._char_index = 0
      continue
    endif
    if bs
      if !empty(self._preedit) && self._preedit[-1] isnot# "\<C-h>"
        call remove(self._preedit, -1)
        let self._char_index -= 1
      elseif !empty(self._committed) && self._committed[-1] isnot# "\<C-h>"
        call remove(self._committed, -1)
        let self._char_index -= 1
      else
        let self._preedit += ["\<C-h>"]
        let self._char_index -= 1
      endif
      continue
    endif
    let self._preedit += [c]
    let self._char_index += 1
  endwhile
  return s:Error.NIL
endfunction

" Sets current column position.
" Return an error if invalid index.
" This removes all cursor keys (e.g.: cursor keys) in
" `self._preedit`, `self._committed`.
function! s:_VimBufferWriter_set_char_index(index) abort dict
  if type(a:index) isnot# v:t_number
    return s:Error.new(
    \ 'Nesk.IO.VimBufferWriter: given index is not a number: ' . string(a:index)
    \)
  endif
  let preedit = filter(copy(self._preedit), {_,c -> index(s:CURSOR_KEYS, c) is# -1})
  let committed = filter(copy(self._committed), {_,c -> index(s:CURSOR_KEYS, c) is# -1})
  if s:_out_of_range(committed, preedit, a:index)
    return s:Error.new(
    \ 'Nesk.IO.VimBufferWriter: given out of range index: ' . a:index
    \)
  endif
  let self._char_index = a:index
  let self._preedit = preedit
  let self._committed = committed
  return s:Error.NIL
endfunction

function! s:_out_of_range(committed, preedit, index) abort
  let committed = join(a:committed, '')
  let idx = a:index + strchars(committed)
  return idx <# 0 || strchars(committed . join(a:preedit, '')) >=# idx
endfunction

" Returns preedit string.
function! s:_VimBufferWriter_get_preedit() abort dict
  return join(self._preedit, '')
endfunction

" Returns committed string.
function! s:_VimBufferWriter_get_committed() abort dict
  return join(self._committed, '')
endfunction

" Sets current state to the state which is a buffer after inserted
" `VimBufferWriter.to_string()` string.
" This is normally used after getting inserted string by
" `VimBufferWriter.to_string()`.
function! s:_VimBufferWriter_commit() abort dict
  PP! ['commit()']
  let self._committed = []
  let self._inserted_preedit = copy(self._preedit)
  let self._prev_char_index = self._char_index
endfunction

" Returns inserted string to Vim buffer.
function! s:_VimBufferWriter_to_string() abort dict
  PP! ['to_string()']
  if empty(self._committed) && self._preedit ==# self._inserted_preedit
    return ''
  endif
  let bs = repeat("\<C-h>", strchars(join(self._inserted_preedit, '')))
  let new = join(self._preedit, '')
  let diff = self._char_index - (self._prev_char_index + strchars(new))
  let move = repeat(diff ># 0 ? "\<Right>" : "\<Left>", diff)
  PP! ['to_string()', bs, new, move, self._committed, self._preedit, self._char_index, self._prev_char_index]
  return bs . new . move
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
