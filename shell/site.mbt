// shell/site.mbt —— 入口：把上面几份拼成一个 moobile 应用。
//
// 实例里只需一行 `@shell.site(ctx)`；`ctx` 提供**内容侧**的东西（首页 / 全部 skill / 页面键换算）。

///|
fn view(ctx : Ctx, model : Model, emit : @cmd.Emit[Msg]) -> @html.Html {
  let home = ctx.home
  let skills = ctx.docs
  // 官网 / 文档：同一个外壳（顶栏），下面换的是正文那半张脸
  let body : @html.Html = if model.mode == 0 {
    site_pane(home, model.sec, emit)
  } else {
    @html.div(
      attrs=attrs(
        @style.Style::new().flex(1.0).flex_direction(@style.FlexDirection::Row),
      ),
      [sidebar(skills, model, emit), pane(page_of(model.sel, skills))],
    )
  }
  @html.div(
    attrs=attrs(
      @style.Style::new()
      .flex(1.0)
      .flex_direction(@style.FlexDirection::Column)
      .background_color(c_bg),
    ),
    [topbar(ctx, home, model, emit), body],
  )
}

///|
///|
/// 入口：**把这一套界面挂成一个 moobile 应用**。
///
/// 实例那边只要一行：`@shell.site(ctx)`（`ctx` 由实例从生成物里取）。
/// ⚠️ 原来这行在实例的 `app()` 里；搬进包之后，实例不再持有任何界面代码。
pub fn site(ctx : Ctx) -> @moobile.JsValue {
  let upd = fn(model : Model, msg : Msg, emit : @cmd.Emit[Msg]) { update(ctx, model, msg, emit) }
  let vw = fn(model : Model, emit : @cmd.Emit[Msg]) { view(ctx, model, emit) }
  @moobile.handlers(model=initial(ctx), update=upd, view=vw)
}
