// shell/state.mbt —— 状态机（从实例的 app.mbt 搬进来，逻辑一字未改）。
//
// `Sel` / `Model` / `Msg` / `initial` / `update` 都在这里。
// ⚠️ `ctx : Ctx` 是**唯一**的改动：原来 `initial` / `update` 直接调 `@content.skills()` /
// `@content.home()` / `@content.find_page()` —— 那是**内容侧**的东西，包不该知道它从哪来。
// 现在它们是参数（见 types.mbt 的 `Ctx`），实例在 `@shell.site(ctx)` 时传进来。
//
// ⚠️ `Sel` / `Model` 的 `derive(Eq)` 是**必需的**（`@moobile.handlers` 要求模型实现 `Eq`；
// 实测去掉就报 `Type Model does not implement trait Eq`），也是这个仓库的惯例
// （moobile 的 `examples/apps/todo-app/model.mbt` 同样五处 `derive(Eq)`）。
// 代价本以为是两条 `implicit_impl_as_method` **弃用提醒**（"impl 里的 `equal` / `not_equal`
// 被隐式提升成普通方法"将来会去掉）—— 但把两个类型标上 `priv` 之后**实测 0 条**：
//   · 不标 `priv`：5 条警告（2 条 `missing_priv` + 2 条 `implicit_impl_as_method` + 1 条别的）
//   · 标了 `priv`：**0 条**（提升不出口，那条弃用提醒自然不触发）
// 试过的另外两条消法都不划算：
//   · `pub extend Sel with Eq::{not_equal, equal}` → 在 `priv` 类型上编不过
//     （"A public definition cannot depend on private type"）
//   · 去掉 `pub` 的 `extend …` → 引入 4 条 `unused_function`（那两个方法没人调用）

///|
/// 文档模式里选中的是哪一页。
///
/// `kind`：`1` = 某个 skill 的主文档，`2` = 某个 skill 的子页（refs / scripts）。
priv struct Sel {
  kind : Int
  i : Int
  k : Int
} derive(Eq)

///|
/// 站点状态。
///
/// `mode`：`0` = 官网（首屏 + 分栏），`1` = 文档（skill 树）。
/// `sec`：官网选中的分栏，`-1` = 首屏（还没点任何分栏）。
/// `hover`：**下拉菜单被鼠标悬停**的那条分栏（`-1` = 没有）。
/// `drop`：**下拉菜单被点开**的那条分栏（触摸屏没有 hover，点一下展开；`-1` = 关着）。
priv struct Model {
  mode : Int
  sec : Int
  sel : Sel
  open : Array[Bool]
  hover : Int
  drop : Int
} derive(Eq)


///|
pub enum Msg {
  /// 官网：切到第 `i` 个分栏（`-1` = 回首屏）
  Top(Int)
  /// 切到文档模式（skill 树）
  Docs
  /// 文档模式里切页：`(kind, skill 下标, 子页下标)`
  Go(Int, Int, Int)
  /// 展开 / 收起某个 skill
  Toggle(Int)
  /// 鼠标进入 / 离开顶栏的第 `i` 条分栏（`-1` = 离开了这一排）
  Hover(Int)
  /// 点某个分栏**下拉菜单里的一条**：`(分栏下标, 菜单项下标)`
  Nav(Int, Int)
}

///|

///|
fn initial(ctx : Ctx) -> Model {
  let n = ctx.docs.length()
  let open : Array[Bool] = []
  for j = 0; j < n; j = j + 1 {
    open.push(false)
  }
  { mode: 0, sec: -1, sel: { kind: 1, i: 0, k: 0 }, open, hover: -1, drop: -1 }
}

///|
/// 点顶栏一条分栏时的**两步语义**：有下拉菜单的，**点一下先展开**，再点一下才进去。
///
/// 为什么这么定：悬停只在有鼠标的地方成立，而**触摸屏没有 hover** ——
/// 只靠 hover 的话，手机上那些子页就永远够不着（顶栏这条通道会在真机上变成摆设）。
/// 展开态（`drop`）就是那条兜底通道，"点一下"在两种设备上都成立。

///|
/// 点顶栏一条分栏时的**两步语义**：有下拉菜单的，**点一下先展开**，再点一下才进去。
///
/// 为什么这么定：悬停只在有鼠标的地方成立，而**触摸屏没有 hover** ——
/// 只靠 hover 的话，手机上那些子页就永远够不着（顶栏这条通道会在真机上变成摆设）。
/// 展开态（`drop`）就是那条兜底通道，"点一下"在两种设备上都成立。
fn update(ctx : Ctx, model : Model, msg : Msg, _emit : @cmd.Emit[Msg]) -> (Model, @cmd.Cmd) {
  match msg {
    Top(i) => {
      // 有菜单、而且还没展开 ⇒ 这一下只用于展开（触摸屏的第一步）
      let secs = ctx.home.sections
      let has_nav = i >= 0 && i < secs.length() && secs[i].nav.length() > 0
      if has_nav && model.drop != i {
        ({ ..model, drop: i, hover: i }, @cmd.none)
      } else {
        ({ ..model, mode: 0, sec: i, drop: -1 }, @cmd.none)
      }
    }
    Docs => ({ ..model, mode: 1, drop: -1 }, @cmd.none)
    Go(kind, i, k) => ({ ..model, mode: 1, sel: { kind, i, k }, drop: -1, hover: -1 }, @cmd.none)
    Toggle(i) => {
      let next : Array[Bool] = []
      for j = 0; j < model.open.length(); j = j + 1 {
        next.push(if j == i { !model.open[j] } else { model.open[j] })
      }
      ({ ..model, open: next }, @cmd.none)
    }
    Hover(i) => ({ ..model, hover: i }, @cmd.none)
    Nav(i, k) => {
      let key = ctx.home.sections[i].nav[k].key
      let (kind, si, ki) = (ctx.find_page)(key)
      if kind > 0 {
        ({ ..model, mode: 1, sel: { kind, i: si, k: ki }, drop: -1, hover: -1 }, @cmd.none)
      } else {
        // 认不出来就当没这一条（生成期已经拦过一次，这里只是不崩）
        (model, @cmd.none)
      }
    }
  }
}

// ── 外观 ──────────────────────────────────────────────────────────────────────

///|
