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
/// 语料根（调试用）。
fn corpus_root() -> String {
  corpus_root_js()
}

///|
extern "js" fn corpus_root_js() -> String =
  #|() => process.env.SKILLPRESS_CORPUS || "（没设）"

///|
/// 语料文件清单（引导层按 `SKILLPRESS_CORPUS` 列好，换行分隔）。
fn md_files() -> String {
  md_files_js()
}

///|
extern "js" fn md_files_js() -> String =
  #|() => ((globalThis.__skillpress_ts && globalThis.__skillpress_ts.mdFiles) || []).join("\n")

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
fn main {
  if !@hl.ready() {
    println("✗ tree-sitter 没装好 —— 请用 `node tools/run-js.mjs` 拉起（它会先 await 装好再进 MoonBit）")
    return
  }
  let args = @env.args()
  let cmd = args[args.length() - 1]
  ignore(cmd)
  // 引导层把 CLI 参数原样放在 argv 里：node tools/run-js.mjs <cmd> [参数…]
  let rest : Array[String] = []
  let mut k = 0
  while k < args.length() {
    if args[k] == "hl" || args[k] == "batch" {
      break
    }
    k = k + 1
  }
  if k >= args.length() {
    println("用法：node tools/run-js.mjs hl <markdown 文件> <语言>   ｜   SKILLPRESS_CORPUS=<根> node tools/run-js.mjs batch")
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
