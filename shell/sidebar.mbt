// shell/sidebar.mbt —— 侧栏树（DESIGN-site.md §4.1.1 的"行语言"，五条）。
//
// ## 行语言（这一节是照着原型改出来的，不是随手配的）
//
// 1. **一行一个链接**：中文 `title`，单行不换行（换行 ⇒ 行高参差 ⇒ 一列毛边）
// 2. **机器名不进侧栏**：slug 只在 kicker / 面包屑末位 / Agent 面板 / URL 四处（§2.3）
// 3. **层级靠缩进 + 引导线，不靠符号**：雪佛龙列 12px，1px 引导线落在雪佛龙**轴心**（= 12+6 = 18px），
//    **二级标题与一级标题同一列**（对齐的竖边比"多缩一点"更整齐）
// 4. **状态只有一条通道**：行左侧 2px 圆头条 —— 当前项 = 靛紫（hover 那条今天还画不出来：moobile 的
//    真 `:hover` 是乙级能力，`press:` 的消费侧也还没接，见 PLAN-ui §3.1）
// 5. **本页目录是树的第三级，挂在"正在读的那个文件"下面**（见 toc.mbt 的文件头）
//
// ## ⚠️ 左条为什么是**子节点**而不是 `::before`
//
// moobile 的样式子集里没有伪元素（`style.mbt` 原文："`::before` 这些根本没有构造器"）。
// 所以状态条是一个**绝对定位的子 div**（`position: absolute` + `left/top/bottom` 都在子集里）。

///| 一行的形状：缩进 + 有没有雪佛龙 + 标题 + 是不是当前项。
priv struct RowOpts {
  label : String
  indent : Double
  chevron : Bool
  open : Bool
  current : Bool
}

///| 一级 / 二级 / 三级行共用的那一行（左条 + 雪佛龙位 + 标题）。
///
/// ## ⚠️ 为什么雪佛龙与标题都是「按钮」而不是挂了 `on_click` 的 `div`（实测的坑）
///
/// moobile 的事件默认映射是 **`click` → `onPress`**（`render.mbt` 的 `default_event_prop`），
/// 而 **`onPress` 只有 `Pressable` 接得住**；标签表里 `div` → `View`、`span` → `Text`
/// ⇒ **挂在 `div` 上的 `.on_click` 在 web 上是个死处理器**（点了没反应，编译器不报、控制台不报）。
/// 只有 `button`（→ `Pressable`）与 `a`（→ `Pressable`）能点。这条是本轮实测出来的，
/// 与"RNW 上 View 认 `onClick`"那种直觉正好相反 —— 别改回 `div`。
///
/// 雪佛龙与标题是**兄弟**（不嵌套）：雪佛龙只展开/收起、标题才跳页（§4.1.1）。
/// 嵌套在 web 上会冒泡（点箭头既展开又跳页），而 RN 上不冒泡 ⇒ 两端口径不一致，从结构上避开。
fn side_row(
  theme : Theme,
  o : RowOpts,
  toggle : Msg?,
  go : Msg,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  let p = theme.palette
  // 标题文字：中文 `title`，单行不换行（换行 ⇒ 行高参差，§4.1.1 第 1 条）
  let title_text = @html.div(
    attrs=attrs(
      @style.Style::new()
      .font_size(fs_sm)
      .line_height_em(lh_tight)
      .white_space(@style.WhiteSpace::NoWrap)
      .overflow(@style.Overflow::Hidden)
      .color(if o.current { p.brand } else { p.fg2 })
      .font_weight(if o.current { @style.FontWeight::W600 } else { @style.FontWeight::W400 }),
    ),
    o.label,
  )
  // 标题那一格：可点 = 跳页（`@html.button` ⇒ Pressable）
  let title = @html.button(
    attrs=attrs(
      @style.Style::new()
      .flex(1.0)
      .min_width(@style.px(0.0))
      .align_items(@style.Align::FlexStart)
      .padding(@style.px(0.0))
      .background_color("transparent"),
    ),
    on_click=emit(go),
    [title_text],
  )
  // 雪佛龙那一格：可点 = 只展开/收起
  let chev_inner = @html.div(
    attrs=attrs(
      @style.Style::new()
      .font_size(fs_aux)
      .line_height_em(lh_tight)
      .color(p.fg2),
    ),
    if o.open { "▾" } else { "▸" },
  )
  let chev : @html.Html = if o.chevron {
    @html.button(
      attrs=attrs(
        @style.Style::new()
        .width(@style.px(12.0))
        .align_items(@style.Align::Center)
        .justify_content(@style.Justify::Center)
        .padding(@style.px(0.0))
        .background_color("transparent"),
      ),
      on_click=match toggle {
        Some(m) => emit(m)
        None => @cmd.none
      },
      [chev_inner],
    )
  } else {
    // 没有雪佛龙的行也要占住那一格，否则标题会跟上一级错开（§4.1.1 第 3 条：同一列）
    @html.div(attrs=attrs(@style.Style::new().width(@style.px(12.0))), ([] : Array[@html.Html]))
  }
  // 左条：绝对定位、上下各留 8px、2px 宽、圆头（状态通道，见文件头第 4 条）
  let bar = @html.div(
    attrs=attrs(
      @style.Style::new()
      .position(@style.Position::Absolute)
      .left(@style.px(0.0))
      .top(@style.px(sp2))
      .bottom(@style.px(sp2))
      .width(@style.px(2.0))
      .border_radius(r1)
      .background_color(if o.current { p.brand } else { "transparent" }),
    ),
    ([] : Array[@html.Html]),
  )
  let line_style = @style.Style::new()
    .position(@style.Position::Relative)
    .flex_direction(@style.FlexDirection::Row)
    .align_items(@style.Align::Center)
    .gap(sp1)
    .padding_left(@style.px(o.indent))
    .padding_right(@style.px(sp3))
    .padding_vertical(@style.px(sp2))
    .border_radius(r2)
    .background_color(if o.current { p.brand_soft } else { "transparent" })
  @html.div(attrs=attrs(line_style), [bar, chev, title])
}

