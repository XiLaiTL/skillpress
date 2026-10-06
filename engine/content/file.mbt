///|
/// **整份 `content.generated.mbt` 的发射**（旧实现 `docLit` / `homeLit` / `generate` 的移植）。
///
/// ⚠️ 这里每一行文本都是**判据**（与旧实现的产物逐字节比），所以字符串一律照抄，
/// 连空行的个数（类型之间一个、`Section` 之后两个）都不能自作主张。
///
/// 形状刻意**不变**：类型声明仍写在生成物里（"类型搬进包"是 P6，不是这一步）。

///|
/// 一份 skill 的完整字面量原料（`blocks` 里的代码块此时已贴好 runs）。
pub struct DocLit {
  slug : String
  desc : String
  full_desc : String
  when : String
  blocks : Array[Block]
  kids : Array[Kid]
}

///|
/// 给一份文档的所有代码块贴 runs（**递归进子页**）——旧实现 `highlightAll` 的一半。
pub fn fill_runs(blocks : Array[Block]) -> Array[Block] raise {
  let out : Array[Block] = []
  for b in blocks {
    match b {
      Code(lang, text, _) => out.push(with_runs(lang, text))
      Ul(items) => {
        let items2 : Array[UlItem] = []
        for it in items {
          items2.push({ indent: it.indent, num: it.num, spans: it.spans, links: it.links })
        }
        out.push(Ul(items2))
      }
      _ => out.push(b)
    }
  }
  out
}

///|
/// 一个 `Doc` 字面量（旧实现 `docLit`）。
fn doc_lit_lines(d : DocLit, pad : String, comma : Bool) -> Array[String] {
  let out : Array[String] = []
  out.push(pad + "{")
  out.push(pad + "  slug: \"" + esc(d.slug) + "\",")
  out.push(pad + "  desc: \"" + esc(d.desc) + "\",")
  out.push(pad + "  full_desc: \"" + esc(d.full_desc) + "\",")
  out.push(pad + "  when: \"" + esc(d.when) + "\",")
  out.push(pad + "  blocks: [")
  for b in d.blocks {
    out.push(emit_block(b, pad + "    "))
  }
  out.push(pad + "  ],")
  out.push(pad + "  kids: [")
  for k in d.kids {
    out.push(pad + "    {")
    out.push(pad + "      kind: \"" + esc(k.kind) + "\",")
    out.push(pad + "      name: \"" + esc(k.name) + "\",")
    out.push(pad + "      title: \"" + esc(k.title) + "\",")
    out.push(pad + "      desc: \"" + esc(k.desc) + "\",")
    out.push(pad + "      blocks: [")
    for b in k.blocks {
      out.push(emit_block(b, pad + "        "))
    }
    out.push(pad + "      ],")
    out.push(pad + "    },")
  }
  out.push(pad + "  ],")
  out.push(pad + "}" + (if comma { "," } else { "" }))
  out
}

///|
/// 一个 `Home` 字面量（旧实现 `homeLit`）。
fn home_lit_lines(h : HomeLit, pad : String) -> Array[String] {
  let out : Array[String] = []
  out.push(pad + "{")
  out.push(pad + "  title: \"" + esc(h.title) + "\",")
  out.push(pad + "  lede: [")
  for b in h.lede {
    out.push(emit_block(b, pad + "    "))
  }
  out.push(pad + "  ],")
  out.push(pad + "  sections: [")
  for s in h.sections {
    let nav = if s.nav.length() == 0 {
      "([] : Array[NavItem])"
    } else {
      let parts : Array[String] = []
      for item in s.nav {
        parts.push("{ label: \"" + esc(item.0) + "\", key: \"" + esc(item.1) + "\" }")
      }
      "[" + parts.fold(init="", fn(acc, x) { if acc == "" { x } else { acc + ", " + x } }) + "]"
    }
    out.push(
      pad + "    { title: " + span_list(s.title) + ", link: \"" + esc(s.link) + "\", nav: " + nav +
      ", blocks: [",
    )
    for b in s.blocks {
      out.push(emit_block(b, pad + "      "))
    }
    out.push(pad + "    ] },")
  }
  out.push(pad + "  ],")
  out.push(pad + "}")
  out
}

