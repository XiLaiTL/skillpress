// shell/site.mbt —— 入口：把各件拼成一个 moobile 应用。
//
// 实例里只需一行 `@shell.site(ctx)`；`ctx` 提供**内容侧**的东西（首页 / 全部 skill / 页面键换算）。
//
// 这一版的形状（DESIGN-site.md §4）：
//
//     主题（值，跟着 Model 走）
//        ↓
//     layout.shell：顶栏 + 三栏行（每栏自己滚）
//        ↓ 侧栏 / 正文 / 目录轨 —— 放不放由**阶梯**决定（rail_of(vw)）
//
// ## 页面种类（不是"两个模式"）
//
// `Model.page` 四类（`state.mbt` 的 `page_home` / `page_shelf` / `page_doc` / `page_404`）：
// 原来只有 `mode`（0 官网 / 1 文档），那个形状装不下"首页与书架是两回事"。
// ⚠️ **404 是兜底、不是走到的**：今天没有 URL 路由（§2.2），认不出的 `sel` 落在那儿。

///|
fn view(ctx : Ctx, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let theme = theme_of("indigo", resolve_scheme(model.pref, model.sys_dark))
  let rail = rail_of(model.vw)
  // 页面种类：文档页要**先验一页真的在**（不在 ⇒ 404 兜底，而不是画一页空的）
  let page = if model.page == page_doc && !sel_valid(model.sel, ctx.docs) {
    page_404
  } else {
    model.page
  }
  let top = topbar(theme, ctx, model, emit)
  // ⚠️ 这里**不能**写 `match page { page_shelf => … }`：那是**绑定一个新变量**（永远匹配第一条），
  //    后面几条会被判成 unreachable —— 编译器会警告，但要读懂警告才知道"页面对不上"。
  //    `let` 常量不是模式，所以用 if/else 比。
  let main : @html.Html = if page == page_shelf {
    shelf_page(theme, ctx, emit)
  } else if page == page_doc {
    article(theme, ctx, model, emit)
  } else if page == page_404 {
    notfound_page(theme, emit)
  } else {
    home_page(theme, ctx, emit)
  }
  // 本页目录的条目（今天在渲染期从正文块里现算 —— P3 之后由生成期带锚点一起给出，见 toc.mbt）
  // ⚠️ 用 `toc_for` 而不是在这里再写一遍：**目录算法只能有一处** ——
  //    `state.mbt` 的跟读高亮也要用它（两边数出来的"第 i 节"必须是同一节）。
  let toc : Array[TocEntry] = toc_for(ctx, model)
  // 侧栏：rail ≥ 2 才有（rail 1 时整个进 sheet —— 那是"根本不画"，不是"藏起来"）
  // 目录挂在**正在读的那个文件**节点下面（用户拍定的 IA），rail 3 才交给右栏那条轨
  let side : @html.Html? = if rail >= 2 {
    Some(sidebar(theme, ctx, model, emit, toc, rail < 3))
  } else {
    None
  }
  let toc_side : @html.Html? = if rail >= 3 {
    Some(toc_rail(theme, toc, emit, model.active))
  } else {
    None
  }
  // 窄屏那一层：rail 1 才画（贴边按钮 + 两级交互 + sheet）。
  // ⚠️ 它必须挂在**根**里（`shell` 的最后一个孩子）：根不滚 ⇒ 绝对定位等价于 fixed。
  let overlay : Array[@html.Html] = if rail == 1 {
    mobile_layer(theme, ctx, model, emit, toc)
  } else {
    []
  }
  shell(theme, top, side, prose_wrap(rail, [main]), toc_side, overlay)
}

///|
/// 入口：**把这一套界面挂成一个 moobile 应用**。
///
/// 实例那边只要一行：`@shell.site(ctx)`（`ctx` 由实例从生成物里取）。
/// ⚠️ 原来这行在实例的 `app()` 里；搬进包之后，实例不再持有任何界面代码。
///|
/// **这一页的目录条目** —— 唯一的一处算法（view 与 update 都用它）。
///
/// ⚠️ 曾经在 `view` 里现算：现在 `update` 的跟读高亮也要"第几节"，两处各写一遍
/// 就会长出"目录里有、高亮数不到"这种静默错位（锚点口径那条账的同一家族）。
fn toc_for(ctx : Ctx, model : Model) -> Array[TocEntry] {
  if model.page == page_doc {
    toc_of(page_view(model.sel, ctx.docs).blocks)
  } else if model.page == page_home {
    toc_of(ctx.home.lede)
  } else {
    []
  }
}

///|
pub fn site(ctx : Ctx) -> @moobile.JsValue {
  let upd = fn(model : Model, msg : Msg, emit : @cmd.Emit[Msg]) { update(ctx, model, msg, emit) }
  let vw = fn(model : Model, emit : @cmd.Emit[Msg]) { view(ctx, model, emit) }
  let sb = fn(model : Model, emit : @cmd.Emit[Msg]) { subs(model, emit) }
  @moobile.handlers(model=initial(ctx), update=upd, view=vw, subscriptions=sb)
}
