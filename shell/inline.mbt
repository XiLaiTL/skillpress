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
      // 链接的可读文本是**标签**（目标另有 `Code(target)` 那一段，不重复算）
      Link(label, _, _) => buf.write_string(label)
    }
  }
  buf.to_string()
}

///|
/// 一个片段。**只改字**（字体 / 颜色 / 粗细）：
/// 嵌套 `Text` 上的盒属性在 RN 那边会丢（web 上看着生效，原生端静默丢掉 ⇒ 两端口径不一致），
/// 所以行内码不带底色 —— 与 DESIGN §3.4"行内码 13.5 + 淡底"差的那一项，账记在这里。
fn span_view(theme : Theme, s : Span, ctx : Ctx, emit : @cmd.Emit[Msg]) -> @html.Html {
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
    // **链接**：可点（对标表 #9）。
    //
    // ⚠️ 用 `@html.span`（→ RN 的 `Text`）而不是 `@html.button`（→ `Pressable`）：
    //    行内片段必须留在**同一个 Text 的流**里 —— `Pressable` 是个 View，塞进 Text 里
    //    会把这一行拆成两个 flex item（本文件头上那条最贵的坑）。`Text` 自己有 `onPress` ✓。
    //    ⇒ 这一条**要在真浏览器里量**（`span` 上的 on_click 到底接不接得住），别靠推断。
    Link(label, target, label_is_path) => {
      // 内部链接（`find_page` 认得出 ⇒ `kind > 0`）**站内跳页**；其余（http(s) / mailto / 锚点）
      // 交给 `url` 能力的动作通道开新窗口。判据：内部那条**不该刷新页面**（地址栏变、DOM 不重建）。
      let (kind, i, k) = (ctx.find_page)(target)
      let msg = if kind > 0 { Go(kind, i, k) } else { LinkOut(target) }
      let mut st = @style.Style::new()
        .color(p.brand)
        .text_decoration_line(@style.TextDecorationLine::Underline)
      if label_is_path {
        st = st.font_family(mono)
      }
      // ⚠️ `@html.span` **没有** `on_click=` 这个具名参数（只有 button/div 那类有）⇒
      //    走 `Attrs::on_click`（它的签名是 `(MouseEvent) -> Cmd`）。映射仍是 `click → onPress`，
      //    落在 `Text` 上＝RN/RNW 都支持的"可点文字"。
      @html.span(attrs=attrs(st).on_click(fn(_) { emit(msg) }), label)
    }
  }
}

///|
/// 一段行内内容 → **一个** `Text`（子片段嵌在它里面，于是它们在同一行里流）。
///
/// `base` 由调用点给（正文 / 标题 / 表格各一套），`theme` 只管颜色。
fn inline_text(
  theme : Theme,
  spans : Array[Span],
  base : @style.Style,
  ctx : Ctx,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  @html.span(attrs=attrs(base), spans.map(fn(s) { span_view(theme, s, ctx, emit) }))
}