///|
/// 类型声明与文件头（旧实现 `generate` 里那段 `out.push(...)` 的照抄）。
fn header_lines() -> Array[String] {
  [
    "// 由 `tools/gen-content.mjs` 生成 —— **别手改**（跑 `--check` 会红）。",
    "//",
    "// 内容源：`skills/skillpress/SKILL.md`（首页）+ `skills/<name>/{SKILL.md,references/*.md,scripts/*}`。",
    "// 为什么在构建期解析 markdown：见 `tools/gen-content.mjs` 的文件头。",
    "",
    "///| 一段行内内容。",
    "pub enum Span {",
    "  Txt(String)",
    "  Code(String)",
    "  Bold(String)",
    "}",
    "",
    "///| 正文里的一个块。",
    "pub enum Block {",
    "  Hr",
    "  H2(Array[Span])",
    "  H3(Array[Span])",
    "  H4(Array[Span])",
    "  P(Array[Span])",
    "  Quote(Array[Span])",
    "  Code(String, String, Array[(String, Int)]) // 语言, 正文, 高亮片段（文本, 色号）",
    "  Ul(Array[(Int, String, Array[Span])]) // 缩进, 序号前缀(有序列表用), 内容",
    "  Table(Array[Array[Span]], Array[Array[Array[Span]]]) // 表头, 行",
    "}",
    "",
    "///| 一个子页：skill 的 references/（深水区）或 scripts/（随 skill 发的脚本）。",
    "pub struct Kid {",
    "  kind : String // \"ref\" | \"script\"",
    "  name : String",
    "  title : String",
    "  desc : String",
    "  blocks : Array[Block]",
    "}",
    "",
    "///| 一页 = 一个 skill。",
    "pub struct Doc {",
    "  slug : String        // 目录名（= skill 名）",
    "  desc : String        // 侧栏用的一行摘要",
    "  full_desc : String   // frontmatter 的完整 description",
    "  when : String        // frontmatter 的 whenToUse",
    "  blocks : Array[Block]",
    "  kids : Array[Kid]",
    "}",
    "",
    "///| 分栏下拉菜单里的一条（来自那一节的第一个链接列表）。",
    "pub struct NavItem {",
    "  label : String  // 显示的名字",
    "  key : String    // 页面键（给 `find_page` 换成第几页）",
    "}",
    "",
    "///| 官网首页的一个**分栏** = 首页那份 skill 里的一个 `##`（顶部栏的一条）。",
    "pub struct Section {",
    "  title : Array[Span]  // 分栏名（就是那个 `##` 的标题文本）",
    "  blocks : Array[Block]",
    "  link : String        // 纯链接节：这一节指向的**页面键**（空 = 普通分栏，点了只换正文）",
    "  nav : Array[NavItem] // 这一节的下拉菜单（空 = 没有）；有它时点一下先展开",
    "}",
    "",
    "",
    "///| 首页（来自 `skills/skillpress/SKILL.md`：H1 + 首个 `##` 之前 = 首屏）。",
    "pub struct Home {",
    "  title : String       // H1 —— 页眉的站名",
    "  lede : Array[Block]  // 首屏正文",
    "  sections : Array[Section]",
    "}",
    "",
  ]
}

///|
/// `find_page` 的固定文本（旧实现逐行 `out.push`；⚠️ 里面那两处 `\{…}` 是**生成物里的插值**，
/// 到了这边必须写成 `\\{…}`，否则会被 MoonBit 自己先解释掉）。
fn find_page_lines() -> Array[String] {
  [
    "///| 页面键 → `(kind, skill 下标, 子页下标)`；认不出来给 `(-1, -1, -1)`。",
    "///",
    "/// 键的形状与生成器里的 `docKey` / `kidKey` **必须对账**：",
    "/// 主文档 = `<slug>`，子页 = `<slug>/<kind>/<name>`（kind 是 `ref` / `script`）。",
    "/// 站在**生成物**这一侧做这个查找，是为了让「第几页」这个编号只有一处定义（`skills()` 的顺序）。",
    "pub fn find_page(key : String) -> (Int, Int, Int) {",
    "  let ks = skills()",
    "  for i = 0; i < ks.length(); i = i + 1 {",
    "    let d = ks[i]",
    "    if key == d.slug {",
    "      return (1, i, 0)",
    "    }",
    "    for j = 0; j < d.kids.length(); j = j + 1 {",
    "      let k = d.kids[j]",
    "      if key == \"\\{d.slug}/\\{k.kind}/\\{k.name}\" {",
    "        return (2, i, j)",
    "      }",
    "    }",
    "  }",
    "  (-1, -1, -1)",
    "}",
  ]
}
