///|
/// 内容管线要用的**宿主能力**（js target 专用）：目录列举与读文件。
///
/// 分工与 P8.0 的结论一致：**IO 归引导层**（`tools/run-js.mjs`），**规矩归 MoonBit**。
/// 列举的两个函数刻意与内容侧 `kids.mjs` 的 `mdFiles` / `scriptFiles` 同口径
/// （遍历顺序与排序也是逐字节判据的一部分 —— 两处各排一次早晚会漂）。

///|
/// 读一个文本文件（读不到给空串 —— 调用方自己去判"这是不是真的空"）。
pub fn read_text(path : String) -> String {
  read_text_js(path)
}

///|
extern "js" fn read_text_js(path : String) -> String =
  #|(path) => { try { return require("node:fs").readFileSync(path, "utf8"); } catch (e) { return ""; } }

///|
/// 一个 skill 目录下所有 `.md`（`SKILL.md` 除外）的相对路径，**按 `mdFiles` 的遍历顺序**。
pub fn md_kids(dir : String) -> Array[String] {
  split_rel(md_kids_js(dir))
}

///|
extern "js" fn md_kids_js(dir : String) -> String =
  #|(dir) => globalThis.__skillpress_ts.mdKids(dir).join("\n")

///|
/// `scripts/` 下直接放着的非 md 文件（相对路径形如 `scripts/x.mjs`），按 `scriptFiles` 的顺序。
pub fn script_kids(dir : String) -> Array[String] {
  split_rel(script_kids_js(dir))
}

///|
extern "js" fn script_kids_js(dir : String) -> String =
  #|(dir) => globalThis.__skillpress_ts.scriptKids(dir).join("\n")

///|
/// 换行分隔 → 数组（空串给空数组）。
///
/// ⚠️ 先 `to_owned()` 再挑：`split()` 出来的迭代器是**对临时字符串的视图**，
/// 直接 `split().filter()` 会读到空（P8.1 实测踩过：语料清单因此变成 0 份）。
fn split_rel(text : String) -> Array[String] {
  if text == "" {
    return []
  }
  text.split("\n").filter(fn(l) { l != "" }).map(fn(l) { l.to_owned() }).collect()
}

///|
/// 诊断信息（纯链接节还带着正文、多少块没配语法之类）—— **走 stderr**，
/// 因为 `gen-file` 的 stdout 是**那份文件本身**（判据要对它做逐字节 diff）。
pub fn note(msg : String) -> Unit {
  note_js(msg)
}

///|
extern "js" fn note_js(msg : String) -> Unit =
  #|(m) => console.error(m)

///|
/// 设退出码（对应旧实现的 `process.exitCode = N`；⚠️ 别用 `process.exit()`，
/// 那会在 wasm 句柄还挂着时强行收摊 —— 旧实现在这条上踩过，退出码会变成 127）。
pub fn set_exit_code(code : Int) -> Unit {
  set_exit_code_js(code)
}

///|
extern "js" fn set_exit_code_js(code : Int) -> Unit =
  #|(c) => { process.exitCode = c }
