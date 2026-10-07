///|
/// skillpress 引擎的 CLI。
///
/// 命令面（开发期用 `node tools/run-js.mjs <子命令>` 拉起；随包发的那份走
/// `launcher/skillpress.mjs`，两者做的是同一件事）：
///
///   hl <markdown 文件> <语言> [第几个围栏块]
///       单块对账：段数 / 未上色 dark,total / 挑中的包装 / "拼回去逐字节等于原文"
///   SKILLPRESS_CORPUS=<内容根> batch
///       全语料对账：把内容根下**所有** .md 的围栏块都高亮一遍，按语言汇总 dark,total
///   dump-blocks <内容根>
///       文档块的对账视图
///   gen-file <内容根> [--home <首页源>] [--ignore <清单>]
///       整份 content.generated.mbt → stdout（认不出的构造**逐条点名**、退 2、一个字节都不吐）
///   check [--repo <根>] [--skills <内容根>] [--program <程序根>] [--ignore <清单>] [--update-lock [名字]]
///       通用门 G1–G8
///   attach [--repo <根>] [--skills <内容根>] [--home <README>] [--ignore <名字>=<理由>]…
///          [--host-dep <依赖值>] [--interactive] [--yes] [--force] [--dry-run]
///       脚手架：给一份 `skills/` 直接生成一个站点（见 PLAN 的 P9）
///
/// ⚠️ 还没做：站点判据（P8.3 —— 今天仍是冻结的 `lib/verify-site.mjs`）与 `pack`（便携目录）。
///    ⚠️ 另外：站点判据那条链**写死了 moobile 那份语料**（6 份 skill 之类的形状），
///    所以它在别的语料上会一片红 —— 那是它还没通用化，不是那些站点坏了。

///|
/// **内容根**（dispatch 在进命令之前设好）。
///
/// ⚠️ 以前这个值是**引导层**喂的（`globalThis.__skillpress_ts.dumpRoot`）—— 而 native 没有引导层。
///    现在两边都从命令行拿：`resolve` 之后**正斜杠化**（与引导层 `prepareRoot` 同口径，
///    因为生成物里出现的就是这个字符串）。
let corpus_ref : Ref[String] = { val: "" }

///|
/// 设内容根（空串 = 没给）。
fn set_corpus(path : String) -> Unit {
  let host = current_host()
  corpus_ref.val = if path == "" { "" } else { @gates.to_slash(host.resolve(path)) }
}

///|
/// 内容根的当前值（`batch` 那条路会退回 `SKILLPRESS_CORPUS` 环境变量）。
fn dump_root() -> String {
  if corpus_ref.val != "" {
    return corpus_ref.val
  }
  match @sys.get_env_var("SKILLPRESS_CORPUS") {
    Some(v) =>
      if v == "" {
        ""
      } else {
        @gates.to_slash(current_host().resolve(v))
      }
    None => ""
  }
}

///|
/// 读一个文本文件（读不到给空串 —— 调用方自己去判"这是不是真的空"）。
/// 两个 target 都走 `content` 的 `read_text`（js：Node fs；native：`moonbitlang/x`）。
fn read_text(path : String) -> String {
  @content.read_text(path)
}

///|
/// 内容根下**带 `SKILL.md` 的目录**名（换行分隔，按 UTF-16 码元序 —— 与引导层的 `.sort()` 同口径）。
fn skill_dirs() -> String {
  let host = current_host()
  let root = dump_root()
  if root == "" {
    return ""
  }
  let kept : Array[String] = []
  for n in host.read_dir(root) {
    let d = @gates.join_path(root, n)
    if host.is_dir(d) && host.exists(@gates.join_path(d, "SKILL.md")) {
      kept.push(n)
    }
  }
  @gates.sort_utf16(kept)
  join_lines(kept)
}

///|
/// 内容根下**所有 `.md` 的绝对路径**（正斜杠），逐层深度优先、每层排序。
/// 跳过 `.` 开头与 `node_modules` / `_build` / `dist`（与引导层 `mdFiles` 同一张跳过表）。
fn md_files() -> String {
  let host = current_host()
  let root = dump_root()
  if root == "" {
    return ""
  }
  let out : Array[String] = []
  md_files_walk(host, root, out)
  join_lines(out)
}

