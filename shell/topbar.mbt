// shell/topbar.mbt —— 顶栏：一排分段控件 + 下拉菜单。
//
// ⚠️ 顶栏是**一行**（左边站名、右边一排），排不下时走横向滚动 —— 换行会让"顶栏"这个形态散架。
// `top_msg` 是"点这一条该发什么消息"的唯一判断处（纯链接节直接跳页、有菜单的先展开）。

///|
/// 顶栏里的一条**分段控件项**（D2）。
///
/// 与旧版（一块圆角实心底）的区别：常态**没有底色**，选中只靠
/// **下划线指示条**（`c_accent`，贴在这一项的底边）＋更亮的字色。
/// 于是整排读起来是"一支分段控件"，而不是"一堆按钮"。
///
/// ⚠️ 下划线是**子 View + `position(Absolute)` + `bottom(0)`** ——
/// 不用 `border_bottom_width`，因为那会把内容往上顶、且按下态不好接。
/// 关于 press()：`Render` 里按下态的键会被拆成 `pressStyle`，而**库侧没有消费点**
/// （见 `moobile-pitfalls`）—— 所以这里**不写按下的视觉**，只留可点性与 `on_click`。
fn nav_tab(
  home : Home,
  i : Int,
  msg : Msg,
  on : Bool,
  emit : @cmd.Emit[Msg],
) -> @html.Html {
  // ⚠️ 负号不止一个：`-1` 是「首页」，**`-2` 是换模式那条**（`seg_bar` 里建的）。
  // 曾经写成 `if i < 0 { "首页" }` ⇒ 换模式那条的标签也成了「首页」，
  // 于是顶栏上有两条长得一样的「首页」，而「文档 / SKILL」在页面里**一次都没出现**。
  // 代价：判据点「首页」点到的其实是它（进了文档区，回不了首页），
  // 而 ① 那条判据用整页子串匹配、被首页中部的 CTA「文档 / SKILL →」蒙绿 —— 假绿 + 真 bug 并存。
  let label = if i == -1 {
    "首页"
  } else if i == -2 {
    "文档 / SKILL"
  } else {
    plain(home.sections[i].title)
  }
  let inner : Array[@html.Html] = [
    @html.span(
      attrs=attrs(
        @style.Style::new()
        .font_size(12.5)
        .color(if on { c_head_ink } else { c_head_ink2 })
        .font_weight(if on { @style.FontWeight::W600 } else { @style.FontWeight::W400 }),
      ),
      label,
    ),
  ]
  if on {
    inner.push(
      @html.div(
        attrs=attrs(
          @style.Style::new()
          .position(@style.Position::Absolute)
          .left(@style.px(7.0))
          .right_(@style.px(7.0))
          .bottom(@style.px(0.0))
          .height(@style.px(2.0))
          .border_radius(1.0)
          .background_color(c_accent),
        ),
        ([] : Array[@html.Html]),
      ),
    )
  }
  @html.button(
    attrs=@html.Attrs::build()
      .styles(
        @style.Style::new()
        .padding_horizontal(@style.px(9.0))
        .padding_vertical(@style.px(9.0))
        // ⚠️ 用 padding（不是 margin）留出间距：`on_mouseenter` 挂在按钮自己身上，
        // 用 margin 的话"两条之间的缝"是死区 —— 鼠标划过会连续触发 leave/enter，
        // 菜单在缝上闪。padding 让它整块都是可悬停面积。
        .padding_left(@style.px(11.0))
        .padding_right(@style.px(11.0))
        .background_color("transparent"),
      )
      .on_mouseenter(_ => emit(Hover(i)))
      .on_mouseleave(_ => emit(Hover(-1))),
    // ⚠️ 用**传进来的** msg，别在这里自己再算一遍 —— 曾经这里写着 `emit(top_msg(ctx, home, i, model))`，
    // 而那正好把调用点给的消息丢掉：`i = -1`（首页）与 `-2`（文档）都是负数，
    // `top_msg` 算不出它们的语义 ⇒ 「首页」那条点了没反应（实测踩过，判据逮到的）。
    on_click=emit(msg),
    [@html.div(attrs=attrs(@style.Style::new().align_items(@style.Align::Center)), inner)],
  )
}

///|
/// 那一排分段控件（含最右那条**换模式**的「文档」）。
///
/// D2：**「文档」就在同一排的最右一栏，不给独立样式** —— 它和别的项只差一条竖细线
/// （那是"这一条是换模式，不是换内容"的提示，不是"实心按钮"）。旧版把它做成实心按钮，
/// 于是整排读起来是"内容项 + 一个动作按钮"两类东西 —— 那正是要拆掉的。

