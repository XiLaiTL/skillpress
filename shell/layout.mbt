// shell/layout.mbt —— 三栏骨架与**阶梯**（DESIGN-site.md §4.1 / §4.2）。
//
// ## 阶梯为什么必须走 Model（而不是媒体查询）
//
// moobile 的样式子集是**故意封闭**的：没有媒体查询、没有 sticky、没有 transform
// （`style/style.mbt` 原文："属性集是封闭的 —— `display:grid`、`position:sticky`、
// `::before` 这些根本没有构造器"）。所以"窄屏收侧栏"这件事**没有 CSS 写法**，
// 唯一的表达是：**视口宽度进 Model ⇒ 渲染时按它分支**。
//
//     vw 来自 `@sub.current_viewport()`（初次读一次）+ `@sub.on_resize`（变了推一次）
//
// 三档（判据是"目录往哪让"）：
//
//     rail 3  ≥1280        三栏：侧栏 272 / 正文 720 / 目录轨 220
//     rail 2  1024–1279    两栏：侧栏（书架树 **+ 本页目录挂在当前文件节点下**）/ 正文
//     rail 1  <1024        一栏 + 三个贴边按钮（侧栏与目录进 sheet）
//
// ## 三个滚动容器，不是 sticky
//
// 根是**定高**的弹性列（顶栏 56 + 余下），余下那一行里三栏各自 `overflow: scroll`
// ⇒ 侧栏/目录各自滚自己的，正文滚自己的，**顶栏不动**。
// 这条能把 PLAN-ui §10.2 那个"实际滚的是整个 document、顶栏跟着走"的根问题一并解掉。

///| 三档里的哪一档。`1` = 最窄（一栏）。
pub fn rail_of(vw : Double) -> Int {
  let w = vw
  if w >= w_rail3 {
    3
  } else if w >= w_rail2 {
    2
  } else {
    1
  }
}

///| 顶栏那一排排不排得下（<700 时导航进 sheet、搜索收成图标 —— 实测那一排会溢出 55px）。
pub fn top_compact(vw : Double) -> Bool {
  vw < w_narrow
}

///|
/// 一栏的外壳：定宽（或弹性）、满高、**自己滚**。
///
/// `border_side`：`0` 不要边、`1` 右边一条（侧栏）、`2` 左边一条（目录轨）。
fn column(
  theme : Theme,
  width : Double?,
  bg : String,
  border_side : Int,
  children : Array[@html.Html],
  id : String?,
) -> @html.Html {
  let mut s = @style.Style::new()
    .flex_direction(@style.FlexDirection::Column)
    .min_height(@style.px(0.0))
    .overflow(@style.Overflow::Scroll)
    .background_color(bg)
  match width {
    Some(w) => s = s.width(@style.px(w)).flex_shrink(0.0)
    None => s = s.flex(1.0).min_width(@style.px(0.0))
  }
  if border_side == 1 {
    s = s.border_right_width(1.0).border_right_color(theme.palette.line1)
  }
  if border_side == 2 {
    s = s.border_left_width(1.0).border_left_color(theme.palette.line1)
  }
  // 节点名（`Attrs::id`）：**跟读高亮**要订阅"内容区这个滚动容器"的滚动，
  // 而订阅与测量都按名字找节点（moobile 的节点寻址，见 `sub/node.mbt`）。
  // 只给**内容栏**（`border_side == 0` 那一栏）名字：侧栏/目录轨今天没人订阅。
  let a = match id {
    Some(n) => attrs(s).id(n)
    None => attrs(s)
  }
  @html.div(attrs=a, children)
}

///|
/// 站点外壳：**顶栏 + 三栏行**。
///
/// `side` / `toc` 给 `None` = 这一档不放它（rail 1 的侧栏、rail <3 的目录轨）——
/// 阶梯就是这样落在渲染上的：**不是把它藏起来，是根本不画**。
pub fn shell(
  theme : Theme,
  topbar : @html.Html,
  side : @html.Html?,
  main : @html.Html,
  toc : @html.Html?,
  overlay : Array[@html.Html],
) -> @html.Html {
  let p = theme.palette
  let cols : Array[@html.Html] = []
  match side {
    Some(h) => cols.push(column(theme, Some(w_side), p.surface2, 1, [h], None))
    None => ()
  }
  cols.push(column(theme, None, p.canvas, 0, [main], Some(prose_node())))
  match toc {
    Some(h) => cols.push(column(theme, Some(w_toc), p.canvas, 2, [h], None))
    None => ()
  }
  let row = @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex(1.0)
      .min_height(@style.px(0.0))
      .flex_direction(@style.FlexDirection::Row),
    ),
    cols,
  )
  // 根：定高 + 弹性列。**`position: relative` 是必须的** —— 窄屏那一层（贴边按钮 / sheet / 遮罩）
  // 是绝对定位的孩子，锚的就是它；而根**不滚**，所以那一层等价于 fixed（DESIGN §4.3 的
  // "没有 fixed"那条能力边界就是这样绕过去的：绝对定位 + 不滚的根）。
  let kids : Array[@html.Html] = [topbar, row]
  // 窄屏那一层是**若干兄弟**（不是一个大容器）：各块自己绝对定位，就没有"一块全屏 div 吃掉所有点击"的问题。
  for h in overlay {
    kids.push(h)
  }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .position(@style.Position::Relative)
      .height(@style.pct(100.0))
      // ⚠️ `overflow: Hidden` 是**窄屏那一层**要的：贴边按钮"半藏"用的是负偏移
      //    （没有 `transform`，见 mobile.mbt 文件头），而负偏移会把**横向滚动宽**撑出去
      //    （内环实测 768px 下溢出 22px）。根裁掉它，比"把按钮往回收"更接近设计原意。
      .overflow(@style.Overflow::Hidden)
      .flex_direction(@style.FlexDirection::Column)
      .background_color(p.canvas)
      .color(p.fg1),
    ),
    kids,
  )
}

///|
/// 正文那一栏的内层：**居中 + 定宽 720**（≈46 个中文字，A2）。
///
/// ⚠️ 定宽之外还要 `padding`：窄到一栏时正文不能贴屏幕边（DESIGN §3.3 / rail 1 的 16px）。
pub fn prose_wrap(rail : Int, children : Array[@html.Html]) -> @html.Html {
  let pad = if rail == 1 { sp4 } else { sp6 }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .width(@style.pct(100.0))
      .align_items(@style.Align::Center)
      .padding_top(@style.px(sp6))
      .padding_bottom(@style.px(sp7))
      .padding_horizontal(@style.px(pad)),
    ),
    [
      @html.div(
        attrs=attrs(@style.Style::new().width(@style.pct(100.0)).max_width(@style.px(w_prose))),
        children,
      ),
    ],
  )
}
