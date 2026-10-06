// shell/docs.mbt —— 文档区：左侧 skill 树 + 右栏正文。
//
// 树是照内容长出来的（`skills : Array[Doc]` → skill → 它的子页），不写死任何一条。

///|
/// 渲染时用的一页（skill 主文档 / 子页都被摊平成这个形状）。
priv struct Page {
  title : String
  kicker : String
  desc : String
  when : String
  blocks : Array[Block]
}

///|

///|
fn page_of(sel : Sel, skills : Array[Doc]) -> Page {
  if sel.i < 0 || sel.i >= skills.length() {
    return { title: "", kicker: "", desc: "", when: "", blocks: ([] : Array[Block]) }
  }
  let d = skills[sel.i]
  if sel.kind == 2 && sel.k >= 0 && sel.k < d.kids.length() {
    let kid = d.kids[sel.k]
    {
      title: kid.title,
      kicker: d.slug + " · " + (if kid.kind == "script" { "script" } else { "ref" }),
      desc: kid.desc,
      when: "",
      blocks: kid.blocks,
    }
  } else {
    { title: d.slug, kicker: "skill", desc: d.full_desc, when: d.when, blocks: d.blocks }
  }
}

///|

///|
fn pane(p : Page) -> @html.Html {
  let head : Array[@html.Html] = []
  if p.kicker != "" {
    head.push(
      @html.span(
        attrs=attrs(
          @style.Style::new()
          .font_family(mono)
          .font_size(11.5)
          .color(c_ink3)
          .margin_bottom(@style.px(4.0)),
        ),
        p.kicker,
      ),
    )
  }
  head.push(
    @html.span(
      attrs=attrs(
        @style.Style::new()
          .font_family(mono)
          .font_size(22.0)
          .color(c_ink)
          .font_weight(@style.FontWeight::W700),
      ),
      p.title,
    ),
  )
  if p.desc != "" {
    head.push(
      @html.div(
        attrs=attrs(@style.Style::new().margin_top(@style.px(8.0))),
        [
          @html.span(
            attrs=attrs(@style.Style::new().font_size(13.0).color(c_ink2).line_height_em(1.75)),
            p.desc,
          ),
        ],
      ),
    )
  }
  if p.when != "" {
    head.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .margin_top(@style.px(10.0))
          .padding(@style.px(10.0))
          .background_color(c_bg)
          .border_radius(8.0),
        ),
        [
          @html.span(
            attrs=attrs(@style.Style::new().font_size(12.5).color(c_ink2).line_height_em(1.65)),
            "何时用它 —— " + p.when,
          ),
        ],
      ),
    )
  }
  @html.node(
    "scroll",
    attrs(
      @style.Style::new()
      .flex(1.0)
      .background_color(c_card)
      .padding_horizontal(@style.px(32.0))
      .padding_vertical(@style.px(24.0)),
    ),
    @html.div(
      attrs=attrs(@style.Style::new().max_width(@style.px(880.0))),
      [
        @html.div(attrs=attrs(@style.Style::new()), head),
        @html.div(
          attrs=attrs(@style.Style::new().margin_top(@style.px(14.0))),
          p.blocks.map(block_view),
        ),
      ],
    ),
  )
}

// ── 官网：顶栏 + 首屏 / 分栏 ─────────────────────────────────────────────────

///|
/// 顶栏里的一条**分段控件项**（D2）。
///
/// 与旧版（一块圆角实心底）的区别：常态**没有底色**，选中只靠
/// **下划线指示条**（`c_accent`，贴在这一项的底边）＋更亮的字色。
/// 于是整排读起来是"一支分段控件"，而不是"一堆按钮"。
///
/// ⚠️ 下划线是**子 View + `position(Absolute)` + `bottom(0)`** ——
/// 不用 `border_bottom_width`，因为那会把内容往上顶、且按下态不好接。
/// 关于 press()：`Render` 里按下态的键会被拆成 `pressStyle`，而**库侧没有消费点**
/// （见 `moobile-pitfalls`）—— 所以这里**不写按下的视觉**，只留可点性与 `on_click`。

