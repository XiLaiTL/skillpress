///|
/// P8.0 探针第二半：**tree-sitter 上色链在 native 上到底跑不跑得起来**。
///
/// 它做的事（刻意很小）：
///   ① `Parser::new()` + `set_language(bash)` + `parse_string(code)`；
///   ② `Query::new(lang, query)` + `QueryCursor` 迭代 capture；
///   ③ capture 名 → 色号（照 `lib/highlight.mjs` 的 `PALETTE` 前缀规则，两边必须一致）；
///   ④ 按字节区间拼成 `(片段, 色号)`，**并断言拼回去逐字节等于原文**（照旧实现的硬断言）；
///   ⑤ 打印未上色比例（非空白字符里色号为 0 的占比）—— 这是**质量**读数，不是"能不能跑"。
///
/// ⚠️ **本探针只验链条**：query 是精简的 4 条 pattern，不是完整的
/// `grammars/bash.highlights.scm`。完整 scm 的**召回对账**放 P8.1
/// （那时文件 IO 用 `moonbitlang/async/fs`，读 scm 与 wasm 都不必再走 extern）。
///
/// ⚠️ **只跑 ASCII 片段**：tree-sitter 给的是 **UTF-8 字节偏移**，而 MoonBit 的 `String`
/// 在 js 后端是 UTF-16（native 是 UTF-8）⇒ 非 ASCII 内容上"字节偏移 ↔ 字符下标"要自己换。
/// 这是 P8.1 必须处理的一件事，探针先用 ASCII 绕开。

///|
/// 精简 query：4 条 pattern，capture 名与旧实现 `PALETTE` 的前缀规则对得上。
const QUERY : String =
  "(command_name) @function\n(string) @string\n(comment) @comment\n(number) @number\n"

///|
/// capture 名 → 色号。**与 `lib/highlight.mjs` 的 `PALETTE` 同一套前缀规则**（两边必须一致）。
fn palette_idx(name : String) -> Int {
  if name.has_prefix("keyword") {
    1
  } else if name.has_prefix("string") || name.has_prefix("escape") || name.has_prefix("character") {
    2
  } else if name.has_prefix("comment") {
    3
  } else if name.has_prefix("number") || name.has_prefix("constant") || name.has_prefix("boolean") {
    4
  } else if name.has_prefix("type") || name.has_prefix("constructor") || name.has_prefix("attribute") {
    5
  } else if name.has_prefix("function") {
    6
  } else if name.has_prefix("module") || name.has_prefix("namespace") {
    7
  } else if name.has_prefix("variable") || name.has_prefix("property") || name.has_prefix("field") ||
    name.has_prefix("parameter") || name.has_prefix("label") {
    8
  } else if name.has_prefix("operator") || name.has_prefix("punctuation") {
    9
  } else {
    0
  }
}

///|
/// 一段上色区间（字节区间 + 色号 + 是哪个 capture）。
priv struct HlSpan {
  start : Int
  end : Int
  idx : Int
  name : String
}

///|
/// 把 query 的 capture 收成区间表：按起点排序，**重叠的后者丢掉**（先到先得 ——
/// 与旧实现"逐字符贴、贴过的不再贴"效果一致）。
fn collect_spans(cursor : @ts.QueryCursor) -> Array[HlSpan] {
  let spans : Array[HlSpan] = []
  while cursor.next_capture() is Some(cap) {
    let node = cap.node()
    let name = cap.name()
    let idx = palette_idx(name)
    if idx > 0 {
      spans.push({ start: node.start_byte(), end: node.end_byte(), idx, name })
    }
  }
  spans.sort_by(fn(a, b) { a.start - b.start })
  let out : Array[HlSpan] = []
  let mut last = -1
  for s in spans {
    if s.start >= last && s.end > s.start {
      out.push(s)
      last = s.end
    }
  }
  out
}

///|
/// 区间表 → `(片段, 色号)` 序列（没被覆盖的部分色号 0）。
/// 返回 `(runs, 未上色非空白字符数)`。
fn to_runs(code : String, spans : Array[HlSpan]) -> (Array[(String, Int)], Int) {
  let runs : Array[(String, Int)] = []
  let mut pos = 0
  for s in spans {
    if s.start > pos {
      runs.push((code[pos:s.start].to_owned(), 0))
    }
    runs.push((code[s.start:s.end].to_owned(), s.idx))
    pos = s.end
  }
  if pos < code.length() {
    runs.push((code[pos:].to_owned(), 0))
  }
  let mut dark = 0
  for run in runs {
    if run.1 == 0 {
      for ch in run.0 {
        if !ch.is_whitespace() {
          dark = dark + 1
        }
      }
    }
  }
  (runs, dark)
}

///|
/// 探针主体：解析一段 bash 代码、跑 query、打印读数。
pub fn highlight_bash(code : String) -> Unit {
  let lang = @bash.language()
  let parser = @ts.Parser::new()
  let tree = try {
    parser.set_language(lang)
    parser.parse_string(code)
  } catch {
    e => {
      println("✗ 解析失败：\{e}")
      return
    }
  }
  let query = try @ts.Query::new(lang, QUERY) catch {
    e => {
      println("✗ query 建不起来：\{e}")
      return
    }
  }
  let root = tree.root_node()
  println("== MoonBit 探针（tree-sitter 原生绑定）==")
  println("  根节点 = \{root.type_()}（子节点 \{root.child_count()} 个）")
  println("  query 里 pattern 数 = \{query.pattern_count()}")
  let cursor = @ts.QueryCursor::new()
  cursor.exec(query, root)
  let spans = collect_spans(cursor)
  let (runs, dark) = to_runs(code, spans)
  println("  capture 区间 = \{spans.length()} 个")
  for s in spans {
    println("    \{s.name} → 色号 \{s.idx}  [\{s.start}, \{s.end})")
  }
  let joined = runs.fold(init="", fn(acc, r) { acc + r.0 })
  let total = code.to_array().filter(fn(ch) { !ch.is_whitespace() }).length()
  let pct = if total == 0 { 0.0 } else { (dark.to_double() / total.to_double()) * 100.0 }
  println("  runs = \{runs.length()} 段｜未上色 \{dark}/\{total}（\{pct}%）")
  let preview = runs[:6].map(fn(r) { "(" + r.0 + "," + r.1.to_string() + ")" }).fold(init="", fn(acc, s) { acc + s })
  println("  前 6 段 = \{preview}")
  println("  ★ 拼回去逐字节等于原文 = \{joined == code}")
}
