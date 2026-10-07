// shell/update.mbt —— **状态迁移**（`Msg` → 新 `Model` + 要跑的命令）。
//
// 为什么单独一份（2026-10-07）：`state.mbt` 撞上了 400 行预算（`tools/line-budget.sh`）。
// 拆的口径是**状态与迁移分开**：`state.mbt` 管"有哪些状态、初始长什么样"，
// 这一份管"收到消息之后怎么变"（含"谁写地址、谁不写"那条规矩 —— 它最容易出难查的 bug），
// 以及**订阅什么**（`subs`：哪些具名节点要跟读、哪些按键要听 —— 它也是"迁移"的一环：
// 订阅的开关跟着状态走，两件事分在两份文件里迟早对不上）。

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