///|
fn nav_button(
  label : String,
  sub : String,
  on : Bool,
  depth : Double,
  msg : Msg,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  let kids : Array[@html.Html] = [
    @html.span(
      attrs=attrs(
        @style.Style::new()
        .font_size(13.0)
        .color(if on { c_accent } else { c_ink })
        .font_weight(if on { @style.FontWeight::W600 } else { @style.FontWeight::W400 }),
      ),
      label,
    ),
  ]
  if sub != "" {
    kids.push(
      @html.span(
        attrs=attrs(
          @style.Style::new()
          .font_size(11.0)
          .color(c_ink3)
          .margin_top(@style.px(2.0))
          .line_height_em(1.4),
        ),
        sub,
      ),
    )
  }
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .flex(1.0)
      .align_items(@style.Align::FlexStart)
      .padding_horizontal(@style.px(8.0))
      .padding_vertical(@style.px(7.0))
      .border_radius(8.0)
      .background_color(if on { c_card } else { "transparent" }),
    ),
    on_click=emit(msg),
    [@html.div(attrs=attrs(@style.Style::new().padding_left(@style.px(depth))), kids)],
  )
}

///|

///|
fn skill_node(
  d : Doc,
  i : Int,
  sel : Sel,
  open : Bool,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  // 一行 = [展开箭头] + [名字 / 摘要]；箭头只在有子页时才画
  let arrow : Array[@html.Html] = if d.kids.length() > 0 {
    [
      @html.button(
        attrs=attrs(
          @style.Style::new()
          .width(@style.px(18.0))
          .padding_vertical(@style.px(8.0))
          .align_items(@style.Align::Center),
        ),
        on_click=emit(Toggle(i)),
        [
          @html.span(
            attrs=attrs(@style.Style::new().font_size(11.0).color(c_ink3)),
            if open { "▾" } else { "▸" },
          ),
        ],
      ),
    ]
  } else {
    [@html.div(attrs=attrs(@style.Style::new().width(@style.px(18.0))), ([] : Array[@html.Html]))]
  }
  let row = @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::Center),
    ),
    [
      @html.div(attrs=attrs(@style.Style::new()), arrow),
      nav_button(d.slug, d.desc, sel.kind == 1 && sel.i == i, 0.0, Go(1, i, 0), emit),
    ],
  )
  if !open {
    return row
  }
  let kids : Array[@html.Html] = [row]
  for k = 0; k < d.kids.length(); k = k + 1 {
    let kid = d.kids[k]
    kids.push(
      nav_button(
        (if kid.kind == "script" { "⌗ " } else { "§ " }) + kid.name,
        kid.desc,
        sel.kind == 2 && sel.i == i && sel.k == k,
        14.0,
        Go(2, i, k),
        emit,
      ),
    )
  }
  @html.div(attrs=attrs(@style.Style::new()), kids)
}

///|

///|
fn sidebar(skills : Array[Doc], model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let items : Array[@html.Html] = []
  for i = 0; i < skills.length(); i = i + 1 {
    items.push(skill_node(skills[i], i, model.sel, model.open[i], emit))
  }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .width(@style.px(292.0))
      .background_color(c_side)
      .border_right_width(1.0)
      .border_right_color(c_line)
      .padding(@style.px(10.0)),
    ),
    [
      @html.div(
        attrs=attrs(@style.Style::new().padding(@style.px(6.0))),
        [
          @html.span(
            attrs=attrs(
              @style.Style::new().font_size(15.0).color(c_ink).font_weight(@style.FontWeight::W700),
            ),
            "SKILL 文档",
          ),
          @html.span(
            attrs=attrs(
              @style.Style::new().font_size(11.0).color(c_ink3).margin_top(@style.px(2.0)),
            ),
            "一个目录 = 一个主题；展开看它的 refs / scripts",
          ),
        ],
      ),
      // ⚠️ 伪标签 `scroll` —— RN 的 `View` **不滚动**（HTML 靠 overflow），不套它手机上只看得到第一屏
      @html.node(
        "scroll",
        attrs(@style.Style::new().flex(1.0)),
        @html.div(attrs=attrs(@style.Style::new()), items),
      ),
    ],
  )
}

///|
