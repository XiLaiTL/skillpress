///|
/// 子页（`kids`）：一个 skill 的 `references/**` 与 `scripts/**`。
///
/// 移植对象是旧实现的 `readSkill` 里那两段（`lib/gen-content.mjs` 的 540–578）+ `kids.mjs` 的取名规矩：
///   · **ref**：任何子目录里的 `.md`（`SKILL.md` 除外）—— `references/` 只是推荐位置；
///   · **script**：`scripts/` 下**直接放的**非 md 文件，`lang` 按扩展名给，正文去掉结尾那一个 `\n`；
///   · 侧栏上显示的名字：`references/x.md` → `x`；其余按相对路径去扩展名；
///     **撞名就都退回全路径**（旧实现 `nameKids`）——"宁可长一点，也不要两个同名的子页"。
///
/// ⚠️ 遍历与排序**不在这里**：那是引导层的 `mdKids` / `scriptKids`（照抄 `kids.mjs` 的规矩），
/// 因为"顺序"也是逐字节判据的一部分，两处各排一次早晚会漂。

///|
/// 旧实现 `LANG_BY_EXT`：脚本子页的代码块按扩展名给语言（认不出来给空串 ⇒ 不上色）。
pub fn lang_by_ext(name : String) -> String {
  if name.has_suffix(".mjs") || name.has_suffix(".js") {
    "javascript"
  } else if name.has_suffix(".mbt") {
    "moonbit"
  } else if name.has_suffix(".sh") {
    "bash"
  } else if name.has_suffix(".py") {
    "python"
  } else if name.has_suffix(".json") {
    "json"
  } else if name.has_suffix(".toml") {
    "toml"
  } else if name.has_suffix(".yml") {
    "yaml"
  } else {
    ""
  }
}

///|
/// 相对路径 → 侧栏上显示的名字（旧实现 `kidName`）：`references/` 前缀不显示。
fn kid_name(rel : String) -> String {
  let no_ext = if rel.has_suffix(".md") { rel[:rel.length() - 3].to_owned() } else { rel }
  if no_ext.has_prefix("references/") {
    no_ext[11:].to_owned()
  } else {
    no_ext
  }
}

///|
/// 一组相对路径 → `(名字, 相对路径)`；**撞名的全部退回"相对路径去扩展名"**（旧实现 `nameKids`）。
pub fn name_kids(rels : Array[String]) -> Array[(String, String)] {
  let names = rels.map(kid_name)
  let out : Array[(String, String)] = []
  for i = 0; i < rels.length(); i = i + 1 {
    let dup = names.filter(fn(n) { n == names[i] }).length() > 1
    let name = if dup {
      if rels[i].has_suffix(".md") { rels[i][:rels[i].length() - 3].to_owned() } else { rels[i] }
    } else {
      names[i]
    }
    out.push((name, rels[i]))
  }
  out
}

///|
/// 一个 kid 字面量所需的东西（blocks 里的代码块这时**还没贴 runs** —— 高亮在整份文件那一步统一做，
/// 与旧实现 `highlightAll` 的时机一致）。
pub struct Kid {
  kind : String
  name : String
  title : String
  desc : String
  blocks : Array[Block]
}

///|
/// 读一个 skill 的子页（refs 在前、scripts 在后 —— 旧实现就是这个顺序）。
///
/// `read` 是"读文件"，由调用方给（IO 归宿主/引导层，这一层只做规矩）。
pub fn read_kids(
  skill_dir : String,
  read : (String) -> String,
  md_kids : (String) -> Array[String],
  script_kids : (String) -> Array[String],
) -> Array[Kid] {
  let kids : Array[Kid] = []
  for (name, rel) in name_kids(md_kids(skill_dir)) {
    let text = read(skill_dir + "/" + rel)
    let data = frontmatter_data(text)
    let body = frontmatter_body(text)
    let h1 = first_h1(body)
    let title = match data.get("title") {
      Some(t) => t
      None => if h1 != "" { h1 } else { name }
    }
    let desc = match data.get("description") {
      Some(d) => summarize(d, 46)
      None => summarize(first_nonempty_line(trim(body)), 46)
    }
    kids.push({ kind: "ref", name, title, desc, blocks: parse_blocks(body) })
  }
  for rel in script_kids(skill_dir) {
    let base = rel[8:].to_owned() // 去掉 "scripts/"
    let text = read(skill_dir + "/" + rel)
    let trimmed = if text.has_suffix("\n") { text[:text.length() - 1].to_owned() } else { text }
    kids.push({
      kind: "script",
      name: base,
      title: base,
      desc: "随这个 skill 一起发的可跑脚本",
      blocks: [Code(lang_by_ext(base), trimmed, [])],
    })
  }
  kids
}

///|
/// 旧实现 `rb.trim().split("\n").find((l) => l.trim()) || ""` —— 正文第一处非空行。
fn first_nonempty_line(body : String) -> String {
  for line in split_lines(body) {
    if trim(line) != "" {
      return trim(line)
    }
  }
  ""
}
