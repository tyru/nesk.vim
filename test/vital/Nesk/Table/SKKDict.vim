
let s:suite = themis#suite('skkdict')
let s:assert = themis#helper('assert')

function! s:suite.before()
  let V = vital#nesk#new()
  let s:Error = V.import('Nesk.Error')
  let s:SKKDict = V.import('Nesk.Table.SKKDict')
endfunction

function! s:suite.__userdict__()
  let suite = themis#suite('userdict')

  function! suite.before() abort
    let [s:USERDICT, err] = s:SKKDict.builder(
                    \  'skkdict/user-dict',
                    \  'testdata/user-dict',
                    \  0,
                    \  'utf-8'
                    \)
                    \.build()
    call s:assert.same(err, s:Error.NIL)
  endfunction

  function! suite.get_okuri() abort
    let [entry, err] = s:USERDICT.get('おもi')
    call s:assert.same(err, s:Error.NIL)
    call s:assert.equals(entry, ['おもi', ['思', '']])
  endfunction

  function! suite.search_okuri() abort
    let [entry, err] = s:USERDICT.search('おお')
    call s:assert.same(err, s:Error.NIL)
    call s:assert.equals(entry, [['おおi', ['多', '']], ['おおk', ['多', '']]])
  endfunction

  function! suite.search_no_okuri() abort
    let [entry, err] = s:USERDICT.search('びみ')
    call s:assert.same(err, s:Error.NIL)
    call s:assert.equals(entry, [['びみょうn', ['微妙', '']], ['びみ', ['美味', '']], ['びみょう', ['微妙', ''], ['美妙', '']]])
  endfunction

  function! suite.after() abort
    unlet s:USERDICT
  endfunction

endfunction

function! s:suite.__sysdict__()
  let suite = themis#suite('sysdict')

  function! suite.before() abort
    let [s:SYSDICT, err] = s:SKKDict.builder(
                    \  'skkdict/system-dict',
                    \  'testdata/system-dict',
                    \  1,
                    \  'euc-jp'
                    \)
                    \.build()
    call s:assert.same(err, s:Error.NIL)
  endfunction

  function! suite.get_no_okuri() abort
    let [entry, err] = s:SYSDICT.get('あいきょう')
    call s:assert.same(err, s:Error.NIL)
    call s:assert.equals(entry, ['あいきょう', ['愛嬌', ''], ['愛敬', '=愛嬌'], ['愛郷', '-心']])
    call s:assert.equals(s:SKKDict.Entry.get_key(entry), 'あいきょう')

    let candidates = s:SKKDict.Entry.get_candidates(entry)
    call s:assert.equals(candidates, [['愛嬌', ''], ['愛敬', '=愛嬌'], ['愛郷', '-心']])
    call s:assert.equals(s:SKKDict.EntryCandidate.get_string(candidates[0]), '愛嬌')
    call s:assert.equals(s:SKKDict.EntryCandidate.get_annotation(candidates[0]), '')
    call s:assert.equals(s:SKKDict.EntryCandidate.get_string(candidates[1]), '愛敬')
    call s:assert.equals(s:SKKDict.EntryCandidate.get_annotation(candidates[1]), '=愛嬌')
    call s:assert.equals(s:SKKDict.EntryCandidate.get_string(candidates[2]), '愛郷')
    call s:assert.equals(s:SKKDict.EntryCandidate.get_annotation(candidates[2]), '-心')
  endfunction

  function! suite.get_okuri() abort
    let [entry, err] = s:SYSDICT.get('おもu')
    call s:assert.same(err, s:Error.NIL)
    call s:assert.equals(entry, ['おもu', ['思', ''], ['想', '(字義:ある対象に向かいおもう)'], ['念', '(字義:心中で深くおもう)'], ['憶', '(字義:あれこれとおもう)'], ['重', '']])
  endfunction

  function! suite.search_no_okuri() abort
    let [entry, err] = s:SYSDICT.search('びみ')
    call s:assert.same(err, s:Error.NIL)
    call s:assert.equals(entry, [['びみょうn', ['微妙', '']], ['びみ', ['美味', '']], ['びみょう', ['微妙', ''], ['美妙', '']]])
  endfunction

  function! suite.after() abort
    unlet s:SYSDICT
  endfunction

endfunction
