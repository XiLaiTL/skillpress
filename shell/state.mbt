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
/// **页面种类**（DESIGN-site.md §2.1 的四类页面）。
///
/// ⚠️ 原来只有 `mode`（`0` 官网 / `1` 文档）—— 那个形状**装不下四类页面**：
/// 首页与书架是两回事，404 也不是"文档模式的一个特例"。
/// ⚠️ **404 不是"走到的"**：今天没有 URL 路由（§2.2 的【实现依赖】），它是**兜底** ——
///    认不出的页面键 / 越界的 `sel` 落在那儿（见 `view` 的判定）。
let page_home : Int = 0
///|
let page_shelf : Int = 1
///|
let page_doc : Int = 2
///|
let page_404 : Int = 3

///|
/// `sel` 指向的那一页今天真的存在吗（不存在 ⇒ 渲染 404 兜底，而不是画一页空的）。
fn sel_valid(sel : Sel, docs : Array[Doc]) -> Bool {
  if sel.i < 0 || sel.i >= docs.length() {
    false
  } else if sel.kind == 2 {
    sel.k >= 0 && sel.k < docs[sel.i].kids.length()
  } else {
    sel.kind == 1
  }
}

///|
/// 站点状态。
///
/// `page`：四类页面里的哪一类（`page_home` / `page_shelf` / `page_doc` / `page_404`）。
/// `sel`：文档页里选中的是哪一页（`page != page_doc` 时不用它）。
/// `open`：侧栏哪些 skill 展开着。
priv struct Model {
  page : Int
  sel : Sel
  open : Array[Bool]
  /// 视口宽度 —— **阶梯唯一依据**（没有媒体查询，见 layout.mbt 的文件头）。
  /// 单位与 `@sub.Viewport.width` 一致（`Double`），省掉一处来回换算。
  vw : Double
  /// 主题偏好三态（跟随系统 / 亮 / 暗）。
  pref : Pref
  /// 宿主报上来的系统明暗（`Auto` 才看它）。
  sys_dark : Bool
  /// 窄屏浮层：`-1` 关着；`0` 导航 / `1` 书架 / `2` 目录（三个**互斥** —— DESIGN §4.3）。
  sheet : Int
  /// 窄屏贴边按钮的两级：`0` 贴边停着 / `1` 已经浮出（第二次点才弹 sheet）。
  peek : Int
} derive(Eq)


///|
pub enum Msg {
  /// 去**首页**（门户）。
  Home
  /// 去**书架**（全部 skill 的总览）。
  Shelf
  /// 去某一页文档：`(kind, skill 下标, 子页下标)`。`kind`：`1` = 主题页（`k` 取 0），`2` = 子页。
  Go(Int, Int, Int)
  /// 展开 / 收起某个 skill（侧栏雪佛龙；**只展开不跳页**）。
  Toggle(Int)
  /// 视口宽度变了（初值由 `@sub.current_viewport()` 读一次，之后由 `on_resize` 推）
  Resized(Double)
  /// 定时问一次"系统现在该用哪套"（轮询；说明见 `subs`）
  SysTick
  /// 换主题偏好：三态轮换（跟随系统 → 亮 → 暗）由渲染侧算好，这里只收结果
  SetTheme(Pref)
  /// 窄屏点某个贴边按钮：`0` 导航 / `1` 书架 / `2` 目录（**两级语义在 update 里**）
  Tap(Int)
  /// 关掉窄屏浮层（点遮罩 / Esc）
  CloseSheet
  /// 键盘按下（今天只用它认 Esc）
  Key(String)
  /// **点目录某一条**：滚到正文里那一节的锚点（下标 = 目录里的第几条，从 0 数）。
  /// 动作由 `@sub.scroll_to_node` 发 —— 见 `shell/toc.mbt` 的账。
  TocTo(Int)
  /// **地址变了**：后退 / 前进 / 手改地址 / 点同文档链接（`on_url_changed` 递过来的是整条 URL）。
  /// 载荷是 hash 那一段（`#/…`）—— 与 `route.mbt` 的解析口径一致。
  UrlChanged(String)
}

///|

