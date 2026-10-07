// shell/mobile.mbt —— **窄屏入口**：三个贴边按钮 + 两级交互 + 下往上 sheet（DESIGN-site.md §4.3）。
//
// ## 它补的是哪一笔欠账
//
// rail 1（<1024）今天**进不去文档区**：侧栏整栏不画、顶栏只负责回首页/切页面，而"进文档区"的唯一入口
// 本来是侧栏那条 ⇒ 窄屏没有门。这个文件就是那扇门（内环探针里那条 rail-1 跳过也随它一起删掉）。
//
// ## 两级交互（照 §4.3 与用户口述）
//
//     平时**贴边停靠**（半藏） → 第一次点：**浮出**（离开边缘） → 第二次点：**弹 sheet**
//     三个 sheet **互斥**；点遮罩 / Esc 关；开着的那一个按钮高亮。
//
// ## ⚠️ 三条能力边界（今天做不到的，如实写在这儿，不悄悄糊）
//
// 1. **没有 `position: fixed`**（`style.mbt` 只有 `Relative` / `Absolute`）。
//    但**根容器不滚**（三栏各自滚，见 layout.mbt）⇒ 绝对定位挂在根上**等价于 fixed**。
//    所以这一层必须渲染在**根**里（`layout.shell` 的最后一个孩子），不能塞进某一栏。
// 2. ✅ **`transform` 已经补上了**（2026-10-07，moobile 的甲级三样收尾）⇒ "浮出"不再靠**负偏移**，
//    而是"布局位置固定 + `Translate(x)` 位移"：
//    · **为什么这件事要做**：负偏移会**把横向滚动宽撑出去**（内环实测 768px 下溢出 22px）——
//      以前只能靠根上的 `overflow: Hidden` 裁掉它（`layout.mbt` 那条注释就是这笔账）；
//      而**位移不参与布局** ⇒ 撑不出去，根那条裁剪也就不再是"为了这个"。
//    · **仍然没有 `transition`**（乙级，D-UI-4 明确不做）⇒ "浮出"依旧是**硬切**，没有动画。
//      这一条仍记在 §4.3 的【实现依赖】里 —— 别把"用了 transform"读成"有过渡动画了"。
// 3. ⚠️ sheet 的高度上限写的是 `max_height: 70%` —— **web 上验过**（内环读到面板高 530px / 视口 900），
//    **原生（RN）上没验**：那里 `%` 是按父容器还是按屏幕算，今天没有读数。别当它验过。
//
// 4. **没有 portal、没有 `pointerEvents`** ⇒ 不能拿一整块全屏 div 当容器（那块 div 会把正文的点击全吃掉）。
//    所以这一层是**若干各自定位的小块**（`@html.fragment`），且遮罩**只在 sheet 开着时才画** ——
//    关着的时候页面上一个多余的可点区域都没有。

///| 一行"菜单行"（sheet 里用）：整行可点，点完由 `update` 顺手关掉 sheet。
fn menu_row(
  theme : Theme,
  label : String,
  msg : Msg,
  emit : @cmd.Emit[Msg],
  big : Bool,
) -> @html.Html {
  let p = theme.palette
  // ⚠️ 可点的一律 `@html.button`：**`div` 上的 `.on_click` 在 web 上是死处理器**
  //    （点了没反应、编译器不报、控制台不报 —— 这个坑 `sidebar.mbt` 的文件头记过，我在这里又踩了一次）。
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .padding_vertical(@style.px(if big { sp3 } else { sp2 }))
      .padding_horizontal(@style.px(sp3))
      .border_radius(r2)
      .border_width(0.0)
      .background_color(if big { p.surface2 } else { "transparent" })
      .color(if big { p.fg1 } else { p.fg2 })
      .font_size(fs_sm)
      .line_height_em(lh_aux)
      .text_align(@style.TextAlign::Left),
    ),
    on_click=emit(msg),
    label,
  )
}

///| 贴边按钮：`edge` = `0` 左 / `1` 右；`slot` = `0` 上 / `1` 下（导航在左上，另外两个在下边）。
fn fab(
  theme : Theme,
  model : Model,
  emit : @cmd.Emit[Msg],
  idx : Int,
  label : String,
  edge : Int,
  slot : Int,
) -> @html.Html {
  let p = theme.palette
  let open = model.sheet == idx
  // 两级：贴边（半藏，**位移 -22px**）→ 浮出（**位移 +12px**）。
  // ⚠️ 位移走 `transform`（不参与布局）而不是 `left/right` 的负偏移 —— 见文件头第 2 条：
  //    负偏移会把横向滚动宽撑出去（实测 768px 下溢出 22px），以前只能靠根上 `overflow: Hidden` 裁。
  //    硬切 —— **仍然没有 transition**（乙级能力，见文件头）。
  let off = if model.peek == 1 { sp3 } else { -22.0 }
  let mut s = @style.Style::new()
    .position(@style.Position::Absolute)
    .padding_vertical(@style.px(sp2))
    .padding_horizontal(@style.px(sp3))
    .border_radius(r4)
    .border_width(1.0)
    .border_color(if open { p.brand } else { p.line2 })
    .background_color(if open { p.brand } else { p.overlay })
    .color(if open { p.on_brand } else { p.fg2 })
    .font_size(fs_aux)
    .line_height_em(lh_aux)
  if slot == 0 {
    s = s.top(@style.px(h_top + sp3))
  } else {
    s = s.bottom(@style.px(sp4))
  }
  // 布局位置钉在贴边（0），"半藏在外面/浮出来"全交给位移。
  // ⚠️ 左右两侧的**符号相反**：左侧要往外 = x 为负；右侧要往外 = x 为正。
  if edge == 0 {
    s = s.left(@style.px(0.0)).transform([@style.Transform::Translate(off, 0.0)])
  } else {
    s = s.right_(@style.px(0.0)).transform([@style.Transform::Translate(-off, 0.0)])
  }
  // 同上：按钮，不是挂了 on_click 的 div
  @html.button(attrs=attrs(s), on_click=emit(Tap(idx)), label)
}

