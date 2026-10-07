// shell/topbar.mbt —— 顶栏（DESIGN-site.md §4.1 顶栏那段 / §5 顶栏那一行）。
//
// 形状：白底 + 1px 底线、**高 56**（`h_top`），左中右三段：
//
//     [s skillpress]   首页  书架  …            [◐]
//      ↑ 站名=回首页   ↑ nav（见 nav_items）      ↑ 主题三态开关
//
// ## 三段各自的来源（§13.1b 那张表）
//
//   左（站名）  `Home.title` —— 站点配置 `title` 到了就换成那一条（§7，【实现依赖】）
//   中（nav）   **`nav_items()` 是唯一的接缝**：今天从首页源的 `##` 推，配置到位只改这一个函数
//   右（工具）  **今天只有主题开关**。搜索与 llms.txt **不画** —— 见下面那段"缺什么"。
//
// ## 缺什么、为什么宁可不画
//
//   · **搜索**：要**构建期索引** + 一层浮层（portal / 遮罩）。moobile 今天没有 portal 与遮罩
//     （`PLAN-ui §4.3` 的实现依赖）⇒ 画出来只能是"点了没反应"。
//   · **llms.txt 入口**：要生成期多产一份 `/llms.txt`。今天没有那个产物，
//     链接会指向一个不存在的地址 —— 那比不画更糟（读者点了才知道我们在吹）。
//   ⇒ **DESIGN §1 反面验收**："点了没反应的元素"出现即红。**宁缺一个按钮，不画一个假按钮。**
//
// ## 站名**不用等宽**
//
// §3.4 明写"等宽只给代码、机器名、kicker"，并点名"现状把它用在站名与页标题上，是气质损失的来源"。
// 所以站名是正文那套字体，靠字重 + 左边那个品牌色小方块立住身份。
//
// ## 旧件去哪了
//
// 原来这份文件里是"分段控件 + 下拉菜单 + `top_msg` 两步语义"（那套是给**吃正文 `##` 的导航**用的）：
// 新 IA 里 nav 每一条都**直接到某一页**，不存在"先展开再进去" ⇒ 整段随 D3 一起退休。

///|
/// 顶栏中段那几条 nav —— **这是"导航从哪来"的唯一接缝**。
///
/// 【实现依赖】设计里这段来自**站点配置**（`.skillpress/` 的 `nav.N.label` / `nav.N.href`，DESIGN §7）：
/// 那份配置今天**不存在** ⇒ 先按下面两条自我约束从首页源推。配置做出来之后，
/// **只改这一个函数**（渲染、当前项、点击语义一行都不用动）。
///
/// 两条自我约束（都是"别把过渡期弄成违规"）：
/// ① **只放点了真的会到某处**的条目 —— "首页 / 书架"是结构性的（任何站点都有），
///    其余只收首页源里**有 link 的节**（`find_page` 认得出目标的那种）；
///    没有目标的那几节**不进 nav**：它们在新 IA 里是首页门户的正文，不是导航。
/// ② **剥掉正文 `##` 的序号**（"一、两份 skill" → "两份 skill"）：§2.3 规定 nav 标签
///    **≤6 字、无序号、无标点**，而过渡期的来源正是带序号的正文标题 ⇒
///    不剥就等于把 D3 那个耦合（正文标题直接当导航）原样端到读者面前。
fn nav_items(ctx : Ctx) -> Array[(String, Msg)] {
  let out : Array[(String, Msg)] = []
  out.push(("首页", Home))
  out.push(("书架", Shelf))
  // 搜索（对标表 #2 的"顶栏要有搜索"）：它是一个**入口**，不是一个页面 ⇒ 走浮层。
  out.push(("搜索", SearchOpen))
  for i = 0; i < ctx.home.sections.length(); i = i + 1 {
    let s = ctx.home.sections[i]
    if s.link != "" {
      let (kind, si, ki) = (ctx.find_page)(s.link)
      if kind > 0 {
        out.push((strip_ordinal(plain(s.title)), Go(kind, si, ki)))
      }
    }
  }
  out
}

///|
/// 剥掉中文小标题开头的序号（"一、" / "（一）" / "1."）。
///
/// §2.3：nav 标签**无序号**。只剥**开头**那一个，不动正文里别的字样。
fn strip_ordinal(s : String) -> String {
  let marks : Array[String] = [
    "（一）", "（二）", "（三）", "（四）", "（五）", "（六）", "（七）", "（八）", "（九）", "（十）",
    "一、", "二、", "三、", "四、", "五、", "六、", "七、", "八、", "九、", "十、",
    "1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9.", "10.", "1、", "2、", "3、",
  ]
  for m in marks {
    if s.has_prefix(m) {
      return s[m.length():].to_owned()
    }
  }
  s
}

///|
/// 一条 nav 是不是**当前项**（顶栏那条要标出来）。
///
/// 判据是"**当前页与它指向的页是同一页**"，不是"上次点了谁" —— 换页之后顶栏要跟着对。
fn nav_current(model : Model, m : Msg) -> Bool {
  match m {
    Home => model.page == page_home
    Shelf => model.page == page_shelf
    Go(kind, i, k) =>
      model.page == page_doc && model.sel.kind == kind && model.sel.i == i && model.sel.k == k
    _ => false
  }
}

