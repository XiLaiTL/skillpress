// shell/article.mbt —— **文档页骨架**（DESIGN-site.md §6 主题页 / 子页）。
//
// 从上到下就六件（这一份是"一页文档长什么样"的唯一出处）：
//
//     面包屑 → kicker（机器名）→ H1 → 定位句 → 正文块 → 上下页 → 页脚
//
// ## 三条规矩
//
// 1. **界面上的名字一律中文 `title`**；机器名（`slug` / `name` / 源文件路径）只准出现在
//    **kicker、面包屑末位、页脚**这三处（§2.3"四处"里属于正文的那三处）。
//    ⇒ 面包屑前面几级是中文，**末位才是机器名**（mono、`--fg-3`）。
// 2. **不画点了没反应的东西**：首页 / 上一页 / 下一页每一格都真的发 `Msg`（`Top(-1)` / `Go(...)`）；
//    算不出上一页就**不画那一格**（画一个灰箭头 = 假控件，§1 反面验收）。
// 3. **拿不到的东西不编**：许可 / 生成时间 / 内容根指纹在契约（`Ctx`）里没有 ⇒ 页脚只写源文件路径
//    （它可以从 `slug` / `name` 推出来），其余留一行注释标明"契约待补"（§5 页脚那一行）。

///|
/// 渲染一页文档要的全部东西（**从 `sel` + `docs` 现算**，不依赖渲染期的别处状态）。
///
/// ⚠️ 以前这个形状叫 `Page` / `page_of`（在 `docs.mbt`），和旧的 `pane` 绑在一起。
///    现在它跟着新骨架走，并且多带了 `slug` / `kid_name` / `src` —— 机器名只在这三处用。
priv struct PageView {
  title : String
  desc : String
  when : String
  blocks : Array[Block]
  slug : String      // 所属 skill 的目录名（kicker / 页脚用）
  kid_kind : String  // "" = 主题页；否则 "ref" / "script"
  kid_name : String  // "" = 主题页
}

///| 当前选中的那一页（`sel` 认不出来时给一个空的 —— 上层会画 404，不在这里崩）。
fn page_view(sel : Sel, docs : Array[Doc]) -> PageView {
  let empty : PageView = {
    title: "",
    desc: "",
    when: "",
    blocks: ([] : Array[Block]),
    slug: "",
    kid_kind: "",
    kid_name: "",
  }
  if sel.i < 0 || sel.i >= docs.length() {
    return empty
  }
  let d = docs[sel.i]
  if sel.kind == 2 && sel.k >= 0 && sel.k < d.kids.length() {
    let kid = d.kids[sel.k]
    {
      title: kid.title,
      desc: kid.desc,
      when: "",
      blocks: kid.blocks,
      slug: d.slug,
      kid_kind: kid.kind,
      kid_name: kid.name,
    }
  } else {
    { title: d.title, desc: d.full_desc, when: d.when, blocks: d.blocks, slug: d.slug, kid_kind: "", kid_name: "" }
  }
}

///|
/// 这一页的**源文件路径**（页脚与面包屑末位用）。
///
/// 从 `slug` / `kid_kind` / `kid_name` 推：主题页 = `skills/<slug>/SKILL.md`，
/// 子页 = `skills/<slug>/references/<name>.md`（脚本则是 `scripts/<name>`）。
/// ⚠️ 这是**约定**而不是契约里带来的值 —— 生成期若改了布局（比如加一层目录），这里要跟着改。
fn src_path(pv : PageView) -> String {
  if pv.kid_name == "" {
    "skills/" + pv.slug + "/SKILL.md"
  } else if pv.kid_kind == "script" {
    "skills/" + pv.slug + "/scripts/" + pv.kid_name
  } else {
    "skills/" + pv.slug + "/references/" + pv.kid_name + ".md"
  }
}

///| 页面键的扁平序（给上下页用）：一份 skill 先它自己，再它的每个子页 —— 与侧栏树的顺序一致。
fn flat_pages(docs : Array[Doc]) -> Array[(Int, Int, Int)] {
  let out : Array[(Int, Int, Int)] = []
  for i = 0; i < docs.length(); i = i + 1 {
    out.push((1, i, 0))
    for k = 0; k < docs[i].kids.length(); k = k + 1 {
      out.push((2, i, k))
    }
  }
  out
}

///| 扁平序里第 `t` 项显示什么名字（中文 title）。
fn flat_title(docs : Array[Doc], t : (Int, Int, Int)) -> String {
  let (kind, i, k) = t
  if i < 0 || i >= docs.length() {
    return ""
  }
  if kind == 2 && k >= 0 && k < docs[i].kids.length() {
    docs[i].kids[k].title
  } else {
    docs[i].title
  }
}

