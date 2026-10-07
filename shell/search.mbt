// shell/search.mbt —— **本地搜索**（对标表 #12：VitePress 那种"构建期索引 + 站点里一个搜索框"）。
//
// ## 三条设计决定（都不是随手选的）
//
// 1. **索引在渲染期从 `ctx` 现算 —— 不做构建期产物**。
//    `ctx.docs` 里本来就有每一页的全部块（`blocks`），而站点只有几页 ⇒ 现算的代价是"扫一遍文本"，
//    比"让 `press` 多产一份索引 + 多一条产物纪律 + 多一条陈旧检查"便宜得多。
//    ⚠️ 但**只在浮层打开时算**（`model.search_open`）—— 关着的时候一次都不扫。
//    v1 的边界照写：**站点长到几百页时要换回构建期索引**（那时"每次打开扫一遍"就不再便宜了）。
//
// 2. **匹配是子串、不是分词/倒排**。中文没有词边界，倒排要先分词（引入依赖 + 一堆口径），
//    而这一版的量级根本不需要。大小写按 ASCII 折（CJK 无大小写）。
//    边界：**不做模糊匹配、不做拼音、不做同义词** —— 搜不到就是搜不到，不给"猜你想搜"。
//
// 3. **命中粒度是"小节"，点一下切页 + 跳锚点**。
//    这正是对标表 #12 的验收口径（"搜索命中能跳到对应节"）。跨页跳锚点有个真问题：
//    切换页面与新页面渲染之间隔着一次 React 提交 ⇒ **同一次 update 里发滚动命令会滚到旧页面的同号锚点**。
//    做法见 `state.mbt` 的 `pending`：先切页，再等**一帧**（`on_animation_frame`）兑现滚动。

///|
/// 一条命中。
///
/// `anchor`：小节下标（对应 `toc.mbt` 的 `heading_anchor`）；`-1` = 整页那条（不跳锚点）。
/// `page` / `section` 是**给人看的**，`text` 只用来匹配与出摘要（不直接显示）。
pub(all) struct Hit {
  kind : Int
  i : Int
  k : Int
  page : String
  section : String
  anchor : Int
  /// 摘要（命中处附近的一小段，或开头一段）
  snip : String
  /// 分数（标题命中 2 分、正文命中 1 分；页面标题再 +1）
  score : Int
} derive(Eq)

///|
/// 一个块的可匹配文本（CJK 直接拼，段间留一个空格 —— 免得"上一段末字 + 下一段首字"拼出新词）。
fn block_text(b : Block) -> String {
  match b {
    H2(sp) => plain(sp)
    H3(sp) => plain(sp)
    H4(sp) => plain(sp)
    P(sp) => plain(sp)
    Quote(sp) => plain(sp)
    Code(_lang, text, _runs) => text
    Ul(items) => {
      let buf = StringBuilder::new()
      for it in items {
        buf.write_string(plain(it.2))
        buf.write_string(" ")
      }
      buf.to_string()
    }
    Table(header, rows) => {
      let buf = StringBuilder::new()
      for c in header {
        buf.write_string(plain(c))
        buf.write_string(" ")
      }
      for r in rows {
        for c in r {
          buf.write_string(plain(c))
          buf.write_string(" ")
        }
      }
      buf.to_string()
    }
    Hr => ""
  }
}

///|
/// 一串块 → 一段可匹配文本。
fn blocks_text(blocks : Array[Block]) -> String {
  let buf = StringBuilder::new()
  for b in blocks {
    buf.write_string(block_text(b))
    buf.write_string(" ")
  }
  buf.to_string()
}

///|
/// 取一小段摘要：`at`（命中位置，`-1` = 从头）附近窗口；超长加省略号。
///
/// ⚠️ 按**字符**切（不是字节、也不是码元）：中文一个字一个字符，emoji 之类也不会被切坏。
fn snippet(text : String, at : Int, width : Int) -> String {
  let chars = text.to_array()
  if chars.length() == 0 {
    return ""
  }
  let start = if at > 12 { at - 12 } else { 0 }
  let mut end = start + width
  if end > chars.length() {
    end = chars.length()
  }
  let buf = StringBuilder::new()
  if start > 0 {
    buf.write_string("…")
  }
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  if end < chars.length() {
    buf.write_string("…")
  }
  buf.to_string()
}

