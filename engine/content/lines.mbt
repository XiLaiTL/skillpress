///|
/// **行级判定**："这一行是什么构造" —— 块解析（`blocks.mbt`）用的全部谓词。
///
/// 单独一份的理由（R9：一个文件一件事、≤400 行）：这些函数是**照正则一比一移植**的，
/// 每一条都对应旧实现里一个 `/^…/` 或一次 `match`，混在块循环里会看不清"哪条规矩落在哪种行上"。
///
/// ⚠️ 这一层里"看着多余"的东西**都是判据要的**，逐条都有出处：
///   · 代码块用**剔除后**的行判闭合（`/^```/` 打在 `trim()` 过的行上）；
///   · 表格的续行判据是 `^\s*\|`（**允许前导空白**），但块的起始判据是 `^\|`（不许）；
///   · 段落续行的 `BREAK` 里，前四条打在**剔除后**的行上，后两条打在**原始行**上；
///   · 列表项的判定同样打在原始行上（`^\s*[-*]\s+`），取内容时才 `trim()`。

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
pub fn heading(t : String) -> (Int, String)? {
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
/// 旧实现 `/^\|[\s:|-]+\|$/` —— 表格的分隔行（`|---|:--:|` 这种）。
///
/// ⚠️ 只认 ASCII 空白：JS 那个 `\s` 还包含全角空格之类的（`\u00a0`/`\u3000`…）。
/// 生成物与退出码的判据里没有这种分隔行；真遇上了这里会说"缺分隔行"而旧实现不说 ——
/// 宁可多说一句，也不把这条规矩悄悄放宽。
fn is_sep_row(r : String) -> Bool {
  let c = chars(r)
  if c.length() < 3 || c[0] != '|' || c[c.length() - 1] != '|' {
    return false
  }
  for k = 1; k < c.length() - 1; k = k + 1 {
    let ch = c[k]
    let ok = ch == '|' || ch == ':' || ch == '-' || ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
    if !ok {
      return false
    }
  }
  true
}
