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
// ## ⚠️ 今天它**只是骨架，还不能点**（这是本轮最重的一条记账）
//
// 目录的价值一半在"点一下跳过去"和"跟读高亮"。这两件事今天**都做不到**：
//   · **跳**：moobile 的公开面里没有"滚到某个节点"（`html/` 与 `vendor/rabbita/html/` 全仓搜
//     `scroll_to` / `scroll_into_view` / `scrollTo` —— 零命中；只有 `html_utils.mbt` 里**读**滚动位置的那一处）。
//     浏览器有 `element.scrollIntoView`，RN 的 ScrollView 有 `scrollTo` ⇒ 这是**甲级能力**
//     （两端都有对应物，形状不同），和 D-UI-4 补的 `cursor` / `box_shadow` / `transform` 同一类。
//   · **高亮**：要"当前那一节"，就得知道每一节在滚动容器里的位置（`getBoundingClientRect` 那一类测量），
//     `@sub.on_scroll` 只给**滚动偏移**、不给"元素在哪" ⇒ 同样缺一件测量能力。
//
// 所以这一轮交出去的是**位置与形状**（用户要的那一条），交互留着 —— 但**不做成假链接**：
// 今天的目录行是**纯文字行**，没有 `on_click`、没有可点的手感。做不出反馈的控件不画成控件（DESIGN §1 反面验收）。

///| 目录里的一条：`level` = 2（h2）或 3（h3）。
pub(all) struct TocEntry {
  level : Int
  text : String
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
pub fn toc_rail(theme : Theme, entries : Array[TocEntry]) -> @html.Html {
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
  let rows = entries.map(fn(e) {
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .font_size(fs_aux)
        .line_height_em(lh_aux)
        .color(p.fg2)
        .padding_vertical(@style.px(sp1))
        .padding_right(@style.px(sp3))
        .padding_left(@style.px(if e.level >= 3 { sp5 } else { sp3 })),
      ),
      e.text,
    )
  })
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
fn toc_tree_rows(theme : Theme, entries : Array[TocEntry]) -> Array[@html.Html] {
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
  entries.map(fn(e) {
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .font_size(fs_aux)
        .line_height_em(lh_aux)
        .color(p.fg2)
        .padding_vertical(@style.px(sp2))
        .padding_right(@style.px(sp3))
        .padding_left(@style.px(if e.level >= 3 { sp6 + sp4 } else { sp6 })),
      ),
      e.text,
    )
  })
}

///| 侧栏里那一段目录的容器（树里的一格：左边一条引导线，和二级用同一套语言）。
fn toc_tree_mount(theme : Theme, entries : Array[TocEntry]) -> @html.Html {
  let p = theme.palette
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .padding_left(@style.px(sp3 + sp4))
      .margin_bottom(@style.px(sp2))
      .border_left_width(1.0)
      .border_left_color(p.line1),
    ),
    toc_tree_rows(theme, entries),
  )
}
