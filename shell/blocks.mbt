// shell/blocks.mbt —— 块级渲染：`Block` → 视图（段落 / 标题 / 列表 / 表格 / 代码块 / 引用 / 分隔线）。
//
// ## 三条规矩（DESIGN-site.md §3 / §5）
//
// 1. **颜色只能来自 `theme`**：`theme.palette.*` 或 `theme.tok(色号)`。
//    这份文件里**不许有字面色号** —— 换主题时漏一处，那一处就不跟着变（这条有判据盯着，见 §6.5 ①）。
//    ⚠️ 旧版这里有 9 个写死的 `#8a2518` 之类（`tok_color`）：那是**换皮必漏**的形状，本轮删掉，
//    改成 `theme.tok(i)` —— 同一份内容产物在明暗两套下都成立，构建期不用重跑（§6.2）。
// 2. **尺度只用 token**：字号 `fs_*`、行高 `lh_*`、间距 `sp*`、圆角 `r*`（`tokens.mbt`）。
//    旧版这里散着 12.0 / 13.0 / 17.5 / 7.0 这类值 —— 那就是"没有一个音阶"的来源。
// 3. **块只负责块的排版**：一份块的样式由"正文那一栏"决定（宽度 720 在 `layout.prose_wrap`），
//    这里不碰宽度。
//
// ## 两个实测过的坑（别改回去）
//
// · **嵌套 `Text` 上的盒属性会丢**：RN 里 `Text` 嵌套只传"字"那一层，background/padding/border
//   落在嵌套节点上不生效。所以行内代码（`Code` span）**只有字体与颜色**，没有底色 —— 这与
//   DESIGN §3.4 的"行内码 13.5 + 淡底"差一项，**账记在这里**（见 reports）。
// · **`overflow` 子集里只有 `Visible / Hidden / Scroll`，没有 `auto`**：`Scroll` 会常驻滚动条。
//   代码块的长行因此选择**折行**（`PreWrap`）而不是横向滚动 —— 与 DESIGN §5"横向可滚"差一项，
//   同样是子集所限，账记在这里。

///|
/// 一个代码块。**构建期**已经高亮好了（tree-sitter），这里只是照着色号上色：
/// 外层一个 `Text` 撑字体与行高，片段嵌在它里面、只改颜色（嵌套 Text 上的盒属性会丢，见文件头）。
fn code_block(theme : Theme, text : String, runs : Array[(String, Int)]) -> @html.Html {
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
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .background_color(p.code_bg)
      .border_width(1.0)
      .border_color(p.code_line)
      .border_radius(r3)
      .padding(@style.px(sp4))
      .margin_bottom(@style.px(sp5)),
    ),
    [@html.span(attrs=attrs(base), kids)],
  )
}

///|
/// 表格：表头一行（次级面 + 1px 底线），数据行一行一条分隔线。
///
/// ⚠️ 与 DESIGN §5 差一项：**列宽等分**、**不能横向滚**（那是真表格 + `overflow: auto` 的能力，
///    子集里没有）⇒ 列多的表会把文字挤窄。账记在这里，别当"已经做完了"。
fn table_view(
  theme : Theme,
  header : Array[Array[Span]],
  rows : Array[Array[Array[Span]]],
) -> @html.Html {
  let p = theme.palette
  let cell = fn(align : @style.Align) {
    @style.Style::new()
    .flex(1.0)
    .min_width(@style.px(0.0))
    .padding_vertical(@style.px(sp3))
    .padding_horizontal(@style.px(sp4))
    .align_items(align)
  }
  let head : Array[@html.Html] = header.map(c =>
    @html.div(
      attrs=attrs(cell(@style.Align::FlexStart).border_bottom_width(1.0).border_bottom_color(p.line1)),
      [
        inline_text(
          theme,
          c,
          @style.Style::new()
          .font_size(fs_meta)
          .line_height_em(lh_tight)
          .color(p.fg2)
          .font_weight(@style.FontWeight::W600),
        ),
      ],
    )
  )
  let body : Array[@html.Html] = rows.map(r =>
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .flex_direction(@style.FlexDirection::Row)
        .align_items(@style.Align::FlexStart)
        .border_bottom_width(1.0)
        .border_bottom_color(p.line1),
      ),
      r.map(c =>
        @html.div(
          attrs=attrs(cell(@style.Align::FlexStart)),
          [
            inline_text(
              theme,
              c,
              @style.Style::new().font_size(fs_sm).line_height_em(lh_aux).color(p.fg1),
            ),
          ],
        )
      ),
    )
  )
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .border_width(1.0)
      .border_color(p.line1)
      .border_radius(r3)
      .margin_bottom(@style.px(sp5)),
    ),
    [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Row)
          .align_items(@style.Align::FlexStart)
          .background_color(p.surface2)
          .border_top_left_radius(r3)
          .border_top_right_radius(r3),
        ),
        head,
      ),
      @html.div(attrs=attrs(@style.Style::new()), body),
    ],
  )
}

