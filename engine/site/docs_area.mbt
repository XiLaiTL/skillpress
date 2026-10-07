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

  // ── ⑪ 进入文档区（正文换成第一份 skill）──────────────────────────────────
  let first_slug = if all.length() > 0 { all[0].slug } else { "" }
  let entered = if first_slug != "" { wait_text(cdp, first_slug, 40) } else { false }
  r.check(
    entered,
    "点「文档 / SKILL」后进入文档区（正文换成第一份 skill）",
    if entered { "" } else { "换了模式但正文没变" },
  )

  let dt = body_text(cdp)

  // ── ⑫ 侧栏列出全部 skill ────────────────────────────────────────────────
  let missing : Array[String] = []
  for d in all {
    if !dt.contains(d.slug) {
      missing.push(d.slug)
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
    let b = find_center(cdp, "div,button", second.slug, false)
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
        let hit : Array[String] = []
        for sb in src_blocks {
          if arr_has(hl.texts, norm(sb)) {
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
      let arrow = arrow_box(cdp, wk.slug)
      match arrow {
        Some(pt) => {
          cdp.click_at(pt.x, pt.y)
          let shown = wait_raw(cdp, kid.name, 30)
          r.check(
            shown,
            "展开 " + wk.slug + " 后露出它的子页（" + kid.name + "）",
            if shown { "" } else { "箭头点了没反应" },
          )
          let kb = kid_box(cdp, kid.name)
          match kb {
            Some(kp) => {
              cdp.click_at(kp.x, kp.y)
              let opened = wait_raw(cdp, kid.probe, 30)
              r.check(
                opened,
                "点子页后正文换成 ref 的内容（" + kid.name + "）",
                if opened { "" } else { "子页点了没反应" },
              )
            }
            None => r.check(false, "找到子页那一行（" + kid.name + "）", "")
          }
        }
        None => r.check(false, "找到 " + wk.slug + " 的展开箭头", "")
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
      let probe = if target != "" {
        pick_probe(read_source(ctx.live_host.read(target)))
      } else {
        ""
      }
      if click_text(cdp, ls.label) {
        let landed = probe != "" && wait_text(cdp, take(norm(probe), 20), 40)
        r.check(
          landed,
          "点纯链接节「" + ls.label + "」后直接渲染目标文件（" + ls.link + "）",
          if landed {
            take(probe, 24)
          } else {
            "没跳到 " + ls.link + "（点了没反应，或跳错了页）"
          },
        )
      } else {
        r.check(false, "找到纯链接节那一栏「" + ls.label + "」", "")
      }
    }
  }
}
