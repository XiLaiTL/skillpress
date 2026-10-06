///|
/// 文档块管线：**一份 markdown → 站点用的 `Block` 序列**（旧实现 `lib/gen-content.mjs` 的移植）。
///
/// 这一版只做 `dump-blocks` 要用的那半：frontmatter 切分、行内片段（`inline`）、块解析
/// （`parseBlocks`）。**没做**的（不是漏，是这条命令不用）：
///   · `summarize`（它只喂 `title` / `desc`，而 `blocks` 里没有它们）；
///   · `links` 收集（顶栏下拉菜单的判据用它，**emitBlock 一个字段都不读**）；
///   · 站点在磁盘上的遍历（那是引导层的事，见 `tools/run-js.mjs`）。
///
/// ⚠️ 与旧实现对齐的**怪细节**（少一个就 diff 不过，且都是"看着多余其实必要"的）：
///   · 行内三件事共用一条扫描：**取最左命中**；同一位置上按 **反引号 → 加粗 → 链接** 顺序试；
///   · `**` 的内容**不许含 `*`**，`[label](target)` 的 label 不许含 `]`、target 不许含 `)`；
///   · 文本片段一律**把连续空白压成一个空格**，相邻 `Txt` **合并**；
///   · 表格行只去掉**一个**首尾 `|`；引用剥 `>` 时**只吃一个**可选空格；
///   · 列表项的 `indent` 是"原始行前导空白 ≥2 个字符 ⇒ 1"，`num` **无论 `.` 还是 `)` 都写成 `. `**。

///|
/// 行内片段。三种，与站点侧的 `Span` 一一对应。
pub enum Span {
  Txt(String)
  Code(String)
  Bold(String)
}

///|
/// 列表项：`indent`（0/1）+ `num`（有序表的 `1. `；无序表是空串）+ 片段。
pub struct UlItem {
  indent : Int
  num : String
  spans : Array[Span]
}

///|
/// 正文里的一块。`Code` 的三个字段是 **语言 / 原文 / 高亮片段**（片段由 `engine/highlight` 给）。
pub enum Block {
  Hr
  H2(Array[Span])
  H3(Array[Span])
  H4(Array[Span])
  P(Array[Span])
  Quote(Array[Span])
  Code(String, String, Array[(String, Int)])
  Ul(Array[UlItem])
  Table(Array[Array[Span]], Array[Array[Array[Span]]])
}

// ── 字符工具：索引一律以 **`to_array()` 的下标**为准 ──────────────────────────
//
// ⚠️ 为什么不用 `s[a:b]` 切片：MoonBit 的 `String` 在 js 后端是 UTF-16、native 是 UTF-8，
// 而"下标"的语义两边可能不同；这里全部走 `Array[Char]`，两边一致。

///|
/// 按 `\n` 切行（JS 的 `split("\n")`）。
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
/// `chars[a..b)` → 字符串。
pub fn slice(chars : Array[Char], a : Int, b : Int) -> String {
  let mut out = ""
  let mut i = a
  while i < b && i < chars.length() {
    out = out + chars[i].to_string()
    i = i + 1
  }
  out
}

///|
/// 字符串 → 字符数组（反复用，包一层省得到处 `to_array`）。
pub fn chars(s : String) -> Array[Char] {
  s.to_array()
}

///|
/// JS 的 `String.prototype.trim()` —— 只吃两端的空白。
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
/// JS 的 `t.replace(/\s+/g, " ")`（**行内文本片段专用**）。
fn squeeze_ws(s : String) -> String {
  let mut out = ""
  let mut in_ws = false
  for ch in s {
    if ch.is_whitespace() {
      if !in_ws {
        out = out + " "
      }
      in_ws = true
    } else {
      out = out + ch.to_string()
      in_ws = false
    }
  }
  out
}

///|
/// 从 `from` 起找第一个下标 `i`：那里 `\` 开头的行内标记能匹配（**最左优先**）。
/// 返回 `(i, 类型, 内容a, 内容b)`；类型：0 = 反引号代码、1 = 加粗、2 = 链接。
/// 链接返回两段（label 与 target），用 `(i, 2, labelA, labelB, targetA, targetB)` 表达不便，
/// 所以这里分开返回两个区间。
priv struct Hit {
  at : Int
  kind : Int
  a : Int
  b : Int
  a2 : Int
  b2 : Int
  /// 整条匹配的**结束下标**（不含）。⚠️ 加粗是 `**…**`，比内容尾巴多**两个**字符 ——
  /// 曾经按"内容尾 +1"算 `last`，于是闭包第二个 `*` 被当成正文，每个加粗后面都多一个 `*`。
  end : Int
}

