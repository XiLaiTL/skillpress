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
      "([] : Array[" + REC + "NavItem])"
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
/// 文件头注释（旧实现 `generate` 里那段 `out.push(...)` 的照抄）。
///
/// ⚠️ **P6 起这里不再有类型声明**：`Span` / `Block` / `Kid` / `Doc` / `NavItem` / `Section` / `Home`
/// 全搬进了包 `shell`（`shell/types.mbt` 是唯一声明处），生成物只填值。
/// 这条"搬家"就是 `tools/file-parity.sh` 里那份**归一化**存在的理由（旧形状 = 有类型声明 + 裸构造器）。
fn header_lines() -> Array[String] {
  [
    "// 由 `skillpress` 生成（P6 起是 MoonBit 引擎：`cmd/skillpress gen-file`）—— **别手改**。",
    "//",
    "// 类型**不在这里**：它们在包 `XiLaiTL/skillpress/shell`（`Span` / `Block` / `Kid` / `Doc` /",
    "// `NavItem` / `Section` / `Home`）。这份文件只**填值**，所以每个构造器都带 `@shell.` 前缀 ——",
    "// 为什么必须带，见 `engine/content/emit.mbt` 里 `REC` 的注释。",
    "//",
    "// 内容源：`skills/skillpress/SKILL.md`（首页）+ `skills/<name>/{SKILL.md,references/*.md,scripts/*}`。",
    "// 为什么在构建期解析 markdown：见 `tools/gen-content.mjs` 的文件头（映射的**参照实现**还在那边）。",
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
