///|
/// 块解析与 frontmatter 切分（旧实现 `parseBlocks` / `parseFrontmatter` 的移植）。
///
/// ⚠️ 这一层里"看着多余"的东西**都是判据要的**，逐条都有出处：
///   · 代码块用**剔除后**的行判闭合（`/^```/` 打在 `trim()` 过的行上）；
///   · 表格的续行判据是 `^\s*\|`（**允许前导空白**），但块的起始判据是 `^\|`（不许）；
///   · 段落续行的 `BREAK` 里，前四条打在**剔除后**的行上，后两条打在**原始行**上；
///   · 列表项的判定同样打在原始行上（`^\s*[-*]\s+`），取内容时才 `trim()`。

///|
/// 切掉 YAML frontmatter（`---` 包起来那段），返回**正文**。
///
/// 与旧实现同一套边界：首行 trim 后必须是 `---`；结束取**第一次**出现的 `\n---`；
/// 正文从那个 `\n---` 之后的第 4 个字符起（即跳过 `\n---`，**留下的换行也算正文**）。
pub fn frontmatter_body(text : String) -> String {
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
  if first_end < 0 {
    return text
  }
  if trim(slice(c, 0, first_end)) != "---" {
    return text
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
    return text
  }
  slice(c, end + 4, c.length())
}

///|
/// 行首空白字符个数（旧实现 `raw.match(/^\s*/)[0].length`）。
fn leading_ws(raw : String) -> Int {
  let c = chars(raw)
  let mut n = 0
  while n < c.length() && c[n].is_whitespace() {
    n = n + 1
  }
  n
}

///|
/// `/^#{2,4}\s+/` → `(级别, 标题原文)`。
fn heading(t : String) -> (Int, String)? {
  let c = chars(t)
  let mut n = 0
  while n < c.length() && c[n] == '#' {
    n = n + 1
  }
  if n < 2 || n > 4 {
    return None
  }
  if n >= c.length() || !c[n].is_whitespace() {
    return None
  }
  let mut k = n
  while k < c.length() && c[k].is_whitespace() {
    k = k + 1
  }
  Some((n, trim(slice(c, k, c.length()))))
}

///|
/// `/^#\s+/`（H1：只吃掉标题，不进 `blocks`）。
fn is_h1(t : String) -> Bool {
  let c = chars(t)
  c.length() >= 2 && c[0] == '#' && c[1].is_whitespace()
}

///|
/// `/^-{3,}$/`（**先 trim 再判**）。
fn is_hr(t : String) -> Bool {
  let c = chars(t)
  if c.length() < 3 {
    return false
  }
  for ch in c {
    if ch != '-' {
      return false
    }
  }
  true
}

///|
/// `/^\s*[-*]\s+/` → 命中的前缀长度（在**原始行**上判）。
fn bullet_prefix(raw : String) -> Int? {
  let c = chars(raw)
  let mut k = 0
  while k < c.length() && c[k].is_whitespace() {
    k = k + 1
  }
  if k >= c.length() || (c[k] != '-' && c[k] != '*') {
    return None
  }
  let mut m = k + 1
  if m >= c.length() || !c[m].is_whitespace() {
    return None
  }
  while m < c.length() && c[m].is_whitespace() {
    m = m + 1
  }
  Some(m)
}

///|
/// `/^\s*\d+[.)]\s+/` → `(前缀长度, 数字串)`（在**原始行**上判）。
fn ordered_prefix(raw : String) -> (Int, String)? {
  let c = chars(raw)
  let mut k = 0
  while k < c.length() && c[k].is_whitespace() {
    k = k + 1
  }
  let mut d = k
  while d < c.length() && c[d] >= '0' && c[d] <= '9' {
    d = d + 1
  }
  if d == k || d >= c.length() || (c[d] != '.' && c[d] != ')') {
    return None
  }
  let mut m = d + 1
  if m >= c.length() || !c[m].is_whitespace() {
    return None
  }
  while m < c.length() && c[m].is_whitespace() {
    m = m + 1
  }
  Some((m, slice(c, k, d)))
}

///|
/// 段落续行的终止判据（旧实现 `BREAK(nt, raw)`）：**前四条打在剔除后的行上，后两条打在原始行上**。
fn breaks(nt : String, raw : String) -> Bool {
  if nt == "" {
    return true
  }
  if nt.has_prefix("```") || nt.has_prefix("|") || nt.has_prefix(">") {
    return true
  }
  match heading(nt) {
    Some(_) => return true
    None => ()
  }
  if is_h1(nt) {
    return true
  }
  if bullet_prefix(raw) is Some(_) {
    return true
  }
  if ordered_prefix(raw) is Some(_) {
    return true
  }
  is_hr(nt)
}

///|
/// 引用行剥掉 `>` 与**一个**可选空白（旧实现 `replace(/^>\s?/, "")`，打在 trim 过的行上）。
fn strip_quote(t : String) -> String {
  let c = chars(t)
  if c.length() == 0 || c[0] != '>' {
    return t
  }
  let mut k = 1
  if k < c.length() && c[k].is_whitespace() {
    k = k + 1
  }
  slice(c, k, c.length())
}

