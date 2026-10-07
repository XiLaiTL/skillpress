///|
/// **README → 首页源**（`WEBSITE.md`）的改写。
///
/// 首页那份文件不是普通 markdown：它有**两处会被当成导航**的构造（见引擎的 `home.mbt`）——
///   · `## [名字](目标)` —— **纯链接节**：点它直接渲染目标页；
///   · 某个 `##` 底下**整条是链接的列表** —— 那一栏的**下拉菜单**。
/// 这两处一旦指向"站点上没有的页"，生成就会**报错**（不给你静默的死链）。
/// 而 README 里的链接绝大多数正是"站点上没有的页"（`docs/xxx.md`、`https://…`）⇒
/// 照抄 README 十有八九生不出站。
///
/// 所以这里的规矩是三条：
///   ① **能对上账的**（目标落在内容根里、且第一段就是书架上那份 skill）⇒ 改写成站点口径的路径；
///   ② **对不上账的** ⇒ **降级成纯文本**，并且**逐条打印**（不静默 —— 悄悄改人家的文档是最坏的一种"帮忙"）；
///   ③ 认不出的构造**一并打印**（表格缺分隔行、围栏没闭合这类最终由引擎点名，这里不重复判）。
///
/// ⚠️ 代码围栏里的东西**一个字都不动**（README 里贴的示例链接不是导航）。

///|
/// 改写结果：产物文本 + 站名（H1）+ 逐条说明。
pub struct Home {
  text : String
  site_name : String
  notes : Array[String]
}

///|
/// `[文字](目标)` —— **整条**就是一个链接才算（前后不能有别的东西）。
/// 返回 `(文字, 目标)`；不是链接给 `None`。
fn whole_link(s : String) -> Option[(String, String)] {
  let t = s.trim()
  if !t.has_prefix("[") {
    return None
  }
  let close = match t.find("](") {
    Some(i) => i
    None => return None
  }
  if !t.has_suffix(")") {
    return None
  }
  let label = t[1:close].to_owned()
  let target = t[close + 2:t.length() - 1].to_owned()
  // 目标里再有括号/方括号 ⇒ 不赌，交回降级那条路（宁可少一个导航，不要一个错的）
  if label.contains("]") || target.contains(")") || target == "" || label == "" {
    return None
  }
  Some((label, target))
}

///|
/// 去掉开头的 `./` 与 `/`，再去掉结尾的 `/`。
fn tidy_target(t : String) -> String {
  let mut s = t.trim().to_owned()
  while s.has_prefix("./") {
    s = s[2:].to_owned()
  }
  while s.has_prefix("/") {
    s = s[1:].to_owned()
  }
  while s.has_suffix("/") {
    s = s[:s.length() - 1].to_owned()
  }
  s
}

///|
/// 一份 skill 目录名字的集合（查"这个目标是不是书架上的一页"）。
fn shelf_index(shelf : Array[String]) -> Map[String, Bool] {
  let m : Map[String, Bool] = Map([])
  for s in shelf {
    m.set(s, true)
  }
  m
}

///|
/// 把 README 里的目标改写成**站点口径**的路径；对不上账给 `None`（调用方降级）。
///
/// 站点口径 = **相对内容根**（`<slug>/SKILL.md`、`<slug>/references/x.md`）。
/// README 口径 = **相对仓根**（`skills/<slug>/SKILL.md`）⇒ 先把内容根那段前缀摘掉再判。
fn to_site_target(raw : String, corpus_rel : String, shelf : Map[String, Bool]) -> Option[String] {
  let t = tidy_target(raw)
  if t == "" {
    return None
  }
  // 外链 / 锚点 / 邮件：**不是站点上的一页**（首页那两处导航只认已收录的页）
  if t.contains("://") || t.has_prefix("#") || t.has_prefix("mailto:") {
    return None
  }
  let mut rel = t
  if corpus_rel != "" && (rel == corpus_rel || rel.has_prefix(corpus_rel + "/")) {
    rel = if rel == corpus_rel { "" } else { rel[corpus_rel.length() + 1:].to_owned() }
  }
  if rel == "" {
    return None
  }
  let seg = match rel.find("/") {
    Some(i) => rel[:i].to_owned()
    None => rel
  }
  if !shelf.contains(seg) {
    return None
  }
  Some(rel)
}

///|
/// 标题行是不是 `##` 级别（返回内容；不是给 `None`）。
fn h2_body(line : String) -> Option[String] {
  if line.has_prefix("## ") {
    return Some(line[3:].to_owned())
  }
  None
}