///|
fn md_files_walk(host : @gates.Host, dir : String, out : Array[String]) -> Unit {
  let names = host.read_dir(dir)
  @gates.sort_utf16(names)
  for n in names {
    if n.has_prefix(".") || n == "node_modules" || n == "_build" || n == "dist" {
      continue
    }
    let p = @gates.join_path(dir, n)
    if host.is_dir(p) {
      md_files_walk(host, p, out)
    } else if n.has_suffix(".md") {
      out.push(@gates.to_slash(p))
    }
  }
}

///|
/// 逐行拼（空表给空串）。
fn join_lines(items : Array[String]) -> String {
  items.fold(init="", fn(a, x) { if a == "" { x } else { a + "\n" + x } })
}

///|
/// 从 `@env.args()` 里取 `--<名字> <值>` 选项（没给就空串）。只认这种**两段式**写法。
///|
/// **布尔开关**（不带值的那类，例如 --llms）。
///
/// ⚠️ 别拿 opt() 判它：那个只认「--名字 值」的形式，开关没有值 ⇒ 永远返回空串。
///    实测踩过：--llms 写完却一直吐出内容包，像是没生效，其实是判据看错了地方。
fn has_opt(name : String) -> Bool {
  for a in @env.args() {
    if a == name {
      return true
    }
  }
  false
}

fn opt(name : String) -> String {
  let args = @env.args()
  let mut i = 0
  while i + 1 < args.length() {
    if args[i] == name {
      return args[i + 1]
    }
    i = i + 1
  }
  ""
}

///|
/// 路径的上一级（只按 `/` 切；内容仓根 = 内容根的上一级，这是 R4 定的清单位置）。
fn parent_dir(p : String) -> String {
  match p.rev_find("/") {
    Some(i) => p[:i].to_owned()
    None => ""
  }
}

///|
/// **`gen-file <内容根>`**：把**整份** `content.generated.mbt` 打到 stdout。
///
/// stdout 只有那份文件（判据对它做逐字节 diff）；诊断与问题清单走 **stderr**。
/// 有问题（认不出的死链、没有 `##`、找不到首页、图片/原始 HTML 这类认不出的构造…）时
/// **退出码 2 且 stdout 是空的** —— 旧实现就是"有问题就不写产物"（那个 `else` 分支才 `writeFileSync`）。
/// 照抄这条不只是为了对齐：`gen-file > 产物文件` 是常见用法，有问题还照吐就等于**把一份坏产物落盘**。
///
/// 选项：`--home <路径>`（首页源覆盖，R2）、`--ignore <路径>`（忽略清单覆盖，R4 —— 默认取
/// **内容仓根**下的 `skillpress.ignore.md`）。
fn gen_file() -> Unit {
  let dirs0 = skill_dirs()
  let dirs = dirs0.split("\n").filter(fn(l) { l != "" }).map(fn(l) { l.to_owned() }).collect()
  if dirs.length() == 0 {
    @content.note("✗ 内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）")
    @content.set_exit_code(2)
    return
  }
  let root = dump_root()
  // ── 忽略清单（R4）：站点**不上桌**，门**也跳过** ────────────────────────────────
  // ⚠️ 解析出问题就**退 2 且一份都不套用** —— "半套用"是最难查的状态。
  let ignore_given = opt("--ignore")
  let ignore_path = if ignore_given != "" {
    ignore_given
  } else {
    parent_dir(root) + "/skillpress.ignore.md"
  }
  let ig_text = read_text(ignore_path)
  if ignore_given != "" && ig_text == "" {
    @content.note("✗ `--ignore` 指的清单读不到：`" + ignore_path + "` —— 指定的清单不存在**不静默**")
    @content.set_exit_code(2)
    return
  }
  let parsed = @ig.parse(ig_text, dirs)
  if parsed.problems.length() > 0 {
    @content.note("忽略清单有问题（**不静默容忍**，逐条点名）：`" + ignore_path + "`")
    for p in parsed.problems {
      @content.note("  ✗ " + p)
    }
    @content.set_exit_code(2)
    return
  }
  let (kept, skipped) = @ig.split_names(dirs, parsed)
  for line in @ig.notice_lines(skipped) {
    @content.note(line)
  }
  if kept.length() == 0 {
    @content.note("⚠️ 忽略清单之后**一份 skill 都不剩**：站点只剩首页（不是错，但你要知道）")
  }
  let gen = try {
    @content.gen_content_full(
      root,
      kept,
      opt("--home"),
      read_text,
      @content.md_kids,
      @content.script_kids,
      @content.note,
      // 站点的**许可**：真源是站点配置的 `footer.license`（DESIGN §7，那份配置还不存在）
      // ⇒ 过渡期由调用方（`press`）从**实例自己的 `moon.mod` 声明**里读出来传进来；
      //    传不进来就是空串，页脚那一项**不画**（不写占位、更不写死一个假值）。
      opt("--license"),
      // 图片在站点上的目录前缀。默认 `img/`：`press` 按同一个名字把图拷进实例（一份口径两处用）。
      if has_opt("--asset-base") { opt("--asset-base") } else { "img/" },
    )
  } catch {
    e => {
      @content.note("✗ 生成失败：\{e}")
      @content.set_exit_code(2)
      return
    }
  }
  if gen.problems.length() > 0 {
    @content.note("gen-content：内容里有解不开的东西（**不静默丢**，逐条点名）：")
    for p in gen.problems {
      @content.note("  ✗ " + p)
    }
    @content.set_exit_code(2)
    return
  }
  // `gen_content` 给回的文本以换行结尾；`println` 自带一个换行 ⇒ 先去掉尾巴再打，
  // 这样 stdout 恰好等于那份文件（不多不少一个换行）
  // `--llms`：同一份解析的另一件产物（Agent 出口）。两条产物共用这一整套前置
  // （内容根列举 / 忽略清单 / 许可 / 问题清单 / 退出码）—— 所以不存在第二份口径。
  let src = if has_opt("--llms") { gen.llms } else { gen.mbt }
  let body = if src.has_suffix("\n") { src[:src.length() - 1].to_owned() } else { src }
  println(body)
}

