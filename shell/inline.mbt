// shell/inline.mbt —— 行内片段：`Span` → 视图。
//
// ⚠️ 这一份里藏着最贵的那条坑（详见 app.mbt 原来的文件头）：
// RN 里每个 `Text` 都是独立的 flex item，把"普通文字 + 加粗 + 行内代码"当**兄弟节点**铺开，
// 每个片段会各占一行 —— 编译器不拦、控制台不报。所以这里**整段嵌进一个 Text**。
//
// 颜色从 M3 起走 `theme`（以前是 `c_accent` / `c_ink` 两个全局常量 —— 那正是"换皮必漏"的形状）。

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
/// 一个片段。**只改字**（字体 / 颜色 / 粗细）：
/// 嵌套 `Text` 上的盒属性在 RN 那边会丢（web 上看着生效，原生端静默丢掉 ⇒ 两端口径不一致），
/// 所以行内码不带底色 —— 与 DESIGN §3.4"行内码 13.5 + 淡底"差的那一项，账记在这里。
fn span_view(theme : Theme, s : Span) -> @html.Html {
  let p = theme.palette
  match s {
    Txt(t) => @html.span(attrs=attrs(@style.Style::new()), t)
    Code(t) =>
      @html.span(
        attrs=attrs(
          @style.Style::new()
          .font_family(mono)
          .font_size(fs_sm)
          .color(p.fg1),
        ),
        t,
      )
    Bold(t) =>
      @html.span(
        attrs=attrs(@style.Style::new().color(p.fg1).font_weight(@style.FontWeight::W600)),
        t,
      )
  }
}

///|
/// 一段行内内容 → **一个** `Text`（子片段嵌在它里面，于是它们在同一行里流）。
///
/// `base` 由调用点给（正文 / 标题 / 表格各一套），`theme` 只管颜色。
fn inline_text(theme : Theme, spans : Array[Span], base : @style.Style) -> @html.Html {
  @html.span(attrs=attrs(base), spans.map(fn(s) { span_view(theme, s) }))
}
