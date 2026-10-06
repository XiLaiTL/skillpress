///|
/// G4：从一个**命令块**里挑出"必须存在的脚本文件"。
///
/// 旧实现那条正则：
/// `/(?:^|\s|&&\s*|\|\|\s*)(?:bash\s+|sh\s+|python3?\s+|node\s+)?((?:tools|npm|examples|docs|vendor)\/[^\s'"]+\.(?:sh|py|mjs|cjs|js))/g`
///
/// 拆开看就是三件事，逐条照抄：
///   ① **边界**：路径前面要么是行首、要么是空白、要么是 `&&` / `||`（后面可以有空白）；
///   ② **可选的解释器**：`bash` / `sh` / `python` / `python3` / `node` + 至少一个空白；
///   ③ **路径**：一级目录是 `tools|npm|examples|docs|vendor` 之一，
///      中间**不含空白与引号**，结尾是 `.sh|.py|.mjs|.cjs|.js`。
///
/// ⚠️ 结尾那个扩展名是**贪婪匹配**的结果：`tools/a.b.mjs` 取整段（不是从第一个点切开）。

///|
/// 一级目录（这条门只认这五个 —— 不含 `bin`/`lib`/`grammars`，那是 G3 的事）。
fn command_top_dirs() -> Array[String] {
  ["tools", "npm", "examples", "docs", "vendor"]
}

///|
/// 解释器前缀（含 `python`/`python3`；`python3?` 在正则里就是"3 可有可无"）。
fn interpreters() -> Array[String] {
  ["bash", "sh", "python3", "python", "node"]
}

///|
/// 一行是不是"注释或空行"（旧实现：`!line || line.startsWith("#") || line.startsWith("//")`）。
fn skip_line(line : String) -> Bool {
  line == "" || line.has_prefix("#") || line.has_prefix("//")
}

///|
/// 从 `start` 处尝试匹配一条路径；给 `(路径, 匹配结束下标)`。
fn path_at(line : String, start : Int) -> (String, Int)? {
  let c = chars(line)
  let mut best : (String, Int)? = None
  for dir in command_top_dirs() {
    let prefix = dir + "/"
    if start + prefix.length() > c.length() {
      continue
    }
    if slice(c, start, start + prefix.length()) != prefix {
      continue
    }
    // `[^\s'"]+` 里不含空白与引号：先吃到第一个空白/引号为止，再从右往左找合法的扩展名结尾
    let mut end = start + prefix.length()
    while end < c.length() {
      let ch = c[end]
      if ch.is_whitespace() || ch == '\'' || ch == '"' {
        break
      }
      end = end + 1
    }
    for ext in [".sh", ".py", ".mjs", ".cjs", ".js"] {
      let mut e = end
      while e > start {
        if slice(c, e - ext.length(), e) == ext && e - ext.length() >= start + prefix.length() {
          let path = slice(c, start, e)
          // 贪婪：正则取**最长**的合法匹配，所以同一起点取到最靠右的那些字符
          match best {
            None => best = Some((path, e))
            Some((prev, _)) => if path.length() > prev.length() {
              best = Some((path, e))
            }
          }
          break
        }
        e = e - 1
      }
    }
  }
  best
}

///|
/// 一行的边界 + 可选解释器之后，路径从哪儿开始（旧正则的那段前缀）。
fn starts_at(line : String, i : Int) -> Bool {
  let c = chars(line)
  if i == 0 {
    return true
  }
  if c[i - 1].is_whitespace() {
    return true
  }
  // `&&` / `||` 后面可以直接接路径（`\s*` 允许零个空白）
  if i >= 2 && (slice(c, i - 2, i) == "&&" || slice(c, i - 2, i) == "||") {
    return true
  }
  false
}

///|
/// 从命令块里抽脚本路径（**去重，保留首次出现顺序** —— 旧实现是 `[...new Set(out)]`）。
pub fn command_files(code : String) -> Array[String] {
  let out : Array[String] = []
  for raw in split_lines(code) {
    let line = trim(raw)
    if skip_line(line) {
      continue
    }
    let c = chars(line)
    let mut i = 0
    while i < c.length() {
      if !starts_at(line, i) {
        i = i + 1
        continue
      }
      // 先试"解释器 + 路径"，再试"直接就是路径"
      let mut hit : (String, Int)? = None
      for itp in interpreters() {
        if i + itp.length() + 1 <= c.length() && slice(c, i, i + itp.length()) == itp {
          let mut k = i + itp.length()
          if k < c.length() && c[k].is_whitespace() {
            while k < c.length() && c[k].is_whitespace() {
              k = k + 1
            }
            match path_at(line, k) {
              Some(h) => hit = Some(h)
              None => ()
            }
          }
        }
      }
      match hit {
        None =>
          match path_at(line, i) {
            Some(h) => hit = Some(h)
            None => ()
          }
        Some(_) => ()
      }
      match hit {
        None => i = i + 1
        Some((path, end)) => {
          if !out.contains(path) {
            out.push(path)
          }
          i = if end > i { end } else { i + 1 }
        }
      }
    }
  }
  out
}
