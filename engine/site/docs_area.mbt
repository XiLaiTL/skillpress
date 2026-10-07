///|
/// **文档区（⑪–⑲）与纯链接节（⑳）** —— 这两段是"点击之后"的判据，
/// 与 `checks.mbt` 里"首屏"那一段分开（一个文件一件事）。
///
/// ⚠️ 每一条前面都先确认"点到了"：`click_text` 返回 false 时用一条
///    `check(false, 找到…)` 顶掉它后面那条 —— **不许静默跳过**
///    （旧实现踩过"失败分支把 3 条判据静默跳过、总数 19 不是 22"那次）。

///|
/// 取路径的目录部分（旧实现 `dirname`）。
pub fn dir_of(path : String) -> String {
  match path.rev_find("\\") {
    Some(i) => path[:i].to_owned()
    None =>
      match path.rev_find("/") {
        Some(i) => path[:i].to_owned()
        None => path
      }
  }
}

///|
/// ⑪–⑲：换到文档模式之后的那一批。
pub async fn run_docs_area(ctx : Ctx, secs : Array[Sec], all : Array[Doc]) -> Unit raise {
  let cdp = ctx.cdp
  let r = ctx.results
  let _ = secs

  // ── ⑪ 进入书架页（正文换成书架：第一份 skill 的摘要那一行）──────────────────
  //
  // ⚠️ 2026-10-07 换血：旧断言点的是「文档 / SKILL」那个模式切换（D3 之后退休），
  //    探针用的是 **slug**（而 slug 在**侧栏**里也有 ⇒ "等它出现"这条其实分辨不出
  //    "正文换了没有"）。现在入口是顶栏的「书架」，探针用**摘要**（书架页那一行才渲染它）。
  let first_slug = if all.length() > 0 { all[0].slug } else { "" }
  let shelf_probe = if all.length() > 0 { take(plain(all[0].desc), 18) } else { "" }
  let entered = shelf_probe != "" && wait_text(cdp, shelf_probe, 40)
  r.check(
    entered,
    "点「书架」后进入书架页（正文列出全部 skill 与它们的摘要）",
    if entered {
      take(shelf_probe, 24)
    } else if first_slug != "" {
      "书架页没出现第一份 skill 的摘要（" + first_slug + "）"
    } else {
      "语料里一份 skill 都没有"
    },
  )

  let dt = body_text(cdp)

  // ── ⑫ 侧栏列出全部 skill ────────────────────────────────────────────────
  let missing : Array[String] = []
  for d in all {
    // ⚠️ 找的是 **title**（读者看得见的那一行），不是 slug —— 理由见 `Doc.title` 的注释
    if !dt.contains(d.title) {
      missing.push(d.title)
    }
  }
  r.check(
    missing.length() == 0,
    "侧栏列出全部 " + all.length().to_string() + " 个 skill",
    if missing.length() > 0 { "缺：" + join_with(missing, "、") } else { "" },
  )

  // ── ⑬ 每个 skill 都带一行摘要 ───────────────────────────────────────────
  let desc_hit : Array[String] = []
  for d in all {
    if d.desc != "" && dt.contains(take(plain(d.desc), 18)) {
      desc_hit.push(d.slug)
    }
  }
  let desc_missing : Array[String] = []
  for d in all {
    if !arr_has(desc_hit, d.slug) {
      desc_missing.push(d.slug)
    }
  }
  r.check(
    desc_hit.length() == all.length(),
    "侧栏每个 skill 都带一行摘要（不是光秃秃的名字）",
    "命中 " + desc_hit.length().to_string() + "/" + all.length().to_string() +
    (if desc_hit.length() < all.length() {
      "；缺：" + join_with(desc_missing, "、")
    } else {
      ""
    }),
  )

  // ── ⑭ 树在左、正文在右 ─────────────────────────────────────────────────
  let geo = if first_slug != "" { docs_geo(cdp, first_slug) } else { None }
  let geo_ok = match geo {
    Some(g) => g.side_x + 100 < g.pane_x
    None => false
  }
  r.check(
    geo_ok,
    "文档区里树在左、正文在右（侧栏没被挤走）",
    match geo {
      Some(g) =>
        "侧栏 x=" + g.side_x.to_string() + "，正文 x=" + g.pane_x.to_string()
      None => "找不到侧栏或正文"
    },
  )

  // ── ⑮⑯⑰ 点第 2 个 skill ───────────────────────────────────────────────
  if all.length() >= 2 {
    let second = all[1]
    let b = find_center(cdp, "div,button", second.title, false)
    match b {
      Some(pt) => {
        cdp.click_at(pt.x, pt.y)
        let swapped = wait_raw(cdp, take(second.when, 24), 40)
        r.check(
          swapped,
          "点第 2 个 skill 后正文换成它（" + second.slug + "）",
          if swapped { "" } else { "点了没反应 —— 事件通道或 update 有问题" },
        )
        let hl = code_blocks(cdp)
        r.check(
          hl.boxes > 0 && hl.colors >= 3,
          "代码块里有高亮（不止一种颜色 —— 上色链路没断）",
          if hl.boxes > 0 {
            hl.boxes.to_string() + " 个代码块，最花的那个 " + hl.colors.to_string() + " 种颜色"
          } else {
            "页面上没有代码块"
          },
        )
        // 渲染出来的代码块 vs 内容源：**逐字**比（上色把代码切成几十个 span，
        // "少了一个空格/换行"编译器不拦、控制台不报，只有对着源比才看得见）
        let src_file = @gates.join_path(@gates.join_path(ctx.root, second.slug), "SKILL.md")
        let src_blocks = fenced_blocks(ctx.live_host.read(src_file))
        // ⚠️ 判"逐字一致"用的是"**渲染出来的块里包含源码**"（2026-10-07 改）：
        //    代码块那个容器里除了代码，还有**工具条那一行**（语言标签 + 「复制」），
        //    所以整块的 `innerText` 不会等于源码。旧写法要求**完全相等** ⇒ 一条都命中不了
        //    （实测 0/2，看着像"span 切分把代码改了"，其实代码一个字没错）。
        //    "包含"仍然是**逐字**的：源码在渲染结果里原样出现，少一个空格都不行。
        let hit : Array[String] = []
        for sb in src_blocks {
          let want = norm(sb)
          let mut found = false
          for t in hl.texts {
            if t.contains(want) {
              found = true
            }
          }
          if found {
            hit.push(sb)
          }
        }
        r.check(
          src_blocks.length() > 0 && hit.length() == src_blocks.length(),
          "渲染出来的代码块与内容源逐字一致（" + hit.length().to_string() + "/" +
          src_blocks.length().to_string() + "）",
          if src_blocks.length() == 0 {
            "(这份 skill 里没有代码块)"
          } else if hit.length() == src_blocks.length() {
            "含：" + take(norm(src_blocks[0]), 34) + "…"
          } else {
            "对不上 —— span 切分把代码改了"
          },
        )
      }
      None => r.check(false, "找到第 2 个 skill 的列表项（" + second.slug + "）", "")
    }
  }

  // ── ⑱⑲ 侧栏树：展开 → 点子页 ──────────────────────────────────────────
  let mut with_kid : Doc? = None
  for d in all {
    if with_kid is None && d.kids.length() > 0 {
      with_kid = Some(d)
    }
  }
  match with_kid {
    Some(wk) => {
      let kid = wk.kids[0]
      // ⚠️ **展开是双态的**（2026-10-07 换血）：新 IA 会把"正在读的那一份"**自动展开**
      //    （目录挂在当前文件下面）⇒ 旧断言"点一下箭头就该露出子页"会**把已经展开的节点收起来**，
      //    然后报"箭头点了没反应"（实测：正是这么红的）。
      //    改成**先读当前状态**：已经开了就点一下**收起**（顺带把"收起"也验了，比旧断言更强），
      //    然后再点开。两端都不是"假设"，而是**量出来的**。
      let open_now = wait_raw(cdp, kid.probe, 2)
      let arrow = arrow_box(cdp, wk.title)
      match arrow {
        Some(pt) => {
          if open_now {
            cdp.click_at(pt.x, pt.y)
            let hid = !wait_raw(cdp, kid.probe, 20)
            r.check(
              hid,
              "收起 " + wk.title + " 后它的子页从树里消失（" + kid.probe + "）",
              if hid { "" } else { "点箭头没能收起 —— 展开/收起是同一个开关吗" },
            )
            // 位置会随收起而变：重新取一次箭头
            match arrow_box(cdp, wk.title) {
              Some(p2) => cdp.click_at(p2.x, p2.y)
              None => r.check(false, "收起后重新找到 " + wk.title + " 的展开箭头", "")
            }
          } else {
            cdp.click_at(pt.x, pt.y)
          }
          // ⚠️ 等的是子页**在界面上显示的名字**（`kid.probe` = frontmatter title → H1 → 文件名）：
          //    旧写法等的是 `kid.name`（**文件名**），而那只有"没有 title/H1 的子页"才渲染得到 ——
          //    这份语料里子页都有标题 ⇒ 旧写法会**假红**。
          let shown = wait_raw(cdp, kid.probe, 30)
          r.check(
            shown,
            "展开 " + wk.title + " 后露出它的子页（" + kid.probe + "）",
            if shown { "" } else { "箭头点了没反应" },
          )
          let kb = kid_box(cdp, kid.probe)
          match kb {
            Some(kp) => {
              cdp.click_at(kp.x, kp.y)
              let opened = wait_raw(cdp, kid.probe, 30)
              r.check(
                opened,
                "点子页后正文换成 ref 的内容（" + kid.probe + "）",
                if opened { "" } else { "子页点了没反应" },
              )
            }
            None => r.check(false, "找到子页那一行（" + kid.probe + "）", "")
          }
        }
        None => r.check(false, "找到 " + wk.title + " 的展开箭头", "")
      }
    }
    None => info("没有带子页的 skill —— 跳过树的两条（加一个 references/*.md 就会自动生效）")
  }
}