///|
/// 表格行 → 单元格：**只去掉一个**首 `|` 与一个尾 `|`，再按 `|` 切、各自 trim。
fn cells(row : String) -> Array[String] {
  let c = chars(row)
  let mut a = 0
  let mut b = c.length()
  if a < b && c[a] == '|' {
    a = a + 1
  }
  if b > a && c[b - 1] == '|' {
    b = b - 1
  }
  let mid = slice(c, a, b)
  let out : Array[String] = []
  let mut cur : Array[Char] = []
  for ch in mid {
    if ch == '|' {
      out.push(trim(cur.fold(init="", fn(acc, x) { acc + x.to_string() })))
      cur = []
    } else {
      cur.push(ch)
    }
  }
  out.push(trim(cur.fold(init="", fn(acc, x) { acc + x.to_string() })))
  out
}

///|
/// 正文 → 块序列。`problems`（旧实现的报错清单）**这条命令不用**：块照收，问题照报的那种口径
/// 是写给人的，`dump-blocks` 的判据是"生成物逐字节一致"。
pub fn parse_blocks(body : String) -> Array[Block] {
  let lines = split_lines(body)
  let blocks : Array[Block] = []
  let mut i = 0
  while i < lines.length() {
    let raw = lines[i]
    let t = trim(raw)
    if t == "" {
      i = i + 1
      continue
    }
    if t.has_prefix("```") {
      let lang = trim(slice(chars(t), 3, chars(t).length()))
      let buf : Array[String] = []
      i = i + 1
      while i < lines.length() && !trim(lines[i]).has_prefix("```") {
        buf.push(lines[i])
        i = i + 1
      }
      i = i + 1
      blocks.push(Code(lang, buf.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "\n" + s } }), []))
      continue
    }
    if is_hr(t) {
      blocks.push(Hr)
      i = i + 1
      continue
    }
    match heading(t) {
      Some((lvl, head)) => {
        let pl = pure_link(head)
        if lvl == 2 && pl is Some(_) {
          let (label, _) = pl.unwrap()
          blocks.push(H2(inline(label)))
        } else if lvl == 2 {
          blocks.push(H2(inline(head)))
        } else if lvl == 3 {
          blocks.push(H3(inline(head)))
        } else {
          blocks.push(H4(inline(head)))
        }
        i = i + 1
        continue
      }
      None => ()
    }
    if is_h1(t) {
      i = i + 1
      continue
    }
    if t.has_prefix("|") {
      let rows : Array[String] = []
      while i < lines.length() && trim(lines[i]).has_prefix("|") {
        rows.push(trim(lines[i]))
        i = i + 1
      }
      let header = cells(rows[0]).map(inline)
      let body_rows : Array[Array[Array[Span]]] = []
      for k = 2; k < rows.length(); k = k + 1 {
        body_rows.push(cells(rows[k]).map(inline))
      }
      blocks.push(Table(header, body_rows))
      continue
    }
    if t.has_prefix(">") {
      let buf : Array[String] = []
      while i < lines.length() && trim(lines[i]).has_prefix(">") {
        buf.push(strip_quote(trim(lines[i])))
        i = i + 1
      }
      blocks.push(Quote(inline(buf.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + " " + s } }))))
      continue
    }
    let as_bullet = bullet_prefix(raw)
    let as_ordered = ordered_prefix(raw)
    if as_bullet is Some(_) || as_ordered is Some(_) {
      let ordered = as_ordered is Some(_)
      let items : Array[UlItem] = []
      while i < lines.length() {
        let r = lines[i]
        let ok = if ordered { ordered_prefix(r) is Some(_) } else { bullet_prefix(r) is Some(_) }
        if !ok {
          break
        }
        let indent = if leading_ws(r) >= 2 { 1 } else { 0 }
        let num = if ordered {
          match ordered_prefix(r) {
            Some((_, digits)) => digits + ". "
            None => ""
          }
        } else {
          ""
        }
        let content = if ordered {
          match ordered_prefix(trim(r)) {
            Some((n, _)) => slice(chars(trim(r)), n, chars(trim(r)).length())
            None => trim(r)
          }
        } else {
          match bullet_prefix(trim(r)) {
            Some(n) => slice(chars(trim(r)), n, chars(trim(r)).length())
            None => trim(r)
          }
        }
        items.push({ indent, num, spans: inline(content) })
        i = i + 1
      }
      blocks.push(Ul(items))
      continue
    }
    if t.has_prefix("![") || t.has_prefix("<") {
      i = i + 1
      continue
    }
    let buf : Array[String] = [t]
    i = i + 1
    while i < lines.length() && !breaks(trim(lines[i]), lines[i]) {
      buf.push(trim(lines[i]))
      i = i + 1
    }
    blocks.push(P(inline(buf.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + " " + s } }))))
  }
  blocks
}

///|
/// `/^\[([^\]]+)\]\(([^)]+)\)$/` —— 整条标题就是一个链接（纯链接节）。
fn pure_link(head : String) -> (String, String)? {
  let c = chars(head)
  if c.length() < 5 || c[0] != '[' {
    return None
  }
  let mut j = 1
  while j < c.length() && c[j] != ']' {
    j = j + 1
  }
  if j >= c.length() || j == 1 {
    return None
  }
  if j + 1 >= c.length() || c[j + 1] != '(' {
    return None
  }
  let mut k = j + 2
  while k < c.length() && c[k] != ')' {
    k = k + 1
  }
  if k >= c.length() || k == j + 2 || k != c.length() - 1 {
    return None
  }
  Some((slice(c, 1, j), trim(slice(c, j + 2, k))))
}
