///|
/// MoonBit 字面量的生成（旧实现 `esc` / `spanList` / `runList` / `emitBlock` 的移植）。
///
/// ⚠️ `esc` 的五步**顺序不能换**（先转义反斜杠，再转义引号，再删 `\r`、把 tab 换成两个空格、
/// 把换行写成 `\n` 两个字面字符）—— 换一步就会把"本来是转义符的字符"再转一次。

///|
/// 字符串 → MoonBit 字符串字面量的内层（旧实现 `esc`）。
pub fn esc(s : String) -> String {
  let mut out = ""
  for ch in s {
    if ch == '\\' {
      out = out + "\\\\"
    } else if ch == '"' {
      out = out + "\\\""
    } else if ch == '\r' {
      // 丢掉（内容里的 CR 一律不进生成物）
    } else if ch == '\t' {
      out = out + "  "
    } else if ch == '\n' {
      out = out + "\\n"
    } else {
      out = out + ch.to_string()
    }
  }
  out
}

///|
/// 片段序列 → `[Code("x"), Txt("y")]`；**空列表写成带类型标注的那种**（旧实现的原话）。
pub fn span_list(list : Array[Span]) -> String {
  if list.length() == 0 {
    return "([] : Array[Span])"
  }
  let parts : Array[String] = []
  for sp in list {
    parts.push(match sp {
      Txt(v) => "Txt(\"" + esc(v) + "\")"
      Code(v) => "Code(\"" + esc(v) + "\")"
      Bold(v) => "Bold(\"" + esc(v) + "\")"
    })
  }
  "[" + parts.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } }) + "]"
}

///|
/// 高亮片段 → `[("文本", 色号), …]`；空列表同样是带类型标注的那种。
pub fn run_list(runs : Array[(String, Int)]) -> String {
  if runs.length() == 0 {
    return "([] : Array[(String, Int)])"
  }
  let parts : Array[String] = []
  for r in runs {
    parts.push("(\"" + esc(r.0) + "\", " + r.1.to_string() + ")")
  }
  "[" + parts.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } }) + "]"
}

///|
/// 一块 → **一行** MoonBit 字面量（含缩进与行尾逗号）。旧实现 `emitBlock` 的一比一移植。
pub fn emit_block(b : Block, pad : String) -> String {
  match b {
    Hr => pad + "Hr,"
    H2(spans) => pad + "H2(" + span_list(spans) + "),"
    H3(spans) => pad + "H3(" + span_list(spans) + "),"
    H4(spans) => pad + "H4(" + span_list(spans) + "),"
    P(spans) => pad + "P(" + span_list(spans) + "),"
    Quote(spans) => pad + "Quote(" + span_list(spans) + "),"
    Code(lang, text, runs) =>
      pad + "Code(\"" + esc(lang) + "\", \"" + esc(text) + "\", " + run_list(runs) + "),"
    Ul(items) => {
      let parts : Array[String] = []
      for it in items {
        parts.push("(" + it.indent.to_string() + ", \"" + esc(it.num) + "\", " + span_list(it.spans) + ")")
      }
      pad + "Ul([" + parts.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } }) + "]),"
    }
    Table(header, rows) => {
      let h = header.map(span_list).fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } })
      let rparts : Array[String] = []
      for row in rows {
        let inner = row.map(span_list).fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } })
        rparts.push("[" + inner + "]")
      }
      let r = rparts.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } })
      pad + "Table([" + h + "], [" + r + "]),"
    }
  }
}
