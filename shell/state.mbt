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
