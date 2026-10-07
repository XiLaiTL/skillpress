// shell/code_block.mbt —— **代码块**：语言标签 + 工具条（复制按钮）+ 构建期上色好的片段。
//
// 为什么单独一份（2026-10-07）：`blocks.mbt` 撞上了 400 行预算（R9 / D21 的判据 `tools/line-budget.sh`）。
// 规矩是"超了就拆成**一个文件一件事**"，而不是删注释凑数 —— 而"代码块工具条"本来就是一件事：
// 它带自己的状态（`copied_at` 决定哪一个按钮显示「已复制」）、自己的坑（嵌套 `Text` 上盒属性会丢）、
// 自己的判据（`_scratch/code-toolbar-check.mjs`）。**块级排版**留在 `blocks.mbt`。

///|
/// 一个代码块。**构建期**已经高亮好了（tree-sitter），这里只是照着色号上色：
/// 外层一个 `Text` 撑字体与行高，片段嵌在它里面、只改颜色（嵌套 Text 上的盒属性会丢，见文件头）。
fn code_block(
  theme : Theme,
  lang : String,
  text : String,
  runs : Array[(String, Int)],
  idx : Int,
  copied : Bool,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  let p = theme.palette
  let kids : Array[@html.Html] = if runs.length() > 0 {
    // `theme.tok(色号)`：色号是引擎在构建期算的（1..9，0 = 正文色），明暗两套各翻各的
    runs.map(r => @html.span(attrs=attrs(@style.Style::new().color(theme.tok_color(r.1))), r.0))
  } else {
    [@html.span(attrs=attrs(@style.Style::new()), text)]
  }
  let base = @style.Style::new()
    .font_family(mono)
    .font_size(fs_sm)
    .line_height_em(lh_aux)
    .color(p.fg1)
    .white_space(@style.WhiteSpace::PreWrap)
  // ── 工具条（对标表 #5：语言标签 + 复制）─────────────────────────────────────
  //
  // ⚠️ 语言标签**只在引擎给了语言时画**（`lang == ""` ⇒ 留空）：不编一个 "text" 糊上去 ——
  //    那是"看起来有信息、其实是假的"（§1 反面验收）。
  // ⚠️ 复制按钮必须是 `@html.button`（`div` 上的 `on_click` 在 web 上是死处理器）。
  let bar : Array[@html.Html] = []
  bar.push(
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .font_family(mono)
        .font_size(fs_meta)
        .color(p.fg3),
      ),
      lang,
    ),
  )
  bar.push(
    @html.button(
      attrs=attrs(
        @style.Style::new()
        .font_size(fs_meta)
        .color(if copied { p.brand } else { p.fg3 })
        .padding_vertical(@style.px(sp1))
        .padding_horizontal(@style.px(sp2))
        .border_width(0.0)
        .border_radius(r2)
        .background_color("transparent"),
      )
      // 节点名：判据按名字点它（`copy-<第几个代码块>`，与工具条的序号一致）
      .id("copy-" + idx.to_string()),
      on_click=emit(CopyCode(idx, text)),
      if copied { "已复制" } else { "复制" },
    ),
  )
  let toolbar = @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::Center)
      .justify_content(@style.Justify::SpaceBetween)
      .padding_left(@style.px(sp4))
      .padding_right(@style.px(sp2))
      .padding_vertical(@style.px(sp1))
      .border_bottom_width(1.0)
      .border_bottom_color(p.code_line),
    ),
    bar,
  )
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .background_color(p.code_bg)
      .border_width(1.0)
      .border_color(p.code_line)
      .border_radius(r3)
      .overflow(@style.Overflow::Hidden)
      .margin_bottom(@style.px(sp5)),
    ),
    [
      toolbar,
      @html.div(
        attrs=attrs(@style.Style::new().padding(@style.px(sp4))),
        [@html.span(attrs=attrs(base), kids)],
      ),
    ],
  )
}
