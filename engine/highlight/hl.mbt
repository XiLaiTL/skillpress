///|
/// 上色：**色号映射与片段拼装**（与旧实现 `lib/highlight.mjs` 同口径）。
///
/// 这一半是纯逻辑，与 target 无关（这也正是"引擎搬 MoonBit"想拿回来的那部分）：
/// 真正依赖运行时的只有"调 tree-sitter 解析 + 跑 query"，那部分在 `ts_shim.mbt` 里，
/// 而且**只产出一个朴素的三列文本**（`名字\t起点\t终点`），剩下的事都在这里做。
///
/// ⚠️ 与旧实现对齐的两条硬约束（改一边必须改另一边）：
///   ① 色号规则 = `PALETTE` 的前缀表（下面 `palette_idx`）；
///   ② 片段拼回去**逐字节等于原文**（`build_runs` 的返回值由调用方断言）。

///|
/// 一条 capture（名字 + 区间）。区间是**解析器给的下标**。
pub struct Capture {
  name : String
  start : Int
  end : Int
}

///|
/// capture 名 → 色号。**照抄旧实现 `lib/highlight.mjs` 的 `PALETTE` 前缀规则**：
/// 1 关键字 ｜ 2 字符串 ｜ 3 注释 ｜ 4 数字/字面量 ｜ 5 类型 ｜ 6 函数 ｜ 7 模块 ｜
/// 8 变量/字段/参数 ｜ 9 标点 —— 没匹配上的**不上色**（色号 0）。
pub fn palette_idx(name : String) -> Int {
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
/// 把 capture 收成区间表：先按起点排，**重叠的后到者丢掉**（先到先得 ——
/// 与旧实现"逐字符贴、贴过的不再贴"等价）。
pub fn collect(caps : Array[Capture]) -> Array[Capture] {
  let kept : Array[Capture] = []
  for c in caps {
    if palette_idx(c.name) > 0 && c.end > c.start {
      kept.push(c)
    }
  }
  kept.sort_by(fn(a, b) { a.start - b.start })
  let out : Array[Capture] = []
  let mut last = -1
  for c in kept {
    if c.start >= last {
      out.push(c)
      last = c.end
    }
  }
  out
}

///|
/// 区间表 → `(片段, 色号)` 序列（没覆盖到的部分色号 0）。
/// ⚠️ 调用方必须断言 `runs` 的文本拼回去等于原文 —— 那是旧实现的硬断言，这边照搬。
pub fn build_runs(code : String, spans : Array[Capture]) -> Array[(String, Int)] {
  let runs : Array[(String, Int)] = []
  let mut pos = 0
  for s in spans {
    if s.start > pos {
      runs.push((code[pos:s.start].to_owned(), 0))
    }
    runs.push((code[s.start:s.end].to_owned(), palette_idx(s.name)))
    pos = s.end
  }
  if pos < code.length() {
    runs.push((code[pos:].to_owned(), 0))
  }
  runs
}

///|
/// 未上色的**非空白**字符数（旧实现的 `dark` 口径：`summarize` 里的那个分子）。
pub fn dark_count(runs : Array[(String, Int)]) -> Int {
  let mut dark = 0
  for r in runs {
    if r.1 == 0 {
      for ch in r.0 {
        if !ch.is_whitespace() {
          dark = dark + 1
        }
      }
    }
  }
  dark
}

///|
/// 非空白字符总数（旧实现的分母）。
pub fn solid_count(code : String) -> Int {
  code.to_array().filter(fn(ch) { !ch.is_whitespace() }).length()
}
