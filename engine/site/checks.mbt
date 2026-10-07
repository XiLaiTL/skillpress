///|
/// **那 22 条断言**（旧实现 `lib/verify-site.mjs` 的 `main()` 逐条搬运）。
///
/// ⚠️ 每条断言的 **label 与 detail 都是逐字照抄**的：它们会印给人看、也是那条判据的名字。
///    "顺手写得更好"等于把对照物的口径换了 —— 而这一层存在的意义正是"与旧实现同口径"。
///
/// ⚠️ 7 条 `check(false, …)` 是**失败分支**（找不到元素时用它顶掉后面几条），
///    它们**不在 22 条里**：22 = 29 个检查点 − 7 个失败分支，也就是"一切绿灯、分支齐全"
///    时实际执行的那 22 次。所以跑完的总数**本身就是读数**（少了就是有分支被静默跳过）。

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
/// 主流程：22 条断言，顺序与旧实现一致。
pub async fn run_flow(ctx : Ctx) -> Unit raise {
  let cdp = ctx.cdp
  let r = ctx.results
  let secs = ctx.secs
  let all = ctx.docs

  // 等 React 挂载（旧实现：等到正文里出现「文档 / SKILL」，最多 30s / 250ms 一次）
  let mut waited = 0
  while waited < 30000 {
    let t = body_text(cdp) catch { _ => "" }
    if t.contains("文档 / SKILL") {
      break
    }
    @async.sleep(250)
    waited = waited + 250
  }
  @async.sleep(400)

  let body_snapshot = body_text(cdp)

  // ── ① 顶栏：首页 + 每个 ## 一栏 ───────────────────────────────────────────
  let miss_sections : Array[String] = []
  for s in secs {
    if !body_snapshot.contains(s.label) {
      miss_sections.push(s.label)
    }
  }
  let sec_labels : Array[String] = []
  for s in secs {
    sec_labels.push(s.label)
  }
  r.check(
    miss_sections.length() == 0,
    "顶栏列出首页 + 全部 " + secs.length().to_string() + " 个分栏（分栏 = 首页 README 的 ##）",
    if miss_sections.length() > 0 {
      "缺：" + join_with(miss_sections, "、")
    } else {
      join_with(sec_labels, " ｜ ")
    },
  )

  // ── ② 顶栏有「首页」 ──────────────────────────────────────────────────────
  r.check(body_snapshot.contains("首页"), "顶栏有「首页」这一条", "")

  // ── ③ 顶栏有换模式的「文档 / SKILL」（按元素整条文本查）────────────────────
  let has_docs = has_docs_tab(cdp)
  r.check(
    has_docs,
    "顶栏有换模式的「文档 / SKILL」这一条（按**元素整条文本**查，不是整页子串）",
    "",
  )

  // `--shot` 只在这一刻截（**图不参与判据**）
  save_shot(ctx)

  // ── ④ 顶栏分栏排在同一行 ──────────────────────────────────────────────────
  let nav_labels : Array[String] = ["首页"]
  for s in secs {
    nav_labels.push(s.label)
  }
  let nav = nav_ys(cdp, nav_labels)
  let mut same_row = false
  let mut nav_detail = "有分栏在页面上找不到"
  match nav {
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

  // ── ⑧⑨ 点一个有探针的分栏 ───────────────────────────────────────────────
  let mut sec2 : Sec? = None
  let mut i = 1
  while i < secs.length() {
    if sec2 is None && secs[i].probe != "" {
      sec2 = Some(secs[i])
    }
    i = i + 1
  }
  if sec2 is None && secs.length() >= 2 {
    sec2 = Some(secs[1])
  }
  match sec2 {
    Some(s2) => {
      if click_text(cdp, s2.label) {
        let swapped = wait_text(cdp, take(norm(s2.probe), 20), 40)
        r.check(
          swapped,
          "点分栏「" + s2.label + "」后正文换成那一节",
          if swapped { take(s2.probe, 24) } else { "点了没反应 —— 事件通道或 update 有问题" },
        )
        let still = home_probe != "" &&
          norm(body_text(cdp)).contains(take(norm(home_probe), 24))
        r.check(still == false, "切到某一栏后首屏引言退出正文（一次只显示一节，不是滚动）", "")
      } else {
        r.check(false, "找到分栏「" + s2.label + "」的那一条", "")
      }
    }
    None => ()
  }

  // ── ⑩ 点「首页」回到官网首屏 ─────────────────────────────────────────────
  if home_probe != "" {
    let _ = click_text(cdp, "首页")
    let back = wait_text(cdp, take(norm(home_probe), 24), 40)
    r.check(back, "点「首页」回到官网首屏", "")
  }

  // ── ⑪-⑲ 文档区 ──────────────────────────────────────────────────────────
  if has_docs {
    if click_text(cdp, "文档 / SKILL") {
      run_docs_area(ctx, secs, all)
    } else {
      r.check(false, "点到顶栏的「文档 / SKILL」", "")
    }
  } else {
    r.check(false, "没有「文档 / SKILL」这一条 —— 后面的文档区判据都做不了", "")
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
