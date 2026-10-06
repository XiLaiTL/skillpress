///|
/// 文本扫描 —— **照旧门那几条正则的口径写**（不是照内容管线的解析器）。
///
/// 索引一律走 `Array[Char]`：MoonBit 的 `String` 在 js 后端是 UTF-16、native 是 UTF-8，
/// 而"下标"的语义两边可能不同；门只在 js 上跑，但口径统一才不会埋雷。
///
/// ⚠️ 两处**故意跟 JS 对齐**的细节：
///   · 围栏代码块的开栏行**不许含反引号**（旧正则 `^```([^\n`]*)\n`），所以 ` ````x ` 那一行
///     既不是开栏也不是闭栏 —— 整块就当没有；
///   · 行内代码**不许跨行**（`/`([^`\n]+)`/`g`），没闭合的反引号会让解析器**从下一个反引号**再试。

///|
/// 字符串 → 字符数组。
pub fn chars(s : String) -> Array[Char] {
  s.to_array()
}

///|
/// `chars[a..b)` → 字符串。
pub fn slice(c : Array[Char], a : Int, b : Int) -> String {
  let mut out = ""
  let mut i = if a < 0 { 0 } else { a }
  let hi = if b > c.length() { c.length() } else { b }
  while i < hi {
    out = out + c[i].to_string()
    i = i + 1
  }
  out
}

///|
/// JS 的 `String.prototype.trim()`（只吃两端空白）。
pub fn trim(s : String) -> String {
  let c = chars(s)
  let mut a = 0
  let mut b = c.length()
  while a < b && c[a].is_whitespace() {
    a = a + 1
  }
  while b > a && c[b - 1].is_whitespace() {
    b = b - 1
  }
  slice(c, a, b)
}

///|
/// ASCII 小写（旧门把围栏标记 `.toLowerCase()`）。
pub fn ascii_lower(s : String) -> String {
  let up = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".to_array()
  let lo = "abcdefghijklmnopqrstuvwxyz".to_array()
  let mut out = ""
  for ch in s {
    let mut piece = ch.to_string()
    for i = 0; i < up.length(); i = i + 1 {
      if up[i] == ch {
        piece = lo[i].to_string()
      }
    }
    out = out + piece
  }
  out
}

///|
/// 按 `\n` 切行（JS `split("\n")` —— 空串给 `[""]`，不是空数组）。
pub fn split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur : Array[Char] = []
  for ch in s {
    if ch == '\n' {
      out.push(cur.fold(init="", fn(acc, c) { acc + c.to_string() }))
      cur = []
    } else {
      cur.push(ch)
    }
  }
  out.push(cur.fold(init="", fn(acc, c) { acc + c.to_string() }))
  out
}

///|
/// 用 `\n` 拼接若干行（**首行判定用显式标记**，不吃空行）。
/// 收 `ArrayView` 是因为调用点常常是切片（`lines[i+1:close]`）。
pub fn join_lines(lines : ArrayView[String]) -> String {
  let mut out = ""
  let mut first = true
  for line in lines {
    out = if first { line } else { out + "\n" + line }
    first = false
  }
  out
}

///|
/// `\r` 的个数（G2 的报错里要点名"几处"）。
pub fn count_cr(s : String) -> Int {
  let mut n = 0
  for ch in s {
    if ch == '\r' {
      n = n + 1
    }
  }
  n
}

///|
/// 一个围栏代码块：语言（已 trim + 小写）+ 正文。
pub struct Fence {
  lang : String
  code : String
}

///|
/// 这一行是不是"闭栏"：以 ``` 开头且后面**只有空白**（旧正则 `^```\s*$`）。
fn is_close_line(line : String) -> Bool {
  if !line.has_prefix("```") {
    return false
  }
  trim(slice(chars(line), 3, chars(line).length())) == ""
}

///|
/// 开栏行 → 语言标记。**含反引号就整行不作数**（旧正则的 `[^`\n]*`）。
fn open_lang(line : String) -> String? {
  if !line.has_prefix("```") {
    return None
  }
  let rest = slice(chars(line), 3, chars(line).length())
  for ch in rest {
    if ch == '`' {
      return None
    }
  }
  Some(ascii_lower(trim(rest)))
}

///|
/// 围栏代码块（旧实现 `fencedBlocks`）：`/^```([^\n`]*)\n([\s\S]*?)^```\s*$/gm`。
///
/// 闭栏之后**从闭栏的下一行继续**（旧正则是全局的、吃掉闭栏那一行）——
/// 所以"没闭合的开栏"不会把后面的块吞掉。
pub fn fenced_blocks(body : String) -> Array[Fence] {
  let lines = split_lines(body)
  let out : Array[Fence] = []
  let mut i = 0
  while i < lines.length() {
    match open_lang(lines[i]) {
      None => i = i + 1
      Some(lang) => {
        // 找闭栏
        let mut j = i + 1
        let mut close = -1
        while j < lines.length() {
          if is_close_line(lines[j]) {
            close = j
            break
          }
          j = j + 1
        }
        if close < 0 {
          i = i + 1
        } else {
          let body_lines = lines[i + 1:close]
          // ⚠️ 拼接**不能**用"acc 是空串就算首行"这种判法：块里第一行本身就是空行时
          // （` ```\n\nx\n``` `）它会把那一行吃掉 —— G2 的"代码块 N 行"当场判少一行。
          out.push({ lang, code: join_lines(body_lines) })
          i = close + 1
        }
      }
    }
  }
  out
}