///|
/// 那一排分段控件（含最右那条**换模式**的「文档」）。
///
/// D2：**「文档」就在同一排的最右一栏，不给独立样式** —— 它和别的项只差一条竖细线
/// （那是"这一条是换模式，不是换内容"的提示，不是"实心按钮"）。旧版把它做成实心按钮，
/// 于是整排读起来是"内容项 + 一个动作按钮"两类东西 —— 那正是要拆掉的。
fn seg_bar(ctx : Ctx, home : Home, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let items : Array[@html.Html] = [
    nav_tab(home, -1, Top(-1), model.mode == 0 && model.sec < 0, emit),
  ]
  for i = 0; i < home.sections.length(); i = i + 1 {
    items.push(nav_tab(home, i, top_msg(ctx, home, i, model), model.mode == 0 && model.sec == i, emit))
  }
  items.push(
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .width(@style.px(1.0))
        .height(@style.px(16.0))
        .margin_horizontal(@style.px(8.0))
        .background_color(c_head_on),
      ),
      ([] : Array[@html.Html]),
    ),
  )
  items.push(nav_tab(home, -2, Docs, model.mode == 1, emit))
  // ⚠️ 这一排必须**能横向滚**：分栏条数由内容源决定（加一节就多一条），
  // 而窗口可能比整排窄 —— 排不下时**最左边几条会跑到屏幕外**，点它们等于点空气
  // （实测：第 9 条分栏进来之后，「首页」落到 x=1883、视口只有 1378 ⇒ `elementFromPoint` 返回 null）。
  // 换行会破坏"顶栏是一行"的形态，所以走**横向滚动**这条路。
  //
  // `horizontal` 是 RN `ScrollView` 的 **prop**（不是样式键），而伪标签 `scroll` 只映射组件类型、
  // 不带任何 prop ⇒ 得用 `prop_bool` 显式递（它走类型化那张表，React 收到的就是布尔 `true`；
  // 若用 `prop_str` 会变成字符串 "true"，RNW 不一定认）。
  @html.div(
    attrs=attrs(@style.Style::new().flex(1.0)),
    [
      @html.node(
        "scroll",
        @html.Attrs::build()
          .styles(@style.Style::new().flex(1.0))
          .prop_bool("horizontal", true),
        [
          @html.div(
            attrs=attrs(
              @style.Style::new()
              .flex_direction(@style.FlexDirection::Row)
              .align_items(@style.Align::Center),
            ),
            items,
          ),
        ],
      ),
    ],
  )
}

///|
/// **下拉菜单**（悬停出，或触摸时点一下展开）。
///
/// 挂在顶栏容器里、`position(Absolute)` 贴着那一排的下沿（`top: 100%`）——
/// 于是它浮在正文上面而不是把正文顶下去（`render.mbt` 的 `styles_to_js` 认这个写法，
/// 实测 `offsetParent` 就是那层 relative 的顶栏容器）。
///
/// 菜单项来自**内容源**：那一节里第一个"整项就是一个链接"的列表（见 `gen-content.mjs`）。
/// 于是"给某条 tab 加个子菜单"= **在那一节里写个链接列表**，站点代码一个字不用改。

///|
/// **下拉菜单**（悬停出，或触摸时点一下展开）。
///
/// 挂在顶栏容器里、`position(Absolute)` 贴着那一排的下沿（`top: 100%`）——
/// 于是它浮在正文上面而不是把正文顶下去（`render.mbt` 的 `styles_to_js` 认这个写法，
/// 实测 `offsetParent` 就是那层 relative 的顶栏容器）。
///
/// 菜单项来自**内容源**：那一节里第一个"整项就是一个链接"的列表（见 `gen-content.mjs`）。
/// 于是"给某条 tab 加个子菜单"= **在那一节里写个链接列表**，站点代码一个字不用改。
fn seg_drop(home : Home, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let i = if model.hover >= 0 { model.hover } else { model.drop }
  let rows : Array[@html.Html] = []
  if i >= 0 && i < home.sections.length() {
    let sec = home.sections[i]
    if sec.nav.length() > 0 {
      for k = 0; k < sec.nav.length(); k = k + 1 {
        rows.push(
          @html.button(
            attrs=attrs(
              @style.Style::new()
              .padding_horizontal(@style.px(13.0))
              .padding_vertical(@style.px(9.0))
              .background_color("transparent"),
            ),
            on_click=emit(Nav(i, k)),
            [
              @html.span(
                attrs=attrs(
                  @style.Style::new().font_size(12.5).color(c_head_ink2),
                ),
                sec.nav[k].label,
              ),
            ],
          ),
        )
      }
    } else if sec.link != "" {
      // 没有菜单、但这一节是个"纯链接节"：给一句说明，
      // 免得点下去"怎么跳到别处了"没有解释
      rows.push(
        @html.div(
          attrs=attrs(
            @style.Style::new()
            .padding_horizontal(@style.px(13.0))
            .padding_vertical(@style.px(9.0)),
          ),
          [
            @html.span(
              attrs=attrs(@style.Style::new().font_size(12.0).color(c_head_ink2)),
              "点这一栏直接打开它指的那一页",
            ),
          ],
        ),
      )
    }
  }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .position(@style.Position::Absolute)
      .top(@style.pct(100.0))
      .left(@style.px(0.0))
      .min_width(@style.px(220.0))
      .padding_vertical(@style.px(5.0))
      .border_top_width(1.0)
      .border_top_color(c_head_on)
      .background_color(c_head)
      .z_index(20.0),
    ),
    [@html.div(attrs=attrs(@style.Style::new().align_items(@style.Align::FlexStart)), rows)],
  )
}

