///|
/// 文本层：`parseFrontmatter` 的**字段表**与 `summarize` 的移植。
///
/// ⚠️ 三处口径必须与旧实现**逐字节等价**（它们会进生成物的 `desc` / `title`，差一个字符整份文件就对不上）：
///   ① `summarize` 的三次**顺序**替换（先反引号、再 `**`、再链接）+ 空白压成一个空格 + 截断；
///   ② 截断长度按 **JS 字符串长度**算（实测：js target 上 MoonBit 的 `String::length()` 就是 JS 的
///      `.length` —— "中文abc" 两边都是 5），所以直接照搬 `max - 1` 个字符 + `…`；
///   ③ frontmatter 只认 `^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$` 这种行，值两端 trim。

///|
/// frontmatter 的字段表（键 → 值，值已 trim）。没有 frontmatter 就给空表。
pub fn frontmatter_data(text : String) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  let c = chars(text)
  let mut first_end = -1
  let mut i = 0
  while i < c.length() {
    if c[i] == '\n' {
      first_end = i
      break
    }
    i = i + 1
  }
  if first_end < 0 || trim(slice(c, 0, first_end)) != "---" {
    return out
  }
  let mut end = -1
  let mut j = first_end + 1
  while j + 3 < c.length() {
    if c[j] == '\n' && c[j + 1] == '-' && c[j + 2] == '-' && c[j + 3] == '-' {
      end = j
      break
    }
    j = j + 1
  }
  if end < 0 {
    return out
  }
  for raw in split_lines(slice(c, first_end + 1, end)) {
    let line = trim(raw)
    // `^([A-Za-z][A-Za-z0-9_-]*):`
    let lc = chars(line)
    if lc.length() == 0 || !is_ascii_alpha(lc[0]) {
      continue
    }
    let mut k = 1
    while k < lc.length() && (is_ascii_alnum(lc[k]) || lc[k] == '_' || lc[k] == '-') {
      k = k + 1
    }
    if k >= lc.length() || lc[k] != ':' {
      continue
    }
    out.set(slice(lc, 0, k), trim(slice(lc, k + 1, lc.length())))
  }
  out
}

///|
fn is_ascii_alpha(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_ascii_alnum(ch : Char) -> Bool {
  is_ascii_alpha(ch) || (ch >= '0' && ch <= '9')
}

///|
/// 一段文本里的**第一处 `# ` 标题**（H1 本身不进正文，页眉与首屏标题用它）。
/// 旧实现：`t.replace(/^#\s+/, "")` —— 即先 `trim()` 再剥掉 `#` 与它后面的空白。
pub fn first_h1(body : String) -> String {
  for raw in split_lines(body) {
    let t = trim(raw)
    let c = chars(t)
    if c.length() > 1 && c[0] == '#' && c[1] == ' ' {
      let mut k = 1
      while k < c.length() && c[k] == ' ' {
        k = k + 1
      }
      return slice(c, k, c.length())
    }
  }
  ""
}

///|
/// `Span` 序列 → 纯文本（旧实现 `plainOf`）。
pub fn plain_of(spans : Array[Span]) -> String {
  spans.map(fn(s) {
    match s {
      Txt(v) | Code(v) | Bold(v) => v
      // 链接的**可读文本是标签**（目标另有 `Code(target)` 那一段，不在这里重复算）
      Link(label, _, _) => label
    }
  }).fold(init="", fn(acc, s) { acc + s })
}

///|
/// 一行摘要（旧实现 `summarize`）。三步替换**顺序不能换**。
pub fn summarize(s : String, max : Int) -> String {
  let t = collapse_ws(unwrap_links(unwrap_bold(unwrap_backticks(s))))
  if t.length() <= max {
    t
  } else {
    // ⚠️ 按 JS 的 `.length` 截断（js target 上 MoonBit 的 `String::length()` 就是它）
    t[:max - 1].to_owned() + "…"
  }
}

///|
/// 空白的定义照 JS 的 `\s`：常见的那几个之外，**全角空格 U+3000 与 NBSP 也算**（中文内容会撞上）。
fn is_js_space(ch : Char) -> Bool {
  ch.is_whitespace() || ch == '\u{00a0}' || ch == '\u{3000}' || ch == '\u{feff}'
}

///|
/// `/`([^`]+)`/g` → 去掉反引号（内容里不许再有反引号，且至少要有一个字符）。
fn unwrap_backticks(s : String) -> String {
  let c = chars(s)
  let out : Array[Char] = []
  let mut i = 0
  while i < c.length() {
    if c[i] == '`' {
      let mut j = i + 1
      while j < c.length() && c[j] != '`' {
        j = j + 1
      }
      if j < c.length() && j > i + 1 {
        for k = i + 1; k < j; k = k + 1 {
          out.push(c[k])
        }
        i = j + 1
        continue
      }
    }
    out.push(c[i])
    i = i + 1
  }
  out.fold(init="", fn(acc, ch) { acc + ch.to_string() })
}

///|
/// `/\*\*([^*]+)\*\*/g` → 去掉加粗标记（内容里不许再有 `*`）。
fn unwrap_bold(s : String) -> String {
  let c = chars(s)
  let out : Array[Char] = []
  let mut i = 0
  while i < c.length() {
    if c[i] == '*' && i + 1 < c.length() && c[i + 1] == '*' {
      let mut j = i + 2
      while j < c.length() && c[j] != '*' {
        j = j + 1
      }
      if j + 1 < c.length() && c[j] == '*' && c[j + 1] == '*' && j > i + 2 {
        for k = i + 2; k < j; k = k + 1 {
          out.push(c[k])
        }
        i = j + 2
        continue
      }
    }
    out.push(c[i])
    i = i + 1
  }
  out.fold(init="", fn(acc, ch) { acc + ch.to_string() })
}

///|
/// `/\[([^\]]+)\]\([^)]*\)/g` → 只留链接文字（这是静态阅读页，"当台词读"）。
fn unwrap_links(s : String) -> String {
  let c = chars(s)
  let out : Array[Char] = []
  let mut i = 0
  while i < c.length() {
    if c[i] == '[' {
      let mut j = i + 1
      while j < c.length() && c[j] != ']' {
        j = j + 1
      }
      if j < c.length() && j > i + 1 && j + 1 < c.length() && c[j + 1] == '(' {
        let mut k = j + 2
        while k < c.length() && c[k] != ')' {
          k = k + 1
        }
        if k < c.length() {
          for m = i + 1; m < j; m = m + 1 {
            out.push(c[m])
          }
          i = k + 1
          continue
        }
      }
    }
    out.push(c[i])
    i = i + 1
  }
  out.fold(init="", fn(acc, ch) { acc + ch.to_string() })
}

///|
/// `/\s+/g` → 一个空格，然后 `trim()`。
fn collapse_ws(s : String) -> String {
  let c = chars(s)
  let out : Array[Char] = []
  let mut pending = false
  let mut started = false
  for ch in c {
    if is_js_space(ch) {
      if started {
        pending = true
      }
      continue
    }
    if pending {
      out.push(' ')
      pending = false
    }
    out.push(ch)
    started = true
  }
  out.fold(init="", fn(acc, ch) { acc + ch.to_string() })
}
