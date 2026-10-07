// shell/home.mbt —— **首页（门户）**（DESIGN-site.md §6 首页那一行）。
//
//      H1（一句定位）→ 3 张入口卡 → "这里有 N 份 skill、M 个子页"的统计行 → 页脚
//
// ## 这一版与旧首页的区别（不是"换皮"，是换 IA）
//
// 旧首页是**一页长文**：首屏 + 一排**分栏**（分栏 = 首页源里的 `##`），点一条换一节正文；
// 顶栏那条导航**就是**这些 `##`（D3 那个病）。
// 新首页是**门户**：一屏说清"这是什么 + 从哪开始"，然后把人送出去（去书架 / 去第一份 skill）。
// ⇒ **首页源里的 `##` 不再进顶栏**（§2.3），也不再是"点一下换一节"的那套交互。
//
// ## 三张卡里为什么只有两张
//
// §6 写的是"3 张入口卡（从哪开始 / 书架 / 规矩）"。**"规矩"那个页面今天不存在**
// （它是内容侧的一页，`skills/` 里还没有），而"点了没反应 / 点了 404"的卡是 §1 的反面验收。
// ⇒ 只画**今天真能到**的两张（从哪开始 → 第一份 skill、书架 → 书架页），
// 并在报告里点名第三张缺什么。**少一张卡不是偷工，是不画假控件。**

///|
/// 首页（门户）。
fn home_page(theme : Theme, ctx : Ctx, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  let kids_n = {
    let mut n = 0
    for d in ctx.docs {
      n = n + d.kids.length()
    }
    n
  }
  let head = @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column).gap(sp3)),
    [
      @html.span(
        attrs=attrs(
          @style.Style::new()
          .font_size(fs_h1)
          .line_height_em(1.2)
          .color(p.fg1)
          .font_weight(@style.FontWeight::W700),
        ),
        ctx.home.title,
      ),
    ],
  )
  // 一句定位 + 首屏正文：都来自首页源（`WEBSITE.md` 的 H1 之后、第一个 `##` 之前那一段）
  let lede = @html.div(
    attrs=attrs(@style.Style::new().margin_top(@style.px(sp5))),
    [blocks_view(theme, ctx.home.lede, model.copied_at, ctx, emit)],
  )
  // 统计行（§6：让读者一眼知道这个站有多大）
  let stats = @html.div(
    attrs=attrs(@style.Style::new().margin_top(@style.px(sp5))),
    [
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_aux).color(p.fg2)),
        "这里有 \{ctx.docs.length()} 份 skill、\{kids_n} 个子页。",
      ),
    ],
  )
  // 入口卡：只画今天真能到的
  let cards : Array[@html.Html] = []
  if ctx.docs.length() > 0 {
    cards.push(card(theme, "从哪开始", "读第一份：\{ctx.docs[0].title}", Go(1, 0, 0), emit))
  }
  cards.push(card(theme, "书架", "全部 \{ctx.docs.length()} 份 skill 的总览", Shelf, emit))
  @html.div(
    attrs=attrs(@style.Style::new().flex_direction(@style.FlexDirection::Column)),
    [
      head,
      lede,
      stats,
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Row)
          .gap(sp3)
          .margin_top(@style.px(sp6)),
        ),
        cards,
      ),
      page_footer(theme, ctx, "本站由 skillpress press 从内容源投影而来，未改动内容源"),
    ],
  )
}