///|
/// 列表项行：整条是一个链接（`- [文字](目标)`）就返回 `(缩进, 文字, 目标)`。
fn bullet_link(line : String) -> Option[(String, String, String)] {
  let mut indent = ""
  let mut i = 0
  while i < line.length() &&
    (line[i:i + 1] == " " || line[i:i + 1] == "\t") {
    indent = indent + line[i:i + 1].to_owned()
    i = i + 1
  }
  let rest = line[i:].to_owned()
  let body = if rest.has_prefix("- ") {
    rest[2:].to_owned()
  } else if rest.has_prefix("* ") {
    rest[2:].to_owned()
  } else {
    return None
  }
  match whole_link(body) {
    Some((label, target)) => Some((indent, label, target))
    None => None
  }
}

///|
/// **把 README 改写成首页源。**
///
/// `shelf` = 会上书架的 skill 目录名（**已排除被忽略的**）；`corpus_rel` = 内容根相对仓根的路径
/// （如 `skills`，用来把 README 口径的链接折成站点口径）；`fallback_name` = 连 H1 都没有时的站名兜底。
pub fn home_from_readme(
  src : String,
  shelf : Array[String],
  corpus_rel : String,
  fallback_name : String,
) -> Home {
  let notes : Array[String] = []
  let idx = shelf_index(shelf)
  let lines : Array[String] = []
  for l in src.split("\n") {
    lines.push(l.to_owned())
  }
  // ① H1：README 的 H1 就是站名。找不到就补一个（并打印）。
  let mut h1 = -1
  let mut i = 0
  while i < lines.length() {
    if lines[i].has_prefix("# ") && h1 < 0 {
      h1 = i
    }
    i = i + 1
  }
  let site_name = if h1 >= 0 {
    lines[h1][2:].trim().to_owned()
  } else {
    notes.push("README 里没有 H1（`# 站名`）⇒ 站名用「" + fallback_name + "」兜底")
    fallback_name
  }
  let out : Array[String] = []
  out.push("# " + site_name)
  out.push("")
  // ② 正文：逐行改写，代码围栏里**一个字不动**。
  let mut fence = false
  let mut seen_h2 = false
  // H1 后面本来就补了一个空行 ⇒ 正文开头再出现的空行要吃掉，否则产物 H1 底下会多一块空白。
  let mut started = false
  let mut j = 0
  while j < lines.length() {
    let line = lines[j]
    if line.has_prefix("```") || line.has_prefix("~~~") {
      fence = !fence
      out.push(line)
      started = true
      j = j + 1
      continue
    }
    // 围栏里的内容**一个字不动**；README 的 H1 也已经写在最前面了，这里跳过它。
    if fence {
      out.push(line)
      j = j + 1
      continue
    }
    if j == h1 {
      j = j + 1
      continue
    }
    if !started && line.trim() == "" {
      j = j + 1
      continue
    }
    started = true
    match h2_body(line) {
      Some(body) => {
        seen_h2 = true
        match whole_link(body) {
          Some((label, target)) => match to_site_target(target, corpus_rel, idx) {
            Some(rel) => {
              if rel != tidy_target(target) {
                notes.push("栏「" + label + "」：链接 `" + target + "` ⇒ 改成站点口径 `" + rel + "`")
              }
              out.push("## [" + label + "](" + rel + ")")
            }
            None => {
              notes.push("栏「" + label + "」：链接 `" + target + "` 指不到站点上的页 ⇒ 降级成纯文本标题")
              out.push("## " + label)
            }
          }
          None => out.push(line)
        }
      }
      None => {
        match bullet_link(line) {
          Some((indent, label, target)) => match to_site_target(target, corpus_rel, idx) {
            Some(rel) => {
              if rel != tidy_target(target) {
                notes.push("列表项「" + label + "」：`" + target + "` ⇒ `" + rel + "`")
              }
              out.push(indent + "- [" + label + "](" + rel + ")")
            }
            None => {
              notes.push("列表项「" + label + "」：`" + target + "` 指不到站点上的页 ⇒ 降级成纯文本")
              out.push(indent + "- " + label)
            }
          }
          None => out.push(line)
        }
      }
    }
    j = j + 1
  }
  // ③ 书架那一栏：模板自己补上 —— 那是**这份语料实际有什么**，README 里通常没有。
  if shelf.length() > 0 {
    out.push("")
    out.push("## 书架")
    out.push("")
    for s in shelf {
      out.push("- [" + s + "](" + s + "/SKILL.md)")
    }
    out.push("")
    out.push("上面这个列表每一项**整条是一个链接**、目标都是已收录的页 ⇒ 它就是这一栏的**下拉菜单**。")
  } else if !seen_h2 {
    // 一份 skill 都没上架、README 又没分栏 ⇒ 首页会**一个栏位都没有**，引擎会点名。
    out.push("")
    out.push("## 一、这里有什么")
    out.push("")
    notes.push("README 里一个 `##` 都没有、书架上也没有 skill ⇒ 补了一栏占位（首页至少要有分栏）")
  }
  { text: out.fold(init="", fn(acc, l) { if acc == "" { l } else { acc + "\n" + l } }) + "\n", site_name, notes }
}