///|
/// 在位置 `i` 上按 反引号 → 加粗 → 链接 的顺序试三种行内标记（与旧实现的正则或 (`|`) 同序）。
fn match_at(c : Array[Char], i : Int) -> Hit? {
  // ① 反引号代码：`…`，内容非空且不含反引号
  if c[i] == '`' {
    let mut j = i + 1
    while j < c.length() && c[j] != '`' {
      j = j + 1
    }
    if j < c.length() && j > i + 1 {
      return Some({ at: i, kind: 0, a: i + 1, b: j, a2: 0, b2: 0, end: j + 1 })
    }
  }
  // ② 加粗：**…**，内容非空且**不含 `*`**
  if i + 1 < c.length() && c[i] == '*' && c[i + 1] == '*' {
    let mut j = i + 2
    while j < c.length() && c[j] != '*' {
      j = j + 1
    }
    if j + 1 < c.length() && j > i + 2 && c[j] == '*' && c[j + 1] == '*' {
      return Some({ at: i, kind: 1, a: i + 2, b: j, a2: 0, b2: 0, end: j + 2 })
    }
  }
  // ③ 链接：[label](target)，label 非空且不含 `]`，target 非空且不含 `)`
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
      if k < c.length() && k > j + 2 {
        return Some({ at: i, kind: 2, a: i + 1, b: j, a2: j + 2, b2: k, end: k + 1 })
      }
    }
  }
  None
}

///|
/// 从 `from` 找最左命中。
fn find_next(c : Array[Char], from : Int) -> Hit? {
  let mut i = from
  while i < c.length() {
    match match_at(c, i) {
      Some(h) => return Some(h)
      None => i = i + 1
    }
  }
  None
}

///|
/// 删掉字符串里**所有**反引号（链接 label 用；对应 JS 的 `.replace(/`/g, "")`）。
fn drop_backticks(s : String) -> String {
  let mut out = ""
  for ch in s {
    if ch != '`' {
      out = out + ch.to_string()
    }
  }
  out
}

///|
/// `^[\w./-]+$`（`\w` = 字母 / 数字 / 下划线）—— 链接 label 走 `Code` 还是 `Txt` 看它。
fn wordy(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for ch in s {
    let ok = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') ||
      ch == '_' || ch == '.' || ch == '/' || ch == '-'
    if !ok {
      return false
    }
  }
  true
}

///|
/// 是不是外链（`/^https?:/i`）。
fn external_link(s : String) -> Bool {
  let low = s.to_array().map(fn(ch) {
    if ch >= 'A' && ch <= 'Z' {
      let up = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".to_array()
      let lo = "abcdefghijklmnopqrstuvwxyz".to_array()
      let mut out = ch.to_string()
      for k = 0; k < up.length(); k = k + 1 {
        if up[k] == ch {
          out = lo[k].to_string()
        }
      }
      out
    } else {
      ch.to_string()
    }
  }).fold(init="", fn(acc, x) { acc + x })
  // ⚠️ `/^https?:/i` 是 "http" + **可有可无的 s** + ":" —— 之前只判 `has_prefix("http:")`，
  // 于是 `https://…` 被当成站内链接、拆成了两个片段（夹具逮到的）
  low.has_prefix("http:") || low.has_prefix("https:")
}

///|
/// **行内 → Span 序列**（旧实现 `inline()`）：链接按"台词"渲染 —— 文字 + 代码样式的路径；
/// 文字与目标相同时只留一份。
pub fn inline(s : String) -> Array[Span] {
  let spans : Array[Span] = []
  let emit = fn(sp : Span) {
    let last : Span? = if spans.length() > 0 { Some(spans[spans.length() - 1]) } else { None }
    match (sp, last) {
      (Txt(v), Some(Txt(prev))) => spans[spans.length() - 1] = Txt(prev + v)
      _ => spans.push(sp)
    }
  }
  let text = fn(t : String) {
    let norm = squeeze_ws(t)
    if norm != "" {
      emit(Txt(norm))
    }
  }
  let c = chars(s)
  let mut last = 0
  while find_next(c, last) is Some(h) {
    if h.at > last {
      text(slice(c, last, h.at))
    }
    if h.kind == 0 {
      emit(Code(slice(c, h.a, h.b)))
    } else if h.kind == 1 {
      emit(Bold(slice(c, h.a, h.b)))
    } else {
      // ⚠️ JS 那边是 `.replace(/`/g, "")` —— **全局删**。MoonBit 的 `String::replace` 只换第一处，
      // 所以这里手写"滤掉所有反引号"（夹具里 ``[`a` 和 `b`](…)`` 逮到过）
      let label = drop_backticks(slice(c, h.a, h.b))
      let target = trim(slice(c, h.a2, h.b2))
      if label == target || external_link(target) {
        emit(if wordy(label) { Code(label) } else { Txt(label) })
      } else {
        emit(Txt(label))
        emit(Code(target))
      }
    }
    last = h.end
  }
  if last < c.length() {
    text(slice(c, last, c.length()))
  }
  spans
}
