// shell/route.mbt —— URL 路由：**解析 / 生成 / 两个 I/O 口子**（DESIGN-site.md §2.2）。
//
// ## 方案（唯一口径，别处不许再拼字符串）
//
//     #/                        首页
//     #/shelf/                  书架
//     #/s/<slug>/               主题页（某一份 skill 的主文档）
//     #/s/<slug>/<kid-name>/    子页（references/ 或 scripts/）
//
// **URL 只用机器名**（`slug` / `name`），界面上的名字一律中文（§2.3）——
// 所以这个文件里出现的字符串都是"机器那一侧"的，中文名一个都不该有。
//
// ## ⚠️ 为什么"首屏要同步读一次"（这条是实测出来的，不是设计洁癖）
//
// `on_url_changed` 只在 **popstate** 那一档推（改 hash / 后退 / 前进 / 点同文档 `<a>` 都推），
// 而 **`pushState` / `replaceState` 不推、首屏也不推** ⇒ **只订它，"进来的时候我在哪"永远拿不到**。
// 所以 `initial` 必须用 `url_now()` **同步读一次**地址栏（与视口那条 `current_viewport()` 同款理由）。
//
// ## ⚠️ 一个**能力缺口**（诚实记账，别当成"已经用上新 API 了"）
//
// `PLAN-ui.md §13.6` 写的是用 `@sub.current_url()`。但**本站今天钉的是 `moobile@0.5.0`**
// （`.mooncakes/XiLaiTL/moobile`），那一版**没有** `current_url()`（它是本地 moobile 仓今天新加的）。
// 0.5.0 里有的是：`@dom.window().current_url()` / `push_url()`，以及 `on_url_changed` 的装载器
// —— 装载器在 web 上**自己挂 `popstate`** 并读地址栏（`vendor/rabbita/sub/sub.mbt` 的 `UrlChanged` 分支）。
// 所以这里走的是**同一条 DOM 路**（就是它内部那一条），而不是另造一条。
// ⇒ 依赖抬版之后，只要把 `url_now()` 换成 `@sub.current_url()`、`push_url_cmd` 换成 `@nav.push_url`，
//    其余（解析/生成的纯逻辑 + 接线）一行不用动。
//
// ⚠️ **不用 `@nav.push_url`**：0.5.0 里 `rabbita/nav` 的 op **没有任何宿主实现**
//    （全仓 `moon.pkg` 零引用）⇒ 调它是个**静默 no-op**，正是本仓最忌讳的"假通道"。
//
// ## 两端差异照写
//
// `@cmd.host_has_dom()` 为假（RN / SSR）时：读不到地址栏 ⇒ 回落首页（**不猜**）；
// 写回地址也无处可写 ⇒ 那次导航**只是不写地址**，界面照常切页（不是崩、也不是假装写了）。

///|
/// 解析结果：四类页面各一档，另有一档"这个地址本站没有"。
///
/// ⚠️ `Doc` 带的是 `(kind, i, k)` —— 与 `Model.sel` 同一套下标，别在这里换一套编号。
priv enum Route {
  AtHome
  AtShelf
  AtDoc(Int, Int, Int)
  At404
}

///|
/// 去掉开头的 `#`（没有也照收）。
///
/// 为什么不用 `@url.parse`：它要一个**完整 URL**（`scheme://host/...`），而我们这里处理的是
/// hash 片段；`url_now()` 给的是整条 href，取 `#` 之后那一段就够了（少一次可失败的解析）。
fn strip_hash(raw : String) -> String {
  if raw.has_prefix("#") {
    raw[1:].to_owned()
  } else {
    raw
  }
}

///|
/// 把整条 href 归成"hash 那一段"：取**第一个** `#` 之后的内容（没有 `#` ⇒ 空串）。
///
/// ⚠️ 用 `find` 而不是 `split('#')`：hash 里再出现 `#`（比如 `#/s/a/b#c`）时，
///    切分出来的第二段就丢了后半截 —— 取"第一个 # 之后全部"才是地址栏的语义。
fn hash_of_href(href : String) -> String {
  match href.find("#") {
    Some(i) => href[i:].to_owned()
    None => ""
  }
}

///|
/// 按 `/` 切成非空段（`#/s/a//b/` 这种多余斜杠不会造出空段）。
fn segments(hash : String) -> Array[String] {
  let out : Array[String] = []
  for sv in strip_hash(hash).split("/") {
    let s = sv.to_owned()
    if s != "" {
      out.push(s)
    }
  }
  out
}

