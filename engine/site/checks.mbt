///|
/// **站点断言**（旧实现 `lib/verify-site.mjs` 的 `main()` 逐条搬来的那 22 条 + 2026-10-07 换血加的一条 = **23 条**）。
///
/// ⚠️ 每条断言的 **label 与 detail 都是逐字照抄**的：它们会印给人看、也是那条判据的名字。
///    "顺手写得更好"等于把对照物的口径换了 —— 而这一层存在的意义正是"与旧实现同口径"。
///
/// ⚠️ 7 条 `check(false, …)` 是**失败分支**（找不到元素时用它顶掉后面几条），
///    它们**不在条数里**：旧口径是 22 = 29 个检查点 − 7 个失败分支，也就是"一切绿灯、
///    分支齐全"时实际执行的那 22 次。所以跑完的总数**本身就是读数**（少了就是有分支被静默跳过）。
///
/// ## ⚠️ 2026-10-07：这一批**换过血**（旧 IA → 新 IA）
///
/// 换血的原因与逐条对照写在 `PLAN.md` 的 **D45**：旧断言判的是 D3 之前那套 IA
/// （"顶栏列出首页 + 全部 5 个分栏"、"换模式的「文档 / SKILL」"、按 slug 找列表项…），
/// 而那套 IA 已经不在了 ⇒ 6 条**永远红**（红得没有信息量，还把真问题淹了）。
/// 换血后判的是**今天这套**：只量 `#topnav` 那一排、认 `Doc.title`、入口是「书架」与首页那张卡、
/// 展开/收起**两态都验**、代码块认**结构**不认颜色。读数：**23 条全绿**。

///|
/// 数组里有没有这个字符串（不做 `Array::contains` 的 Eq 假设）。
fn arr_has(items : Array[String], s : String) -> Bool {
  for it in items {
    if it == s {
      return true
    }
  }
  false
}

///|
/// ASCII 小写（给 favicon 那条**大小写不敏感**的过滤用）。
fn lower_ascii(s : String) -> String {
  let out : Array[String] = []
  for ch in s {
    let c = ch.to_int()
    if c >= 65 && c <= 90 {
      out.push(Char::from_int(c + 32).to_string())
    } else {
      out.push(ch.to_string())
    }
  }
  out.join("")
}

///|
/// 这个节标签**开头带序号**吗（`一、` / `（一）` / `1.` 那几种）。
///
/// 用途：断言"带序号的正文标题**不许**原样进顶栏导航"（§2.3：nav 标签 ≤6 字、无序号）。
/// ⚠️ 这里是一份**判据侧**的判定，不是渲染规则的副本 —— 渲染那份在 `shell/topbar.mbt`（它会把序号
///    剥掉再当标签）；判据这份只回答"**这个标签本身**带不带序号"，用来抓"根本没剥就端上来了"。
fn has_ordinal_prefix(label : String) -> Bool {
  let marks : Array[String] = [
    "一、", "二、", "三、", "四、", "五、", "六、", "七、", "八、", "九、", "十、",
    "（一）", "（二）", "（三）", "（四）", "（五）",
    "1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9.",
  ]
  for m in marks {
    if label.has_prefix(m) {
      return true
    }
  }
  false
}

