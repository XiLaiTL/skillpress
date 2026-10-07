///|
/// MoonBit 字面量的生成（旧实现 `esc` / `spanList` / `runList` / `emitBlock` 的移植）。
///
/// ⚠️ `esc` 的五步**顺序不能换**（先转义反斜杠，再转义引号，再删 `\r`、把 tab 换成两个空格、
/// 把换行写成 `\n` 两个字面字符）—— 换一步就会把"本来是转义符的字符"再转一次。

///|
/// 生成物里**值构造器与类型名**必须带的包前缀。
///
/// 为什么不能裸写 `Txt(...)`：P6 把这些类型搬进 `shell` 包之后，生成物落在**实例的 `content` 包**里，
/// 裸构造器在那里根本找不到。**实测**（P6 语言实验 + `_scratch` 探针）：
///   · `using @shell {type Span, type Block}` 只引进**类型名**，构造器仍然 unbound；
///   · `@shell.Txt("x")`（限定构造器）**可以**；
///   · `@shell.NavItem { … }`（限定结构体字面量）**不是合法语法** —— 好在生成物里的结构体字面量
///     本来就是**匿名**的（靠字段类型推），所以不受影响。
const REC : String = "@shell."

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
    return "([] : Array[" + REC + "Span])"
  }
  let parts : Array[String] = []
  for sp in list {
    parts.push(match sp {
      Txt(v) => REC + "Txt(\"" + esc(v) + "\")"
      Code(v) => REC + "Code(\"" + esc(v) + "\")"
      Bold(v) => REC + "Bold(\"" + esc(v) + "\")"
      Link(a, b, mono) =>
        REC +
        "Link(\"" +
        esc(a) +
        "\", \"" +
        esc(b) +
        "\", " +
        (if mono { "true" } else { "false" }) +
        ")"
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
    Hr => pad + REC + "Hr,"
    H2(spans) => pad + REC + "H2(" + span_list(spans) + "),"
    H3(spans) => pad + REC + "H3(" + span_list(spans) + "),"
    H4(spans) => pad + REC + "H4(" + span_list(spans) + "),"
    P(spans) => pad + REC + "P(" + span_list(spans) + "),"
    Quote(spans) => pad + REC + "Quote(" + span_list(spans) + "),"
    Code(lang, text, runs) =>
      pad + REC + "Code(\"" + esc(lang) + "\", \"" + esc(text) + "\", " + run_list(runs) + "),"
    Ul(items) => {
      let parts : Array[String] = []
      for it in items {
        parts.push("(" + it.indent.to_string() + ", \"" + esc(it.num) + "\", " + span_list(it.spans) + ")")
      }
      pad + REC + "Ul([" + parts.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } }) + "]),"
    }
    Table(header, rows) => {
      let h = header.map(span_list).fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } })
      let rparts : Array[String] = []
      for row in rows {
        let inner = row.map(span_list).fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } })
        rparts.push("[" + inner + "]")
      }
      let r = rparts.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + ", " + s } })
      pad + REC + "Table([" + h + "], [" + r + "]),"
    }
  }
}
