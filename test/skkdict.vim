
function! s:init(V) abort
  let s:Error = a:V.import('Nesk.Error')
  let s:SKKDict = a:V.import('Nesk.Table.SKKDict')
endfunction
call s:init(vital#nesk#new())

function! s:run() abort
  let v:errors = []

  let userdict = nesk#table#skkdict#new('skkdict/user-dict', expand('~/.skkdict/user-dict'), 0, 'utf-8')
  let err = userdict.reload()
  call assert_equal(s:Error.NIL, err)

  let [entry, err] = userdict.get('おもi')
  call assert_equal(s:Error.NIL, err)
  call assert_equal(['おもi', ['思']], entry)

  let [entry, err] = userdict.search('おお')
  call assert_equal(s:Error.NIL, err)
  call assert_equal([['おおi', ['多']], ['おおk', ['多']]], entry)

  let [entry, err] = userdict.search('びみ')
  call assert_equal(s:Error.NIL, err)
  call assert_equal([['びみょうn', ['微妙']], ['びみ', ['美味']], ['びみょう', ['微妙'], ['美妙']]], entry)

  let sysdict = nesk#table#skkdict#new('skkdict/system-dict', expand('~/.skkdict/system-dict'), 1, 'euc-jp')
  let err = sysdict.reload()
  call assert_equal(s:Error.NIL, err)

  let [entry, err] = sysdict.get('わんきゅう')
  call assert_equal(s:Error.NIL, err)
  call assert_equal(['わんきゅう', ['椀久', '椀屋久右衛門']], entry)
  call assert_equal('わんきゅう', s:SKKDict.Entry.get_key(entry))
  let candidates = s:SKKDict.Entry.get_candidates(entry)
  call assert_equal([['椀久', '椀屋久右衛門']], candidates)
  call assert_equal('椀久', s:SKKDict.EntryCandidate.get_string(candidates[0]))
  call assert_equal('椀屋久右衛門', s:SKKDict.EntryCandidate.get_annotation(candidates[0]))

  let [entry, err] = sysdict.get('おもu')
  call assert_equal(s:Error.NIL, err)
  call assert_equal(['おもu', ['思'], ['想', '(字義:ある対象に向かいおもう)'], ['念', '(字義:心中で深くおもう)'], ['憶', '(字義:あれこれとおもう)'], ['重']], entry)

  let [entry, err] = sysdict.search('びみ')
  call assert_equal(s:Error.NIL, err)
  call assert_equal([['びみょうn', ['微妙']], ['びみ', ['美味']], ['びみょう', ['微妙'], ['美妙']]], entry)

  echohl ErrorMsg
  for err in v:errors
    echomsg err
  endfor
  echohl None
endfunction

call s:run()