///|
/// 按名字找下标（找不到给 `-1`）—— `docs` / `kids` 都是小数组，线扫就够。
fn index_of_slug(docs : Array[Doc], slug : String) -> Int {
  let mut found = -1
  for i = 0; i < docs.length(); i = i + 1 {
    if docs[i].slug == slug {
      found = i
    }
  }
  found
}

///|
/// `#/s/<slug>/<kid>` 那一支：slug 认不出、或 kid 名认不出 ⇒ `NotFound`（**不是**回落首页）。
///
/// 为什么认不出是 404 而不是首页：地址栏是**可分享**的（§2.2）——把 `#/s/typo/` 悄悄送去首页，
/// 分享出去的人会以为"这个站只有首页"，而链接其实早就坏了。
fn route_doc(slug : String, rest : ArrayView[String], docs : Array[Doc]) -> Route {
  let i = index_of_slug(docs, slug)
  if i < 0 {
    return At404
  }
  match rest {
    [] => AtDoc(1, i, 0)
    [kid_name, ..] => {
      let kids = docs[i].kids
      let mut k = -1
      for j = 0; j < kids.length(); j = j + 1 {
        if kids[j].name == kid_name {
          k = j
        }
      }
      if k < 0 { At404 } else { AtDoc(2, i, k) }
    }
  }
}

///|
/// 解析一个 hash（`#/…` 或裸 `#` 都收）。
///
/// ⚠️ 多出来的段（`#/s/a/b/c`）**不是**"忽略就算"：今天没有第三层，多一段只可能是地址写错或
///    版本不一致 ⇒ 明确 404，别猜一个"最接近的页"出来。
fn route_of_hash(hash : String, docs : Array[Doc]) -> Route {
  match segments(hash) {
    [] => AtHome
    ["shelf", ..] => AtShelf
    ["s", slug, ..rest] => route_doc(slug, rest, docs)
    _ => At404
  }
}

///|
/// 反过来：`Model` 的那个状态该写成什么地址。
///
/// `page_404` 也归到 `#/` —— 但**实际不会用到**：404 是"地址认不出"的结果，
/// 那时我们**不写回地址**（写回就把用户输错的那条地址从历史里抹掉了，他没法改）。
fn hash_of(page : Int, sel : Sel, docs : Array[Doc]) -> String {
  if page == page_shelf {
    "#/shelf/"
  } else if page == page_doc && sel_valid(sel, docs) {
    let d = docs[sel.i]
    if sel.kind == 2 {
      "#/s/" + d.slug + "/" + d.kids[sel.k].name + "/"
    } else {
      "#/s/" + d.slug + "/"
    }
  } else {
    "#/"
  }
}

///|
/// **同步读一次**地址栏（首屏的真源）。
///
/// 取不到（没有 DOM）⇒ 空串 ⇒ 调用方回落首页 —— **不猜**（与 `initial_vw()` 同一条规矩）。
fn url_now() -> String {
  if @cmd.host_has_dom() {
    @dom.window().current_url()
  } else {
    ""
  }
}

///|
/// 把模型里的页面状态**写回地址**（`pushState`：加一条历史，且**不触发 popstate**）。
///
/// ⚠️ `pushState` 不触发 popstate 是**好事**：这次导航的模型已经由同一个 `update` 改好了，
///    再被推一次就会多绕一圈；而后退/前进是浏览器的动作，那时 popstate 照推（订阅在管）。
/// ⚠️ 历史条目**只在真的换了页**时才加 —— 所以调用点必须只在实际导航的分支里返回它，
///    别在 `Resized` / `SetTheme` / `Toggle` 这些分支里也返回（否则点一下主题就多一条历史，
///    用户按一次后退会发现"什么都没发生"）。
fn push_url_cmd(hash : String) -> @cmd.Cmd {
  @cmd.custom_cmd(_ => {
    if @cmd.host_has_dom() {
      @dom.window().push_url(hash)
    }
  })
}

///|
/// 订阅那边递过来的 URL → hash（`on_url_changed` 的载荷是整条 URL）。
fn hash_of_url(u : @url.Url) -> String {
  match u.fragment {
    Some(f) => "#" + f
    None => "#/"
  }
}

///|
/// 解析结果 → `(页面种类, 选中页)`（`update` 与 `initial` 共用一处，别各写一份）。
///
/// `keep`：这一档不需要改 `sel` 时原样保留（首页/书架/404 都不动它 ——
/// 用户从某一页去书架再回来，`sel` 还在原来那份上）。
fn state_of_route(r : Route, keep : Sel) -> (Int, Sel) {
  match r {
    AtHome => (page_home, keep)
    AtShelf => (page_shelf, keep)
    AtDoc(kind, i, k) => (page_doc, { kind, i, k })
    At404 => (page_404, keep)
  }
}