///|
/// ⑳ 纯链接节：点它应当**直接渲染目标文件**。
///
/// ⚠️ 排在整个流程的**最后**：它会把页面留在文档模式（跳到的那一页），
///    而前面的几何/树那几条都要求干净状态 —— 旧实现实测插在中间会把几何判据带红。
pub async fn run_link_section(ctx : Ctx, secs : Array[Sec]) -> Unit raise {
  let cdp = ctx.cdp
  let r = ctx.results
  let mut link_sec : Sec? = None
  for s in secs {
    if link_sec is None && s.link != "" {
      link_sec = Some(s)
    }
  }
  match link_sec {
    None => info("（首页里没有纯链接节，这一条判据本轮跳过）")
    Some(ls) => {
      // 从官网首屏出发，保证这条判据只测"点那一栏"这一件事
      let _ = click_text(cdp, "首页")
      // 目标解析与引擎**同一套**：先按首页目录相对、再按内容根相对
      let target = resolve_link_target(ctx.live_host, dir_of(ctx.home_file), ctx.root, ls.link)
      // ⚠️ 判"落到了哪一页"用**那一页的标题**（2026-10-07 换血）：
      //    旧写法拿目标文件里"第一段够长的正文"当探针，而正文里的段落未必原样渲染
      //    （标题/列表/表格/代码块都可能被排成别的形态）⇒ 探针取不中时看着像"点了没反应"，
      //    其实**页面已经跳对了**（实测：手工点它，hash 与正文标题都对）。
      //    标题是**渲染出来的那一行**（`Doc.title`：frontmatter → H1 → slug），拿它当探针最稳。
      // 目标那一页的 **slug**：从路径里现取（`<…>/<slug>/SKILL.md` 的倒数第二段）。
      // ⚠️ 用**链接原文**当回退（不依赖"目标文件解析成功"）：解析那条路要读盘，
      //    而这条判据只想知道"要点开的是哪一页" —— 实测就是这里拿到空串，
      //    于是探针为空、判据报"没跳"（而 hash 明明已经跳到对的那一页上了）。
      let mut slug = ""
      let cand = if target != "" { target } else { ls.link }
      let segs : Array[String] = []
      for raw in cand.split("/") {
        for s2 in raw.split("\\") {
          let t = s2.to_owned()
          if t != "" && t != "." && t != ".." {
            segs.push(t)
          }
        }
      }
      if segs.length() >= 2 {
        slug = segs[segs.length() - 2]
      }
      let mut probe = ""
      for d in ctx.docs {
        if slug != "" && d.slug == slug {
          probe = d.title
        }
      }
      if probe == "" && target != "" {
        probe = pick_probe(read_source(ctx.live_host.read(target)))
      }
      if click_text(cdp, ls.label) {
        let landed = probe != "" && wait_text(cdp, take(norm(probe), 20), 40)
        r.check(
          landed,
          "点纯链接节「" + ls.label + "」后直接渲染目标文件（" + ls.link + "）",
          if landed {
            take(probe, 24)
          } else {
            // ⚠️ 失败时**把停在哪一页也打出来**：只写"点了没反应"没法查
            //    （这一句正是"没点动"与"跳对了但探针没取中"的分水岭）。
            "没跳到 " + ls.link + "（slug=" + slug + "，探针=" + take(probe, 30) + "）；现在停在 `" +
            (cdp.eval_str("location.hash") catch { _ => "?" }) +
            "`，正文开头：" + take(norm(body_text(cdp)), 30)
          },
        )
      } else {
        r.check(false, "找到纯链接节那一栏「" + ls.label + "」", "")
      }
    }
  }
}
