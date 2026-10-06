///|
/// **门的 CLI（开发/对账用）** —— 目的只有一个：能拿它与旧实现 `lib/check.mjs` 的输出
/// **逐字节 diff**。所以它的参数口径、默认根、打印格式、退出码全部照抄旧实现。
///
///   moon run engine/gates/dev --target js -- [--repo <内容仓根>] [--skills <内容根>] [--program <程序根>]
///
/// ## 三个根怎么来的（与 `lib/roots.mjs` 同一套约定）
///
/// | 根 | 参数 | 默认 |
/// |---|---|---|
/// | 程序 | `--program` | 当前工作目录（`moon run --target js` 会把 cwd 设成模块根，即程序根） |
/// | 仓库 | `--repo` | `<程序>/../moobile`（有 `skills/` 或 `.agents/skills/` 才算），否则 `<程序>/../../..` |
/// | 内容 | `--skills` | `<仓库>/skills`，没有就退回 `<仓库>/.agents/skills` |
///
/// ## 与旧实现的**已知差异**（如实写在报告里，不偷偷改）
///
///   · 旧实现读环境变量 `MOOBILE_ROOT` / `SKILLPRESS_REPO` / `SKILLPRESS_SKILLS`；
///     这里只用参数（对账时把参数传全即可，语义一致）。
///   · `--selftest` 与 `--update-lock` 没搬（前者是 14 条诱饵，已经作为 `test` 落在
///     `gates_test.mbt` 里；后者是**写**锁，不属于"门"的判据 —— 见包报告）。

///|
/// 参数（`process.argv.slice(2)`，一行一个）。
extern "js" fn argv_lines() -> String =
  #|() => process.argv.slice(2).join("\n")

///|
/// 退出码：写 `process.exitCode`（不打断还没 flush 的输出），`main` 自然返回后 node 用它。
extern "js" fn set_exit_code_js(code : Int) -> Unit =
  #|(code) => { process.exitCode = code; }

///|
/// stderr（旧实现那条"找不到根"的错是 `console.error` —— 通道也是判据的一部分）。
extern "js" fn eprintln_js(text : String) -> Unit =
  #|(text) => { process.stderr.write(text + "\n"); }

///|
/// 参数表：`--key value` 的取值；没给就 `None`。
fn arg_value(args : Array[String], key : String) -> String? {
  let mut i = 0
  while i + 1 < args.length() {
    if args[i] == key {
      return Some(args[i + 1])
    }
    i = i + 1
  }
  None
}

///|
/// 默认仓库根（旧实现 `defaultRepo`）：先找兄弟 `moobile/`，找不到退回往上三层。
fn default_repo(host : @gates.Host, program : String) -> String {
  let sibling = host.resolve(@gates.join_path(@gates.join_path(program, ".."), "moobile"))
  if host.exists(@gates.join_path(sibling, "skills")) ||
    host.exists(@gates.join_path(sibling, ".agents/skills")) {
    return sibling
  }
  host.resolve(@gates.join_path(@gates.join_path(@gates.join_path(program, ".."), ".."), ".."))
}

///|
/// 默认内容根（旧实现 `defaultSkills`）：`<仓库>/skills`，没有才退回老约定。
fn default_skills(host : @gates.Host, repo : String) -> String {
  let plain = @gates.join_path(repo, "skills")
  if host.exists(plain) {
    return plain
  }
  let legacy = @gates.join_path(@gates.join_path(repo, ".agents"), "skills")
  if host.exists(legacy) {
    return legacy
  }
  plain
}

///|
fn main {
  let host = js_host()
  let args = argv_lines().split("\n").filter(fn(l) { l != "" }).map(fn(l) { l.to_owned() }).collect()
  let program = match arg_value(args, "--program") {
    Some(p) => host.resolve(p)
    None => host.resolve(host.cwd())
  }
  // 模式 A：造对账夹具（写进 `--emit-fixtures <目录>`，通常是 gitignore 的 `_build/`）
  match arg_value(args, "--emit-fixtures") {
    Some(dir) => {
      let root = host.resolve(dir)
      let written = emit_fixtures(host, root, program)
      println("夹具已写好：" + written.length().to_string() + " 个文件 → " + root)
      return
    }
    None => ()
  }
  // 模式 B：锁的**序列化回环**（读 `<程序根>/skills.lock.json` ⇒ 解析 ⇒ 再序列化 ⇒ 与原文字节比）
  if args.contains("--roundtrip-lock") {
    let file = @gates.join_path(program, "skills.lock.json")
    let original = host.read(file)
    match @gates.load_lock(host, program) {
      None => {
        eprintln_js("✗ 读不出锁：" + file)
        set_exit_code_js(2)
      }
      Some(l) => {
        let text = @gates.lock_text(match l.note {
          Some(n) => n
          None => ""
        }, l.skills)
        if text == original {
          println("锁回环：逐字节一致（" + l.skills.length().to_string() + " 条 / " + original.length().to_string() + " 字符）")
        } else {
          println("锁回环：**不一致**")
          println("--- 原文长度 " + original.length().to_string() + " / 重排长度 " + text.length().to_string())
          set_exit_code_js(1)
        }
      }
    }
    return
  }
  let repo = match arg_value(args, "--repo") {
    Some(r) => host.resolve(r)
    None => default_repo(host, program)
  }
  let skills = match arg_value(args, "--skills") {
    Some(s) => host.resolve(s)
    None => default_skills(host, repo)
  }
  // 前置：内容仓根不存在 ⇒ 退 2（旧实现 `main` 里那段，**在报告之前**）
  if !host.exists(repo) {
    eprintln_js("✗ 找不到 moobile 根目录（用 --repo 指定）：" + repo)
    set_exit_code_js(2)
    return
  }
  let ctx = @gates.Ctx::new(
    host,
    [repo, program],
    skills,
    @gates.load_claims(host, program),
    @gates.build_index(host, repo),
  )
  // 清单路径：`--ignore <路径>` 可覆盖（默认 `<仓库根>/skillpress.ignore.md`）。
  // 为什么需要这个开关：对账要在**副本**上跑（副本上一级没有清单），而旧门的 G5/G6 又要靠
  // 真仓库的 `.mbt` 索引 ⇒ 两边**不能**同时用"默认的清单路径"（那会把真清单漏进副本比较）。
  let ignore_path = match arg_value(args, "--ignore") {
    Some(p) => host.resolve(p)
    None => ""
  }
  let out = @gates.run(ctx, repo, program, "moobile", ignore_path)
  for line in out.lines {
    println(line)
  }
  set_exit_code_js(out.code)
}
