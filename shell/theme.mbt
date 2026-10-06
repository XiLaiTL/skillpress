// shell/theme.mbt —— 外观常量与基础样式（换皮就改这一份）。
//
// 13 个颜色 + 一个等宽字体族 + `attrs()` / `body_style()`。
// ⚠️ 代码块的**色号**不在这里：色号由引擎的 `highlight` 产出，"色号长什么样"在 blocks.mbt 的 `tok_color`。

///|
let c_bg : String = "#f2ede3"

///|

///|
let c_side : String = "#eae3d5"

///|

///|
let c_card : String = "#fffdf8"

///|

///|
let c_ink : String = "#1a1410"

///|

///|
let c_ink2 : String = "#5b4f3f"

///|

///|
let c_ink3 : String = "#8b7c66"

///|

///|
let c_accent : String = "#8a2518"

///|

///|
let c_line : String = "#ddd3c0"

///|

///|
let c_code : String = "#f0e9da"

///|
/// 顶栏（官网的页眉）—— 深色，和正文的暖纸色拉开层次。

///|
/// 顶栏（官网的页眉）—— 深色，和正文的暖纸色拉开层次。
let c_head : String = "#211a13"

///|

///|
let c_head_ink : String = "#fffdf8"

///|

///|
let c_head_ink2 : String = "#b3a48c"

///|

///|
let c_head_on : String = "#3a2f24"

///|

///|
let mono : String = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

///|
/// 行内片段 → 纯文本。顶栏的分栏名要用它（导航栏里塞不下加粗/代码样式）。

///|
fn attrs(s : @style.Style) -> @html.Attrs {
  @html.Attrs::build().styles(s)
}

///|

///|
fn body_style() -> @style.Style {
  @style.Style::new().font_size(14.0).color(c_ink2).line_height_em(1.85)
}

// ── 行内：**一个 Text，里面嵌套 Text**（见文件头的坑） ──────────────────────

///|
