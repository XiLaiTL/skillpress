///|
/// 整份内容包的生成（旧实现 `generate` 的编排）。
///
/// 顺序照抄（**顺序也是判据**）：先解析全部 → 建页面键索引（首页认纯链接节要用）→ 解析首页 →
/// **统一贴 runs** → 再发射。把"贴 runs"放在最后一步是刻意的：旧实现就是先攒好结构再一次性高亮，
/// 于是代码块在发射时已经带着 runs；顺序换了不会立刻出错，但会与产物对不上。

///|
/// `Map` 取字段（没有给空串）—— frontmatter 的字段都是"没有就是空"。
fn field(data : Map[String, String], key : String) -> String {
  data.get(key).unwrap_or("")
}

///|
/// 生成整份 `content.generated.mbt` 的文本 + 问题清单。
///
/// `read` / `md_kids` / `script_kids` 由调用方注入（IO 归宿主，规矩在这一层）——
/// 这样这层逻辑是**纯**的：给它一份内容根的形状，它给回那份文件。
pub fn gen_content(
  root : String,
  dirs : Array[String],
  read : (String) -> String,
  md_kids : (String) -> Array[String],
  script_kids : (String) -> Array[String],
  note : (String) -> Unit,
) -> (String, Array[String]) raise {
  let problems : Array[String] = []
  // ① 页面键索引：文件路径（相对内容根）→ 页面键
  // ⚠️ 这两个回调拿到的是 **slug**，要自己拼成绝对路径再交给引导层（P8.1 实测：给 slug
  // 会让 `readdir` 去程序仓根找 `<slug>`，报 ENOENT）
  let index = build_index(
    dirs,
    fn(d) { name_kids(md_kids(root + "/" + d)) },
    fn(d) { script_kids(root + "/" + d) },
  )
  // ② 每份 skill（SKILL.md + 它的子页）
  let docs : Array[DocLit] = []
  for d in dirs {
    let text = read(root + "/" + d + "/SKILL.md")
    let data = frontmatter_data(text)
    let body = frontmatter_body(text)
    docs.push({
      slug: d,
      desc: summarize(field(data, "description"), 60),
      full_desc: field(data, "description"),
      when: field(data, "whenToUse"),
      blocks: parse_blocks(body, "skills/" + d + "/SKILL.md", fn(p) { problems.push(p) }),
      kids: read_kids(root + "/" + d, read, md_kids, script_kids, fn(p) { problems.push(p) }),
    })
  }
  // ③ 首页
  let (home0, home_problems) = read_home(root, index, read, note)
  for p in home_problems {
    problems.push(p)
  }
  // ④ 统一贴 runs（首页的 lede + 每一栏 + 每份 skill + 它的每个子页）
  let home : HomeLit? = match home0 {
    None => None
    Some(h) => {
      let sections : Array[SectionLit] = []
      for s in h.sections {
        sections.push({ title: s.title, link: s.link, nav: s.nav, blocks: fill_runs(s.blocks) })
      }
      Some({ title: h.title, lede: fill_runs(h.lede), sections })
    }
  }
  let filled : Array[DocLit] = []
  for d in docs {
    let kids : Array[Kid] = []
    for k in d.kids {
      kids.push({
        kind: k.kind,
        name: k.name,
        title: k.title,
        desc: k.desc,
        blocks: fill_runs(k.blocks),
      })
    }
    filled.push({
      slug: d.slug,
      desc: d.desc,
      full_desc: d.full_desc,
      when: d.when,
      blocks: fill_runs(d.blocks),
      kids,
    })
  }
  // ⑤ 发射（顺序与空行都照抄旧实现）
  let out = header_lines()
  out.push("///| 首页（来自 `skills/skillpress/SKILL.md`）。")
  out.push("pub fn home() -> " + REC + "Home {")
  match home {
    Some(h) => for line in home_lit_lines(h, "  ") {
      out.push(line)
    }
    None => out.push("  { title: \"moobile\", lede: [], sections: [] },")
  }
  out.push("}")
  out.push("")
  out.push("///| 全部 skill（按 slug 排序，保证生成物稳定）。")
  out.push("pub fn skills() -> Array[" + REC + "Doc] {")
  out.push("  [")
  for d in filled {
    for line in doc_lit_lines(d, "    ", true) {
      out.push(line)
    }
  }
  out.push("  ]")
  out.push("}")
  out.push("")
  for line in find_page_lines() {
    out.push(line)
  }
  (out.fold(init="", fn(acc, l) { acc + l + "\n" }), problems)
}
