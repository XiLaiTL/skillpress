///|
/// 内容管线要用的**宿主能力**（**native target 专用**）：目录列举与读文件。
///
/// 与 `io.mbt`（js）对称：那边 IO 归**引导层**（`tools/run-js.mjs` 把 5 份 wasm/query 与
/// mdKids/scriptKids 挂在 `globalThis.__skillpress_ts` 上），这边**什么都不靠** ——
/// 目录列举与读文件直接走 `moonbitlang/x`，诊断走一个 20 行的 C 桩（stderr）。
///
/// ⚠️ **两个函数的遍历顺序是判据的一部分**，必须与 `io.mbt`（js 那条）同口径：
///    · `md_kids`：逐层递归、每层按名字排序、跳过 `.` 开头与产物目录、收 `.md`（`SKILL.md` 除外）；
///    · `script_kids`：`scripts/` 下**直接放的**非 md 文件，按名字排序。
///    ⚠️ **已知口径差**（写在明处）：js 那条用的是 JS 的 `localeCompare`（分语言环境），
///    这里是 UTF-16 码元序。两者在"同一层里既有大写开头又有小写开头的名字"时会**不同**
///    （例：`B.md` vs `a.md`）。我们的语料里没有这种名字（判据会盯着），但**别人的语料可能有** ——
///    真出现差异时要在 PLAN 里记一笔，而不是让两个 target 悄悄给出两种站点。

///|
/// 读一个文本文件（读不到给空串 —— 调用方自己去判"这是不是真的空"）。
pub fn read_text(path : String) -> String {
  try {
    @fs.read_file_to_string(path)
  } catch {
    _ => ""
  }
}

///|
/// 产物目录 / 依赖目录：两个 target 同一张表（`io.mbt` 那侧读的是引导层的 `SKIP_DIRS`）。
fn skip_name(name : String) -> Bool {
  name.has_prefix(".") ||
  name == "node_modules" ||
  name == "_build" ||
  name == "dist" ||
  name == "target" ||
  name == ".mooncakes" ||
  name == ".git" ||
  name == ".scratch"
}

///|
/// 一个 skill 目录下所有 `.md`（`SKILL.md` 除外）的相对路径，**按 `mdFiles` 的遍历顺序**。
pub fn md_kids(dir : String) -> Array[String] {
  let out : Array[String] = []
  md_walk(dir, "", out)
  out
}

///|
fn md_walk(dir : String, prefix : String, out : Array[String]) -> Unit {
  let names = try {
    @fs.read_dir(dir).to_owned()
  } catch {
    _ => []
  }
  let sorted = names.copy()
  // 每层排序（与 js 那条同口径；差异见文件头的"已知口径差"）
  @gates.sort_utf16(sorted)
  for name in sorted {
    if skip_name(name) {
      continue
    }
    let rel = if prefix == "" { name } else { prefix + "/" + name }
    let abs = @gates.join_path(dir, name)
    let is_dir = try {
      @fs.is_dir(abs)
    } catch {
      _ => false
    }
    if is_dir {
      md_walk(abs, rel, out)
    } else if name.has_suffix(".md") && rel != "SKILL.md" {
      out.push(rel)
    }
  }
}

///|
/// `scripts/` 下直接放着的非 md 文件（相对路径形如 `scripts/x.mjs`），按名字排序。
pub fn script_kids(dir : String) -> Array[String] {
  let scripts = @gates.join_path(dir, "scripts")
  let names = try {
    @fs.read_dir(scripts).to_owned()
  } catch {
    _ => []
  }
  let kept : Array[String] = []
  for name in names {
    if skip_name(name) || name.has_suffix(".md") {
      continue
    }
    let is_file = try {
      @fs.is_file(@gates.join_path(scripts, name))
    } catch {
      _ => false
    }
    if is_file {
      kept.push(name)
    }
  }
  @gates.sort_utf16(kept)
  let out : Array[String] = []
  for name in kept {
    out.push("scripts/" + name)
  }
  out
}

///|
/// 诊断信息（纯链接节还带着正文、多少块没配语法之类）—— **走 stderr**，
/// 因为 `gen-file` 的 stdout 是**那份文件本身**（判据要对它做逐字节 diff）。
pub fn note(msg : String) -> Unit {
  sp_eprintln(msg)
}

///|
/// 设退出码。⚠️ 与 js 那条（`process.exitCode = N`）**同一套语义**：只记下来，
/// 由**可执行件**在收摊时用它退出 —— 不在中途 `exit`（中途退会把还在跑的事截断）。
pub fn set_exit_code(code : Int) -> Unit {
  exit_code_ref.val = code
}

///|
/// 现在记着的退出码（native 的可执行件在 `main` 末尾用它退出）。
pub fn exit_code() -> Int {
  exit_code_ref.val
}

///|
/// 退出码的家（native 上没有 `process.exitCode` 那种全局，就自己留一个）。
let exit_code_ref : Ref[Int] = { val: 0 }

///|
#borrow(msg)
extern "c" fn sp_eprintln(msg : String) -> Unit = "sp_eprintln"
