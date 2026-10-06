///|
/// skillpress 引擎的 CLI（P8.1 阶段）。
///
/// 两条命令，都是**与旧实现同口径地量数**：
///
///   node tools/run-js.mjs hl <markdown 文件> <语言> [第几个围栏块]
///       单块对账：段数 / 未上色 dark/total / 挑中的包装 / "拼回去逐字节等于原文"
///
///   SKILLPRESS_CORPUS=<内容根> node tools/run-js.mjs batch
///       全语料对账：把内容根下**所有** .md 的围栏块都高亮一遍，按语言汇总 dark/total
///       （旧实现那份读数由 `tools/spike/node-side-batch.mjs` 出，两边必须一样）
///
/// ⚠️ 还没做：markdown → 内容包（P8.1 的下一半）、门（P8.2）、站点判据（P8.3）。

///|
/// 读文件（js：node:fs）。IO 归引导层/宿主，逻辑在 MoonBit。
fn read_text(path : String) -> String {
  read_text_js(path)
}

///|
extern "js" fn read_text_js(path : String) -> String =
  #|(path) => { try { return require("node:fs").readFileSync(path, "utf8"); } catch (e) { return ""; } }

///|
/// 语料文件清单（引导层按 `SKILLPRESS_CORPUS` 列好，换行分隔）。
fn md_files() -> String {
  md_files_js()
}

///|
extern "js" fn md_files_js() -> String =
  #|() => ((globalThis.__skillpress_ts && globalThis.__skillpress_ts.mdFiles) || []).join("\n")

///|
/// `dump-blocks` 的内容根（引导层按参数解析好，绝对路径、正斜杠）。
fn dump_root() -> String {
  dump_root_js()
}

///|
extern "js" fn dump_root_js() -> String =
  #|() => (globalThis.__skillpress_ts && globalThis.__skillpress_ts.dumpRoot) || ""

///|
/// 内容根下**带 `SKILL.md` 的目录名**（引导层已按名字排好序 —— 顺序也是判据的一部分，别再排一次）。
fn skill_dirs() -> String {
  skill_dirs_js()
}

///|
extern "js" fn skill_dirs_js() -> String =
  #|() => ((globalThis.__skillpress_ts && globalThis.__skillpress_ts.skillDirs) || []).join("\n")

///|
/// 一个围栏块：语言标记 + 正文。
struct Fence {
  lang : String
  code : String
}

///|
/// 扫出一份 markdown 里的**全部**围栏块（**真值 = 纯文本扫**，与旧实现口径一致）。
fn fences(src : String) -> Array[Fence] {
  let out : Array[Fence] = []
  let lines = src.split("\n").collect()
  let mut i = 0
  while i < lines.length() {
    let line = lines[i].to_owned()
    if line.has_prefix("```") {
      let tag = line[3:].trim().to_owned()
      let body : Array[String] = []
      i = i + 1
      while i < lines.length() && !lines[i].trim().has_prefix("```") {
        body.push(lines[i].to_owned())
        i = i + 1
      }
      out.push({
        lang: tag,
        code: body.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "\n" + s } }),
      })
    }
    i = i + 1
  }
  out
}

///|
/// 高亮一块，打印一行读数；返回 `(dark, total, 认得这个语言吗)`。
/// **自己把错误吃掉并打印** —— `fn main` 不能直接调会抛的函数（也不该把栈甩给人看）。
fn show(f : Fence, label : String) -> (Int, Int, Bool) {
  let total = @hl.solid_count(f.code)
  let spec = match @hl.lang_spec(f.lang) {
    Some(s) => s
    None => {
      println("\{label}|\{f.lang}|（没配语法，照原文渲染）|\{total}")
      return (0, 0, false)
    }
  }
  let h = try {
    @hl.highlight(f.code, f.lang, @hl.caps_of(spec.wasm))
  } catch {
    e => {
      println("\{label}|\{f.lang}|✗ \{e}")
      return (0, 0, false)
    }
  }
  match h {
    None => (0, 0, false)
    Some(x) => {
      println("\{label}|\{f.lang}|\{x.label}|\{x.wrapper}|dark=\{x.dark}|\{total}")
      (x.dark, total, true)
    }
  }
}

///|
struct Tally {
  blocks : Int
  dark : Int
  total : Int
}

///|
/// 汇总：按语言累加（键是站点上显示的语言名）。
fn add(t : Map[String, Tally], label : String, dark : Int, total : Int) -> Unit {
  let cur = t.get_or_default(label, { blocks: 0, dark: 0, total: 0 })
  t.set(label, { blocks: cur.blocks + 1, dark: cur.dark + dark, total: cur.total + total })
}

