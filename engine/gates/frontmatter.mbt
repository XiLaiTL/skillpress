///|
/// frontmatter 的解析 —— 与 DSH 注册表**同款语义**：只认 `name` / `description` / `whenToUse`
/// 三个标量，多写的字段会被注册表丢掉（这里也丢掉，但给一条提示）。
///
/// ⚠️ 三条必须照抄的细节：
///   · 首行去掉**尾部 CR** 后必须正好是 `---`（CRLF 文件也得认出来）；
///   · 每行**先 trim 再匹配** —— CRLF 文件里行尾是 `\r`，而 JS 的 `.` 不匹配 `\r`，
///     不 trim 的话整份 frontmatter 会**静默丢失**（实测踩过：报错只是"缺 name"）；
///   · 值两侧同款引号会被剥掉（`"x"` → `x`，`'x'` → `x`）。
///
/// 返回 `(三字段?, 正文)`；frontmatter 缺失或未闭合时前者是 `None`、正文是**整份文本**
/// （旧实现就是这个口径：没 frontmatter 也照样扫正文）。

///|
/// 解析结果。
pub struct Frontmatter {
  /// 三个必需字段（**在就是 Some**，值可能是空串 —— "有但空"与"没有"在 G1 里都是红）。
  name : String?
  description : String?
  whenToUse : String?
  /// **全部**字段，按**首次出现顺序**（G1 的"多余字段"提示要用它，顺序也要一致）。
  all : Array[(String, String)]
}

///|
/// 三字段名（顺序固定 —— 报错顺序与提示里的列举顺序都跟它走）。
pub fn required_fields() -> Array[String] {
  ["name", "description", "whenToUse"]
}

///|
/// 一行 → `(键, 值)`（旧实现那条 `^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$`）。
fn field_of(line : String) -> (String, String)? {
  let c = chars(line)
  if c.length() == 0 {
    return None
  }
  let head = c[0]
  let ok_head = (head >= 'A' && head <= 'Z') || (head >= 'a' && head <= 'z')
  if !ok_head {
    return None
  }
  let mut i = 1
  while i < c.length() {
    let ch = c[i]
    let ok = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') ||
      ch == '_' || ch == '-'
    if !ok {
      break
    }
    i = i + 1
  }
  if i >= c.length() || c[i] != ':' {
    return None
  }
  let key = slice(c, 0, i)
  let mut j = i + 1
  while j < c.length() && c[j].is_whitespace() {
    j = j + 1
  }
  let mut v = slice(c, j, c.length())
  // ⚠️ 边界照抄 JS：`v` 就是单个引号时 `startsWith` 与 `endsWith` 同时成立，
  //    而 `'"'.slice(1, -1)` 是**空串** ⇒ 判成"有但空"（G1 照样红）。长度 0 则不剥。
  if v.length() > 0 {
    let first = v[0:1]
    let last = v[v.length() - 1:]
    if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
      v = if v.length() >= 2 { v[1:v.length() - 1].to_owned() } else { "" }
    }
  }
  Some((key, v))
}

///|
/// 解析。返回 `(三字段?, 正文)`。
pub fn parse_frontmatter(text : String) -> (Frontmatter?, String) {
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
    return (None, text)
  }
  let mut first_line = slice(c, 0, first_end)
  if first_line.length() > 0 && first_line[first_line.length() - 1:] == "\r" {
    first_line = first_line[:first_line.length() - 1].to_owned()
  }
  if first_line != "---" {
    return (None, text)
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
    return (None, text)
  }
  let all : Array[(String, String)] = []
  let lines = split_lines(slice(c, first_end + 1, end))
  for raw in lines {
    match field_of(trim(raw)) {
      None => ()
      Some((k, v)) => {
        // JS 对象：**后来的同名键覆盖值，但键的位置留在第一次出现的地方**
        let mut found = false
        for idx = 0; idx < all.length(); idx = idx + 1 {
          if all[idx].0 == k {
            all[idx] = (k, v)
            found = true
          }
        }
        if !found {
          all.push((k, v))
        }
      }
    }
  }
  let get = fn(k : String) -> String? {
    for pair in all {
      if pair.0 == k {
        return Some(pair.1)
      }
    }
    None
  }
  (
    Some({ name: get("name"), description: get("description"), whenToUse: get("whenToUse"), all }),
    slice(c, end + 4, c.length()),
  )
}