///| sheet 的标题行（抓手的横条 + 标题）。
fn sheet_head(theme : Theme, title : String) -> @html.Html {
  let p = theme.palette
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Column)
      .align_items(@style.Align::Center)
      .margin_bottom(@style.px(sp2)),
    ),
    [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .width(@style.px(36.0))
          .height(@style.px(4.0))
          .border_radius(r1)
          .background_color(p.line2)
          .margin_bottom(@style.px(sp3)),
        ),
        ([] : Array[@html.Html]),
      ),
      @html.div(
        attrs=attrs(
          @style.Style::new().font_size(fs_h3).font_weight(@style.FontWeight::W600).color(p.fg1),
        ),
        title,
      ),
    ],
  )
}

///| sheet 的内容：`0` 导航 / `1` 书架 / `2` 目录。
fn sheet_body(
  theme : Theme,
  ctx : Ctx,
  model : Model,
  emit : @cmd.Emit[Msg],
  toc : Array[TocEntry],
  which : Int,
) -> @html.Html {
  if which == 1 {
    // 书架 = 侧栏那棵树（同一份渲染，导轨不出现在窄屏的 sheet 里）
    sidebar(theme, ctx, model, emit, toc, true)
  } else if which == 2 {
    // 目录 = 树里那一段（同一份渲染）
    toc_tree_mount(theme, toc, emit, model.active)
  } else {
    let rows : Array[@html.Html] = []
    // 一级导航（就是顶栏那排 —— 窄屏时它进了这里）
    for pair in nav_items(ctx) {
      let (label, msg) = pair
      rows.push(menu_row(theme, label, msg, emit, true))
    }
    rows.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_aux)
          .font_weight(@style.FontWeight::W600)
          .color(theme.palette.fg2)
          .margin_top(@style.px(sp3))
          .margin_bottom(@style.px(sp1))
          .padding_horizontal(@style.px(sp3)),
        ),
        "栏目",
      ),
    )
    // 栏目 = 全部 skill（中文 title；机器名不进界面，§2.3）
    for i = 0; i < ctx.docs.length(); i = i + 1 {
      rows.push(menu_row(theme, ctx.docs[i].title, Go(1, i, 0), emit, false))
    }
    @html.div(
      attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)),
      rows,
    )
  }
}

///|
/// 窄屏那一层：**遮罩 + sheet + 三个贴边按钮**（各自的绝对定位小块，见文件头第 3 条）。
///
/// 挂在**根**里（`layout.shell` 的最后一个孩子）—— 根不滚，所以它等价于 fixed。
fn mobile_layer(
  theme : Theme,
  ctx : Ctx,
  model : Model,
  emit : @cmd.Emit[Msg],
  toc : Array[TocEntry],
) -> Array[@html.Html] {
  let p = theme.palette
  let parts : Array[@html.Html] = []
  if model.sheet >= 0 {
    // ① 遮罩：只在开着时画（关着时画一块全屏 div 会把正文的点击全吃掉 —— 没有 pointerEvents）
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
        on_click=emit(CloseSheet),
        ([] : Array[@html.Html]),
      ),
    )
    // ② sheet：贴底、下往上（**硬切**：今天没有 transition —— §4.3 的【实现依赖】）
    let title = if model.sheet == 0 { "导航" } else if model.sheet == 1 { "书架" } else { "本页目录" }
    parts.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .position(@style.Position::Absolute)
          .left(@style.px(0.0))
          .right_(@style.px(0.0))
          .bottom(@style.px(0.0))
          .max_height(@style.pct(70.0))
          .overflow(@style.Overflow::Scroll)
          .background_color(p.overlay)
          .border_top_width(1.0)
          .border_top_color(p.line2)
          .border_top_left_radius(r4)
          .border_top_right_radius(r4)
          .padding_top(@style.px(sp3))
          .padding_bottom(@style.px(sp6))
          .padding_horizontal(@style.px(sp4)),
        ),
        [
          sheet_head(theme, title),
          sheet_body(theme, ctx, model, emit, toc, model.sheet),
        ],
      ),
    )
  }
  // ③ 三个贴边按钮（导航在左上，书架/目录在下边两侧 —— §4.3 那张表）
  parts.push(fab(theme, model, emit, 0, "≡ 导航", 0, 0))
  parts.push(fab(theme, model, emit, 1, "▤ 书架", 0, 1))
  parts.push(fab(theme, model, emit, 2, "☰ 目录", 1, 1))
  // ⚠️ 这里是 **若干兄弟节点**、不是 `@html.fragment([...])`：实测 fragment 这一层**没渲出来**
  //    （页面上一个贴边按钮都没有，而 JS 报错是 0 —— 静默丢节点）。根里多几个绝对定位的孩子，
  //    形状上更直白，也就不用赌某个容器节点被不被支持。
  parts
}
