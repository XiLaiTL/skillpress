// shell/inline.mbt —— 行内片段：`Span` → 视图。
//
// ⚠️ 这一份里藏着最贵的那条坑（详见 app.mbt 原来的文件头）：
// RN 里每个 `Text` 都是独立的 flex item，把"普通文字 + 加粗 + 行内代码"当**兄弟节点**铺开，
// 每个片段会各占一行 —— 编译器不拦、控制台不报。所以这里**整段嵌进一个 Text**。

///|
/// 行内片段 → 纯文本。顶栏的分栏名要用它（导航栏里塞不下加粗/代码样式）。
fn plain(spans : Array[Span]) -> String {
  let buf = StringBuilder()
  for sp in spans {
    match sp {
      Txt(t) => buf.write_string(t)
      Code(t) => buf.write_string(t)
      Bold(t) => buf.write_string(t)
    }
  }
  buf.to_string()
}

///|

///|
fn span_view(s : Span) -> @html.Html {
  match s {
    Txt(t) => @html.span(attrs=attrs(@style.Style::new()), t)
    Code(t) =>
      @html.span(
        attrs=attrs(@style.Style::new().font_family(mono).font_size(12.5).color(c_accent)),
        t,
      )
    Bold(t) =>
      @html.span(
        attrs=attrs(@style.Style::new().color(c_ink).font_weight(@style.FontWeight::W600)),
        t,
      )
  }
}

///|
/// 一段行内内容 → **一个** `Text`（子片段嵌在它里面，于是它们在同一行里流）。

///|
/// 一段行内内容 → **一个** `Text`（子片段嵌在它里面，于是它们在同一行里流）。
fn inline_text(spans : Array[Span], base : @style.Style) -> @html.Html {
  @html.span(attrs=attrs(base), spans.map(span_view))
}

// ── 块 ────────────────────────────────────────────────────────────────────────

///|
/// 高亮片段的**色号 → 颜色**。
///
/// 色号是 `tools/highlight.mjs` 里 `PALETTE` 的索引（那边定"什么是什么"，这边定"长什么样"）。
/// 类别顺序改了要**同时**改两边 —— `check.mjs` 管不到这里，靠这条注释对账。