///| 面包屑上的一格：可点的（有 `msg`）与不可点的（当前那一级）。
fn crumb_item(
  theme : Theme,
  label : String,
  mono_font : Bool,
  clickable : Bool,
  msg : Msg?,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  let p = theme.palette
  let st = @style.Style::new()
    .font_size(if mono_font { fs_meta } else { fs_aux })
    .line_height_em(lh_aux)
    .color(if clickable { p.fg2 } else { p.fg3 })
  let st = if mono_font { st.font_family(mono) } else { st }
  // ⚠️ 可点的那几格必须是 `@html.button`（→ `Pressable`）：`div` 上的 `on_click` 在 web 上
  //    是**死处理器**（事件默认映射成 `onPress`，只有 Pressable 接得住）—— 见 sidebar.mbt 的账。
  match msg {
    Some(m) =>
      @html.button(
        attrs=attrs(
          @style.Style::new()
          .padding(@style.px(0.0))
          .align_items(@style.Align::FlexStart)
          .background_color("transparent"),
        ),
        on_click=emit(m),
        [@html.div(attrs=attrs(st), label)],
      )
    None => @html.div(attrs=attrs(st), label)
  }
}

///| 分隔符（`/`、`·`）—— 纯装饰，用 `--fg-3`（§3.2 给装饰留的那一格）。
fn crumb_sep(theme : Theme, s : String) -> @html.Html {
  @html.span(
    attrs=attrs(@style.Style::new().font_size(fs_aux).line_height_em(lh_aux).color(theme.palette.fg3)),
    s,
  )
}

///|
/// 面包屑：`首页 / [skill 中文名] / [子页中文名] · 机器名`。
///
/// 末位那条机器名（源文件路径）是**给 Agent 与 URL 用的**，所以允许它单独 mono + `fg-3`。
fn crumb(theme : Theme, ctx : Ctx, model : Model, pv : PageView, emit : @cmd.Emit[Msg]) -> @html.Html {
  let d = ctx.docs[model.sel.i]
  let kids : Array[@html.Html] = []
  // 首页：真的回得去（`Msg::Home` 走的是新 IA 的首页门户）
  kids.push(crumb_item(theme, "首页", false, true, Some(Home), emit))
  kids.push(crumb_sep(theme, "/"))
  if pv.kid_name == "" {
    kids.push(crumb_item(theme, pv.title, false, false, None, emit))
  } else {
    kids.push(crumb_item(theme, d.title, false, true, Some(Go(1, model.sel.i, 0)), emit))
    kids.push(crumb_sep(theme, "/"))
    kids.push(crumb_item(theme, pv.title, false, false, None, emit))
  }
  kids.push(crumb_sep(theme, "·"))
  kids.push(crumb_item(theme, src_path(pv), true, false, None, emit))
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::Center)
      .gap(sp2)
      .margin_bottom(@style.px(sp3)),
    ),
    kids,
  )
}

///| 上下页的一格。`None` = 这一头没有页 ⇒ 上层**不画**（别画一个点了没反应的箭头）。
fn pager_cell(
  theme : Theme,
  label : String,
  title : String,
  msg : Msg,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  let p = theme.palette
  // 同样是 `button`（Pressable）——上下页要**真的能切页**，不能是个画出来的箭头
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .flex(1.0)
      .min_width(@style.px(0.0))
      .align_items(@style.Align::FlexStart)
      .padding(@style.px(sp4))
      .border_width(1.0)
      .border_color(p.line1)
      .border_radius(r3)
      .background_color(p.surface),
    ),
    on_click=emit(msg),
    [
      @html.div(attrs=attrs(@style.Style::new().font_size(fs_meta).color(p.fg3)), label),
      @html.div(
        attrs=attrs(
          @style.Style::new().font_size(fs_sm).line_height_em(lh_tight).color(p.fg1)
          .font_weight(@style.FontWeight::W600),
        ),
        title,
      ),
    ],
  )
}

