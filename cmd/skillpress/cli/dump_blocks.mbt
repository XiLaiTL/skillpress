///|
/// **`dump-blocks <内容根>`**：文档块的**对账视图**（`cmd/skillpress gen-file` 那条链的另一半仪器）。
///
/// R9：一个文件一件事 —— 这一件（块的对账与它的高亮切片）原来住在 `main.mbt` 里，
/// 2026-10-06 那条文件被别处的注释顶到 404 行时把它切了出来（**拆文件，不删注释凑数**）。
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
/// 输出格式是**判据的接口**（与 `tools/fixtures/expected/dump-blocks.txt`（入库的 golden） 逐字节可比）：
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

