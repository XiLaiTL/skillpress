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
  // 图片在站点上的目录前缀（`--asset-base`，如 `img/`）。**站点把图放哪儿是站点的事** ——
  // 引擎只负责把"相对那份 md 的路径"折成"内容根里的规范路径"（见 `links.mbt` 的 `asset_src`）。
  asset_base : String,
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
        asset_base,
      ),
      kids: read_kids(
        root + "/" + d,
        read,
        md_kids,
        script_kids,
        fn(p) { problems.push(p) },
        pick.label,
        index,
        asset_base,
      ),
    })
  }
  // ③ 首页（源已经选好；这里只解析）
  let hr = read_home(pick, index, asset_base)
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
  // 首页源：`///|` 那条文档注释与文件头那句注释**都要用真的那个**（见下面各自的说明）。
  let home_src0 = if hr.source == "" {
    "skills/skillpress/SKILL.md"
  } else if hr.source.has_prefix("skillpress/") {
    "skills/" + hr.source
  } else {
    hr.source
  }
  let out = header_lines(home_src0)
  // 这条注释里点名的**首页源**要与实际用的一致（否则生成物在撒谎）。
  // ⚠️ 回退那一路必须与旧实现**逐字节一致** —— 旧实现把 `skills/skillpress/SKILL.md` 写死在这句里，
  //    而这句话在归一化规则里**不会被抹掉**（规则①只抹开头的 `//` 块，`///|` 文档注释算正文）。
  //    所以内容根口径写成 `skills/<相对路径>`；`--home` 覆盖时就用给的那条路径（那是"用户指定"，不猜）。
  out.push("///| 首页（来自 `" + home_src0 + "`）。")
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
    // ⚠️ 指纹要用**这次真的用到的那份文本**（`pick.text`），**不许**用 `read(root + "/" + hr.source)` 再读一遍
    //    （2026-10-07 修，实测的后果是**产物不幂等**）：
    //    首页这份文件被**两条路径**读 —— ① `pick_home` 用的是调用方给的**标签**（可能是相对路径，
    //    也可能是 `--home` 指的一条绝对路径）；② 这里的指纹当初按"内容根 + 标签"拼了个绝对路径。
    //    于是调用方那个"虚拟读"（`attach` 用它在首页还没落盘时喂一份计划稿）**只命中 ① 那条**：
    //    第一次 `attach` 时盘上还没有 `WEBSITE.md` ⇒ 指纹算的是**空串**，第二次跑文件已经在了
    //    ⇒ 指纹变了 ⇒ `attach-check` 的"幂等"那一条红（而页面照常渲染，只是内容包悄悄换了）。
    //    **同一份内容两个读法 = 迟早分叉**；这里收成一处：文本同一个，指纹自然同一个。
    pairs.push((hr.source, @gates.fingerprint(pick.text)))
  }
  out.push("")
  for line in footer_lit_lines({ license: license, fingerprint: footprint_of(pairs) }) {
    out.push(line)
  }
  // llms.txt（Agent 出口）：同一份解析产出的第二件产物（见 Generated 的注释）。
  // ⚠️ 第三个参数是**这次真的选中的首页源**（`hr.source`：`skillpress/WEBSITE.md`，或回退时的
  //    `skillpress/SKILL.md`）—— 首页那条原文路径**不许写死**（那会让"没写 WEBSITE.md 的工程"
  //    印出来的 llms.txt 指一份不存在的文件，`press` 当场停下。见 `llms_lines` 的注释）。
  let llms = llms_lines(home, filled, hr.source).fold(init="", fn(acc, l) { acc + l + "\n" })
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
  // ⚠️ 这一层是**旧口径的薄包装**（老判据/探针在用）：给一个默认前缀，别逼所有调用方都改。
  //    真源只有一处（`--asset-base`），这里只是它的默认值。
  asset_base? : String = "img/",
) -> (String, Array[String]) raise {
  let g = gen_content_full(root, dirs, home_file, read, md_kids, script_kids, note, license, asset_base)
  (g.mbt, g.problems)
}