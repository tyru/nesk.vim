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


function! s:new() abort
  return {
  \ '_str': '',
  \ 'write': function('s:_VimBufferWriter_write'),
  \ 'to_string': function('s:_VimBufferWriter_to_string'),
  \}
endfunction

" TODO: skip last parsed string
function! s:_VimBufferWriter_write(str) abort dict
  if a:str is# ''
    return s:Error.NIL
  endif
  let reader = s:StringReader.new(self._str . a:str)
  let result = []
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
      if c . reader.read(2)[0] is# "\<BS>"
        let bs = 1
        let c = "\<C-h>"
      else
        call reader.unread()
      endif
    endif
    if bs && !empty(result) && result[-1] isnot# "\<C-h>"
      call remove(result, -1)
    else
      let result += [c]
    endif
  endwhile
  let self._str = join(result, '')
  return s:Error.NIL
endfunction

function! s:_VimBufferWriter_to_string() abort dict
  return self._str
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
