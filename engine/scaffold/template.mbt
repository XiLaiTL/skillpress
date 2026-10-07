///|
/// **模板读取与占位符替换。**
///
/// 模板真源是 `template/.skillpress/**`（程序仓里那一份）；生成器把它逐个文件读出来、
/// 替换占位符、写进目标实例目录。
///
/// 两条判据写在这里而不是留给调用方：
///   · **产物里不许剩占位符**（替换漏了不会报错，只会静静编不过）；
///   · **目录里不许出现"没登记过的占位符样子"**（`{{…}}`）—— 那多半是模板里手滑写了个
///     名字不一样的占位符，而它会被原样写到生成物里。

///|
/// 模板里的一个文件（`rel` 是相对模板根的路径，正斜杠）。
pub struct TplFile {
  rel : String
  text : String
}

///|
/// `from` 在 `text` 里的**全部**出现替换成 `to`。
///
/// 自己写而不用标准库：`String::replace_all` 在不同版本里名字与口径变过，而这条路径是
/// "生成物对不对"的一部分 —— 少替换一处就是一份编不过的产物。自己写只有一种行为。
fn replace_all(text : String, from : String, to : String) -> String {
  if from == "" {
    return text
  }
  let mut out = ""
  let mut rest = text
  while true {
    match rest.find(from) {
      Some(i) => {
        out = out + rest[:i].to_owned() + to
        rest = rest[i + from.length():].to_owned()
      }
      None => {
        out = out + rest
        break
      }
    }
  }
  out
}

///|
/// 用替换表过一遍文本。
pub fn substitute(text : String, subs : Map[String, String]) -> String {
  let mut out = text
  for tok in all_tokens() {
    match subs.get(tok) {
      Some(v) => out = replace_all(out, tok, v)
      None => ()
    }
  }
  out
}

///|
/// 文本里还剩下的占位符（空表 = 干净）。判据遍历**全部**占位符名，不看"像不像"。
pub fn leftover_tokens(text : String) -> Array[String] {
  let out : Array[String] = []
  for tok in all_tokens() {
    if text.find(tok) is Some(_) {
      out.push(tok)
    }
  }
  out
}

///|
/// 文本里有没有**没登记过**的 `{{…}}` 形状（多半是模板里手滑写错的名字）。
///
/// 返回找到的那个片段（第一个），没有给 `None`。只认一行之内、非空、不含空白的 `{{x}}` ——
/// 免得把文档里"像占位符的举例"也当成错。
pub fn stray_token(text : String) -> Option[String] {
  let mut i = 0
  while i + 3 < text.length() {
    if text[i:i + 2] == "{{" {
      match text[i + 2:].find("}}") {
        Some(k) => {
          let body = text[i + 2:i + 2 + k].to_owned()
          let known = all_tokens().contains("{{" + body + "}}")
          let clean = body != "" && !body.contains(" ") && !body.contains("\n") && !body.contains("{")
          if clean && !known {
            return Some("{{" + body + "}}")
          }
          i = i + 2 + k + 2
        }
        None => i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  None
}

///|
/// 递归读模板目录（**按名字排序**：产物的顺序也是判据的一部分，读盘顺序不能进产物）。
///
/// 跳过：`node_modules/` `_build/` `dist/` `.mooncakes/` `.git/` 与 `README.md`
/// （那份是**模板自己的**说明，不是要发给使用者的实例文件）。
/// 返回 (文件, 问题)。
pub fn read_template(
  exists : (String) -> Bool,
  is_dir : (String) -> Bool,
  read : (String) -> String,
  read_dir : (String) -> Array[String],
  root : String,
) -> (Array[TplFile], Array[String]) {
  let files : Array[TplFile] = []
  let problems : Array[String] = []
  if !exists(root) {
    problems.push("找不到模板目录：`" + root + "` —— 这一份程序里应当带着 `template/.skillpress/`")
    return (files, problems)
  }
  walk(exists, is_dir, read, read_dir, root, "", files, problems)
  (files, problems)
}

///|
fn walk(
  exists : (String) -> Bool,
  is_dir : (String) -> Bool,
  read : (String) -> String,
  read_dir : (String) -> Array[String],
  root : String,
  rel : String,
  files : Array[TplFile],
  problems : Array[String],
) -> Unit {
  let here = if rel == "" { root } else { root + "/" + rel }
  let names : Array[String] = []
  for n in read_dir(here) {
    names.push(n)
  }
  // 排序：同一份模板在任何机器上都要生成同一份产物（读盘顺序不进产物）
  // ⚠️ 用 `@gates.sort_utf16`（JS `.sort()` 的码元序）—— **不许**用 `Array::sort()`：
  //    MoonBit 里它不是字典序（`tools/mbt-traps.sh` 会当场点名这一条）。
  let sorted = names.copy()
  @gates.sort_utf16(sorted)
  for name in sorted {
    if name == "node_modules" ||
      name == "_build" ||
      name == "dist" ||
      name == ".mooncakes" ||
      name == ".git" {
      continue
    }
    let child_rel = if rel == "" { name } else { rel + "/" + name }
    if is_dir(root + "/" + child_rel) {
      walk(exists, is_dir, read, read_dir, root, child_rel, files, problems)
    } else {
      if child_rel == "README.md" {
        continue
      }
      files.push({ rel: child_rel, text: read(root + "/" + child_rel) })
    }
  }
}
