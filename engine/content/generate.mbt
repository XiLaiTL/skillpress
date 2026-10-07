///|
/// **一次生成的全部产物**（`content.generated.mbt` + `llms.txt`）。
///
/// ⚠️ 为什么绑在一起返回：`llms.txt` 必须**与内容包同源**（同一份解析、同一套 slug/kid 枚举）。
///    让调用方各跑一遍「生成」就等于两份口径 —— 本仓明令禁止同一件事两个副本。
pub(all) struct Generated {
  mbt : String
  llms : String
  problems : Array[String]
}

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
pub fn gen_content_full(
  root : String,
  dirs : Array[String],
  home_file : String,
  read : (String) -> String,
  md_kids : (String) -> Array[String],
  script_kids : (String) -> Array[String],
  note : (String) -> Unit,
  license : String,
) -> Generated raise {
  let problems : Array[String] = []
  // ⓪ 首页源**先**选好（R2/D20）：索引与 kids 都要用它把首页源排除出去（首页不算子页）
  let pick = pick_home(root, home_file, read, note)
  // ① 页面键索引：文件路径（相对内容根）→ 页面键
  // ⚠️ 这两个回调拿到的是 **slug**，要自己拼成绝对路径再交给引导层（P8.1 实测：给 slug
  // 会让 `readdir` 去程序仓根找 `<slug>`，报 ENOENT）
  let index = build_index(
    dirs,
    fn(d) { name_kids(md_kids(root + "/" + d)) },
    fn(d) { script_kids(root + "/" + d) },
    pick.label,
  )
  // ② 每份 skill（SKILL.md + 它的子页）
  let docs : Array[DocLit] = []
  for d in dirs {
    let text = read(root + "/" + d + "/SKILL.md")
    let data = frontmatter_data(text)
    let body = frontmatter_body(text)
    // 界面上的名字 = frontmatter `title` → 正文 H1 → 回退 slug（与子页 `Kid.title` 同一套取法）
    let h1 = first_h1(body)
    let doc_title = match data.get("title") {
      Some(t) => t
      None => if h1 != "" { h1 } else { d }
    }
    docs.push({
      slug: d,
      title: doc_title,
      desc: summarize(field(data, "description"), 60),
      full_desc: field(data, "description"),
      when: field(data, "whenToUse"),
      blocks: resolve_block_links(
        parse_blocks(body, "skills/" + d + "/SKILL.md", fn(p) { problems.push(p) }),
        "skills/" + d + "/SKILL.md",
        index,
      ),
      kids: read_kids(
        root + "/" + d,
        read,
        md_kids,
        script_kids,
        fn(p) { problems.push(p) },
        pick.label,
        index,
      ),
    })
  }
  // ③ 首页（源已经选好；这里只解析）
  let hr = read_home(pick, index)
  for p in hr.problems {
    problems.push(p)
  }
  // ④ 统一贴 runs（首页的 lede + 每一栏 + 每份 skill + 它的每个子页）
  let home : HomeLit? = match hr.home {
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
      title: d.title,
      desc: d.desc,
      full_desc: d.full_desc,
      when: d.when,
      blocks: fill_runs(d.blocks),
      kids,
    })
  }
  // ⑤ 发射（顺序与空行都照抄旧实现）
  let out = header_lines()
  // 这条注释里点名的**首页源**要与实际用的一致（否则生成物在撒谎）。
  // ⚠️ 回退那一路必须与旧实现**逐字节一致** —— 旧实现把 `skills/skillpress/SKILL.md` 写死在这句里，
  //    而这句话在归一化规则里**不会被抹掉**（规则①只抹开头的 `//` 块，`///|` 文档注释算正文）。
  //    所以内容根口径写成 `skills/<相对路径>`；`--home` 覆盖时就用给的那条路径（那是"用户指定"，不猜）。
  let home_src = if hr.source == "" {
    "skills/skillpress/SKILL.md"
  } else if hr.source.has_prefix("skillpress/") {
    "skills/" + hr.source
  } else {
    hr.source
  }
  out.push("///| 首页（来自 `" + home_src + "`）。")
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
  // ⑥ 页脚那一块：**内容根摘要**（真值，生成期算）。
  //    ⚠️ 文件清单与**生成物自己用的那份同源** —— 同一个 `dirs`、同一套 kids 枚举，
  //    不另立一份"要指纹的文件列表"（两份清单 = 迟早一份多一份少，而摘要看不出少了谁）。
  //    去重是必需的：首页源回退那一路**就是**某份 skill 的 `SKILL.md`（`read_kids` 里同样要排掉它）。
  let pairs : Array[(String, @gates.Fingerprint)] = []
  let seen : Array[String] = []
  for d in dirs {
    let dir = root + "/" + d
    let rels : Array[String] = ["SKILL.md"]
    for rel in md_kids(dir) {
      rels.push(rel)
    }
    for rel in script_kids(dir) {
      rels.push(rel)
    }
    for rel in rels {
      let key = d + "/" + rel
      if !seen.contains(key) {
        seen.push(key)
        pairs.push((key, @gates.fingerprint(read(dir + "/" + rel))))
      }
    }
  }
  if hr.source != "" && !seen.contains(hr.source) {
    pairs.push((hr.source, @gates.fingerprint(read(root + "/" + hr.source))))
  }
  out.push("")
  for line in footer_lit_lines({ license: license, fingerprint: footprint_of(pairs) }) {
    out.push(line)
  }
  // llms.txt（Agent 出口）：同一份解析产出的第二件产物（见 Generated 的注释）。
  let llms = llms_lines(home, filled).fold(init="", fn(acc, l) { acc + l + "\n" })
  { mbt: out.fold(init="", fn(acc, l) { acc + l + "\n" }), llms, problems }
}


///|
/// 旧口径的薄包装：只要内容包文本 + 问题清单（`gen-file` 那条路走它）。
pub fn gen_content(
  root : String,
  dirs : Array[String],
  home_file : String,
  read : (String) -> String,
  md_kids : (String) -> Array[String],
  script_kids : (String) -> Array[String],
  note : (String) -> Unit,
  license : String,
) -> (String, Array[String]) raise {
  let g = gen_content_full(root, dirs, home_file, read, md_kids, script_kids, note, license)
  (g.mbt, g.problems)
}