///|
///|
/// 读一次视口宽度。
///
/// ⚠️ `on_resize` **两端都不会在挂载时补发一次**（`sub.mbt` 的原文），所以"现在多大"
///    只能用 `current_viewport()` 同步读一次 —— 这条正是为"按窗口宽度排版"加的 API。
///    拿不到（RN 且宿主没实现 `geometry`）时**不猜 0**（0 宽会算出 0 宽的版面，那种 bug 更难查），
///    按最宽回落：先按桌面排，用户一拖窗口 `on_resize` 就会纠正过来。
fn initial_vw() -> Double {
  match @sub.current_viewport() {
    Some(v) => v.width
    None => 1440.0
  }
}

///|
fn initial(ctx : Ctx) -> Model {
  let n = ctx.docs.length()
  // 首屏的真源是**地址栏**（`route.mbt` 的文件头记着为什么必须同步读一次：
  // `on_url_changed` 首屏不推）。读不到（没有 DOM）⇒ 空串 ⇒ 解析成首页 —— 回落，不猜。
  let (page, sel) = state_of_route(route_of_hash(hash_of_href(url_now()), ctx.docs), {
    kind: 1,
    i: 0,
    k: 0,
  })
  let open : Array[Bool] = []
  for j = 0; j < n; j = j + 1 {
    // 直接打开一个深链时，那一份**默认展开**（与点进去时的行为一致，§9 第 3 条）
    open.push(page == page_doc && j == sel.i)
  }
  {
    page,
    sel,
    open,
    vw: initial_vw(),
    // 偏好与"此刻该用哪套"来自**宿主首屏那格**（`index.html` 的同步脚本，见 hosttheme.mbt）：
    // 与 `initial_vw()` 同款理由 —— 订阅**不会补发首帧**，所以"我现在该用哪套"必须同步读一次。
    pref: pref_now(),
    sys_dark: dark_now(),
    sheet: -1,
    peek: 0,
  }
}

///|
/// 状态迁移。四条消息，各自只做一件事（分栏下拉那套"两步语义"随旧顶栏一起退休了：
/// 新顶栏的 nav 每一条都**直接到某一页**，不存在"先展开再进去"）。
///
/// ⚠️ **谁写地址、谁不写**（这一条错了就是"点一下主题多一条历史"那类难查的 bug）：
///   · **用户驱动的导航**（`Home` / `Shelf` / `Go`）⇒ 改模型 + **写回地址**（`push_url_cmd`）；
///   · **地址驱动的导航**（`UrlChanged`）⇒ **只改模型，绝不写回** —— 那是后退/前进，
///     写回会把用户刚走过的那条历史搅乱（按一次后退像什么都没发生）；
///   · 其余（`Resized` / `SetTheme` / `Toggle` / `Tap` / `Key`）⇒ 一行历史都不该加。
fn update(ctx : Ctx, model : Model, msg : Msg, _emit : @cmd.Emit[Msg]) -> (Model, @cmd.Cmd) {
  match msg {
    Home => {
      let next = { ..model, page: page_home }
      (next, push_url_cmd(hash_of(next.page, next.sel, ctx.docs)))
    }
    Shelf => {
      let next = { ..model, page: page_shelf }
      (next, push_url_cmd(hash_of(next.page, next.sel, ctx.docs)))
    }
    Go(kind, i, k) => {
      // 进到某一页 ⇒ 那一份自动展开（DESIGN §9 第 3 条"只展开当前那一份"）。
      // 用户手动收起的那些不动 —— 这是"默认"，不是"强制"。
      let next : Array[Bool] = []
      for j = 0; j < model.open.length(); j = j + 1 {
        next.push(if j == i { true } else { model.open[j] })
      }
      let moved = { ..model, page: page_doc, sel: { kind, i, k }, open: next }
      (moved, push_url_cmd(hash_of(moved.page, moved.sel, ctx.docs)))
    }
    UrlChanged(h) => {
      // 地址是**真源**：以它为准改模型（解析不出 ⇒ 404，不回落首页 —— 见 `route.mbt`）
      let (page, sel) = state_of_route(route_of_hash(h, ctx.docs), model.sel)
      let next : Array[Bool] = if page == page_doc {
        // 深链/后退到某一页时，那一份同样要展开（否则侧栏找不到"当前项"）
        let out : Array[Bool] = []
        for j = 0; j < model.open.length(); j = j + 1 {
          out.push(if j == sel.i { true } else { model.open[j] })
        }
        out
      } else {
        model.open
      }
      ({ ..model, page, sel, open: next }, @cmd.none)
    }
    Toggle(i) => {
      let next : Array[Bool] = []
      for j = 0; j < model.open.length(); j = j + 1 {
        next.push(if j == i { !model.open[j] } else { model.open[j] })
      }
      ({ ..model, open: next }, @cmd.none)
    }
    Resized(w) => ({ ..model, vw: w }, @cmd.none)
    /// 两级：第一次点只让按钮**浮出**，第二次点才弹 sheet；点开着的那一个 = 收起
    /// （DESIGN §4.3："平时贴边停靠 → 第一次点浮出来 → 第二次点弹层"）。
    TocTo(i) =>
      // 滚到那一节。⚠️ 节点名由 `heading_anchor(i)` **两边各自算**（目录行与正文标题），
      //    口径是"第 i 个 h2/h3" —— 同一次渲染里两边数出来的顺序必然一致。
      //    `block="start"` = 让那一节**顶到内容区上沿**（与站点"跳过去"的语义一致）。
      (model, @sub.scroll_to_node(heading_anchor(i), block="start"))
    Tap(i) =>
      if model.peek == 0 {
        ({ ..model, peek: 1 }, @cmd.none)
      } else if model.sheet == i {
        ({ ..model, sheet: -1, peek: 0 }, @cmd.none)
      } else {
        ({ ..model, sheet: i, peek: 1 }, @cmd.none)
      }
    CloseSheet => ({ ..model, sheet: -1, peek: 0 }, @cmd.none)
    Key(k) =>
      if k == "Escape" {
        ({ ..model, sheet: -1, peek: 0 }, @cmd.none)
      } else {
        (model, @cmd.none)
      }
    // 换了偏好 ⇒ 同时**写回宿主**（下次首屏才不会闪）。效应走 `custom_cmd`，不在 update 里裸写。
    SetTheme(p) => ({ ..model, pref: p }, @cmd.custom_cmd(fn(_) { save_pref(pref_key(p)) }))
    SysTick => {
      // 定时问一次"系统该用哪套"（轮询，见 `subs` 的权宜通道说明）。
      // 值没变就返回**同一个 model**（`Eq` 会据此跳过重渲）⇒ 轮询不产生无谓渲染。
      let dark = dark_now()
      if dark == model.sys_dark { (model, @cmd.none) } else { ({ ..model, sys_dark: dark }, @cmd.none) }
    }
  }
}

