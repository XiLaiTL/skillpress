///|
/// **行内标记的剥离**（`plain()` 那三步）—— markdown → 页面上真能看见的字。
///
/// ⚠️ 为什么要三趟扫描而不是一个正则：JS 那边是三条 `replace(/…/g)` **依次**打进同一个串，
///    而后一条能看见前一条的结果（`[**x**](u)` 就先剥链、再剥粗体）。
///    顺序换了，剥出来的字就不同 —— 而探针就是拿这个字去页面上找的。
/// 找下一个匹配并把整段换成别的 —— `plain()` 那三步全局替换的公共骨架。
///
/// `scan(cs, from)` 返回 `(start, end, 替换文本)`；找不到给 `None`。
/// 替换后从 `end` 继续扫，所以不会重叠 —— 与 JS 的 `replace(/…/g)` 同口径。
///
/// ⚠️ 匹不上时要**从下一个候选字符接着试**（JS 的正则会回溯），见三个 `scan_*`。
fn replace_scanned(s : String, scan : (Array[Char], Int) -> (Int, Int, String)?) -> String {
  let cs = chars_of(s)
  let out : Array[String] = []
  let n = cs.length()
  let mut i = 0
  while i < n {
    match scan(cs, i) {
      Some((a, b, rep)) => {
        out.push(@content.slice(cs, i, a))
        out.push(rep)
        i = b
      }
      None => {
        out.push(@content.slice(cs, i, n))
        i = n
      }
    }
  }
  out.join("")
}

///|
/// 下一个 `[文字](目标)`（`\[([^\]]+)\]\([^)]*\)`）。文字至少一个字符，目标可以为空。
fn scan_link(cs : Array[Char], from : Int) -> (Int, Int, String)? {
  let n = cs.length()
  let mut j = from
  while j < n {
    if cs[j] != '[' {
      j = j + 1
      continue
    }
    let mut k = j + 1
    while k < n && cs[k] != ']' {
      k = k + 1
    }
    if k >= n || k == j + 1 || k + 1 >= n || cs[k + 1] != '(' {
      j = j + 1
      continue
    }
    let mut m = k + 2
    while m < n && cs[m] != ')' {
      m = m + 1
    }
    if m >= n {
      j = j + 1
      continue
    }
    return Some((j, m + 1, @content.slice(cs, j + 1, k)))
  }
  None
}

///|
/// 下一个 `**粗体**`（`\*\*([^*]+)\*\*`）：内容至少一个非 `*` 字符，且必须紧跟 `**`。
fn scan_bold(cs : Array[Char], from : Int) -> (Int, Int, String)? {
  let n = cs.length()
  let mut j = from
  while j + 1 < n {
    if !(cs[j] == '*' && cs[j + 1] == '*') {
      j = j + 1
      continue
    }
    let mut k = j + 2
    while k < n && cs[k] != '*' {
      k = k + 1
    }
    if k >= n || k == j + 2 || k + 1 >= n || cs[k + 1] != '*' {
      j = j + 1
      continue
    }
    return Some((j, k + 2, @content.slice(cs, j + 2, k)))
  }
  None
}

///|
/// 下一个 `` `行内代码` ``（`` `([^`]+)` ``）。
fn scan_code(cs : Array[Char], from : Int) -> (Int, Int, String)? {
  let n = cs.length()
  let mut j = from
  while j < n {
    if cs[j] != '`' {
      j = j + 1
      continue
    }
    let mut k = j + 1
    while k < n && cs[k] != '`' {
      k = k + 1
    }
    if k >= n || k == j + 1 {
      j = j + 1
      continue
    }
    return Some((j, k + 1, @content.slice(cs, j + 1, k)))
  }
  None
}

///|
/// markdown 行内标记去掉、空白归一 —— 与页面上的 `innerText` 对得上。
///
/// ⚠️ 三步的**顺序**是判据的一部分（先链、再粗体、再行内代码）：换顺序会让
///    `[**x**](u)` 这类嵌套剥出不同的结果。照抄旧实现，别"顺手理一理"。
pub fn plain(s : String) -> String {
  let a = replace_scanned(s, scan_link)
  let b = replace_scanned(a, scan_bold)
  let c = replace_scanned(b, scan_code)
  norm(c)
}

///|