///|
/// 主题开关上那个记号：跟随系统 `◐` / 亮 `☀` / 暗 `☾`。
///
/// 用字符而不是图标：**今天没有图标通道**（moobile 那边要先有矢量/图标那条路），
/// 而这三个字符本来就表达"半明半暗 / 太阳 / 月亮"三态。
fn pref_glyph(pref : Pref) -> String {
  match pref {
    Auto => "◐"
    Light => "☀"
    Dark => "☾"
  }
}

///| 可点的图标钮（34×34，圆角 6）—— 顶栏右端那一排共用。
fn icon_btn(theme : Theme, label : String, hint : String, msg : Msg, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  @html.button(
    attrs=attrs(
      @style.Style::new()
      .width(@style.px(34.0))
      .height(@style.px(34.0))
      .align_items(@style.Align::Center)
      .justify_content(@style.Justify::Center)
      .border_radius(r2)
      .border_width(1.0)
      .border_color(p.line1)
      .background_color(p.canvas),
    ),
    on_click=emit(msg),
    [
      // `hint` 走可见文字之外：文本通道今天只有"看得见"这一种，所以记号 + 说明都用同一格
      // （记号是主，说明挂在 `accessibilityLabel` 那条路上——今天没有可用的标注通道，留待补）
      @html.span(
        attrs=attrs(@style.Style::new().font_size(fs_sm).color(p.fg2).text_align(@style.TextAlign::Center)),
        label,
      ),
    ],
  )
}

///|
/// 一整条顶栏。
fn topbar(theme : Theme, ctx : Ctx, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let p = theme.palette
  let compact = top_compact(model.vw)
  // ── 左：站名（= 回首页的入口）
  let brand = @html.button(
    attrs=attrs(
      @style.Style::new()
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::Center)
      .gap(sp2)
      .border_width(0.0)
      .background_color(p.canvas),
    ),
    on_click=emit(Home),
    [
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .width(@style.px(20.0))
          .height(@style.px(20.0))
          .border_radius(r2)
          .background_color(p.brand)
          .align_items(@style.Align::Center)
          .justify_content(@style.Justify::Center),
        ),
        [
          @html.span(
            attrs=attrs(
              @style.Style::new().font_size(fs_aux).color(p.on_brand).font_weight(@style.FontWeight::W700),
            ),
            "s",
          ),
        ],
      ),
      @html.span(
        attrs=attrs(@style.Style::new().font_size(15.0).color(p.fg1).font_weight(@style.FontWeight::W700)),
        ctx.home.title,
      ),
    ],
  )
  // ── 中：nav（窄屏整排收起 —— 那是"这一排排不下"，不是版面换档；见 layout.mbt 的 top_compact）
  let mid : Array[@html.Html] = []
  if !compact {
    for item in nav_items(ctx) {
      let (label, m) = item
      let cur = nav_current(model, m)
      mid.push(
        @html.button(
          attrs=attrs(
            @style.Style::new()
            .padding_horizontal(@style.px(sp3))
            .padding_vertical(@style.px(6.0))
            .border_radius(r2)
            .border_width(0.0)
            .background_color(if cur { p.brand_soft } else { p.canvas }),
          ),
          on_click=emit(m),
          [
            @html.span(
              attrs=attrs(
                @style.Style::new()
                .font_size(fs_sm)
                .color(if cur { p.brand } else { p.fg2 })
                .font_weight(if cur { @style.FontWeight::W600 } else { @style.FontWeight::W400 }),
              ),
              label,
            ),
          ],
        ),
      )
    }
  }
  // ── 右：主题三态开关（**今天右端只有它** —— 搜索与 llms 的理由见文件头）
  let right : Array[@html.Html] = [
    icon_btn(theme, pref_glyph(model.pref), pref_key(model.pref), SetTheme(next_pref(model.pref)), emit),
  ]
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .height(@style.px(h_top))
      .flex_shrink(0.0)
      .flex_direction(@style.FlexDirection::Row)
      .align_items(@style.Align::Center)
      .gap(sp3)
      .padding_horizontal(@style.px(sp5))
      .background_color(p.canvas)
      .border_bottom_width(1.0)
      .border_bottom_color(p.line1)
      .z_index(30.0),
      // ⚠️ 顶栏一个**具名节点**（`id="topbar"`）：判据要能**指到它**再说话。
      //    站点判据（`engine/site/`）里那些"顶栏有哪几条导航 / 导航排在同一行吗"如果只按
      //    整页子串找，就会**把正文里的同名文字也算进去**（实测：首页那张 CTA 卡片上写着
      //    「文档 / SKILL」⇒ 一条本该红的判据假绿）。有名字之后，量的是**顶栏里**的东西。
      //    （与 `#prose` / `#toc-rail` / `#pane` 同一套做法：判断先要能指得准。）
    ).id("topbar"),
    [
      brand,
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Row)
          .align_items(@style.Align::Center)
          .gap(sp1),
          // 导航那一排的具名节点（`#topnav`）：判据要能**只量这一排** ——
          // 每一条都是这一排的**直接子元素**，于是"顶栏列了哪几条"可以逐条读出来比
          // （判据在 `engine/site/`：`#topnav > *` 取条目自己的文字）。
        ).id("topnav"),
        mid,
      ),
      @html.div(attrs=attrs(@style.Style::new().flex(1.0)), ([] : Array[@html.Html])),
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .flex_direction(@style.FlexDirection::Row)
          .align_items(@style.Align::Center)
          .gap(sp2),
        ),
        right,
      ),
    ],
  )
}