///|
/// 在正文里等一段文字出现**若干次**（每次 100ms、**不归一化**）—— 旧实现那三处手写轮询。
async fn wait_raw(cdp : Cdp, sub : String, tries : Int) -> Bool raise {
  let mut i = 0
  while i < tries {
    @async.sleep(100)
    let t = body_text(cdp) catch { _ => "" }
    if t.contains(sub) {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// 主流程：23 条断言，顺序与旧实现一致。
pub async fn run_flow(ctx : Ctx) -> Unit raise {
  let cdp = ctx.cdp
  let r = ctx.results
  let secs = ctx.secs
  let all = ctx.docs

  // 等 React 挂载。
  // ⚠️ 屏障用的字要挑**新 IA 里稳定的结构性条目**：旧实现等的是「文档 / SKILL」，
  //    而那个模式切换在 D3 之后**退休了** —— 不等它就得空等到超时（30 秒白等，读数还看不出来）。
  //    现在等的是顶栏那条「搜索」（任何一站都有，且它是**顶栏里**的整条文本，正文同名文字不算）。
  let mut waited = 0
  while waited < 30000 {
    let mounted = topbar_has(cdp, "搜索") catch { _ => false }
    if mounted {
      break
    }
    @async.sleep(250)
    waited = waited + 250
  }
  @async.sleep(400)

  let body_snapshot = body_text(cdp)

  // ── ① 顶栏：结构性的三条（首页 / 书架 / 搜索）+ 首页里**有目标**的那几节 ──────
  //
  // ⚠️ 这一组是 2026-10-07 **换过血的**（旧 IA 的断言在新 IA 上必然红，而红得没有信息量）：
  //    · 旧 ①：「顶栏列出首页 + **全部 5 个分栏**」—— 新 IA 里**只有带目标的节**进导航
  //      （没有目标的节是首页门户的正文，`topbar.mbt` 的 `nav_items` 写着这条规矩），
  //      而且**序号要剥掉**（§2.3：nav 标签 ≤6 字、无序号）⇒ 拿正文标题逐字去顶栏找，
  //      找到才怪。旧断言因此**永远红**，而它想守的东西（"导航有没有跟内容对上"）其实没被守住。
  //    · 旧 ③：「顶栏有换模式的『文档 / SKILL』」—— 那个模式切换随 D3 一起退休，现在是
  //      **顶栏三条 + 书架页**。断言一个不存在的控件，等于给自己发红牌。
  //    ⇒ 换成的三条判据如下（每条都只量 `#topnav` / `#topbar`，不再按整页子串猜）。
  let nav = nav_labels(cdp)
  let structural : Array[String] = ["首页", "书架", "搜索"]
  let miss_struct : Array[String] = []
  for k in structural {
    if !arr_has(nav, k) {
      miss_struct.push(k)
    }
  }
  r.check(
    miss_struct.length() == 0,
    "顶栏列出 首页 / 书架 / 搜索 三条结构性导航（只量 `#topnav` 那一排）",
    if miss_struct.length() > 0 {
      "缺：" + join_with(miss_struct, "、") + "；实到：" + join_with(nav, " ｜ ")
    } else {
      join_with(nav, " ｜ ")
    },
  )

  // ①′ 顶栏里凡**不是**这三条的，都必须来自首页里**有目标**的节；带序号的节标签不许进导航。
  let linked : Array[String] = []
  let ordinal_only : Array[String] = []
  for sec in secs {
    if sec.link != "" {
      linked.push(sec.label)
    } else if has_ordinal_prefix(sec.label) {
      ordinal_only.push(sec.label)
    }
  }
  let extra : Array[String] = []
  for l in nav {
    if !arr_has(structural, l) && !arr_has(linked, l) {
      extra.push(l)
    }
  }
  let leaked : Array[String] = []
  for l in ordinal_only {
    if arr_has(nav, l) {
      leaked.push(l)
    }
  }
  let sec_ok = extra.length() == 0 && leaked.length() == 0 && linked.length() == nav.length() - structural.length()
  r.check(
    sec_ok,
    "顶栏除那三条外**只有**首页里带目标的 " + linked.length().to_string() + " 节（且序号已剥）",
    "导航：" + join_with(nav, " ｜ ") +
    (if extra.length() > 0 { "；多出来的：" + join_with(extra, "、") } else { "" }) +
    (if leaked.length() > 0 { "；带序号的节漏进导航：" + join_with(leaked, "、") } else { "" }),
  )

  // ② 书架有入口（顶栏那条 —— 换模式那个控件的**新家**）
  let has_docs = topbar_has(cdp, "书架")
  r.check(has_docs, "顶栏有进书架页的「书架」这一条（按**元素整条文本**查，不是整页子串）", "")

  // `--shot` 只在这一刻截（**图不参与判据**）
  save_shot(ctx)

  // ── ④ 顶栏分栏排在同一行 ──────────────────────────────────────────────────
  // ⚠️ 标签取的是**DOM 里实测到的那一排**（`nav_labels`），不是"照内容算出来的期望值" ——
  //    这一条量的是**版面**（换行会把它们排到两行），标签该由页面自己说了算。
  let row_labels = nav
  let nav_row = nav_ys(cdp, row_labels)
  let mut same_row = false
  let mut nav_detail = "有分栏在页面上找不到"
  match nav_row {
    Some(ys) => {
      nav_detail = "y = " +
        join_with(ys.map(fn(y) { y.to_string() }), " / ")
      if ys.length() > 0 {
        let mut same = true
        let mut i = 1
        while i < ys.length() {
          if ys[i] != ys[0] {
            same = false
          }
          i = i + 1
        }
        same_row = same
      }
    }
    None => ()
  }
  r.check(same_row, "顶栏的分栏排在**同一行**里（挤成两行是静默的）", nav_detail)

  // ── ⑤ 首屏渲染的是首页源（H1 + 引言）────────────────────────────────────
  let home_probe = ctx.home_probe
  r.check(
    home_probe != "" && norm(body_snapshot).contains(take(norm(home_probe), 24)),
    "首屏渲染的是首页源（" + rel_path(ctx.repo, ctx.home_file) + " 的 H1 + 引言）",
    if home_probe != "" { take(home_probe, 26) } else { "(没从那份 SKILL.md 里取到探针段落)" },
  )

  // ── ⑥ 首屏没有侧栏（认容器底色，不是"skill 名一个都没露"）────────────────
  let sidebar = sidebar_count(cdp)
  r.check(
    sidebar == 0,
    "首屏没有侧栏（左侧树那个容器不在 —— 两个模式是真分开的）",
    if sidebar != 0 { "出现了 " + sidebar.to_string() + " 个侧栏容器" } else { "" },
  )

  // ── ⑦ 行内流：整段装在一个 Text 里、且里面有嵌套 span ─────────────────────
  let inline = if home_probe == "" {
    { found: false, count: 0, spans: 0 }
  } else {
    inline_probe(cdp, home_probe)
  }
  r.check(
    inline.found && inline.spans >= 1,
    "段落里的加粗 / 行内代码嵌在同一个 Text 里（不是各占一行）",
    if inline.found {
      inline.count.to_string() + " 个 Text 命中，嵌套 " + inline.spans.to_string() + " 个 span"
    } else {
      "没有任何一个 Text 装得下整段 —— 片段被铺成兄弟节点了"
    },
  )

  // ── ⑧⑨ 点首页那张「从哪开始」卡片 ⇒ 正文换成第一份 skill ────────────────────
  //
  // ⚠️ 旧 ⑧⑨ 点的是「一个有探针的分栏」——新 IA 里首页**不再逐节渲染正文**
  //    （`home_page` 只画 H1 + 引言 + 统计 + 两张入口卡），分栏只决定顶栏那几条导航。
  //    所以入口换成今天真能到某处的那张卡：「从哪开始」→ 第一份 skill。
  //    探针取那份 skill 的 frontmatter `whenToUse`（**只在文档页上渲染** ⇒ 不会与首页撞车）。
  let first = if all.length() > 0 { Some(all[0]) } else { None }
  match first {
    Some(d0) => {
      if click_text(cdp, "从哪开始") {
        let swapped = d0.when != "" && wait_text(cdp, take(norm(d0.when), 20), 40)
        r.check(
          swapped,
          "点首页那张「从哪开始」卡片 ⇒ 正文换成第一份 skill（" + d0.slug + "）",
          if swapped { take(d0.when, 24) } else { "点了没反应 —— 事件通道或 update 有问题" },
        )
        let still = home_probe != "" &&
          norm(body_text(cdp)).contains(take(norm(home_probe), 24))
        r.check(still == false, "切到那一页后首屏引言退出正文（一次只显示一页，不是滚过去）", "")
      } else {
        r.check(false, "找到首页那张「从哪开始」卡片", "")
      }
    }
    None => r.check(false, "语料里一份 skill 都没有 —— 上面那几条也就没有对象", "")
  }

  // ── ⑩ 点「首页」回到官网首屏 ─────────────────────────────────────────────
  if home_probe != "" {
    let _ = click_text(cdp, "首页")
    let back = wait_text(cdp, take(norm(home_probe), 24), 40)
    r.check(back, "点「首页」回到官网首屏", "")
  }

  // ── ⑪-⑲ 文档区（新 IA 的入口是顶栏那条「书架」）──────────────────────────
  if has_docs {
    if click_text(cdp, "书架") {
      run_docs_area(ctx, secs, all)
    } else {
      r.check(false, "点到顶栏的「书架」", "")
    }
  } else {
    r.check(false, "顶栏没有「书架」这一条 —— 后面的文档区判据都做不了", "")
  }

  // ── ⑳ 纯链接节（**排最后**：它会把页面留在文档模式）──────────────────────
  run_link_section(ctx, secs)

  // ── ㉑ 吸顶 ──────────────────────────────────────────────────────────────
  let stick = stick_probe(cdp)
  r.check(
    stick.why == "" && stick.room > 0 && stick.got > 0 && stick.moved == 0,
    "吸顶：长内容下滚的是正文容器、顶栏不动",
    if stick.why != "" {
      "量不到：" + stick.why
    } else {
      "容器可滚 " + stick.room.to_string() + "px、实际滚了 " + stick.got.to_string() +
      "px，顶栏移动 " + stick.moved.to_string() + "px（整页可滚 " +
      stick.page_room.to_string() + "）"
    },
  )
  reset_scroll(cdp)

  // ── ㉒ 控制台没有 error ─────────────────────────────────────────────────
  let errors = console_errors(cdp)
  let real : Array[String] = []
  for t in errors {
    if !lower_ascii(t).contains("favicon") {
      real.push(t)
    }
  }
  let head : Array[String] = []
  let mut k = 0
  while k < real.length() && k < 3 {
    head.push(real[k])
    k = k + 1
  }
  r.check(
    real.length() == 0,
    "控制台没有 error",
    join_with(head, "  ｜ "),
  )
}
