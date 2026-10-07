// shell/hosttheme.mbt —— "系统明暗"这条通道（DESIGN-site.md §12.2 / PLAN-ui §13.7 的 ③）。
//
// ## 为什么这事必须走宿主
//
// moobile 的样式子集**故意封闭**（没有媒体查询），而"系统现在是暗的还是亮的"只有宿主知道。
// 所以这条路拆成两半：
//
//   ① **首屏**：宿主模板（实例的 `index.html`）里一段**同步脚本**读 `localStorage` 的三态偏好
//      + `matchMedia('(prefers-color-scheme: dark)')`，把**解析结果**写进 `globalThis.__skillpress_theme`。
//      MoonBit 的 `initial` 同步读它 ⇒ **首帧就是对的**（不闪）。这与引擎 `ts_shim.mbt` 读
//      `globalThis.__skillpress_ts` 是**同一种形状**（宿主挂值、MoonBit `extern "js"` 读）。
//   ② **变化**：`@sub` 的公开面里**没有媒体查询订阅**（只有 resize / scroll / visibility / url / key …），
//      给 `@sub` 加一条要动 vendored rabbita（**跨仓**）。本仓这一版用 `@sub.every` **轮询**顶上，
//      并在 `state.mbt` 的 `subs` 里写明"这是权宜通道、代价是 2 秒粒度"。
//
// ⚠️ **诚实边界**：`Pref::Light` / `Pref::Dark` 是用户钉死的偏好（持久化在 `localStorage`）；
//    只有 `Pref::Auto` 才看系统。首屏那格里的 `dark` 是**解析结果**（已经把偏好算进去），
//    所以 `initial` 拿到的是"此刻该用哪套"，而不是"系统是暗的吗"——两者别混。

///|
/// 宿主在首屏之前写下的那一格，形如 `"<pref>|<dark:0|1>"`。
///
/// 读不到（非 js 宿主 / 宿主模板还没铺这段脚本）⇒ **空串**：调用方按"没有提示"回落，**不猜**。
extern "js" fn theme_hint() -> String =
  #|() => {
  #|  const g = globalThis.__skillpress_theme;
  #|  return g ? (String(g.pref || 'auto') + '|' + (g.dark ? '1' : '0')) : '';
  #|}

///|
/// 把偏好写回宿主（`Msg::SetTheme` 时调）。
///
/// ⚠️ 失败**不影响渲染**（隐私模式里 `localStorage` 会抛）⇒ 静默吞掉，但**不吞掉"没写成功"这个事实**：
/// 下一轮首屏会回落到系统值，用户会发现偏好没记住 —— 那是可见的，不需要在这里抛。
extern "js" fn save_pref(key : String) -> Unit =
  #|(k) => { try { localStorage.setItem('sp-theme', k); } catch (e) {} }

///|
/// 系统此刻是深色吗（按**偏好解析后**的结果）。
///
/// ⚠️ 名字里的 `dark` 指"此刻该用深色"，已经含偏好；读不到宿主那格 ⇒ `false`
///    （与 `initial` 的回落一致：**不猜**、也不假装知道）。
pub fn dark_now() -> Bool {
  let h = theme_hint()
  match h.find("|") {
    Some(i) => h[i + 1:].to_owned().has_prefix("1")
    None => false
  }
}

///| 宿主那格里记的偏好（读不到 ⇒ `Auto`：跟随系统是唯一不需要假设的默认）。
pub fn pref_now() -> Pref {
  let h = theme_hint()
  match h.find("|") {
    Some(i) => pref_of_key(h[:i].to_owned())
    None => Auto
  }
}