///|
/// 正文那一栏（文档页）。
///
/// ⚠️ **不是滚动容器**：滚动由 `layout.column` 给（三栏各自滚，见 `layout.mbt` 的文件头）。
///    这一份只画内容。
fn article(theme : Theme, ctx : Ctx, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  // 空内容兜底（内容根为空时引擎会退 2，但界面也得有个画面 —— DESIGN §6 的"空态"）
  if ctx.docs.length() == 0 || model.sel.i < 0 || model.sel.i >= ctx.docs.length() {
    return @html.div(
      attrs=attrs(@style.Style::new().font_size(fs_base).line_height_em(lh_base).color(p.fg2)),
      "这个站点还没有内容。",
    )
  }
  let pv = page_view(model.sel, ctx.docs)
  let head : Array[@html.Html] = []
  head.push(crumb(theme, ctx, model, pv, emit))
  // kicker：机器名（`slug`，子页再带上 ref / script）—— mono、小字、`fg-3`
  head.push(
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .font_family(mono)
        .font_size(fs_meta)
        .line_height_em(lh_aux)
        .color(p.fg3)
        .margin_bottom(@style.px(sp2)),
      ),
      if pv.kid_name == "" { pv.slug } else { pv.slug + " · " + pv.kid_kind },
    ),
  )
  // H1：这一页的名字（中文 title，**不是** slug）
  head.push(
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .font_size(fs_h1)
        .line_height_em(1.2)
        .letter_spacing_em(-0.02)
        .color(p.fg1)
        .font_weight(@style.FontWeight::W700)
        .margin_bottom(@style.px(sp3)),
      ),
      pv.title,
    ),
  )
  if pv.desc != "" {
    head.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_h3)
          .line_height_em(1.65)
          .color(p.fg2)
          .margin_bottom(@style.px(sp5)),
        ),
        pv.desc,
      ),
    )
  }
  // skill 的"何时用它"—— 契约里有这个值，丢了就等于把内容藏起来。
  // ⚠️ DESIGN §6 的页面模板没有列它（模板里只有 kicker / H1 / 定位句 / 正文块 / 上下页 / 页脚）
  //    ⇒ 这里按"次级面的一小块说明"画，**与设计文档的口径差一条，报给上游定夺**。
  if pv.when != "" {
    head.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .background_color(p.surface2)
          .border_radius(r3)
          .padding(@style.px(sp4))
          .margin_bottom(@style.px(sp5)),
        ),
        [
          @html.div(
            attrs=attrs(
              @style.Style::new().font_size(fs_sm).line_height_em(lh_aux).color(p.fg2),
            ),
            "何时用它 —— " + pv.when,
          ),
        ],
      ),
    )
  }
  let tail : Array[@html.Html] = []
  // ── 上下页：真能切页；没有那一头就不画 ──
  let flat = flat_pages(ctx.docs)
  let cur : (Int, Int, Int) = if pv.kid_name == "" {
    (1, model.sel.i, 0)
  } else {
    (2, model.sel.i, model.sel.k)
  }
  let mut idx = -1
  for t = 0; t < flat.length(); t = t + 1 {
    if flat[t] == cur {
      idx = t
    }
  }
  if idx >= 0 {
    let cells : Array[@html.Html] = []
    if idx > 0 {
      cells.push(pager_cell(theme, "上一页", flat_title(ctx.docs, flat[idx - 1]), msg_of(flat[idx - 1]), emit))
    }
    if idx + 1 < flat.length() {
      cells.push(pager_cell(theme, "下一页", flat_title(ctx.docs, flat[idx + 1]), msg_of(flat[idx + 1]), emit))
    }
    if cells.length() > 0 {
      tail.push(
        @html.div(
          attrs=attrs(
            @style.Style::new()
            .flex_direction(@style.FlexDirection::Row)
            .gap(sp3)
            .margin_top(@style.px(sp7)),
          ),
          cells,
        ),
      )
    }
  }
  // ── 页脚（DESIGN §5）：**出处 · 许可 · 构建时间 · 内容根指纹**。
  //    主文本是源文件路径（真拿得到），其余三样由 `footer_line` 拼 —— 拿不到的**那一项不画**，
  //    不写"许可 —"这种占位（§1 反面验收）。三样的真源与空值语义见 `shell/types.mbt` 的 `Footer`。
  tail.push(
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
          footer_line(ctx, "源文件 " + src_path(pv)),
        ),
      ],
    ),
  )
  // ⚠️ 根上挂一个**页专属**的节点名（`page-<kind>-<i>-<k>`）：跨页跳锚点要靠它。
  //    为什么不能用锚点本身（`sec-<i>`）来判断"新页面渲染好了没有"：**锚点 id 每页都一样**
  //    （第 1 节在每一页都叫 `sec-0`）⇒ 切页那一瞬间它**在旧页面上也存在**，
  //    于是"等它出现"会等到旧页面的同号节点，滚动发生在旧内容上（看起来像"跳错一节"，且是静默的）。
  //    页专属的名字在**新页面挂上之前**一定不存在 ⇒ 只有它才能当"渲染好了"的信号。
  @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)),
    [@html.div(attrs=attrs(@style.Style::new()), head), blocks_view(theme, pv.blocks, model.copied_at, ctx, emit), @html.div(attrs=attrs(@style.Style::new()), tail)],
  )
}

///| 扁平序里的一项 → 切页消息（kind 1 = 主题页，2 = 子页）。
fn msg_of(t : (Int, Int, Int)) -> Msg {
  let (kind, i, k) = t
  Go(kind, i, k)
}
