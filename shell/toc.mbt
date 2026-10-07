// shell/toc.mbt —— **本页目录**（DESIGN-site.md §4.1.1 第 5 条 / §4.2）。
//
// ## 它挂在哪（这条是用户拍定的 IA，不是样式问题）
//
//   rail 3（≥1280）  → 右栏那条**轨**（细线 + 当前段），跟正文一起看
//   rail 2/1（<1280）→ **塞进侧栏、挂在"正在读的那个文件"节点下面**（树的第三级，缩进再进一格）
//
// 三个候选里选第三个的理由（DESIGN §4.2）：挂侧栏底部 = 把"本页目录"提升成和书架平级的栏目（IA 错误）；
// 挂正文顶部 = 把机器的骨架塞进人的阅读流。**目录属于这一页，所以它长在这一页那条下面。**
//
// ## 状态：**可点了**（2026-10-07，等 moobile 那一刀落地之后）
//
// 目录的价值一半在"点一下跳过去"和"跟读高亮"：
//   · **跳**：✅ **已通** —— moobile 补了**节点寻址**（`sub/node.mbt`：`Attrs::id("…")` 写名字，
//     `@sub.scroll_to_node(name, block="start")` 滚过去；真 Chrome 读数见
//     `moobile/examples/apps/node-spike/README.md`）。本文件把目录行做成 `@html.button`
//     （→ RN `Pressable`），点一下发 `TocTo(i)`，`state.mbt` 里转成那条命令。
//   · **高亮**：✅ **2026-10-07 也通了** —— moobile 补了**容器级滚动订阅**（`@sub.on_node_scroll`），
//     本文件只负责"当前是第几节"这件事：
//       **量一遍每节的绝对偏移**（`section_offsets`，`N+1` 次同步 DOM 读）→ 之后滚动时**纯算术**
//       （`active_of`）⇒ 不是每个滚动事件都扫 DOM；只在"跨节 / 换页 / 第一次"时重锚一次。
//     ⚠️ 订阅**装载后会先补一次当前值**（moobile 特意做的，本仓在 `current_viewport` / `current_url`
//     上各栽过一次"订阅不补首帧"）⇒ **首屏就有高亮**，不必等用户先滚一下。
//     读数：`_scratch/toc-click.mjs` 的 ⑤⑥（真 Chrome，看的是**计算样式**：品牌色 + 600 加重；
//     装载后恰好一条高亮在第 0 条、滚到第 4 节后高亮换到第 4 条）。
//
// ⚠️ 锚点口径（**两处必须一致，否则会出现"点第 3 条跳到第 4 节"这种静默错位**）：
//    `heading_anchor(i)` = `"sec-<i>"`，`i` = **第几个 h2/h3**（从 0 数，h4 不算）。
//    目录侧（本文件的 `toc_of`）与正文侧（`blocks.mbt` 的 `blocks_view`）各自数一遍 ——
//    顺序由同一份 `blocks` 决定 ⇒ 必然一致。P3 把锚点挪到生成期之后，这里就该改成读生成物。

///| 目录里的一条：`level` = 2（h2）或 3（h3）。
pub(all) struct TocEntry {
  level : Int
  text : String
}

///|
/// **锚点名**：第 `i` 个 h2/h3 → `"sec-<i>"`（从 0 数）。
///
/// ⚠️ 目录行与正文标题**各自算一遍**这一个函数 —— 它们读的是同一份 `blocks`，
/// 所以顺序必然一致；把它做成一个函数（而不是两处各写一遍字符串拼接）就是为了
/// "改口径时只有一个地方要改"。
pub fn heading_anchor(i : Int) -> String {
  "sec-" + i.to_string()
}

///|
/// **内容区那个滚动容器的节点名**（`shell/layout.mbt` 的 `column(...)` 用的同一个字面量）。
/// 做成函数是为了只有一个地方能改它 —— 名字对不上时症状是"高亮永远不动"。
pub fn prose_node() -> String {
  "prose"
}

///|
/// 量一遍每一节的**绝对偏移**（相对内容区的内容坐标系，单位 px；量不到给 `-1`）。
///
/// 口径：`偏移 = 那一节在视口里的 y − (容器的 y − 容器已滚掉的部分)`。
/// 也就是"把容器滚到顶时，这一节离容器上沿多远"。
///
/// ⚠️ 一次要 `N+1` 次**同步** DOM 读（N 个小节 + 容器本身）⇒ **别在每个滚动事件里调它**：
/// 调用方（`state.mbt`）只在"第一次 / 跨节了 / 换了页"时重锚一次，其余时刻用纯算术。
pub fn section_offsets(pane : String, count : Int) -> Array[Double] {
  let out : Array[Double] = []
  match @sub.node_rect(pane) {
    Some(p) => {
      let scrolled = match @sub.node_scroll_top(pane) {
        Some(v) => v
        None => 0.0
      }
      let base = p.y - scrolled
      for i = 0; i < count; i = i + 1 {
        match @sub.node_rect(heading_anchor(i)) {
          Some(r) => out.push(r.y - base)
          None => out.push(-1.0)
        }
      }
    }
    None => ()
  }
  out
}

///|
/// 由偏移表算"**现在读的是哪一节**"——**纯算术，不碰 DOM**。
///
/// 取"最后一个偏移 ≤ 当前滚动量 + 容差"的那一节。容差 12px 是刻意的：
/// 标题**刚好压到上沿**时就该算它了，否则高亮会"慢一节"（那是最容易被读成功能坏了的形状）。
pub fn active_of(offsets : Array[Double], top : Double) -> Int {
  let mut a = -1
  for i = 0; i < offsets.length(); i = i + 1 {
    if offsets[i] >= 0.0 && offsets[i] <= top + 12.0 {
      a = i
    }
  }
  a
}