///|
/// **CLI 的入口**（与 target 无关）：由两个薄可执行件分别接上自己的宿主与程序根提示。
///
/// `host` = 磁盘/终端那一面（js 走引导层 + Node fs，native 走 `moonbitlang/x` + 60 行 C）；
/// `hint` = "程序根在哪"的提示（js 来自引导层 `globalThis.__skillpress_ts.root`，
/// native 来自 `SKILLPRESS_PROGRAM` 环境变量）—— 拿不到就退回 `--program` 参数、再退回 cwd。
/// ⚠️ 退出码不用返回：命令自己调 `content.set_exit_code`（js 上就是 `process.exitCode`，
///    native 上是一个 Ref，由**可执行件**收摊时用它退出 —— 中途 exit 会把还在跑的事截断）。
pub fn run(host : @gates.Host, hint : String) -> Unit {
  ctx_ref.val = Some({ host, hint })
  let args = @env.args()
  // 找出命令词的位置（`node tools/run-js.mjs <cmd> [参数…]`：引导层把 CLI 参数原样放在 argv 里）
  let rest : Array[String] = []
  let mut k = 0
  while k < args.length() {
    if args[k] == "hl" ||
      args[k] == "batch" ||
      args[k] == "dump-blocks" ||
      args[k] == "gen-file" ||
      args[k] == "attach" ||
      args[k] == "gen-queries" ||
      args[k] == "audit" ||
      args[k] == "check" {
      break
    }
    k = k + 1
  }
  // ── `check`：**不需要引导层**，所以先于下面那道 tree-sitter 检查分发 ────────────────────
  // 门不碰高亮 ⇒ 没装 tree-sitter 也该能跑门。这条对 R6 有实际意义：别人拿这个包跑门时，
  // 不该被"高亮装好了没有"挡住（那两件事没有任何依赖关系）。
  if k < args.length() && args[k] == "check" {
    for j = k + 1; j < args.length(); j = j + 1 {
      rest.push(args[j])
    }
    gate_check(rest)
    return
  }
  // ── `gen-queries`：**同样不需要引导层**（它读 `.scm` 写 `.mbt`，与高亮运行时无关）──────
  //    判据 `tools/queries-check.sh` 就是调它；native 那份 CLI 与 js 那份都能跑。
  if k < args.length() && args[k] == "gen-queries" {
    for j = k + 1; j < args.length(); j = j + 1 {
      rest.push(args[j])
    }
    gen_queries(rest)
    return
  }
  // 引导层没装好 ⇒ **退 2 且 stdout 什么都不打**。原先这里既能过、又往 stdout 打了句"✗"：
  // `gen-file > 产物` 那种用法会因此得到一份写着报错的"产物"、退出码还是 0 ——
  // 正是旧实现注释里骂过的"一个退出码不对的门比没有门更糟"（P8.1 自查发现，已改）。
  if !@hl.ready() {
    @content.note("✗ tree-sitter 没装好 —— 请用 `node tools/run-js.mjs` 拉起（它会先 await 装好再进 MoonBit）")
    @content.set_exit_code(2)
    return
  }
  if k >= args.length() {
    no_command(args)
    return
  }
  for j = k + 1; j < args.length(); j = j + 1 {
    rest.push(args[j])
  }
  // 需要内容根的两条命令：位置参数就是内容根（与引导层 `prepareRoot(process.argv[at+1])` 同口径）。
  // ⚠️ 以前这个值由**引导层**喂 —— native 没有引导层，所以两边都改成从命令行拿（见 `set_corpus`）。
  if (args[k] == "gen-file" || args[k] == "dump-blocks") && rest.length() > 0 {
    set_corpus(rest[0])
  }
  if args[k] == "hl" {
    if rest.length() < 2 {
      println("用法：node tools/run-js.mjs hl <markdown 文件> <语言>")
      return
    }
    let src = read_text(rest[0])
    if src == "" {
      println("✗ 读不到文件：\{rest[0]}")
      return
    }
    let all = fences(src).filter(fn(f) { f.lang == rest[1] })
    if all.length() == 0 {
      println("✗ 文件里没有 ```\{rest[1]} 的围栏块")
      return
    }
    println("== MoonBit 引擎（engine/highlight）==")
    println("输入 = \{rest[0]}（```\{rest[1]} 共 \{all.length()} 块）")
    let (dark, total, _) = show(all[0], "块 1")
    println("未上色 = \{dark}/\{total}")
    return
  }
  if args[k] == "dump-blocks" {
    dump_blocks()
    return
  }
  if args[k] == "gen-file" {
    gen_file()
    return
  }
  // ⚠️ `attach` 排在 `@hl.ready()` 检查**之后**：它要生成内容包，而内容管线里那段上色
  //    需要引导层装好的 tree-sitter。所以它和 `gen-file` 是同一档的（都得用引导层拉起）。
  if args[k] == "attach" {
    attach_cmd(rest)
    return
  }
  // audit：上色的回归闸门（**需要高亮** ⇒ 在"引导层装好了没有"那道检查之后分发）
  if args[k] == "audit" {
    audit(rest)
    return
  }
  // batch：全语料
  // ⚠️ 语料清单要先落成 Array 再挑空行：直接 `split().filter()` 拿到的是
  // **对临时字符串的视图迭代器**，实测读出来是 0 份（"没语料"这种假象最容易骗过自己）
  let raw = md_files()
  let files = raw.split("\n").filter(fn(l) { l != "" }).map(fn(l) { l.to_owned() }).collect()
  if files.length() == 0 {
    println("✗ 没有语料 —— 用 SKILLPRESS_CORPUS=<内容根> 指定（引导层负责列举）")
    return
  }
  println("== MoonBit 引擎：全语料对账（\{files.length()} 份 .md）==")
  let tally : Map[String, Tally] = Map([])
  for file in files {
    let src = read_text(file)
    for f in fences(src) {
      let (dark, total, ok) = show(f, file)
      if ok {
        let spec = @hl.lang_spec(f.lang).unwrap()
        add(tally, spec.label, dark, total)
      }
    }
  }
  println("== 汇总（按语言）==")
  // 固定顺序（两边的输出要能 `diff`）：顺序本身就是判据的一部分
  let keys = ["moonbit", "bash", "json", "javascript", "toml"]
  for key in keys {
    match tally.get(key) {
      None => ()
      Some(t) => {
        let pct = if t.total == 0 { 0.0 } else { (t.dark.to_double() / t.total.to_double()) * 100.0 }
        println("  \{key}|\{t.blocks} 块|dark=\{t.dark}|\{t.total}|\{pct}%")
      }
    }
  }
}

