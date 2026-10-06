// shell/blocks.mbt —— 块级渲染：`Block` → 视图（段落 / 标题 / 列表 / 表格 / 代码块 / 引用 / 分隔线）。
//
// `tok_color` 把引擎给的**色号**翻成颜色：色号的含义在引擎的 `highlight`（PALETTE），
// 这里只管"长什么样" —— 两边改要一起改。

///|
/// 高亮片段的**色号 → 颜色**。
///
/// 色号是 `tools/highlight.mjs` 里 `PALETTE` 的索引（那边定"什么是什么"，这边定"长什么样"）。
/// 类别顺序改了要**同时**改两边 —— `check.mjs` 管不到这里，靠这条注释对账。
fn tok_color(i : Int) -> String {
  match i {
    1 => "#8a2518" // 关键字
    2 => "#3f6b47" // 字符串
    3 => "#9a8b73" // 注释
    4 => "#7a4a12" // 数字 / 字面量
    5 => "#1d4e73" // 类型
    6 => "#2f5d8a" // 函数
    7 => "#5b3a70" // 模块
    8 => "#6b5a44" // 变量 / 字段
    9 => "#8b7c66" // 标点 / 运算符
    _ => c_ink
  }
}

///|
/// 一个代码块。**构建期**已经高亮好了（tree-sitter），这里只是照着色号上色：
/// 外层一个 `Text` 撑字体与行高，片段嵌在它里面、只改颜色（嵌套 Text 上的盒属性会丢，见文件头）。

///|
/// 一个代码块。**构建期**已经高亮好了（tree-sitter），这里只是照着色号上色：
/// 外层一个 `Text` 撑字体与行高，片段嵌在它里面、只改颜色（嵌套 Text 上的盒属性会丢，见文件头）。
fn code_block(text : String, runs : Array[(String, Int)]) -> @html.Html {
  let base = @style.Style::new().font_family(mono).font_size(12.0).line_height_em(1.65)
  let kids : Array[@html.Html] = if runs.length() > 0 {
    runs.map(r => @html.span(attrs=attrs(@style.Style::new().color(tok_color(r.1))), r.0))
  } else {
    [@html.span(attrs=attrs(@style.Style::new()), text)]
  }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .background_color(c_code)
      .border_width(1.0)
      .border_color(c_line)
      .border_radius(8.0)
      .padding(@style.px(12.0))
      .margin_vertical(@style.px(6.0)),
    ),
    [@html.span(attrs=attrs(base.color(c_ink)), kids)],
  )
}

///|

///|
fn table_view(
  header : Array[Array[Span]],
  rows : Array[Array[Array[Span]]],
) -> @html.Html {
  let head : Array[@html.Html] = header.map(c =>
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .flex(1.0)
        .padding(@style.px(7.0))
        .border_bottom_width(2.0)
        .border_bottom_color(c_line),
      ),
      [inline_text(c, body_style().color(c_ink).font_weight(@style.FontWeight::W600))],
    )
  )
  let body : Array[@html.Html] = rows.map(r =>
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .flex_direction(@style.FlexDirection::Row)
        .align_items(@style.Align::FlexStart)
        .border_bottom_width(1.0)
        .border_bottom_color(c_line),
      ),
      r.map(c =>
        @html.div(
          attrs=attrs(@style.Style::new().flex(1.0).padding(@style.px(7.0))),
          [inline_text(c, body_style().font_size(13.0).line_height_em(1.6))],
        )
      ),
    )
  )
  @html.div(
    attrs=attrs(@style.Style::new().margin_vertical(@style.px(6.0))),
    [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Row)
          .align_items(@style.Align::FlexStart)
          .background_color(c_bg),
        ),
        head,
      ),
      @html.div(attrs=attrs(@style.Style::new()), body),
    ],
  )
}

///|

///|
fn heading(spans : Array[Span], size : Double, weight : @style.FontWeight) -> @html.Html {
  @html.div(
    attrs=attrs(@style.Style::new().margin_top(@style.px(18.0)).margin_bottom(@style.px(4.0))),
    [inline_text(spans, @style.Style::new().font_size(size).color(c_ink).font_weight(weight))],
  )
}

///|

///|
fn bullet_view(item : (Int, String, Array[Span])) -> @html.Html {
  let (indent, num, sp) = item
  let ordered = num != ""
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::FlexStart)
      .margin_vertical(@style.px(3.0))
      .padding_left(@style.px(if indent == 0 { 4.0 } else { 20.0 })),
    ),
    [
      @html.span(
        attrs=attrs(@style.Style::new().font_size(13.5).color(c_ink3).margin_right(@style.px(6.0))),
        if ordered { num } else if indent == 0 { "·" } else { "–" },
      ),
      @html.div(attrs=attrs(@style.Style::new().flex(1.0)), [inline_text(sp, body_style())]),
    ],
  )
}

///|

///|
fn block_view(b : Block) -> @html.Html {
  match b {
    Hr =>
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .height(@style.px(1.0))
          .background_color(c_line)
          .margin_vertical(@style.px(14.0)),
        ),
        ([] : Array[@html.Html]),
      )
    H2(sp) => heading(sp, 17.5, @style.FontWeight::W700)
    H3(sp) => heading(sp, 15.0, @style.FontWeight::W600)
    H4(sp) => heading(sp, 13.5, @style.FontWeight::W600)
    P(sp) =>
      @html.div(
        attrs=attrs(@style.Style::new().margin_vertical(@style.px(5.0))),
        [inline_text(sp, body_style())],
      )
    Quote(sp) =>
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .border_left_width(3.0)
          .border_left_color(c_accent)
          .padding_left(@style.px(12.0))
          .margin_vertical(@style.px(8.0)),
        ),
        [inline_text(sp, body_style())],
      )
    Code(_lang, text, runs) => code_block(text, runs)
    Ul(items) =>
      @html.div(
        attrs=attrs(@style.Style::new().margin_vertical(@style.px(4.0))),
        items.map(bullet_view),
      )
    Table(header, rows) => table_view(header, rows)
  }
}

// ── 页面 ──────────────────────────────────────────────────────────────────────

///|
/// 渲染时用的一页（skill 主文档 / 子页都被摊平成这个形状）。
