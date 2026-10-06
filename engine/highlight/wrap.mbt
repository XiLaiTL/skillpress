///|
/// 语言表与**包装候选** —— 照抄旧实现 `lib/highlight.mjs` 的 `LANGS` / `WRAPS`
/// （那是调出来的经验：裸解析召回只有 12%，挑对包装之后到 93%）。
///
/// ⚠️ 这两张表是**契约**：旧实现是唯一真相，搬过来之后要逐块对账；
/// 改一边必须改另一边（`hl.mbt` 顶上也写着这句）。

///|
/// 一种语言：用哪份 wasm / 哪份 query、站点上显示什么名、**要不要试包装**。
pub struct LangSpec {
  wasm : String
  label : String
  wrap : Bool
}

///|
/// ASCII 小写（旧实现是 `String(...).toLowerCase()`；core 里没有对应方法，
/// 而"fence 标记大小写不敏感"是**旧实现的行为**，不能因为换个语言就悄悄改掉）。
/// 非 ASCII 字符原样保留 —— 语言标记本来就只可能是 ASCII。
fn ascii_lower(s : StringView) -> String {
  let up = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".to_array()
  let lo = "abcdefghijklmnopqrstuvwxyz".to_array()
  s.to_array().map(fn(ch) {
    let mut out = ch.to_string()
    for i = 0; i < up.length(); i = i + 1 {
      if up[i] == ch {
        out = lo[i].to_string()
      }
    }
    out
  }).fold(init="", fn(acc, x) { acc + x })
}

///|
/// fence 上写的标记 → 语言。别名（`mbt` / `sh` / `js`…）都落到同一份语法资产。
/// 认不出来的标记**返回 None** —— 调用方照原文渲染即可（内容里允许出现没配语法的语言）。
pub fn lang_spec(tag : String) -> LangSpec? {
  let t = ascii_lower(tag.trim())
  if t == "moonbit" || t == "mbt" {
    Some({ wasm: "moonbit", label: "moonbit", wrap: true })
  } else if t == "bash" || t == "sh" || t == "shell" || t == "console" {
    Some({ wasm: "bash", label: "bash", wrap: false })
  } else if t == "json" || t == "jsonc" {
    Some({ wasm: "json", label: "json", wrap: false })
  } else if t == "javascript" || t == "js" || t == "mjs" {
    Some({ wasm: "javascript", label: "javascript", wrap: false })
  } else if t == "toml" {
    Some({ wasm: "toml", label: "toml", wrap: false })
  } else {
    None
  }
}

///|
/// 一种包装：名字 + 前缀 + 后缀。
pub struct Wrap {
  name : String
  pre : String
  post : String
}

///|
/// 包装候选（**只有 moonbit 需要**：它的文档块大量是裸表达式）。
pub fn wraps() -> Array[Wrap] {
  [
    { name: "裸着解析", pre: "", post: "" },
    { name: "包进函数体", pre: "fn __snip() {\n", post: "\n}" },
    { name: "包进函数体（Unit）", pre: "fn __snip() -> Unit {\n", post: "\n}" },
    { name: "let 绑定", pre: "fn __snip() {\n  let __x = ", post: "\n}" },
    { name: "调用参数", pre: "fn __snip() {\n  __f(", post: "\n  )\n}" },
    { name: "数组元素", pre: "fn __snip() {\n  let __a = [", post: "\n  ]\n}" },
    { name: "struct 字段", pre: "struct __S {\n", post: "\n}" },
    { name: "match 分支", pre: "fn __snip(x : Int) {\n  match x {\n", post: "\n  }\n}" },
  ]
}

///|
/// 一次高亮的结果。
pub struct Highlight {
  runs : Array[(String, Int)]
  dark : Int
  wrapper : String
  label : String
}

///|
/// 一次"包装下的解析"：把 `pre + code + post` 交给解析器，再按优先级刷回片段坐标。
/// `caps_of` 由调用方给（它才知道怎么调底层解析器）—— 这样这层逻辑是**纯**的、可测的。
pub fn shade_with(
  code : String,
  wrap : Wrap,
  caps_of : (String) -> Array[Capture] raise,
) -> Shade raise {
  let source = wrap.pre + code + wrap.post
  let caps = caps_of(source)
  shade(code, wrap.pre.length(), caps)
}

///|
/// 一个代码块 → 高亮结果（挑"未上色最少"的那个包装；`dark == 0` 就提前收工）。
///
/// ⚠️ 硬不变量：`runs` 拼回去必须**逐字节等于原文**，否则抛 —— 照搬旧实现那条断言
/// （"高亮把代码改坏了"是绝不能静默发生的事）。
pub fn highlight(code : String, tag : String, caps_of : (String) -> Array[Capture] raise) -> Highlight? raise {
  let spec = match lang_spec(tag) {
    Some(s) => s
    None => return None
  }
  let candidates = if spec.wrap { wraps() } else { [wraps()[0]] }
  let mut best : (Shade, String)? = None
  for w in candidates {
    let s = shade_with(code, w, caps_of)
    let better = match best {
      None => true
      Some((b, _)) => s.dark < b.dark
    }
    if better {
      best = Some((s, w.name))
    }
    match best {
      Some((b, _)) => if b.dark == 0 { break }
      None => ()
    }
  }
  let (shade0, wrapper) = match best {
    Some(pair) => pair
    None => return None
  }
  let runs = runs_of(code, shade0.flags)
  let back = runs.fold(init="", fn(acc, r) { acc + r.0 })
  if back != code {
    raise Failure("高亮把代码改坏了（拼回来与原文不一致）：\{code[:60]}")
  }
  Some({ runs, dark: shade0.dark, wrapper, label: spec.label })
}