///|
/// 订阅：视口（阶梯的唯一输入）、键盘（Esc）、**地址变化**（后退/前进/手改地址）。
///
/// ⚠️ "跟随系统亮暗"今天走**轮询**（`@sub.every`）而不是事件 —— 事件通道要动 vendored rabbita（跨仓），
///    本仓先给一条**真的有效**的权宜通道，代价（2 秒粒度）写在那一行旁边。
fn subs(_model : Model, emit : @cmd.Emit[Msg]) -> @sub.Sub {
  @sub.batch([
    @sub.on_resize(fn (v) { emit(Resized(v.width)) }),
    // Esc 关浮层（§4.3）。键盘走**订阅**（不是元素级监听）：浮层没有焦点，
    // 而 `on_key_down` 是文档级的 —— 今天唯一够得着 Esc 的通道。
    @sub.on_key_down(fn (k) { emit(Key(k.key())) }),
    // 地址变了 ⇒ 交给 `update` 解析（它**不写回地址**，见 update 的注释）。
    // ⚠️ 这条**只在 popstate 那一档推**（见 route.mbt 的文件头），首屏那一次靠 `initial` 同步读。
    @sub.on_url_changed(fn (u) { emit(UrlChanged(hash_of_url(u))) }),
    // ⚠️ **权宜通道**：`@sub` 今天**没有媒体查询订阅**（要加得动 vendored rabbita = 跨仓），
    //    所以"系统换了明暗"用 2 秒轮询顶上。代价照写：**粒度 2 秒** + 一条常驻定时器；
    //    真正的事件通道（`prefers-color-scheme` 的 change）留给 moobile 那侧补。
    @sub.every(2000, emit(SysTick)),
  ])
}

// ── 外观 ──────────────────────────────────────────────────────────────────────

///|