///|
///|
/// **`dump-blocks <内容根>`**：把内容根下每份 skill 的 `blocks` 段按旧实现的排版吐出来。
///
/// 输出格式是**判据的接口**（与 `tools/spike/old-doc-blocks.mjs` 逐字节可比）：
/// `### <slug>` + 那段原文（含 8 格缩进）+ 一个空行，最后一行 `### end`。
fn dump_blocks() -> Unit {
  let dirs0 = skill_dirs()
  let dirs = dirs0.split("\n").filter(fn(l) { l != "" }).map(fn(l) { l.to_owned() }).collect()
  if dirs.length() == 0 {
    println("✗ 内容根下没有带 SKILL.md 的目录（引导层按 `dump-blocks <内容根>` 列举，检查那个参数）")
    return
  }
  let root = dump_root()
  let out : Array[String] = []
  for dir in dirs {
    let md = read_text(root + "/" + dir + "/SKILL.md")
    if md == "" {
      println("✗ 读不到 \{root}/\{dir}/SKILL.md")
      return
    }
    let lines = try {
      @content.doc_block_lines(md, "        ")
    } catch {
      e => {
        println("✗ \{dir} 出块失败：\{e}")
        return
      }
    }
    out.push("### " + dir)
    for line in lines {
      out.push(line)
    }
    out.push("")
  }
  out.push("### end")
  // 逐字节可比：`join("\n")` + `println` 自带的那一个换行 = 旧实现的 `join("\n") + "\n"`
  // （core 里没有不带换行的 `print`，所以这里刻意把换行交给 `println`）
  println(out.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "\n" + s } }))
}


///|
/// 从 `@env.args()` 里取 `--<名字> <值>` 选项（没给就空串）。只认这种**两段式**写法。
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
  let (text, problems) = try {
    @content.gen_content(
      root,
      kept,
      opt("--home"),
      read_text,
      @content.md_kids,
      @content.script_kids,
      @content.note,
    )
  } catch {
    e => {
      @content.note("✗ 生成失败：\{e}")
      @content.set_exit_code(2)
      return
    }
  }
  if problems.length() > 0 {
    @content.note("gen-content：内容里有解不开的东西（**不静默丢**，逐条点名）：")
    for p in problems {
      @content.note("  ✗ " + p)
    }
    @content.set_exit_code(2)
    return
  }
  // `gen_content` 给回的文本以换行结尾；`println` 自带一个换行 ⇒ 先去掉尾巴再打，
  // 这样 stdout 恰好等于那份文件（不多不少一个换行）
  let body = if text.has_suffix("\n") { text[:text.length() - 1].to_owned() } else { text }
  println(body)
}

///|
fn main {
  // 引导层没装好 ⇒ **退 2 且 stdout 什么都不打**。原先这里既能过、又往 stdout 打了句"✗"：
  // `gen-file > 产物` 那种用法会因此得到一份写着报错的"产物"、退出码还是 0 ——
  // 正是旧实现注释里骂过的"一个退出码不对的门比没有门更糟"（P8.1 自查发现，已改）。
  if !@hl.ready() {
    @content.note("✗ tree-sitter 没装好 —— 请用 `node tools/run-js.mjs` 拉起（它会先 await 装好再进 MoonBit）")
    @content.set_exit_code(2)
    return
  }
  let args = @env.args()
  let cmd = args[args.length() - 1]
  ignore(cmd)
  // 引导层把 CLI 参数原样放在 argv 里：node tools/run-js.mjs <cmd> [参数…]
  let rest : Array[String] = []
  let mut k = 0
  while k < args.length() {
    if args[k] == "hl" || args[k] == "batch" || args[k] == "dump-blocks" || args[k] == "gen-file" {
      break
    }
    k = k + 1
  }
  if k >= args.length() {
    println("用法：node tools/run-js.mjs hl <markdown 文件> <语言>")
    println("      SKILLPRESS_CORPUS=<根> node tools/run-js.mjs batch")
    println("      node tools/run-js.mjs dump-blocks <内容根>")
    println("      node tools/run-js.mjs gen-file <内容根>      # 整份 content.generated.mbt → stdout")
    println("垫片装的语法：\{@hl.languages()}")
    return
  }
  for j = k + 1; j < args.length(); j = j + 1 {
    rest.push(args[j])
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
