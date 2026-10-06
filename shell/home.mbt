// shell/home.mbt —— 官网那半张脸：首屏 + 分栏正文 + CTA。

///|
/// 首屏上的按钮（官网那种"下一步去哪"）。
fn cta(label : String, primary : Bool, msg : Msg, emit : @cmd.Emit[Msg]) -> @html.Html {
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .padding_horizontal(@style.px(15.0))
      .padding_vertical(@style.px(10.0))
      .margin_right(@style.px(9.0))
      .border_radius(8.0)
      .border_width(1.0)
      .border_color(if primary { c_accent } else { c_line })
      .background_color(if primary { c_accent } else { c_bg }),
    ),
    on_click=emit(msg),
    [
      @html.span(
        attrs=attrs(
          @style.Style::new()
          .font_size(13.0)
          .color(if primary { c_head_ink } else { c_ink })
          .font_weight(@style.FontWeight::W600),
        ),
        label,
      ),
    ],
  )
}

///|
/// 点顶栏的一条分栏时该发哪条消息（D3：**纯链接节**直接跳到它指的那一页；有菜单的先展开）。
///
/// 数据侧已经把这个节的目标认成了**页面键**（`content.generated.mbt` 的 `Section.link`），
/// 这里只把键换算成"文档模式里的第几页"。认不出来（`kind < 0`）就退回普通分栏。

///|
/// 首屏 = H1 + 引言（`home.lede`）+ 两个"下一步"。
fn hero(home : Home, emit : @cmd.Emit[Msg]) -> Array[@html.Html] {
  let out : Array[@html.Html] = [
    @html.div(
      attrs=attrs(@style.Style::new().margin_vertical(@style.px(4.0))),
      [
        @html.span(
          attrs=attrs(
            @style.Style::new()
            .font_family(mono)
            .font_size(34.0)
            .color(c_ink)
            .font_weight(@style.FontWeight::W700),
          ),
          home.title,
        ),
      ],
    ),
  ]
  for b in home.lede {
    out.push(block_view(b))
  }
  out.push(
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .flex_direction(@style.FlexDirection::Row)
        .align_items(@style.Align::Center)
        .margin_top(@style.px(18.0)),
      ),
      [cta("快速上手 →", true, Top(0), emit), cta("文档 / SKILL →", false, Docs, emit)],
    ),
  )
  out
}

///|
/// 官网正文：`sec < 0` 是首屏，否则是那一栏（只有那一栏 —— 一次显示一节，见文件头）。

///|
/// 官网正文：`sec < 0` 是首屏，否则是那一栏（只有那一栏 —— 一次显示一节，见文件头）。
fn site_pane(home : Home, sec : Int, emit : @cmd.Emit[Msg]) -> @html.Html {
  let inner : Array[@html.Html] = if sec >= 0 && sec < home.sections.length() {
    let s = home.sections[sec]
    [
      heading(s.title, 25.0, @style.FontWeight::W700),
      @html.div(attrs=attrs(@style.Style::new().margin_top(@style.px(6.0))), s.blocks.map(block_view)),
    ]
  } else {
    hero(home, emit)
  }
  @html.node(
    "scroll",
    attrs(
      @style.Style::new()
      .flex(1.0)
      .background_color(c_card)
      .padding_horizontal(@style.px(34.0))
      .padding_vertical(@style.px(28.0)),
    ),
    @html.div(attrs=attrs(@style.Style::new().max_width(@style.px(880.0))), inner),
  )
}

// ── 左侧树 ────────────────────────────────────────────────────────────────────

///|
