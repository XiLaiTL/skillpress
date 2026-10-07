///|
/// **站点判据的主流程** —— 那 23 条断言的编排（旧实现 `lib/verify-site.mjs` 的 `main()`）。
///
/// ⚠️ 顺序是判据的一部分，不许"顺手理一理"：
///    · **纯链接节那条排最后**：它会把页面留在**文档模式**（跳到的那一页），
///      而前面的几何/树那几条都要求干净状态 —— 旧实现实测插在中间会把几何判据带红；
///    · `--shot` 截在**第 ③ 条之后、第 ④ 条之前**（那一刻还是官网首屏）；
///    · 断言 ① ② ⑤ 用的是**同一份页面快照**（还没点过任何东西），⑥ ⑦ 是各自现读。

///|
/// 一次站点判据的全部输入（省得到处传十个参数）。
pub struct Ctx {
  cdp : Cdp
  /// 内容根（绝对路径）—— 子页/代码块那些读数要从源里再读一遍。
  root : String
  /// 内容仓根（用来把首页源打成"仓库相对"的标签，与旧实现的 `relative(ROOT, HOME_MD)` 同口径）。
  repo : String
  live_host : @gates.Host
  home_file : String
  /// 首屏那段含加粗的正文（`home_paragraph` 的读数）。
  home_probe : String
  secs : Array[Sec]
  docs : Array[Doc]
  results : Results
  /// `--shot <文件>`：空串 = 不截。
  shot : String
}

///|
/// 取前 `n` 个**码元**（JS 的 `slice(0, n)` —— 短了就全给，不越界）。
pub fn take(s : String, n : Int) -> String {
  let m = if s.length() < n { s.length() } else { n }
  s[0:m].to_owned()
}

///|
/// 把一串字符串用分隔符连起来。
fn join_with(items : Array[String], sep : String) -> String {
  let mut out = ""
  let mut first = true
  for it in items {
    if !first {
      out = out + sep
    }
    out = out + it
    first = false
  }
  out
}

///|
/// `path` 用的分隔符（看它自己长什么样 —— 生成物里要逐字符对上旧实现的 `path.relative`）。
fn sep_of(path : String) -> String {
  if path.contains("\\") { "\\" } else { "/" }
}

///|
/// `from` 目录到 `to` 路径的相对形式（够用的那一档：只做前缀剥离）。
///
/// ⚠️ 用途只有一个：断言 ⑤ 的标签里要打"首页源的**仓库相对**路径"（旧实现用 `path.relative`）。
///    Windows 上它是反斜杠，所以这里按 `from` 自己的分隔符拼回去 —— 换个写法标签就与旧实现不同。
pub fn rel_path(from : String, to : String) -> String {
  let sep = sep_of(from)
  let f = if from.has_suffix("\\") || from.has_suffix("/") {
    from[:from.length() - 1].to_owned()
  } else {
    from
  }
  if to.has_prefix(f + "\\") || to.has_prefix(f + "/") {
    let rest = to[(f.length() + 1):].to_owned()
    let s2 = sep_of(rest)
    if s2 == sep {
      rest
    } else {
      // 分隔符不统一时统一成 `from` 那一套（判据只在乎"与旧实现同形"）
      let out : Array[String] = []
      for ch in rest {
        out.push(if ch == '\\' || ch == '/' { sep } else { ch.to_string() })
      }
      out.join("")
    }
  } else {
    to
  }
}

///|
/// `--shot`：截一张首页首屏存下来（**图不参与判据**，所以截在"首屏刚验完"那一刻）。
async fn save_shot(ctx : Ctx) -> Unit raise {
  if ctx.shot == "" {
    return
  }
  let b64 = ctx.cdp.screenshot_png()
  let path = ctx.live_host.resolve(ctx.shot)
  let bytes = decode_base64(b64)
  @fs.write_file(path, bytes)
  info("首页首屏截图 → " + rel_path(ctx.repo, path))
}

///|
/// 极简 base64 解码（截图用；只认标准字母表与 `=` 填充）。
fn decode_base64(s : String) -> Bytes {
  let out : Array[Byte] = []
  let mut buf = 0
  let mut bits = 0
  for ch in s {
    let v = b64_val(ch)
    if v < 0 {
      continue
    }
    buf = (buf << 6) | v
    bits = bits + 6
    if bits >= 8 {
      bits = bits - 8
      out.push(((buf >> bits) & 0xFF).to_byte())
    }
  }
  let arr : Array[Byte] = out
  Bytes::from_array(arr)
}

///|
fn b64_val(ch : Char) -> Int {
  let c = ch.to_int()
  if c >= 65 && c <= 90 {
    c - 65
  } else if c >= 97 && c <= 122 {
    c - 97 + 26
  } else if c >= 48 && c <= 57 {
    c - 48 + 52
  } else if ch == '+' {
    62
  } else if ch == '/' {
    63
  } else {
    -1
  }
}
