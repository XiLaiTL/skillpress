///|
/// `--<名字> <值>` 的**全部**出现（`arg_value` 只给第一个，而 `--ignore` 要能重复给）。
fn values_of(rest : Array[String], name : String) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i + 1 < rest.length() {
    if rest[i] == name {
      out.push(rest[i + 1])
    }
    i = i + 1
  }
  out
}

///|
/// 有没有这个开关（不带值的那种：`--yes` / `--force` / `--dry-run` / `--interactive`）。
fn has_flag(rest : Array[String], name : String) -> Bool {
  let mut found = false
  for a in rest {
    if a == name {
      found = true
    }
  }
  found
}

///|
fn join_names(names : Array[String]) -> String {
  names.fold(init="", fn(acc, n) { if acc == "" { n } else { acc + " / " + n } })
}

///|
/// **`attach` 子命令** —— 脚手架：给一份 `skills/` 直接生成一个站点。
///
/// ```
/// node <引导层> attach [--repo <仓根>] [--skills <内容根>] [--program <程序根>]
///                      [--home <README 路径>] [--ignore <名字>=<理由>]…
///                      [--host-dep <依赖值>] [--interactive] [--yes] [--force] [--dry-run]
/// ```
///
/// 它做四件事（顺序是刻意的）：
///   ① 扫内容根 → 列出书架上会有哪几份 skill；
///   ② 忽略清单：给了 `--ignore` 就用给的；是终端就问人（默认**全部进文档区**）；都不是就默认全上；
///   ③ 首页源：`--home` → 目标仓的 `README.md`（复制 + 改写）→ 都没有就生成模板首页；
///   ④ **先把全部产物在内存里算完**（含跑一遍内容管线），一份问题都不剩才开始往磁盘写。
///
/// ⚠️ 为什么"先算后写"：这套东西写的是**别人的仓库**。边算边写的话，中途发现"这个语料生不出站"
///    就会留下一个**半成品实例** —— 它看着像装好了，其实缺一半，而下次再跑会被"不覆盖"挡住。
///    所以：有问题 ⇒ 退 2 且**一个字节都不写**。
fn attach_cmd(rest : Array[String]) -> Unit {
  let host = current_host()
  let program = match arg_value(rest, "--program") {
    Some(p) => host.resolve(p)
    None => {
      let boot = program_hint()
      if boot != "" {
        host.resolve(boot)
      } else {
        host.resolve(host.cwd())
      }
    }
  }
  let repo = match arg_value(rest, "--repo") {
    Some(r) => host.resolve(r)
    None => default_repo(host, program)
  }
  let skills = match arg_value(rest, "--skills") {
    Some(s) => host.resolve(s)
    None => default_skills(host, repo)
  }
  if !host.exists(repo) {
    @content.note("✗ 找不到仓库根（用 --repo 指定）：" + repo)
    @content.set_exit_code(2)
    return
  }
  if !host.exists(skills) {
    @content.note("✗ 找不到内容根（用 --skills 指定）：" + skills)
    @content.set_exit_code(2)
    return
  }
  let all = @sc.list_skill_dirs(host, skills)
  if all.length() == 0 {
    @content.note("✗ 内容根下没有带 `SKILL.md` 的目录：" + skills + "\n  站点是那批 skill 的投影 —— 一份都没有，就没有站点可生成。")
    @content.set_exit_code(2)
    return
  }
  // ⚠️ **书架上会有几份，要按"这次 attach 跑完之后"的语料算**，不是按现在磁盘上有什么算。
  //    因为 attach 自己会写出 `skillpress/SKILL.md`（门口那一份）—— 那**也是一份 skill**，
  //    于是"先按现状算"会让第一次跑出来的书架少一份、第二次多一份 ⇒ 产物**不幂等**（实测踩到）。
  let known : Array[String] = []
  let mut has_home_skill = false
  for n in all {
    known.push(n)
    if n == "skillpress" {
      has_home_skill = true
    }
  }
  if !has_home_skill {
    known.push("skillpress")
  }
  @gates.sort_utf16(known)
  println("skillpress attach —— 内容根：`" + @gates.display_path(host, [repo, program], skills) + "`")
  println("  写完之后内容根里会有 " + known.length().to_string() + " 份：" + join_names(known))
  // ── ① 忽略清单 ─────────────────────────────────────────────────────────────────
  let entries : Array[@sc.IgEntry] = []
  let given = values_of(rest, "--ignore")
  for v in given {
    // 形状 `名字=理由`（理由里可以有 `=`，所以只切第一个）
    match v.find("=") {
      Some(i) => entries.push(@sc.IgEntry::new(v[:i].to_owned(), v[i + 1:].to_owned()))
      None => entries.push(@sc.IgEntry::new(v, ""))
    }
  }
  // ⚠️ **没有 `--ignore` 时要沿用盘上那份清单**（R4：清单是唯一口径）。
  //    不读它的话，"再跑一次"会把本该被忽略的 skill 又放回书架 —— 站点的内容会**悄悄变**，
  //    而 `press --check` 当场红（实测踩到的那个 bug）。
  let ig_path_now = repo + "/skillpress.ignore.md"
  let ig_existing = host.read(ig_path_now)
  let mut adopted = 0
  if entries.length() == 0 && ig_existing != "" {
    let parsed = @ig.parse(ig_existing, known)
    if parsed.problems.length() > 0 {
      @content.note("✗ 盘上那份忽略清单有问题（**不静默容忍**，逐条点名）：`" + ig_path_now + "`")
      for p in parsed.problems {
        @content.note("  ✗ " + p)
      }
      @content.set_exit_code(2)
      return
    }
    for e in parsed.entries {
      entries.push(@sc.IgEntry::new(e.name(), e.reason()))
    }
    adopted = parsed.entries.length()
    if adopted > 0 {
      println("  忽略清单：沿用盘上那份 `skillpress.ignore.md`（" + adopted.to_string() + " 条）")
    }
  } else if given.length() > 0 && ig_existing != "" {
    println("  ⚠️ 盘上已经有一份 `skillpress.ignore.md`：这次按你给的 " + given.length().to_string() + " 条**整个替换**它")
  }
  let forced_interactive = has_flag(rest, "--interactive")
  let quiet = has_flag(rest, "--yes") || given.length() > 0 || adopted > 0
  // 交互式只在**终端**上默认开：管道/CI 里问人等于卡死，而"卡住不返回"比"用默认值并打印一句"难查得多。
  let interactive = forced_interactive || (host.is_tty() && !quiet)
  if interactive {
    println("  逐份问一遍（回车 = 上书架；答 `n` 的请给一条**理由** —— 清单里没理由会当场红）：")
    for name in known {
      let tag = if host.exists(skills + "/" + name + "/SKILL.md") { "" } else { "（这次会新建）" }
      let ans = host.read_line("  · " + name + tag + " 上不上书架？[Y/n] ")
      let hide = ans == "n" || ans == "N" || ans == "no" || ans == "NO"
      if hide {
        let reason = host.read_line("    理由（必填）：")
        entries.push(@sc.IgEntry::new(name, reason))
      }
    }
  } else if given.length() == 0 && adopted == 0 && !interactive {
    println("  忽略清单：没有指定（也不是终端）⇒ **默认全部进文档区**；要藏哪几份用 `--ignore <名字>=<理由>`")
  }
  let ignored : Map[String, Bool] = Map([])
  for e in entries {
    ignored.set(e.name, true)
  }
  let shelf : Array[String] = []
  for n in known {
    if !ignored.contains(n) {
      shelf.push(n)
    }
  }
  // ── ② 首页源 ───────────────────────────────────────────────────────────────────
  let (home_text, home_from, home_bad) = match arg_value(rest, "--home") {
    Some(p) => {
      let abs = host.resolve(p)
      let text = host.read(abs)
      (text, abs, text == "")
    }
    None => {
      let readme = repo + "/README.md"
      let text = host.read(readme)
      (text, if text == "" { "" } else { readme }, false)
    }
  }
  if home_bad {
    @content.note("✗ `--home` 指的首页源读不到：`" + home_from + "` —— 指定的文件不存在**不静默**")
    @content.set_exit_code(2)
    return
  }
  let force = has_flag(rest, "--force")
  let dry = has_flag(rest, "--dry-run")
  // ── ③ 算计划（全部产物在内存里）──────────────────────────────────────────────────
  let app_dir = skills + "/skillpress/scripts/.skillpress"
  let host_dep = match arg_value(rest, "--host-dep") {
    Some(d) => d
    None => @sc.host_dep_default
  }
  let inp = @sc.Inputs::new(
    repo,
    skills,
    @sc.rel_path(repo, skills),
    program,
    @sc.rel_path(app_dir, program),
    @sc.module_name_for(@sc.base_name(repo)),
    host_dep,
    home_text,
    home_from,
    @sc.base_name(repo),
    entries,
  )
  let plan = @sc.static_plan(host, inp, known, shelf)
  for n in plan.notes {
    println("  " + n)
  }
  if plan.problems.length() > 0 {
    @content.note("✗ 生成不了（**一个字节都没写**，逐条点名）：")
    for p in plan.problems {
      @content.note("  ✗ " + p)
    }
    @content.set_exit_code(2)
    return
  }
  // ── ④ 内容包：**同一份引擎**跑一遍（首页用的是内存里那份，还没落盘）─────────────────
  // ⚠️ 传给引擎的首页源要用**内容根相对**的那种标签（`skillpress/WEBSITE.md`），**不是**绝对路径：
  //    引擎靠这个标签认出"首页源不算子页"（D20）。传绝对路径的话它认不出来，第二次跑
  //    （首页已经在盘上了）`WEBSITE.md` 就会被当成 `skillpress` 那份 skill 的子页收进去
  //    —— 于是两次产物不一样（实测踩到的那条"不幂等"的**最后一个**根因）。
  let home_rel = "skillpress/WEBSITE.md"
  let home_path = skills + "/" + home_rel
  let mut home_planned = ""
  for w in plan.writes {
    if w.path == home_path {
      home_planned = w.text
    }
  }
  // ⚠️ 首页**已经存在**且这次不覆盖它 ⇒ 内容包要按**盘上那一份**生成，不能按 README 改写稿。
  //    否则会出现"站上的内容与盘上的首页不一致"：人改过首页（跳过没动它），而内容包还是
  //    README 的改写稿 —— 页面照常渲染，只是内容与首页对不上，`press --check` 也会红。
  let home_effective = if host.exists(home_path) && !force {
    host.read(home_path)
  } else {
    home_planned
  }
  // ⚠️ 门口那份 SKILL.md **也是这次才有的**（第一次跑时磁盘上还没有）—— 同样要喂虚拟读。
  //    不喂的话，内容管线读到空文档 ⇒ 第一次跑的产物与第二次不一样（产物**不幂等**，实测踩到）。
  let skill_md_path = skills + "/skillpress/SKILL.md"
  let mut skill_md_planned = ""
  for w in plan.writes {
    if w.path == skill_md_path {
      skill_md_planned = w.text
    }
  }
  let virtual_read = fn(p : String) -> String {
    if p == home_rel {
      home_effective
    } else if p == skill_md_path && !host.exists(skill_md_path) {
      skill_md_planned
    } else {
      read_text(p)
    }
  }
  let (content_text, content_problems) = try {
    @content.gen_content(
      skills,
      shelf,
      home_rel,
      virtual_read,
      @content.md_kids,
      @content.script_kids,
      @content.note,
      // 许可：`attach` 这一路还不知道目标仓声明了什么 ⇒ 空串（页脚那一项不画）。
      // 真源仍是站点配置（DESIGN §7）；`press` 那条路会从实例的 `moon.mod` 读出来传进来。
      "",
    )
  } catch {
    e => {
      @content.note("✗ 内容管线跑不动：\{e}")
      @content.set_exit_code(2)
      return
    }
  }
  if content_problems.length() > 0 {
    @content.note("✗ 内容里有解不开的东西（**一个字节都没写**，逐条点名）：")
    for p in content_problems {
      @content.note("  ✗ " + p)
    }
    @content.set_exit_code(2)
    return
  }
  // 内容包是**生成物**：文本来自上面那条管线，当作计划里的最后一条（`Derived` ⇒ 每次都写）。
  let content_path = app_dir + "/content/content.generated.mbt"
  plan.writes.push(@sc.derived_write(content_path, content_text, "内容包（content.generated.mbt）"))
  // ── ⑤ 落盘：人写的已存在就跳过（`--force` 才覆盖）；生成物每次都写 ────────────────
  let created : Array[String] = []
  let skipped : Array[String] = []
  let overwritten : Array[String] = []
  for w in plan.writes {
    let exists = host.exists(w.path)
    let authored = match w.kind {
      Authored => true
      Derived => false
    }
    if exists && authored && !force {
      skipped.push(w.what + " —— " + w.path)
      continue
    }
    if dry {
      println("  [dry-run] 会写：" + w.what + " —— " + w.path)
      continue
    }
    host.mkdir_p(parent_dir(w.path))
    host.write(w.path, w.text)
    if exists {
      overwritten.push(w.what)
    } else {
      created.push(w.what)
    }
  }
  if dry {
    println("  [dry-run] 会写：内容包 —— " + content_path)
    println("（dry-run：磁盘上一个字节都没动）")
    return
  }
  println("")
  println("✓ 新增 " + created.length().to_string() + " 个文件，覆盖 " + overwritten.length().to_string() + " 个，跳过已存在 " + skipped.length().to_string() + " 个")
  for s in skipped {
    println("  ⊘ 已经有，没动它：" + s + "（要覆盖加 `--force`）")
  }
  for s in overwritten {
    println("  ↻ 覆盖了：" + s)
  }
  println("  站点实例：" + @gates.display_path(host, [repo, program], app_dir))
  println("  首页源：" + home_path)
  println("  内容包：已生成（" + content_text.split("\n").filter(fn(l) { l != "" }).count().to_string() + " 行非空）")
  println("")
  println("下一步（在实例目录里）：")
  println("  npm install && npm run build && npm run serve")
}
