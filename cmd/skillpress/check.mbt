///|
/// **`check` 子命令**（G1–G4 / G7 / G8）—— 从 `main.mbt` 切出来的一件独立的事：
/// "跑一遍通用门并照旧实现的格式打报告"，与"hl / batch / dump-blocks / gen-file"那几条
/// 没有共享状态（除了同在一个包里）。R9：一个文件一件事。
/// **`check [--repo <根>] [--skills <内容根>] [--program <程序根>] [--ignore <清单>] [--update-lock [名字]]`**
/// —— 跑一遍**通用门**（G1–G4 / G7 / G8）。
///
/// 输出与退出码照旧实现：报告走 **stdout**、退出码 0（全过）/1（有不合格项）/2（找不到仓库根）。
/// ⚠️ 与旧实现的**已知差异**（写在明处，不偷改）：`--selftest` 没搬（14 条诱饵已经作为 `moon test`
/// 落在 `engine/gates/gates_wbtest.mbt` 里）。G5 / G6 / `facts` 按 D18 **不在核心里**。
fn gate_check(rest : Array[String]) -> Unit {
  let host = @gjs.js_host()
  // ⚠️ **程序根默认取"引导层给的程序根"，不是 cwd** —— 这条是实测踩出来的：
  //    `check` 从**内容仓**跑（我们自己的文档就那么教）时 cwd 是内容仓 ⇒ 指纹锁会被算成
  //    `<内容仓>/skills.lock.json`（不存在）⇒ 门红着说"没有 skills.lock.json"，
  //    而锁与 `claims.txt` 其实都住在**程序**仓里（它们是"跟着程序走"的东西）。
  let program = match @gjs.arg_value(rest, "--program") {
    Some(p) => host.resolve(p)
    None => {
      let boot = program_root()
      if boot != "" {
        host.resolve(boot)
      } else {
        host.resolve(host.cwd())
      }
    }
  }
  let repo = match @gjs.arg_value(rest, "--repo") {
    Some(r) => host.resolve(r)
    None => @gjs.default_repo(host, program)
  }
  let skills = match @gjs.arg_value(rest, "--skills") {
    Some(s) => host.resolve(s)
    None => @gjs.default_skills(host, repo)
  }
  // 前置：内容仓根不存在 ⇒ 退 2（旧实现那段，**在报告之前**，而且走 stderr）
  if !host.exists(repo) {
    @gjs.eprintln("✗ 找不到 moobile 根目录（用 --repo 指定）：" + repo)
    @gjs.set_exit_code(2)
    return
  }
  let ignore_path = match @gjs.arg_value(rest, "--ignore") {
    Some(p) => host.resolve(p)
    None => ""
  }
  // `--update-lock [名字]`：**不要求它排第一个**（旧实现 2026-10-06 改成"出现在哪儿都认"：
  // 原先判据是 `argv[2] === "--update-lock"`，于是 `check --skills <目录> --update-lock` 会静默不落锁）
  let mut lock_at = -1
  let mut i = 0
  while i < rest.length() {
    if rest[i] == "--update-lock" {
      lock_at = i
    }
    i = i + 1
  }
  if lock_at >= 0 {
    let after = if lock_at + 1 < rest.length() { rest[lock_at + 1] } else { "" }
    let only = if after != "" && !after.has_prefix("--") { after } else { "" }
    let (missing, total) = @gates.update_lock(host, skills, program, only)
    match missing {
      Some(name) => {
        @gjs.eprintln("✗ --update-lock：没有这个 skill：" + name)
        @gjs.set_exit_code(2)
        return
      }
      None => ()
    }
    println(
      "skills.lock.json 已落锁：" +
      (if only != "" { only } else { total.to_string() + " 个 skill" }),
    )
    println("⚠️ 落锁 = 你**看过**这次的体量变化；它不是「让门变绿」的手段（SPEC §6 G8）。")
    return
  }
  let ctx = @gates.Ctx::new(
    host,
    [repo, program],
    skills,
    @gates.load_claims(host, program),
    @gates.build_index(host, repo),
  )
  let out = @gates.run(ctx, repo, program, "moobile", ignore_path)
  for line in out.lines {
    println(line)
  }
  @gjs.set_exit_code(out.code)
}

///|
/// **引导层给的程序根**（`tools/run-js.mjs` / `launcher/skillpress.mjs` 都会挂上 `root`）。
///
/// 为什么门需要它：指纹锁（`<程序根>/skills.lock.json`）与禁语表（`<程序根>/claims.txt`）都是
/// **跟着程序走**的东西，而 `check` 常常是从**内容仓**里跑的 ⇒ 拿 cwd 当程序根会去内容仓找锁。
/// ⚠️ 拿不到（例如 `moon run engine/gates/dev` 那条路没有引导层）就给空串，调用方退回 cwd。
extern "js" fn program_root() -> String =
  #|() => (globalThis.__skillpress_ts && globalThis.__skillpress_ts.root) || ""