///|
/// 侧栏：`Skill 书架 · N 份` 分组 + 树 + （rail < 3 时）挂在当前文件节点下面的**本页目录** + 页脚。
///
/// `toc` / `mount_toc`：目录的入口。`mount_toc = false`（rail 3）时目录在右栏，树里不放。
fn sidebar(
  theme : Theme,
  ctx : Ctx,
  model : Model,
  emit : @cmd.Emit[Msg],
  toc : Array[TocEntry],
  mount_toc : Bool,
) -> @html.Html {
  let p = theme.palette
  let docs = ctx.docs
  let items : Array[@html.Html] = []
  let mut hung = false          // 目录有没有挂到"当前那个文件"下面
  let n = docs.length()
  for i = 0; i < n; i = i + 1 {
    let d = docs[i]
    let here = model.sel.i == i
    let is_self = here && model.sel.kind == 1
    let open = if i < model.open.length() { model.open[i] } else { false }
    items.push(
      side_row(
        theme,
        { label: d.title, indent: sp3, chevron: d.kids.length() > 0, open, current: is_self },
        Some(Toggle(i)),
        Go(1, i, 0),
        emit,
      ),
    )
    if open {
      let kids : Array[@html.Html] = []
      let m = d.kids.length()
      for k = 0; k < m; k = k + 1 {
        let kid = d.kids[k]
        let self = here && model.sel.kind == 2 && model.sel.k == k
        kids.push(
          side_row(
            theme,
            { label: kid.title, indent: sp3 + sp4, chevron: false, open: false, current: self },
            None,
            Go(2, i, k),
            emit,
          ),
        )
        // ★ 目录就挂在**这一条**下面（用户拍定：不是塞到侧栏底部）
        if self && mount_toc {
          hung = true
          kids.push(toc_tree_mount(theme, toc, emit, model.active))
        }
      }
      items.push(
        @html.div(
          attrs=attrs(
            @style.Style::new()
            .padding_left(@style.px(sp3 + 6.0))
            .border_left_width(1.0)
            .border_left_color(p.line1)
            .margin_bottom(@style.px(sp2)),
          ),
          kids,
        ),
      )
      // 主题页（不是子页）⇒ 目录挂在它那棵子树的最下面
      if is_self && mount_toc {
        hung = true
        items.push(toc_tree_mount(theme, toc, emit, model.active))
      }
    }
  }
  // 兜底：树里没有对应节点的页面（首页 / 书架 / llms / 404）⇒ 挂在树末，带一条分隔线。
  // 这一条是**有意的**：目录总得有个地方待着，而"没有对应文件"不等于"没有目录"。
  if mount_toc && !hung {
    items.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .margin_top(@style.px(sp3))
          .padding_top(@style.px(sp3))
          .border_top_width(1.0)
          .border_top_color(p.line1),
        ),
        [toc_tree_mount(theme, toc, emit, model.active)],
      ),
    )
  }
  let head = @html.div(
    attrs=attrs(
      @style.Style::new()
      .font_size(fs_aux)
      .font_weight(@style.FontWeight::W600)
      .color(p.fg2)
      .padding_left(@style.px(sp3))
      .padding_bottom(@style.px(sp2)),
    ),
    "Skill 书架 · \{n} 份",
  )
  let foot = @html.div(
    attrs=attrs(
      @style.Style::new()
      .margin_top(@style.px(sp4))
      .padding_top(@style.px(sp3))
      .padding_left(@style.px(sp3))
      .border_top_width(1.0)
      .border_top_color(p.line1)
      .font_size(fs_aux)
      .color(p.fg2),
    ),
    "全部 \{n} 份 →",
  )
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Column)
      .padding_top(@style.px(sp6))
      .padding_horizontal(@style.px(sp3))
      .padding_bottom(@style.px(sp7)),
    ),
    [head, @html.div(attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)), items), foot],
  )
}
