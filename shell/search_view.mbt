// shell/search_view.mbt —— **搜索的视图那半**：命中行（可点）+ 提示语 + 浮层。
//
// 为什么单独一份（2026-10-07）：`search.mbt` 撞上了 400 行预算（`tools/line-budget.sh`）。
// 拆的口径是**索引与画分开**：`search.mbt` 管"搜什么、怎么排"（`Hit` / `page_hits` / `search_of`），
// 这一份管"画成什么样"（`hit_row` / `search_hint` / `search_layer`）。
// 两半的判据也不同：索引那半有白盒测试，视图那半靠真 Chrome（`_scratch/search-check.mjs`）。

///|
/// 一条结果 —— **可点**（`@html.button`：`div` 上的 `on_click` 在 web 上是死处理器）。
fn hit_row(theme : Theme, h : Hit, idx : Int, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Column)
      .align_items(@style.Align::FlexStart)
      .width(@style.pct(100.0))
      .padding_vertical(@style.px(sp2))
      .padding_horizontal(@style.px(sp3))
      .border_width(0.0)
      .border_radius(r2)
      .background_color("transparent"),
    )
    // 节点名（`Attrs::id`）：判据按名字点它（本仓的节点寻址那一刀）。
    // ⚠️ 名字里**带上锚点**（`-a-1` = 整页那条、`-a0` / `-a1`… = 第几节）：
    //    判据要能**按语义**区分两种粒度，而不是去猜文字里有没有"·"（那是形状，不是语义 ——
    //    第一版就是这么猜的，一旦某条摘要里出现"·"就找不着了）。
    .id("hit-" + idx.to_string() + "-a" + h.anchor.to_string()),
    on_click=emit(HitGo(h.kind, h.i, h.k, h.anchor)),
    [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_aux)
          .font_weight(@style.FontWeight::W600)
          .color(p.fg1)
          .white_space(@style.WhiteSpace::NoWrap)
          .overflow(@style.Overflow::Hidden),
        ),
        hit_title(h),
      ),
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_aux)
          .line_height_em(lh_aux)
          .color(p.fg3)
          .white_space(@style.WhiteSpace::NoWrap)
          .overflow(@style.Overflow::Hidden)
          .margin_top(@style.px(sp1)),
        ),
        h.snip,
      ),
    ],
  )
}

///|
/// 一行提示（没输入 / 没命中）—— **不编**"猜你想搜"那种东西。
fn search_hint(theme : Theme, text : String) -> @html.Html {
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .font_size(fs_aux)
      .color(theme.palette.fg3)
      .padding_vertical(@style.px(sp3))
      .padding_horizontal(@style.px(sp3)),
    ),
    text,
  )
}

///|
/// **搜索浮层**：遮罩 + 面板（输入框 + 结果）。
///
/// 关着时返回**空数组** —— 一个多余的可点区域都不留（没有 `pointerEvents`，
/// 见 `mobile.mbt` 文件头第 3 条：画一块全屏 div 会把正文的点击全吃掉）。
/// 挂在**根**里（`layout.shell` 的最后一个孩子）⇒ 等价于 fixed。
fn search_layer(
  theme : Theme,
  ctx : Ctx,
  model : Model,
  emit : @cmd.Emit[Msg],
) -> Array[@html.Html] {
  let p = theme.palette
  if !model.search_open {
    return []
  }
  let parts : Array[@html.Html] = []
  // ① 遮罩（点一下关；必须 `@html.button`）
  parts.push(
    @html.button(
      attrs=attrs(
        @style.Style::new()
        .position(@style.Position::Absolute)
        .left(@style.px(0.0))
        .right_(@style.px(0.0))
        .top(@style.px(0.0))
        .bottom(@style.px(0.0))
        .border_width(0.0)
        .background_color(p.scrim),
      ),
      on_click=emit(SearchClose),
      ([] : Array[@html.Html]),
    ),
  )
  // ② 结果
  let rows : Array[@html.Html] = []
  let hits = search_of(ctx, model.query, 20)
  if model.query.trim() == "" {
    rows.push(search_hint(theme, "输入关键词搜页名 / 小节名 / 正文（Esc 关）"))
  } else if hits.length() == 0 {
    rows.push(search_hint(theme, "没有匹配「" + model.query.trim().to_string() + "」的页或小节 —— 不猜。"))
  } else {
    for i = 0; i < hits.length(); i = i + 1 {
      rows.push(hit_row(theme, hits[i], i, emit))
    }
  }
  // ③ 面板（左/右拉伸 + 上沿压在顶栏下面；**不遮满**，看得见后面是哪个页面）
  parts.push(
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .position(@style.Position::Absolute)
        .left(@style.pct(4.0))
        .right_(@style.pct(4.0))
        .top(@style.px(h_top + sp3))
        .max_height(@style.pct(64.0))
        .overflow(@style.Overflow::Scroll)
        .background_color(p.overlay)
        .border_width(1.0)
        .border_color(p.line2)
        .border_radius(r3)
        .padding(@style.px(sp3)),
      ).id("search-panel"),
      [
        @html.div(
          attrs=attrs(
            @style.Style::new()
            .font_size(fs_aux)
            .font_weight(@style.FontWeight::W600)
            .color(p.fg2)
            .margin_bottom(@style.px(sp2)),
          ),
          "搜索（" + "⌘K" + "）",
        ),
        @html.input(
          value=model.query,
          placeholder="搜页名、小节名、正文…",
          on_input=emit.map(fn (s) { SearchInput(s) }),
          attrs=attrs(
            @style.Style::new()
            .width(@style.pct(100.0))
            .padding_vertical(@style.px(sp2))
            .padding_horizontal(@style.px(sp3))
            .font_size(fs_base)
            .color(p.fg1)
            .background_color(p.surface2)
            .border_width(1.0)
            .border_color(p.line1)
            .border_radius(r2),
          )
          .id("search-input")
          .prop_bool("autoFocus", true),
        ),
        @html.div(
          attrs=attrs(
            @style.Style::new().height(@style.px(1.0)).background_color(p.line1).margin_vertical(
              @style.px(sp3),
            ),
          ),
          ([] : Array[@html.Html]),
        ),
        @html.div(
          attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)),
          rows,
        ),
      ],
    ),
  )
  parts
}
