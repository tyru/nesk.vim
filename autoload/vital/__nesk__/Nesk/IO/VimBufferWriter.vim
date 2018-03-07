" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:StringWriter = a:V.import('Nesk.IO.StringWriter')
  let s:StringReader = a:V.import('Nesk.IO.StringReader')
endfunction

function! s:_vital_depends() abort
  return ['Nesk.IO.StringWriter', 'Nesk.IO.StringReader']
endfunction


function! s:new() abort
  return {
  \ '_writer': s:StringWriter.new(),
  \ 'write': function('s:_VimBufferWriter_write'),
  \ 'to_string': function('s:_VimBufferWriter_to_string'),
  \}
endfunction

function! s:_VimBufferWriter_write(str) abort dict
  return self._writer.write(a:str)
endfunction

function! s:_VimBufferWriter_to_string() abort dict
  let reader = s:StringReader.new(self._writer.to_string())
  let result = ''
  while reader.size() ># 0
    let c = reader.read_char()
    if c is# "\<C-h>"
      let result = strcharpart(result, 0, strchars(result)-1)
    elseif c is# "\x80"
      " NOTE: StringReader.read() does not return non-nil error
      let str = c . reader.read(2)[0]
      if str is# "\<BS>"
        let result = strcharpart(result, 0, strchars(result)-1)
      else
        call reader.unread()
        let result .= "\x80"
      endif
    else
      let result .= c
    endif
  endwhile
  return result
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
