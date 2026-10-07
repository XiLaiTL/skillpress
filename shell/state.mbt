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
///|
/// **待兑现的滚动**（跨页导航用）：切页与渲染之间隔着一次 React 提交 ⇒ 不能在同一次 update 里滚
/// （会滚到旧页面的同号锚点上）。做法：记下"要去哪"，由 `Frame` 一帧一帧地问"新页面挂上了吗"。
priv enum Pending {
  /// 没有待办
  NoPending
  /// 切页之后**回到顶部**（任何一次换页都该这样 —— 否则新页面停在上一页滚到的位置）
  ToTop
  /// 切页之后跳到**第几节**（`heading_anchor(i)`）
  ToSection(Int)
} derive(Eq)

///|
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
  /// **跟读高亮**：现在读到第几节（`-1` = 还没量到 / 这一页没有分节）。
  active : Int
  /// **上一次点"复制"的是第几个代码块**（`-1` = 还没复制过）。
  /// 用途只有一个：把那个按钮的文案换成「已复制」。⚠️ 这是**乐观显示** ——
  /// `navigator.clipboard.writeText` 是 Promise、可能被拒，而我们**拿不到回执**
  /// （`@cmd` 是同步的；`@js.Promise` 在钉住的版本里没有 then/catch）⇒ 失败只打控制台。见 `sub/clipboard_action.mbt`。
  copied_at : Int
  /// **搜索浮层开着吗**（对标表 #12）。⚠️ 索引只在它开着时才算（`search.mbt` 文件头第 1 条）。
  search_open : Bool
  /// 搜索框里的当前输入（受控 —— `@html.input` 的 `value` 就是它）。
  query : String
  /// **待兑现的滚动**（见 `Pending`）
  pending : Pending
  /// 为兑现上面那个锚点**已经等了几帧**（`pending = -1` 时无意义）。
  /// 有上限：等不到就让**它报错**，而不是无限等下去（见 `Frame`）。
  pending_frames : Int
  /// 每一节的**绝对偏移**（相对内容区的内容坐标系，见 `toc.mbt` 的 `section_offsets`）。
  /// ⚠️ 它只是一个**缓存**：只在"第一次 / 跨节 / 换了页"时重锚，滚动时用纯算术（不碰 DOM）。
  offsets : Array[Double]
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
  /// 键盘按下：`(键名, ctrl 或 meta 按着)` —— 后者用来认 ⌘K / Ctrl+K（打开搜索）。
  /// ⚠️ 载荷里**必须带上修饰键**：只给键名的话 `k` 与 `⌘K` 分不开。
  Key(String, Bool)
  /// 打开搜索浮层（顶栏那条 nav 点它）
  SearchOpen
  /// 关掉搜索浮层（遮罩 / Esc）
  SearchClose
  /// 搜索框的输入变了
  SearchInput(String)
  /// 点了一条搜索结果：`(kind, i, k, 锚点下标)` —— 锚点 `-1` = 只切页不跳节
  HitGo(Int, Int, Int, Int)
  /// **一帧到了** —— 用来兑现 `pending` 那个锚点（跨页滚动必须等新页面渲染出来）
  Frame
  /// 点了某个代码块的「复制」：`(第几个, 正文)` —— 正文直接跟着载荷走，
  /// 免得"复制的内容"要去 DOM 里再捞一次（那样就得跟渲染形状绑死）。
  CopyCode(Int, String)
  /// 点了正文里一条**外部**链接（站内链接走 `Go`，见 `inline.mbt` 的判法）：
  /// 交给 `url` 能力的动作通道开新窗口（`@sub.open_url`）。
  LinkOut(String)
  /// **点目录某一条**：滚到正文里那一节的锚点（下标 = 目录里的第几条，从 0 数）。
  /// 动作由 `@sub.scroll_to_node` 发 —— 见 `shell/toc.mbt` 的账。
  TocTo(Int)
  /// **内容区滚了**（`@sub.on_node_scroll("prose", …)`，载荷 = 它当前的 `scrollTop`）。
  /// 跟读高亮就靠它：滚动时**纯算术**算"现在读的是哪一节"（见 `toc.mbt` 的 `active_of`）。
  ProseScrolled(Double)
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
    // 跟读高亮：装载后由 `on_node_scroll` **补的那一次**填上（订阅会先推一次当前 scrollTop），
    // 所以这两格一开始就是空的，不用同步读 DOM（首屏那会儿 DOM 里还没有东西）。
    active: -1,
    offsets: [],
    copied_at: -1,
    search_open: false,
    query: "",
    pending: NoPending,
    pending_frames: 0,
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
      // ⚠️ 换页必须清掉跟读高亮的缓存（`active` / `offsets`）：它们是**按这一页的小节**量的，
      //    留着会拿上一页的偏移表算这一页 —— 症状是"高亮停在一个不存在的小节上"。
      let next = { ..model, page: page_home, active: -1, offsets: [], pending: ToTop, pending_frames: 0, copied_at: -1 }
      (next, push_url_cmd(hash_of(next.page, next.sel, ctx.docs)))
    }
    Shelf => {
      let next = { ..model, page: page_shelf, active: -1, offsets: [], pending: ToTop, pending_frames: 0, copied_at: -1 }
      (next, push_url_cmd(hash_of(next.page, next.sel, ctx.docs)))
    }
    Go(kind, i, k) => {
      // 进到某一页 ⇒ 那一份自动展开（DESIGN §9 第 3 条"只展开当前那一份"）。
      // 用户手动收起的那些不动 —— 这是"默认"，不是"强制"。
      let next : Array[Bool] = []
      for j = 0; j < model.open.length(); j = j + 1 {
        next.push(if j == i { true } else { model.open[j] })
      }
      let moved = { ..model, page: page_doc, sel: { kind, i, k }, open: next, active: -1, offsets: [], pending: ToTop, pending_frames: 0, copied_at: -1 }
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
      // 地址变了也可能换了页 ⇒ 同样清掉高亮缓存（见 `Home` 那条注释）
      ({ ..model, page, sel, open: next, active: -1, offsets: [], pending: ToTop, pending_frames: 0, copied_at: -1 }, @cmd.none)
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
    ProseScrolled(top) => {
      let toc = toc_for(ctx, model)
      if toc.length() == 0 {
        // 这一页没有分节（书架 / 404）⇒ 不量、不高亮
        (model, @cmd.none)
      } else if model.offsets.length() != toc.length() {
        // 第一次（或换了页/节数变了）：**量一遍**每一节的绝对偏移
        let offs = section_offsets(prose_node(), toc.length())
        ({ ..model, offsets: offs, active: active_of(offs, top) }, @cmd.none)
      } else {
        let a = active_of(model.offsets, top)
        if a == model.active {
          // ⚠️ **值没变就返回同一个 model** —— 滚动事件是高频的（一次拖动能上百个），
          //    每次都造新 Model 会让整棵树重渲染。与 `hosttheme` 那条轮询同一条纪律。
          (model, @cmd.none)
        } else {
          // 跨节了（或尺寸变了导致偏移过期）：重锚一次 —— 顺带把"字体/主题/窗口变了"
          // 这类偏移漂移自愈掉。
          let offs = section_offsets(prose_node(), toc.length())
          ({ ..model, offsets: offs, active: active_of(offs, top) }, @cmd.none)
        }
      }
    }
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
    CopyCode(idx, text) => ({ ..model, copied_at: idx }, @sub.copy_text(text))
    LinkOut(url) => (model, @sub.open_url(url))
    SearchOpen => ({ ..model, search_open: true }, @cmd.none)
    SearchClose => ({ ..model, search_open: false }, @cmd.none)
    SearchInput(q) => ({ ..model, query: q }, @cmd.none)
    HitGo(kind, i, k, anchor) => {
      // 与 `Go` 同一套：进某一页 ⇒ 那一份自动展开；同时**关掉浮层**并把锚点记成待办。
      let next : Array[Bool] = []
      for j = 0; j < model.open.length(); j = j + 1 {
        next.push(if j == i { true } else { model.open[j] })
      }
      let moved = {
        ..model,
        page: page_doc,
        sel: { kind, i, k },
        open: next,
        search_open: false,
        pending: if anchor >= 0 { ToSection(anchor) } else { ToTop },
        pending_frames: 0,
        active: -1,
        offsets: [],
      }
      (moved, push_url_cmd(hash_of(moved.page, moved.sel, ctx.docs)))
    }
    Frame =>
      // ⚠️ **为什么不能"切页那次 update 里顺手滚一下"**：滚动命令跑的时候新页面**还没被 React 提交**
      //    ⇒ 会滚到**旧页面的同号锚点**上（锚点 id `sec-<i>` 每页都重名），而且是**静默**的。
      //    ⚠️ 也**不能**用"锚点出现没有"当信号（同理：它在旧页面上也存在）⇒ 用**页专属**的节点名。
      //    做法：一帧一帧地问"目标页挂上了吗"，挂上才滚；等够帧数还没挂上 ⇒ **报错**（不无限等）。
      if model.pending is NoPending {
        (model, @cmd.none)
      } else if @sub.node_exists(page_node(model.page, model.sel)) {
        // 新页面**挂上了** ⇒ 兑现：回顶 or 跳到某一节（都靠 `scroll_to_node`；
        // 回顶就是"把这一页的根滚到容器上沿"，等价于 scrollTop = 0）
        let cmd = match model.pending {
          ToTop => @sub.scroll_to_node(page_node(model.page, model.sel), block="start")
          ToSection(a) => @sub.scroll_to_node(heading_anchor(a), block="start")
          NoPending => @cmd.none
        }
        ({ ..model, pending: NoPending, pending_frames: 0 }, cmd)
      } else if model.pending_frames >= 60 {
        let what = match model.pending {
          ToTop => "回顶部"
          ToSection(a) => "第 " + a.to_string() + " 节"
          NoPending => "（无）"
        }
        ({ ..model, pending: NoPending, pending_frames: 0 }, @cmd.custom_cmd(fn(_) {
          abort(
            "shell: 等新页面（" +
            page_node(model.page, model.sel) +
            "）挂上，等了 60 帧（约 1 秒）还没出现 ⇒ 不滚了（本来要去：" +
            what +
            "）。" +
            "要么这一页渲染不出来，要么页面根上的节点名没跟上（见 toc.mbt 的 page_node）。",
          )
        }))
      } else {
        ({ ..model, pending_frames: model.pending_frames + 1 }, @cmd.none)
      }
    Key(k, mod_) =>
      if k == "Escape" {
        // Esc 一次关一层：**先搜索浮层、再窄屏 sheet**（搜索是后画的，按"最上面那层先关"来）。
        if model.search_open {
          ({ ..model, search_open: false }, @cmd.none)
        } else {
          ({ ..model, sheet: -1, peek: 0 }, @cmd.none)
        }
      } else if mod_ && (k == "k" || k == "K") {
        // ⌘K / Ctrl+K（`mod_` = ctrl 或 meta 按着 —— 载荷里带了修饰键才认得出，见 Msg::Key）
        ({ ..model, search_open: true }, @cmd.none)
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
fn subs(model : Model, emit : @cmd.Emit[Msg]) -> @sub.Sub {
  let all : Array[@sub.Sub] = [
    @sub.on_resize(fn (v) { emit(Resized(v.width)) }),
    // Esc 关浮层（§4.3）。键盘走**订阅**（不是元素级监听）：浮层没有焦点，
    // 而 `on_key_down` 是文档级的 —— 今天唯一够得着 Esc 的通道。
    @sub.on_key_down(fn (k) { emit(Key(k.key(), k.ctrl_key() || k.meta_key())) }),
    // 地址变了 ⇒ 交给 `update` 解析（它**不写回地址**，见 update 的注释）。
    // ⚠️ 这条**只在 popstate 那一档推**（见 route.mbt 的文件头），首屏那一次靠 `initial` 同步读。
    @sub.on_url_changed(fn (u) { emit(UrlChanged(hash_of_url(u))) }),
    // ⚠️ **权宜通道**：`@sub` 今天**没有媒体查询订阅**（要加得动 vendored rabbita = 跨仓），
    //    所以"系统换了明暗"用 2 秒轮询顶上。代价照写：**粒度 2 秒** + 一条常驻定时器；
    //    真正的事件通道（`prefers-color-scheme` 的 change）留给 moobile 那侧补。
    @sub.every(2000, emit(SysTick)),
    // **内容区的滚动**（跟读高亮那条通道）：载荷 = 那个容器当前的 scrollTop。
    // ⚠️ 它是**订阅**，不是轮询 —— 而且装载后会**先补一次当前值**（moobile 那边特意做的），
    //    所以首屏就有高亮，不必等用户先滚一下。
    @sub.on_node_scroll(prose_node(), fn (v) { emit(ProseScrolled(v)) }),
  ]
  // **只在有待兑现的锚点时**才订"一帧" —— 常驻的 60fps 订阅是白花的（那正是本仓会记的代价）。
  // 它的用途只有一个：跨页跳节时等新页面渲染出来（见 `HitGo` / `Frame`）。
  if not(model.pending is NoPending) {
    all.push(@sub.on_animation_frame(fn (_t) { emit(Frame) }))
  }
  @sub.batch(all)
}

// ── 外观 ──────────────────────────────────────────────────────────────────────

///|