///|
/// ASCII 小写（CJK 原样 —— 它们本来就没有大小写）。
fn lower_c(c : Char) -> Char {
  let n = c.to_int()
  if n >= 65 && n <= 90 {
    (n + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
/// 子串查找（**折 ASCII 大小写**）；返回**字符下标**，找不到给 `-1`。
///
/// 自己写而不是用 `String::find`：一是要折大小写，二是要拿到**位置**来出摘要
/// （`String::find` 只告诉你"有没有"）。
fn find_ci(hay : Array[Char], needle : Array[Char]) -> Int {
  if needle.length() == 0 {
    return 0
  }
  if hay.length() < needle.length() {
    return -1
  }
  let last = hay.length() - needle.length()
  for i = 0; i <= last; i = i + 1 {
    let mut ok = true
    let mut j = 0
    while j < needle.length() {
      if lower_c(hay[i + j]) != needle[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return i
    }
  }
  -1
}

///|
/// 一页（主题页或子页）→ 若干条命中：**整页一条 + 每个 h2/h3 一条**。
///
/// ⚠️ 分节的序号口径必须与 `toc_of` / `blocks_view` **一模一样**（只数 h2/h3）——
///    否则"搜到的第 3 节"与"正文的第 3 节"不是一个东西（那种错位是静默的）。
fn page_hits(
  kind : Int,
  i : Int,
  k : Int,
  page : String,
  blocks : Array[Block],
) -> Array[Hit] {
  let out : Array[Hit] = []
  out.push({
    kind,
    i,
    k,
    page,
    section: "",
    anchor: -1,
    snip: snippet(blocks_text(blocks), -1, 56),
    score: 0,
  })
  let mut sec_title = ""
  let mut sec_text = ""
  let mut sec_no = -1
  for b in blocks {
    let is_section = match b {
      H2(_) => true
      H3(_) => true
      _ => false
    }
    if is_section {
      if sec_no >= 0 {
        out.push({
          kind,
          i,
          k,
          page,
          section: sec_title,
          anchor: sec_no,
          snip: snippet(sec_text, -1, 56),
          score: 0,
        })
      }
      sec_no = sec_no + 1
      sec_title = block_text(b)
      sec_text = ""
    } else {
      sec_text = sec_text + block_text(b) + " "
    }
  }
  if sec_no >= 0 {
    out.push({
      kind,
      i,
      k,
      page,
      section: sec_title,
      anchor: sec_no,
      snip: snippet(sec_text, -1, 56),
      score: 0,
    })
  }
  out
}

///|
/// 建索引（只在搜索浮层打开时调用 —— 见文件头第 1 条）。
fn build_index(ctx : Ctx) -> Array[Hit] {
  let out : Array[Hit] = []
  // 首页也算一页（它的正文在 `ctx.home.lede` 里）
  for h in page_hits(page_home, 0, 0, ctx.home.title, ctx.home.lede) {
    out.push(h)
  }
  for i = 0; i < ctx.docs.length(); i = i + 1 {
    let d = ctx.docs[i]
    for h in page_hits(page_doc, i, 0, d.title, d.blocks) {
      out.push(h)
    }
    for k = 0; k < d.kids.length(); k = k + 1 {
      let kid = d.kids[k]
      for h in page_hits(page_doc, i, k + 1, kid.title, kid.blocks) {
        out.push(h)
      }
    }
  }
  out
}

///|
/// 查询 → 命中（按分数降序、同分保持页面顺序；截到 `limit` 条）。
///
/// 空查询 ⇒ 空结果（**不**给"热门推荐"那种自作主张的东西）。
pub fn search_of(ctx : Ctx, q : String, limit : Int) -> Array[Hit] {
  let query = q.trim()
  if query == "" {
    return []
  }
  let needle : Array[Char] = []
  for c in query.to_array() {
    needle.push(lower_c(c))
  }
  let scored : Array[Hit] = []
  for h in build_index(ctx) {
    let title = if h.section == "" { h.page } else { h.section }
    let in_title = find_ci(title.to_array(), needle)
    let text = if h.section == "" {
      h.page + " " + h.snip
    } else {
      h.section + " " + h.snip
    }
    let in_text = find_ci(text.to_array(), needle)
    let in_page = find_ci(h.page.to_array(), needle) >= 0
    if in_title >= 0 || in_text >= 0 || in_page {
      let s = (if in_title >= 0 { 2 } else { 0 }) + (if in_text >= 0 { 1 } else { 0 }) + (
        if in_page { 1 } else { 0 }
      )
      scored.push({
        ..h,
        // 摘要从**命中处**开窗（标题命中就用正文开头）
        snip: if in_title < 0 && in_text >= 0 {
          snippet(text, in_text, 48)
        } else {
          h.snip
        },
        score: s,
      })
    }
  }
  // 选择排序：条数本来就不多，且要**稳定**（同分保持页面顺序）
  let out : Array[Hit] = []
  let left = scored.copy()
  while out.length() < limit && left.length() > 0 {
    let mut best = 0
    for j = 1; j < left.length(); j = j + 1 {
      if left[j].score > left[best].score {
        best = j
      }
    }
    out.push(left[best])
    ignore(left.remove(best))
  }
  out
}

// ── 界面（浮层） ──────────────────────────────────────────────────────────────

///|
/// 结果行的标题行（`页面 · 小节`；整页那条只有页面名）。
fn hit_title(h : Hit) -> String {
  if h.section == "" {
    h.page
  } else {
    h.page + " · " + h.section
  }
}

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