///|
/// 首屏上的按钮（官网那种"下一步去哪"）。

///|
/// 点顶栏的一条分栏时该发哪条消息（D3：**纯链接节**直接跳到它指的那一页；有菜单的先展开）。
///
/// 数据侧已经把这个节的目标认成了**页面键**（`content.generated.mbt` 的 `Section.link`），
/// 这里只把键换算成"文档模式里的第几页"。认不出来（`kind < 0`）就退回普通分栏。
fn top_msg(ctx : Ctx, home : Home, i : Int, model : Model) -> Msg {
  if i < home.sections.length() {
    if home.sections[i].nav.length() > 0 && model.drop != i {
      return Top(i)
    }
    let key = home.sections[i].link
    if key != "" {
      let (kind, si, ki) = (ctx.find_page)(key)
      if kind > 0 {
        return Go(kind, si, ki)
      }
    }
  }
  Top(i)
}

///|
/// 顶栏：**一行** —— 左边站名，右边一排分段控件（D2）；下面挂着可选的**下拉菜单**。
///
/// 为什么合成一行：旧版是两行（"站名 + 换模式按钮" / "分栏"），于是页面顶部有一行
/// 只放一个按钮、很空。合起来之后「文档」成了同一排的最右一栏，和分栏同形（只有一条竖线分隔）。
///
/// ⚠️ 顶栏在**滚动容器外面**（`view` 里 topbar 与正文是兄弟）—— 这是"吸顶"在 RN 上
/// 唯一可靠的表达（样式层里没有 `sticky`）。⚠️ **但目前还不成立**：正文那个 `scroll`
/// 容器被撑成内容那么高 ⇒ 实际滚的是整个 document、顶栏会跟着走。
/// 实测与三条候选见 `PLAN.md` 的 P2 未决项 —— 别把这条注释读成"已经吸顶了"。
///
/// 外层容器带 `position: relative`：下拉菜单靠它定位（`top: 100%` 贴着这一排的下沿）。

///|
/// 顶栏：**一行** —— 左边站名，右边一排分段控件（D2）；下面挂着可选的**下拉菜单**。
///
/// 为什么合成一行：旧版是两行（"站名 + 换模式按钮" / "分栏"），于是页面顶部有一行
/// 只放一个按钮、很空。合起来之后「文档」成了同一排的最右一栏，和分栏同形（只有一条竖线分隔）。
///
/// ⚠️ 顶栏在**滚动容器外面**（`view` 里 topbar 与正文是兄弟）—— 这是"吸顶"在 RN 上
/// 唯一可靠的表达（样式层里没有 `sticky`）。⚠️ **但目前还不成立**：正文那个 `scroll`
/// 容器被撑成内容那么高 ⇒ 实际滚的是整个 document、顶栏会跟着走。
/// 实测与三条候选见 `PLAN.md` 的 P2 未决项 —— 别把这条注释读成"已经吸顶了"。
///
/// 外层容器带 `position: relative`：下拉菜单靠它定位（`top: 100%` 贴着这一排的下沿）。
fn topbar(ctx : Ctx, home : Home, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let show_drop = (model.hover >= 0 || model.drop >= 0) && model.mode == 0
  let wrap : Array[@html.Html] = [
    @html.div(
      attrs=attrs(
        @style.Style::new()
        .padding_horizontal(@style.px(20.0))
        .padding_vertical(@style.px(9.0))
        .flex_direction(@style.FlexDirection::Row)
        .align_items(@style.Align::Center),
      ),
      [
        @html.span(
          attrs=attrs(
            @style.Style::new()
            .font_family(mono)
            .font_size(16.0)
            .color(c_head_ink)
            .font_weight(@style.FontWeight::W700),
          ),
          home.title,
        ),
        // ⚠️ 这里**不能**用 `flex(1.0)`：那一排是 [品牌, 空隙, 分段控件] 三个弹性项，
        // 空隙与分段控件会**平分**剩余宽度（实测 1478 的排里各得 580），
        // 于是分段控件只拿到 580 —— 而它要 961 才排得下 9 条分栏 ⇒ 只能看见一条。
        // 固定间距 + 让分段控件**长到自己需要的宽度**（它内部再横向滚）。
        @html.div(attrs=attrs(@style.Style::new().width(@style.px(14.0))), ([] : Array[@html.Html])),
        seg_bar(ctx, home, model, emit),
      ],
    ),
  ]
  if show_drop {
    wrap.push(seg_drop(home, model, emit))
  }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .position(@style.Position::Relative)
      .background_color(c_head)
      .z_index(10.0),
    ),
    wrap,
  )
}

///|
/// 首屏 = H1 + 引言（`home.lede`）+ 两个"下一步"。