///|
/// 标题：字号与上下留白按层级给（`h2` 之前要留出"翻页感"的空白，`h3` 只要一点）。
///
/// `top` / `bottom` 由调用点给 —— 标题的间距是"层级"这件事的一半，写在 `block_view` 里更清楚。
fn heading(
  theme : Theme,
  spans : Array[Span],
  size : Double,
  weight : @style.FontWeight,
  top : Double,
  bottom : Double,
) -> @html.Html {
  let p = theme.palette
  @html.div(
    attrs=attrs(@style.Style::new().margin_top(@style.px(top)).margin_bottom(@style.px(bottom))),
    [
      inline_text(
        theme,
        spans,
        @style.Style::new()
        .font_size(size)
        .line_height_em(if size >= fs_h2 { 1.3 } else { lh_tight })
        .letter_spacing_em(if size >= fs_h2 { -0.01 } else { 0.0 })
        .color(p.fg1)
        .font_weight(weight),
      ),
    ],
  )
}

///|
/// 一条列表项：前面一个记号（有序用序号、无序用 `·` / `–`），后面是内容。
///
/// 记号色用 `--fg-3`：它是**装饰**（不承载信息）—— 正是 §3.2 给 `fg-3` 留的那一格。
fn bullet_view(theme : Theme, item : (Int, String, Array[Span])) -> @html.Html {
  let p = theme.palette
  let (indent, num, sp) = item
  let ordered = num != ""
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::FlexStart)
      .margin_bottom(@style.px(sp2))
      .padding_left(@style.px(if indent == 0 { 0.0 } else { sp4 })),
    ),
    [
      @html.span(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_base)
          .line_height_em(lh_base)
          .color(p.fg3)
          .margin_right(@style.px(sp2)),
        ),
        if ordered { num } else if indent == 0 { "·" } else { "–" },
      ),
      @html.div(
        attrs=attrs(@style.Style::new().flex(1.0).min_width(@style.px(0.0))),
        [
          inline_text(
            theme,
            sp,
            @style.Style::new().font_size(fs_base).line_height_em(lh_base).color(p.fg1),
          ),
        ],
      ),
    ],
  )
}

///| 正文段落用的那一份字（正文块的"默认形"，全篇一致）。
fn body_text(theme : Theme) -> @style.Style {
  @style.Style::new().font_size(fs_base).line_height_em(lh_base).color(theme.palette.fg1)
}

///| 一个块 → 视图。
pub fn block_view(theme : Theme, b : Block) -> @html.Html {
  let p = theme.palette
  match b {
    Hr =>
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .height(@style.px(1.0))
          .background_color(p.line1)
          .margin_top(@style.px(sp5))
          .margin_bottom(@style.px(sp5)),
        ),
        ([] : Array[@html.Html]),
      )
    // 标题层级 3 档（DESIGN §1 A2）：h2 48/16、h3 32/12、h4 24/8
    H2(sp) => heading(theme, sp, fs_h2, @style.FontWeight::W700, sp7, sp4)
    H3(sp) => heading(theme, sp, fs_h3, @style.FontWeight::W600, sp6, sp3)
    H4(sp) => heading(theme, sp, fs_base, @style.FontWeight::W600, sp5, sp2)
    P(sp) =>
      @html.div(
        attrs=attrs(@style.Style::new().margin_bottom(@style.px(sp4))),
        [inline_text(theme, sp, body_text(theme))],
      )
    Quote(sp) =>
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .border_left_width(2.0)
          .border_left_color(p.line2)
          .padding_left(@style.px(sp4))
          .margin_bottom(@style.px(sp4)),
        ),
        [
          inline_text(
            theme,
            sp,
            @style.Style::new().font_size(fs_base).line_height_em(lh_base).color(p.fg2),
          ),
        ],
      )
    Code(_lang, text, runs) => code_block(theme, text, runs)
    Ul(items) =>
      @html.div(
        attrs=attrs(@style.Style::new().margin_bottom(@style.px(sp4))),
        items.map(fn(it) { bullet_view(theme, it) }),
      )
    Table(header, rows) => table_view(theme, header, rows)
  }
}

///|
/// 一串块 → 视图（正文那一栏的内容）。
pub fn blocks_view(theme : Theme, blocks : Array[Block]) -> @html.Html {
  @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)),
    blocks.map(fn(b) { block_view(theme, b) }),
  )
}
