///|
/// **名字索引**：走一遍内容仓的 `.mbt` / `.mbti` 源码，数出"多少文件、多少个名字"。
///
/// ⚠️ 这一件**不是 G5 的判据**（G5 按 D18 搬去内容仓自己），它只服务报告的**第二行**：
///   `索引：N 个 .mbt 文件 / M 个名字（供 G5 对账）`
/// 那行是旧实现打的，为了让两边输出逐字节可比，这里把**计数**也搬了过来。
/// 真要通用化时，这行应该由内容仓自己的门去打 —— 见报告里的"偏差"一节。
///
/// 两个扫描口径照抄旧实现：
///   · `/\b(?:fn|struct|enum|type|trait|let|const)\s+([A-Za-z_][A-Za-z0-9_]*)/g`（关键字前要有词边界）
///   · `pub\s+using\s+@[A-Za-z0-9_/.@-]+\s*\{([^}]*)\}` 里逗号分隔的名字（可带 `type ` 前缀）
pub struct Index {
  files : Int
  names : Array[String]
}

///|
/// 走一遍（深度上限 12、跳过构建/依赖目录 —— 与旧实现同一套 skip 名单）。
pub fn build_index(host : Host, root : String) -> Index {
  let names : Array[String] = []
  let mut files = 0
  walk_index(host, root, 0, names, fn(_n) { files = files + 1 })
  { files, names }
}

///|
fn skip_dir(name : String) -> Bool {
  name == "_build" || name == "node_modules" || name == ".mooncakes" || name == ".git" || name == "target"
}

///|
fn walk_index(
  host : Host,
  dir : String,
  depth : Int,
  names : Array[String],
  bump : (Int) -> Unit,
) -> Unit {
  if depth > 12 {
    return
  }
  for entry in host.read_dir(dir) {
    if skip_dir(entry) {
      continue
    }
    let p = join_path(dir, entry)
    if host.is_dir(p) {
      walk_index(host, p, depth + 1, names, bump)
      continue
    }
    if !entry.has_suffix(".mbt") && !entry.has_suffix(".mbti") {
      continue
    }
    bump(1)
    let text = host.read(p)
    collect_names(text, names)
  }
}

///|
/// 两个扫描（照旧实现的两条正则）。
fn collect_names(text : String, names : Array[String]) -> Unit {
  let c = chars(text)
  let keywords = ["fn", "struct", "enum", "type", "trait", "let", "const"]
  let mut i = 0
  while i < c.length() {
    // 词边界：前一个字符不能是 [A-Za-z0-9_]
    let boundary = i == 0 || !is_word_char(c[i - 1])
    if boundary && is_word_char(c[i]) {
      for kw in keywords {
        let k = chars(kw)
        if starts_with_at(c, i, k) && i + k.length() < c.length() && c[i + k.length()].is_whitespace() {
          let mut j = i + k.length()
          while j < c.length() && c[j].is_whitespace() {
            j = j + 1
          }
          let mut e = j
          while e < c.length() && is_word_char(c[e]) {
            e = e + 1
          }
          let name = slice(c, j, e)
          if name != "" && !names.contains(name) {
            names.push(name)
          }
        }
      }
    }
    i = i + 1
  }
  // `pub using @pkg { … }`
  let mut k = 0
  while k < c.length() {
    if starts_with_at(c, k, chars("pub")) {
      let mut m = k + 3
      while m < c.length() && c[m].is_whitespace() {
        m = m + 1
      }
      if starts_with_at(c, m, chars("using")) {
        let mut n = m + 5
        while n < c.length() && c[n].is_whitespace() {
          n = n + 1
        }
        if n < c.length() && c[n] == '@' {
          let mut b = n + 1
          while b < c.length() && c[b] != '{' {
            b = b + 1
          }
          if b < c.length() {
            let mut e = b + 1
            while e < c.length() && c[e] != '}' {
              e = e + 1
            }
            if e < c.length() {
              for raw in slice(c, b + 1, e).split(",") {
                let t = trim(raw.to_owned())
                let stripped = if t.has_prefix("type ") { trim(t[5:].to_owned()) } else { t }
                let mut end = 0
                while end < stripped.length() &&
                      is_word_char(chars(stripped)[end]) {
                  end = end + 1
                }
                let name = slice(chars(stripped), 0, end)
                if name != "" && !names.contains(name) {
                  names.push(name)
                }
              }
              k = e
            }
          }
        }
      }
    }
    k = k + 1
  }
}

///|
fn is_word_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_'
}

///|
fn starts_with_at(c : Array[Char], i : Int, pat : Array[Char]) -> Bool {
  if i + pat.length() > c.length() {
    return false
  }
  let mut k = 0
  while k < pat.length() {
    if c[i + k] != pat[k] {
      return false
    }
    k = k + 1
  }
  true
}
