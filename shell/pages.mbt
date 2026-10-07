// shell/pages.mbt —— **书架 / 404 / 页脚**这三件（首页门户在 `home.mbt`）。
//
// DESIGN-site.md §6 的页面模板：
//
//   首页    门户：H1 + 一句定位 + 入口卡 + 统计行（在 `home.mbt`）
//   书架    按分组列全部 skill：中文 title + 一句 desc + 子页数，每张卡可点
//   文档页  面包屑 → kicker → H1 → …（在 `article.mbt`）
//   404     一句人话 + 两个出口
//
// 三条贯穿的规矩：
// 1. **界面上的名字一律中文 `title`**（机器名只在 kicker / 面包屑末位 / 页脚，§2.3）；
// 2. **不画点了没反应的东西**：每张卡、每个出口都真的发 `Msg`（§1 反面验收）；
// 3. **拿不到的东西不编**：页脚只写源文件路径 —— 许可 / 生成时间 / 内容根指纹在契约（`Ctx`）里没有，
//    宁可少一行，也不写死一个假值（假值迟早变成"文档说错了"）。见 §5 页脚那一行。

///|
/// 摘要的**短形态**：`sha256:` 徽标只显示头 8 与尾 4（中间省略）——
/// 数据侧存的是**完整** 64 位十六进制，短形态只发生在展示这一层。
fn short_fp(hex : String) -> String {
  if hex.length() <= 16 {
    hex
  } else {
    hex[:8].to_owned() + "…" + hex[hex.length() - 4:].to_owned()
  }
}

///|
/// 页脚那一行：**出处 · 许可 · 构建时间 · 内容根指纹**（DESIGN §5）。
///
/// ⚠️ 每一项都可能拿不到 —— 拿不到的**那一项直接不画**，不写「许可 —」这种占位
///    （§1 反面验收：不画假东西）。三个字段各自为什么可能空，写在 `shell/types.mbt` 的 `Footer`。
fn footer_line(ctx : Ctx, text : String) -> String {
  let parts : Array[String] = [text]
  let f = ctx.footer
  if f.license != "" {
    parts.push("许可 " + f.license)
  }
  // 生成时间的真源是**宿主**（构建那一刻）：契约里那格留给"将来内容侧也能给出可复现的时间"，
  // 今天它总是空 ⇒ 用构建戳顶上（读不到就还是不画）。
  let when = if f.generated_at != "" { f.generated_at } else { build_stamp() }
  if when != "" {
    parts.push("构建于 " + when)
  }
  if f.root_fingerprint != "" {
    parts.push("内容根指纹 sha256:" + short_fp(f.root_fingerprint))
  }
  let buf = StringBuilder()
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(" · ")
    }
    buf.write_string(parts[i])
  }
  buf.to_string()
}

///|
/// 页脚：一行出处（调用点给主文本：源文件路径 / "本站由 … 印成"），其余几样由 `footer_line` 拼。
fn page_footer(theme : Theme, ctx : Ctx, text : String) -> @html.Html {
  let p = theme.palette
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .margin_top(@style.px(sp6))
      .padding_top(@style.px(sp4))
      .border_top_width(1.0)
      .border_top_color(p.line1),
    ),
    [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .font_family(mono)
          .font_size(fs_meta)
          .line_height_em(lh_aux)
          .color(p.fg3),
        ),
        footer_line(ctx, text),
      ),
    ],
  )
}

///|
/// 一张卡（书架的一张 skill 卡 / 首页的一张入口卡）。
///
/// `sub` 是卡里那行小字（子页数 / 说明）。整张卡可点 ⇒ 它必须是**一个按钮**（不是"看着像卡的 div"）。
fn card(
  theme : Theme,
  title : String,
  sub : String,
  msg : Msg,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  let p = theme.palette
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Column)
      .align_items(@style.Align::FlexStart)
      .gap(sp1)
      .padding(@style.px(sp4))
      .border_radius(r3)
      .border_width(1.0)
      .border_color(p.line1)
      .background_color(p.surface),
    ),
    on_click=emit(msg),
    [
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_h3).color(p.fg1).font_weight(@style.FontWeight::W600)),
        title,
      ),
      @html.span(
        attrs=attrs(
          @style.Style::new().font_size(fs_aux).line_height_em(lh_aux).color(p.fg2).text_align(@style.TextAlign::Left),
        ),
        sub,
      ),
    ],
  )
}

///|
/// **书架**：全部 skill 的总览（DESIGN §2.4：一级 ≥8 份时它是侧栏之外的总览出口）。
fn shelf_page(theme : Theme, ctx : Ctx, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  let kids_n = {
    let mut n = 0
    for d in ctx.docs {
      n = n + d.kids.length()
    }
    n
  }
  let head = @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column).gap(sp2)),
    [
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_h1).line_height_em(1.2).color(p.fg1).font_weight(@style.FontWeight::W700)),
        "书架",
      ),
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_base).color(p.fg2)),
        "\{ctx.docs.length()} 份 skill、\{kids_n} 个子页 —— 一个目录一个主题。",
      ),
    ],
  )
  let cards : Array[@html.Html] = []
  for i = 0; i < ctx.docs.length(); i = i + 1 {
    let d = ctx.docs[i]
    cards.push(
      card(
        theme,
        d.title,
        "\{d.desc}（\{d.kids.length()} 个子页）",
        Go(1, i, 0),
        emit,
      ),
    )
  }
  @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)),
    [
      head,
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Column)
          .gap(sp3)
          .margin_top(@style.px(sp5)),
        ),
        cards,
      ),
      page_footer(theme, ctx, "本站由 skillpress press 从内容源投影而来，未改动内容源"),
    ],
  )
}

///|
/// **404**：一句人话 + 两个出口（DESIGN §6）。
///
/// ⚠️ 今天它**没有读者的到达路径**：站点还没有 URL 路由（§2.2 的【实现依赖】），
/// 所以它只在"页面键认不出 / `sel` 越界"时由 `view` 兜底渲染。路由到了之后它才是真的一页。
fn notfound_page(theme : Theme, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column).gap(sp3)),
    [
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_h1).line_height_em(1.2).color(p.fg1).font_weight(@style.FontWeight::W700)),
        "没找到这一页",
      ),
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_base).color(p.fg2)),
        "它可能被改名了，或者从来没存在过。",
      ),
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Row)
          .gap(sp3)
          .margin_top(@style.px(sp2)),
        ),
        [
          card(theme, "回首页", "从头看这个站点", Home, emit),
          card(theme, "去书架", "全部 skill 的总览", Shelf, emit),
        ],
      ),
    ],
  )
}
