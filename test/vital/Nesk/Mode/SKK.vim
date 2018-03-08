
let s:suite = themis#suite('Nesk.Mode.SKK')
let s:assert = themis#helper('assert')

function! s:suite.before()
  let V = vital#nesk#new()
  let s:Error = V.import('Nesk.Error')
  let s:Nesk = V.import('Nesk')
endfunction

function! s:suite.__convert__()
  let suite = themis#suite('convert')

  function! suite.before_each() abort
    let s:INSTANCE = s:Nesk.new()
    let err = s:INSTANCE.load_modes_in_rtp()
    call s:assert.same(err, s:Error.NIL)
    let err = s:INSTANCE.enable()
    call s:assert.same(err, s:Error.NIL)
  endfunction

  function! suite.basic() abort
    for [in, out, outraw] in [
    \ ['a', 'あ', 'あ'],
    \ ['u ma', 'う ま', "う m\<C-h>ま"],
    \ ['ka', 'か', "k\<C-h>か"],
    \ ['kya', 'きゃ', "ky\<C-h>\<C-h>きゃ"],
    \ ['kana', 'かな', "k\<C-h>かn\<C-h>な"],
    \ ['kanji', 'かんじ', "k\<C-h>かn\<C-h>んj\<C-h>じ"],
    \ ['kannji', 'かんじ', "k\<C-h>かn\<C-h>んj\<C-h>じ"],
    \ ['kan''ji', 'かんじ', "k\<C-h>かn\<C-h>んj\<C-h>じ"],
    \ ['kekkon', 'けっこn', "k\<C-h>けk\<C-h>っk\<C-h>こn"],
    \ ['kekkonn', 'けっこん', "k\<C-h>けk\<C-h>っk\<C-h>こn\<C-h>ん"],
    \ ["ky\<C-h>a", 'か', "ky\<C-h>\<C-h>か"],
    \ ['www', 'っっw', "w\<C-h>っw\<C-h>っw"],
    \ ["ab\<C-h>c", 'あc', "あb\<C-h>c"],
    \ ["ab\<C-h>\<C-h>c", 'c', "あb\<C-h>\<C-h>c"],
    \ ["ab\<C-h>c\<C-h>", 'あ', "あb\<C-h>c\<C-h>"],
    \ ["ab\<BS>c", 'あc', "あb\<C-h>c"],
    \ ["\<C-h>c", "\<C-h>c", "\<C-h>c"],
    \ ["\<C-h>\<C-h>c", "\<C-h>\<C-h>c", "\<C-h>\<C-h>c"],
    \
    \ ['Kekkonq(Kariq)', 'ケッコン(カリ)', "▽k\<C-h>けk\<C-h>っk\<C-h>こn\<C-h>\<C-h>\<C-h>\<C-h>\<C-h>ケッコン(▽k\<C-h>かr\<C-h>り\<C-h>\<C-h>\<C-h>カリ)"],
    \ ['Qkekkonq(Qkariq)', 'ケッコン(カリ)', "▽k\<C-h>けk\<C-h>っk\<C-h>こn\<C-h>\<C-h>\<C-h>\<C-h>ケッコン(k\<C-h>かr\<C-h>り\<C-h>\<C-h>カリ)"],
    \ ['Kekkonnq(Kariq)', 'ケッコン(カリ)', "▽k\<C-h>けk\<C-h>っk\<C-h>こn\<C-h>ん\<C-h>\<C-h>\<C-h>\<C-h>\<C-h>ケッコン(▽k\<C-h>かr\<C-h>り\<C-h>\<C-h>\<C-h>カリ)"],
    \ ['qwarewareha', 'ワレワレハ', "w\<C-h>ワr\<C-h>レw\<C-h>ワr\<C-h>レh\<C-h>ハ"],
    \ ['warewareha ittai z.?', 'われわれは いったい …？', "w\<C-h>わr\<C-h>れw\<C-h>わr\<C-h>れh\<C-h>はいt\<C-h>っt\<C-h>たい …？"],
    \ ['madokaqmagika', 'まどかマギカ', "m\<C-h>まd\<C-h>どk\<C-h>かm\<C-h>マg\<C-h>ギk\<C-h>カ"],
    \ ['madokaMagikaq', 'まどかマギカ', "m\<C-h>まd\<C-h>どk\<C-h>か\<C-h>▽m\<C-h>まg\<C-h>ぎk\<C-h>か\<C-h>\<C-h>\<C-h>\<C-h>マギカ"],
    \ ['madokaQmagikaq', 'まどかマギカ', "m\<C-h>まd\<C-h>どk\<C-h>か\<C-h>▽m\<C-h>まg\<C-h>ぎk\<C-h>か\<C-h>\<C-h>\<C-h>\<C-h>マギカ"],
    \ ['qMadokaqmagika', 'まどかマギカ', "▽m\<C-h>マd\<C-h>ドk\<C-h>カ\<C-h>\<C-h>\<C-h>\<C-h>まどかm\<C-h>マg\<C-h>ギk\<C-h>カ"],
    \ ['qQmadokaqmagika', 'まどかマギカ', "▽m\<C-h>マd\<C-h>ドk\<C-h>カ\<C-h>\<C-h>\<C-h>\<C-h>まどかm\<C-h>マg\<C-h>ギk\<C-h>カ"],
    \ ['hidamariSukettiqhosimittu', 'ひだまりスケッチほしみっつ', "h\<C-h>ひd\<C-h>だm\<C-h>まr\<C-h>り▽s\<C-h>すk\<C-h>けt\<C-h>っt\<C-h>ち\<C-h>\<C-h>\<C-h>\<C-h>\<C-h>スケッチh\<C-h>ほs\<C-h>しm\<C-h>みt\<C-h>っt\<C-h>つ"],
    \
    \ ['lyou', 'you', 'you'],
    \ ['lwindows xp', 'windows xp', 'windows xp'],
    \ ["lyou\<C-j>hananisiniNipponqhe?", 'youはなにしにニッポンへ？', "youh\<C-h>はn\<C-h>なn\<C-h>にs\<C-h>しn\<C-h>に▽n\<C-h>にt\<C-h>っp\<C-h>ぽn\<C-h>\<C-h>\<C-h>\<C-h>\<C-h>ニッポンh\<C-h>へ？"],
    \ ['Yoyol', 'yoyo', "y\<C-h>よy\<C-h>よ\<C-h>\<C-h>yoyo"],
    \ ['Qyoyol', 'yoyo', "y\<C-h>よy\<C-h>よ\<C-h>\<C-h>yoyo"],
    \
    \ ["\<C-q>uboxa-", 'ｳﾎﾞｧｰ', "ｩb\<C-h>ﾎﾞx\<C-h>ｧｰ"],
    \ ["Uboxa-\<C-q>", 'ｳﾎﾞｧｰ', "▽うb\<C-h>ぼx\<C-h>ぁー\<C-h>\<C-h>\<C-h>\<C-h>\<C-h>\<C-h>ｳﾎﾞｧｰ"],
    \]
      let [str, err] = s:INSTANCE.convert(in)
      call s:assert.same(err, s:Error.NIL)
      call s:assert.equals(str, out, printf('Nesk.convert(): %s => %s', in, out))

      let str = nesk#convert(in)
      call s:assert.equals(str, out, printf('nesk#convert(): %s => %s', in, out))

      let [str, err] = s:INSTANCE.send(in)
      call s:assert.same(err, s:Error.NIL, 'Nesk.init_active_mode()')
      call s:assert.equals(str, outraw, printf('Nesk.send(): %s => %s', in, outraw))

      let err = s:INSTANCE.init_active_mode()
      call s:assert.same(err, s:Error.NIL, 'Nesk.init_active_mode()')
    endfor
  endfunction

  function! suite.after() abort
    unlet s:INSTANCE
  endfunction

endfunction