///|
/// 目录的**一行** —— 可点。
///
/// ⚠️ 必须是 `@html.button`（→ RN 的 `Pressable`）：实测（站点 M5 那笔账，moobile 的 node-spike
/// 又复现过一次）**挂在 `div` 上的 `on_click` 在 web 上是死处理器** —— `on_click` 在 web 上
/// 映射成 `onPress`（`render.mbt` 的 `default_event_prop`），只有 `Pressable` 接得住。
fn toc_row(
  theme : Theme,
  e : TocEntry,
  i : Int,
  emit : @cmd.Emit[Msg],
  pad_v : Double,
  pad_root : Double,
  pad_sub : Double,
  active : Bool,
) -> @html.Html {
  let p = theme.palette
  let pad = if e.level >= 3 { pad_sub } else { pad_root }
  // **跟读高亮**的语言与侧栏"当前项"同一套：品牌色 + 加重 + 左边一条 2px 条。
  // ⚠️ 左边条用 `border_left` 而不是绝对定位的方块 ⇒ 会**占宽度**，
  //    所以激活时把左内边距减 2px：文字**不许因为高亮而左右跳**。
  let mut s = @style.Style::new()
    .font_size(fs_aux)
    .line_height_em(lh_aux)
    .padding_vertical(@style.px(pad_v))
    .padding_right(@style.px(sp3))
  if active {
    s = s
      .color(p.brand)
      .font_weight(@style.FontWeight::W600)
      .border_left_width(2.0)
      .border_left_color(p.brand)
      .padding_left(@style.px(pad - 2.0))
  } else {
    s = s.color(p.fg2).padding_left(@style.px(pad))
  }
  @html.button(attrs=attrs(s), on_click=emit(TocTo(i)), e.text)
}

///|
/// 从正文块里抽出目录。
///
/// ⚠️ 今天这是**渲染期现算**的（P3 的计划是生成期算、并把锚点 id 一起带出来 —— 见 `PLAN.md` P3）。
///    生成期那条通了之后，这个函数就该退休：目录的层级/文本/锚点是**内容侧**的事实，
///    渲染侧重算一遍等于两处口径（迟早会出现"目录里有、正文里没有"这种静默错位）。
fn toc_of(blocks : Array[Block]) -> Array[TocEntry] {
  let out : Array[TocEntry] = []
  for b in blocks {
    match b {
      H2(spans) => out.push({ level: 2, text: plain(spans) })
      H3(spans) => out.push({ level: 3, text: plain(spans) })
      _ => ()
    }
  }
  out
}

///|
/// 目录在**右栏轨**上的样子：一条细线 + 当前段（DESIGN §4.1 的图）。
pub fn toc_rail(
  theme : Theme,
  entries : Array[TocEntry],
  emit : @cmd.Emit[Msg],
  active : Int,
) -> @html.Html {
  let p = theme.palette
  let head = @html.div(
    attrs=attrs(
      @style.Style::new()
      .font_size(fs_aux)
      .font_weight(@style.FontWeight::W600)
      .color(p.fg2)
      .padding_bottom(@style.px(sp2)),
    ),
    "本页目录",
  )
  if entries.length() == 0 {
    return @html.div(
      attrs=attrs(@style.Style::new().padding_horizontal(@style.px(sp3))),
      [
        head,
        @html.div(attrs=attrs(@style.Style::new().font_size(fs_aux).color(p.fg2)), "这一页没有分节。"),
      ],
    )
  }
  let rows : Array[@html.Html] = []
  for i = 0; i < entries.length(); i = i + 1 {
    rows.push(toc_row(theme, entries[i], i, emit, sp1, sp3, sp5, i == active))
  }
  @html.div(
    attrs=attrs(@style.Style::new()),
    [
      head,
      @html.div(
        attrs=attrs(@style.Style::new().border_left_width(1.0).border_left_color(p.line1)),
        rows,
      ),
    ],
  )
}

///|
/// 目录在**侧栏树里**的样子：第三级行（缩进再进一格，字号小一档，颜色仍用可读的 `--fg-2`）。
///
/// `indent` = 与同级条目比再进多少像素（DESIGN：+16）。
fn toc_tree_rows(
  theme : Theme,
  entries : Array[TocEntry],
  emit : @cmd.Emit[Msg],
  active : Int,
) -> Array[@html.Html] {
  let p = theme.palette
  if entries.length() == 0 {
    return [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_aux)
          .color(p.fg2)
          .padding_vertical(@style.px(sp2))
          .padding_left(@style.px(sp6)),
        ),
        "这一页没有分节。",
      ),
    ]
  }
  let out : Array[@html.Html] = []
  for i = 0; i < entries.length(); i = i + 1 {
    out.push(toc_row(theme, entries[i], i, emit, sp2, sp6, sp6 + sp4, i == active))
  }
  out
}

///| 侧栏里那一段目录的容器（树里的一格：左边一条引导线，和二级用同一套语言）。
fn toc_tree_mount(
  theme : Theme,
  entries : Array[TocEntry],
  emit : @cmd.Emit[Msg],
  active : Int,
) -> @html.Html {
  let p = theme.palette
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .padding_left(@style.px(sp3 + sp4))
      .margin_bottom(@style.px(sp2))
      .border_left_width(1.0)
      .border_left_color(p.line1),
    ),
    toc_tree_rows(theme, entries, emit, active),
  )
}
