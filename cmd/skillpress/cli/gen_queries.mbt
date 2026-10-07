///|
/// **`gen-queries [--program <程序根>] [--check]`** —— 把 `grammars/*.highlights.scm`
/// **嵌进** `engine/highlight/queries.generated.mbt`。
///
/// ## 为什么要嵌
///
/// **native 垫片没有引导层去读盘**（js 那条路由 `run-js.mjs` / `launcher` 在起 CLI 之前把
/// 五份 `.scm` 读进内存）。一支本机二进制要么自己在文件系统里找 `grammars/`（那要知道"包在哪"，
/// 装到 `~/.moon` 之后那条路径没人告诉它），要么**把 query 编进二进制** —— 五份加起来才 11 KB。
///
/// ## 为什么必须有一条判据钉着
///
/// 于是有"同一个事实的两个副本"：native 读内嵌、js 读盘。它们一变味，症状是
/// **同一份内容在两边成两种颜色**（而两边各自的判据可能都还是绿的）。
/// `--check`（判据 `tools/queries-check.sh`）钉的就是"两份**逐字节**相同"。
///
/// ⚠️ 产物**要进仓库**（native 编译时需要它），而且**由这个子命令生成** —— 别手改。
/// ⚠️ 这门子命令的产物是"新引擎自己的资产"，所以它**不需要 tree-sitter**（与 `check` 同理：
///    先于"引导层装好了没有"那道检查分发）。

///|
/// 语言集合与顺序**照抄旧实现**（`tools/gen-queries.mjs`）：写死的候选表，再按
/// "目录里真的有这份 `.scm`"过滤 —— 不写死一张表会漂，只写死不过滤又会生成出一份
/// 指向不存在 query 的产物。
fn gen_query_langs() -> Array[String] {
  // ⚠️ 不能写成 `const`：MoonBit 的常量类型只允许**不可变基本类型**（实测报
  //    "Array[String] is not a valid constant type"）。
  ["bash", "javascript", "json", "moonbit", "toml"]
}

///|
/// MoonBit **字符串字面量**的转义：`\` / `"` / `\r` / `\n`。
///
/// ⚠️ 四个都要、顺序也要对（`\` 先转，否则后面转出来的反斜杠会被二次转义）。
/// ⚠️ 与 `engine/site/dump.mbt` 的 `esc_line` **不是**同一套（那是"一行化转储"的协议，
///    连 `\t` 都转、且不碰 `"`）—— 两处格式不同，别合并。
fn mbt_literal(text : String) -> String {
  let out : Array[String] = []
  for ch in text {
    if ch == '\\' {
      out.push("\\\\")
    } else if ch == '"' {
      out.push("\\\"")
    } else if ch == '\r' {
      out.push("\\r")
    } else if ch == '\n' {
      out.push("\\n")
    } else {
      out.push(ch.to_string())
    }
  }
  "\"" + out.join("") + "\""
}

///|
/// 渲染整份产物（**行与行之间是 `\n`，末尾带一个换行** —— 与旧实现逐字节一致）。
///
/// ⚠️ 文件头那段话里点名的命令换成了新的（`skillpress gen-queries`）：它只是注释，
///    但**换它就会让产物变一行** —— 所以换的时候要**重新生成**、再用 `queries-check` 确认。
fn render_queries(read : (String) -> String, grammars : String, names : Array[String]) -> String {
  let out : Array[String] = []
  out.push("// 由 `skillpress gen-queries` 生成 —— **不要手改**（改了会被下一次生成覆盖）。")
  out.push("//")
  out.push("// 内容 = `grammars/<语言>.highlights.scm` 的**逐字节**副本，给 **native** 垫片用：")
  out.push("// 那一侧没有引导层去读盘，所以 query 编进二进制（五份共 11 KB）。")
  out.push("// js 那条路仍然走引导层读盘（`globalThis.__skillpress_ts.scms`）—— 两边同源由")
  out.push("// `skillpress gen-queries --check` 钉住（不一致就红）。")
  out.push("")
  out.push("///|")
  out.push("/// 这门语言的 highlights query（没有这门语言就给空串）。")
  out.push("pub fn query_of(name : String) -> String {")
  out.push("  match name {")
  for n in names {
    out.push("    " + mbt_literal(n) + " => " + mbt_literal(read(@gates.join_path(grammars, n + ".highlights.scm"))))
  }
  out.push("    _ => \"\"")
  out.push("  }")
  out.push("}")
  out.push("")
  out.push("///|")
  out.push("/// 内嵌了哪几门语言（顺序固定 = 这套 query 集合的样子）。")
  out.push("pub fn query_languages() -> Array[String] {")
  let quoted : Array[String] = []
  for n in names {
    quoted.push(mbt_literal(n))
  }
  out.push("  [" + join_commas(quoted) + "]")
  out.push("}")
  out.join("\n") + "\n"
}

///|
/// 用 `, ` 连起来（`render_queries` 里那行数组字面量用）。
fn join_commas(items : Array[String]) -> String {
  let mut out = ""
  let mut first = true
  for it in items {
    if !first {
      out = out + ", "
    }
    out = out + it
    first = false
  }
  out
}

///|
/// 子命令本体。
fn gen_queries(rest : Array[String]) -> Unit {
  let host = current_host()
  // 程序根：`--program` → 引导层/环境变量给的提示 → cwd（与 `check` 同一套口径）。
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
  let mut check = false
  for a in rest {
    if a == "--check" {
      check = true
    }
  }
  let grammars = @gates.join_path(program, "grammars")
  let names : Array[String] = []
  for n in gen_query_langs() {
    if host.exists(@gates.join_path(grammars, n + ".highlights.scm")) {
      names.push(n)
    }
  }
  if names.length() == 0 {
    @content.note("✗ \{grammars} 下没有 .highlights.scm —— 这条判据不允许在空集合上通过")
    @content.set_exit_code(2)
    return
  }
  let text = render_queries(host.read, grammars, names)
  let out_file = @gates.join_path(
    @gates.join_path(@gates.join_path(program, "engine"), "highlight"),
    "queries.generated.mbt",
  )
  if check {
    let on_disk = host.read(out_file)
    if on_disk == text {
      println("✓ 内嵌 query 与 grammars/*.scm 逐字节同源（\{names.length()} 门）")
      return
    }
    @content.note("✗ engine/highlight/queries.generated.mbt 与 grammars/*.scm 不一致")
    @content.note("  跑 `skillpress gen-queries` 重新生成（别手改那份产物）")
    @content.set_exit_code(1)
    return
  }
  host.write(out_file, text)
  println("✓ 写好 engine/highlight/queries.generated.mbt（\{names.length()} 门，\{text.length()} 字节）")
}
