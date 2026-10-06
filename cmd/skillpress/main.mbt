///|
/// skillpress 引擎的 CLI（P8.1 起点）。
///
/// 这一轮只接了一条命令，它的唯一任务是**与旧实现同口径地量同一块代码**：
///
///   node tools/run-js.mjs hl <markdown 文件> <语言> [第几个该语言的围栏块]
///
/// 读数要和 `tools/spike/node-side-hl.mjs`（直接调旧实现 `lib/highlight.mjs`）**逐项对得上**：
/// 段数 / 未上色 `dark/total` / 前几段的 `(文本, 色号)` / "拼回去逐字节等于原文"。
///
/// ⚠️ 还没做（别当成已覆盖）：**包装候选**（旧实现里 moonbit 那套"裸着解析不中就把片段包进
/// 函数体/let/调用参数…，取未上色最少的那个"）。所以这一轮拿 **bash** 比 ——
/// 它不需要包装，两边是同一件事。moonbit 的包装对账放 P8.1 的下一步。

///|
/// 读文件（js：node:fs）。⚠️ 引导层负责装 tree-sitter，读文件这种小事直接用宿主能力。
fn read_text(path : String) -> String {
  read_text_js(path)
}

///|
extern "js" fn read_text_js(path : String) -> String =
  #|(path) => { try { return require("node:fs").readFileSync(path, "utf8"); } catch (e) { return ""; } }

///|
/// 程序根（引导层塞进来的）—— 用来定位 `grammars/*.highlights.scm`。
fn root() -> String {
  root_js()
}

///|
extern "js" fn root_js() -> String =
  #|() => (globalThis.__skillpress_ts && globalThis.__skillpress_ts.root) || "."

///|
/// 从 markdown 里取出第 n 个 ```<lang> 围栏块（**真值 = 纯文本扫**，与旧实现口径一致）。
fn fenced_block(src : String, lang : String, nth : Int) -> String? {
  let lines = src.split("\n").collect()
  let mut found = 0
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
      if tag == lang {
        found = found + 1
        if found == nth {
          return Some(body.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "\n" + s } }))
        }
      }
    }
    i = i + 1
  }
  None
}

///|
fn main {
  if !@hl.ready() {
    println("✗ tree-sitter 没装好 —— 请用 `node tools/run-js.mjs` 拉起（它会先 await 装好再进 MoonBit）")
    return
  }
  let args = @env.args()
  let rest = args[args.length() - 3:]
  let (file, lang, nth) = if rest.length() == 3 && rest[0] == "hl" {
    (rest[1], rest[2], 1)
  } else if rest.length() >= 3 {
    (rest[rest.length() - 3], rest[rest.length() - 2], 1)
  } else {
    ("", "", 1)
  }
  ignore(nth)
  if file == "" || lang == "" {
    println("用法：node tools/run-js.mjs hl <markdown 文件> <语言> [第几个]")
    println("垫片装的语法：\{@hl.languages()}")
    return
  }
  let src = read_text(file)
  if src == "" {
    println("✗ 读不到文件：\{file}")
    return
  }
  let code = match fenced_block(src, lang, 1) {
    Some(c) => c
    None => {
      println("✗ 文件里没有 ```\{lang} 的围栏块")
      return
    }
  }
  let scm = read_text(root() + "/grammars/" + lang + ".highlights.scm")
  if scm == "" {
    println("✗ 读不到 query：grammars/\{lang}.highlights.scm")
    return
  }
  println("== MoonBit 引擎（engine/highlight + 薄垫片）==")
  println("输入 = \{file}（```\{lang} 第 1 个，\{code.split("\n").collect().length()} 行）")
  let caps = try {
    @hl.parse_captures(@hl.captures_raw(lang, code, scm))
  } catch {
    e => {
      println("✗ 上色失败：\{e}")
      return
    }
  }
  let spans = @hl.collect(caps)
  let runs = @hl.build_runs(code, spans)
  let dark = @hl.dark_count(runs)
  let total = @hl.solid_count(code)
  let joined = runs.fold(init="", fn(acc, r) { acc + r.0 })
  let preview = runs[:6].map(fn(r) { "[" + r.0.trim().to_owned() + " → \{r.1}]" }).fold(init="", fn(acc, s) { acc + s })
  println("capture 命中 = \{caps.length()} 个（留下的区间 \{spans.length()} 个）")
  println("未上色 = \{dark}/\{total}")
  println("前 6 段 = \{preview}")
  println("★ 拼回去逐字节等于原文 = \{joined == code}")
}
