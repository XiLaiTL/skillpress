///|
/// 调色板与"上色"这步的核心算法（**纯逻辑**，与 target 无关）。
///
/// 与旧实现 `lib/highlight.mjs` 对齐的两处**语义细节**（照抄，不许自创）：
///   ① **优先级**：`PALETTE` 的**顺序**就是优先级 —— 越靠前越"专有"
///      （`keyword.control` 与 `keyword` 都该走关键字那一档）。同一个字符被多个 capture
///      盖住时，**先按优先级、再按起点**，先到先得。
///   ② **按字符上色**：不是"按区间丢重叠"，而是每个字符一个色号位（-1 = 没上色）。
///      两者在重叠情形下**不等价** —— 曾经的实现就是按区间丢的，moonbit 块因此对不上。

///|
/// 一条 capture（名字 + 区间 + **优先级**）。区间是解析器给的下标。
pub struct Capture {
  name : String
  start : Int
  end : Int
  prio : Int
}

///|
/// capture 名 → `(色号, 优先级)`；没匹配上的给 `(0, -1)`（不上色 —— `spell`/`error` 本来就
/// 不是颜色）。优先级 = `PALETTE` 里的下标。
pub fn palette_of(name : String) -> (Int, Int) {
  if name.has_prefix("keyword") {
    (1, 0)
  } else if name.has_prefix("string") || name.has_prefix("escape") || name.has_prefix("character") {
    (2, 1)
  } else if name.has_prefix("comment") {
    (3, 2)
  } else if name.has_prefix("number") || name.has_prefix("constant") || name.has_prefix("boolean") {
    (4, 3)
  } else if name.has_prefix("type") || name.has_prefix("constructor") || name.has_prefix("attribute") ||
    name.has_prefix("support.type") {
    (5, 4)
  } else if name.has_prefix("function") {
    (6, 5)
  } else if name.has_prefix("module") || name.has_prefix("namespace") {
    (7, 6)
  } else if name.has_prefix("variable") || name.has_prefix("property") || name.has_prefix("field") ||
    name.has_prefix("parameter") || name.has_prefix("label") {
    (8, 7)
  } else if name.has_prefix("operator") || name.has_prefix("punctuation") {
    (9, 8)
  } else {
    (0, -1)
  }
}

///|
/// 给一个 capture 填上色号与优先级。
pub fn with_palette(c : Capture) -> Capture {
  let (idx, prio) = palette_of(c.name)
  { name: c.name, start: c.start, end: c.end, prio: if idx == 0 { -1 } else { prio } }
}

///|
/// 按"优先级 → 起点"排序（旧实现：`sort((a,b) => a.prio - b.prio || a.start - b.start)`）。
fn by_priority(caps : Array[Capture]) -> Array[Capture] {
  let kept = caps.filter(fn(c) { c.prio >= 0 })
  kept.sort_by(fn(a, b) { if a.prio != b.prio { a.prio - b.prio } else { a.start - b.start } })
  kept
}

///|
/// 一次"包装下的解析"结果：每个字符的色号（-1 = 没上色）+ 未上色非空白字符数。
pub struct Shade {
  flags : Array[Int]
  dark : Int
}

///|
/// 把 capture 刷到 `code` 的每个字符上。
///
/// `offset` = 包装前缀的长度：capture 的区间是在 **`pre + code + post`** 这份文本上的，
/// 减掉它就回到片段自己的坐标；落在片段外的字符**直接忽略**（旧实现同样只在
/// `0 <= j < code.length` 时刷）。
pub fn shade(code : String, offset : Int, caps : Array[Capture]) -> Shade {
  let flags : Array[Int] = []
  for _ in 0..<code.length() {
    flags.push(-1)
  }
  for c in by_priority(caps) {
    let (idx, _) = palette_of(c.name)
    let mut i = c.start
    while i < c.end {
      let j = i - offset
      if j >= 0 && j < code.length() && flags[j] == -1 {
        flags[j] = idx
      }
      i = i + 1
    }
  }
  let mut dark = 0
  let chars = code.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if !chars[i].is_whitespace() && flags[i] == -1 {
      dark = dark + 1
    }
  }
  { flags, dark }
}

///|
/// 色号表 → `(片段, 色号)` 序列：**相邻同色合并**（逐字符走，与旧实现一致）。
pub fn runs_of(code : String, flags : Array[Int]) -> Array[(String, Int)] {
  let runs : Array[(String, Int)] = []
  let chars = code.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let idx = if flags[i] == -1 { 0 } else { flags[i] }
    let ch = chars[i].to_string()
    if runs.length() > 0 && runs[runs.length() - 1].1 == idx {
      let (text, k) = runs[runs.length() - 1]
      runs[runs.length() - 1] = (text + ch, k)
    } else {
      runs.push((ch, idx))
    }
  }
  runs
}

///|
/// 未上色的**非空白**字符数（色号表版本）。
pub fn dark_of(flags : Array[Int], code : String) -> Int {
  let mut dark = 0
  let chars = code.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if !chars[i].is_whitespace() && flags[i] == -1 {
      dark = dark + 1
    }
  }
  dark
}

///|
/// 非空白字符总数（旧实现 `--audit` 的分母）。
pub fn solid_count(code : String) -> Int {
  code.to_array().filter(fn(ch) { !ch.is_whitespace() }).length()
}