///|
/// 行内代码（旧实现 `inlineCodes`）：`/`([^`\n]+)`/g` —— 非空、**不跨行**、非重叠。
pub fn inline_codes(body : String) -> Array[String] {
  let c = chars(body)
  let out : Array[String] = []
  let mut i = 0
  while i < c.length() {
    if c[i] != '`' {
      i = i + 1
      continue
    }
    let mut j = i + 1
    let mut closed = -1
    while j < c.length() {
      if c[j] == '\n' {
        break
      }
      if c[j] == '`' {
        closed = j
        break
      }
      j = j + 1
    }
    if closed > i + 1 {
      out.push(slice(c, i + 1, closed))
      i = closed + 1
    } else {
      // 没闭合（或内容为空）⇒ 从下一个字符再试 —— 与正则引擎的推进方式一致
      i = i + 1
    }
  }
  out
}

///|
/// 字符串的 **UTF-16 码元**序列（`Char` 是码点，星平面字符在这里变两个单元）。
/// G7 的否定窗口要用它，排序也要用它。
pub fn utf16_units(s : String) -> Array[Int] {
  let out : Array[Int] = []
  for ch in s {
    let cp = ch.to_int()
    if cp < 0x10000 {
      out.push(cp)
    } else {
      let v = cp - 0x10000
      out.push(0xD800 + (v >> 10))
      out.push(0xDC00 + (v & 0x3FF))
    }
  }
  out
}

///|
/// **按 UTF-16 码元序比较** —— 就是 JS `Array.prototype.sort()` 的默认比较（`a < b` 那套）。
///
/// ⚠️ 不能用 MoonBit 的 `Array::sort()`：实测它给 `["styles.md","structure.md","events-and-subs.md","FAQ.md"]`
/// 排出 `["FAQ.md","styles.md","structure.md","events-and-subs.md"]`（像是按长度先比）——
/// **不是字典序**。这一处曾经让真仓对账整片错位（`references/` 的文件顺序就是输出顺序）。
pub fn utf16_compare(a : String, b : String) -> Int {
  let ua = utf16_units(a)
  let ub = utf16_units(b)
  let mut i = 0
  while i < ua.length() && i < ub.length() {
    if ua[i] != ub[i] {
      return if ua[i] < ub[i] { -1 } else { 1 }
    }
    i = i + 1
  }
  if ua.length() == ub.length() {
    0
  } else if ua.length() < ub.length() {
    -1
  } else {
    1
  }
}

///|
/// 稳定插入排序（按 `utf16_compare`）。元素数很小（`references/` 顶多几十个），
/// 而**稳定性是判据的一部分**：JS 的 `sort` 从 ES2019 起保证稳定。
pub fn sort_utf16(items : Array[String]) -> Unit {
  let mut i = 1
  while i < items.length() {
    let cur = items[i]
    let mut j = i
    while j > 0 && utf16_compare(items[j - 1], cur) > 0 {
      items[j] = items[j - 1]
      j = j - 1
    }
    items[j] = cur
    i = i + 1
  }
}

///|
/// `chars` 里从 `from` 起找 `needle` 的下标（码点下标；找不到给 -1）。
pub fn index_of_from(hay : Array[Char], needle : Array[Char], from : Int) -> Int {
  if needle.length() == 0 {
    return if from <= hay.length() { from } else { -1 }
  }
  let mut i = if from < 0 { 0 } else { from }
  while i + needle.length() <= hay.length() {
    let mut k = 0
    let mut hit = true
    while k < needle.length() {
      if hay[i + k] != needle[k] {
        hit = false
        break
      }
      k = k + 1
    }
    if hit {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// **UTF-16 单元宽度**：JS 的 `slice`/`length` 都按 UTF-16 单元算，而旧门的 G7 用的是
/// `body.slice(at - 4, at)` —— 这段窗口得按**单元**切，不能按码点切（星平面字符占两个单元）。
pub fn utf16_width(ch : Char) -> Int {
  if ch.to_int() > 0xFFFF {
    2
  } else {
    1
  }
}

///|
/// 取"命中点前面 4 个 UTF-16 单元"那一段（旧实现 `body.slice(Math.max(0, at - 4), at)`）。
///
/// ⚠️ 跨在边界上的**星平面字符会被整只排除**：JS 的 `slice` 会把它切一半（留一个孤立的
/// 代理项），而孤立的代理项永远匹配不到 `[不非别没]` —— 所以"排除"与"切一半"在这条判据上等价。
pub fn utf16_window_before(c : Array[Char], at : Int, units : Int) -> String {
  let mut want = units
  let mut i = at - 1
  let mut lo = at
  while i >= 0 && want > 0 {
    let w = utf16_width(c[i])
    if w > want {
      break
    }
    want = want - w
    lo = i
    i = i - 1
  }
  slice(c, lo, at)
}
