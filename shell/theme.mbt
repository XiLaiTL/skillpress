// shell/theme.mbt —— **主题是一个值**，跟着 Model 走（PLAN-ui §6.3 / DESIGN-site.md §3）。
//
// 为什么不是"模块级常量"：moobile 里没有 CSS 变量、也没有媒体查询，样式就是值。
// 主题只能是值 ⇒ 它在 Model 里，`Msg::SetTheme` 换一次就重渲一次（静态站无所谓）。
// 代价照写：**每个渲染函数都要拿到 theme**（参数传下去），没有全局通道可挂。
//
// 【实现依赖】"首屏用哪套"（不闪）与"跟随系统变化"两条通路**尚未验证**（PLAN-ui §6.4）：
//   · 首屏：宿主模板（实例的 `index.html`）里一段同步脚本读 localStorage / matchMedia，
//     把结果写进全局，MoonBit 的 `initial` 读它 —— 与引擎的 `ts_shim.mbt` 同形；
//   · 跟随系统：现役是 `react_host`（不用 `@dom`）⇒ 要走 React 侧，或给 `@sub` 加一个。
//   在那之前：默认跟随系统由宿主给的那个全局值决定，用户点开关则三态轮换。

///| 明暗。
pub(all) enum Scheme {
  Light
  Dark
}

///| 用户偏好（三态）。`Auto` = 跟随系统。
pub(all) enum Pref {
  Auto
  Light
  Dark
} derive(Eq)

///|
/// 一套主题 = 一套语义色 + "色号 → 颜色"的映射。
///
/// ⚠️ `tok` 是**函数**而不是表：色号是引擎在构建期算出来的 int（1..9，0 = 正文前景），
///    明暗两套各自给一份 ⇒ **同一份内容产物在两种主题下都成立**，构建期不用重跑（§6.2）。
///    漏映射是**安静**的（那一类 token 悄悄变回正文色）⇒ 有判据盯着（§6.5 ④）。
pub(all) struct Theme {
  scheme : Scheme
  palette : Palette
  tok : (Int) -> String
}

///| 色号 → 颜色。`0` 与未知值都给正文色（引擎只会吐 0..9）。
fn tok_of(p : Palette) -> (Int) -> String {
  fn (i) {
    match i {
      1 => p.tok_kw   // 关键字
      2 => p.tok_st   // 字符串
      3 => p.tok_cm   // 注释
      4 => p.tok_num  // 数字 / 字面量
      5 => p.tok_ty   // 类型
      6 => p.tok_fn   // 函数
      7 => p.tok_mod  // 模块
      8 => p.tok_var  // 变量 / 字段
      9 => p.tok_op   // 标点 / 运算符
      _ => p.fg1
    }
  }
}

///|
/// 按"调色板名 + 明暗"取一套主题。
///
/// ⚠️ 暖纸**没有深色版** ⇒ 深色下退回靛紫深色（宁可给一套对的深色，也不给一套没设计过的深色）。
///    名字认不出时同样退回默认（生成期已经拦过一次，这里只是不崩）。
pub fn theme_of(name : String, scheme : Scheme) -> Theme {
  let p : Palette = match (name, scheme) {
    ("paper", Light) => paper_light
    ("paper", Dark) => indigo_dark
    (_, Dark) => indigo_dark
    (_, Light) => indigo_light
  }
  { scheme, palette: p, tok: tok_of(p) }
}

///|
/// 色号 → 颜色（字段 `tok` 的调用口）。
///
/// 为什么包一层：`tok` 是**字段**（函数值），`theme.tok(1)` 在 MoonBit 里不成立
/// （会提示 "Type Theme has no method tok"）—— 包一个方法比在每个调用点写 `(theme.tok)(1)` 清楚。
pub fn Theme::tok_color(self : Theme, i : Int) -> String {
  (self.tok)(i)
}

///| 偏好 + 系统值 ⇒ 最终用哪套（`Auto` 才看系统）。
pub fn resolve_scheme(pref : Pref, system_dark : Bool) -> Scheme {
  match pref {
    Light => Light
    Dark => Dark
    Auto => if system_dark { Dark } else { Light }
  }
}

///| 三态轮换（点一下换下一个）：跟随系统 → 亮 → 暗 → 跟随系统。
pub fn next_pref(pref : Pref) -> Pref {
  match pref {
    Auto => Light
    Light => Dark
    Dark => Auto
  }
}

///| 偏好 → 存进宿主的那三个字（`localStorage` 里只存"偏好"，不存"当前明暗"）。
pub fn pref_key(pref : Pref) -> String {
  match pref {
    Auto => "auto"
    Light => "light"
    Dark => "dark"
  }
}

///| 反过来：认不出的串当 `Auto`。
pub fn pref_of_key(k : String) -> Pref {
  match k {
    "light" => Light
    "dark" => Dark
    _ => Auto
  }
}

///| 一份样式 = 一个 `Attrs`（全仓唯一的装法，别在渲染处各写各的）。
fn attrs(s : @style.Style) -> @html.Attrs {
  @html.Attrs::build().styles(s)
}

// ── 字体栈（不是颜色，所以留在这儿：它是"等宽只给代码 / 机器名 / kicker"那条规矩的落点）──

///|
let mono : String = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
