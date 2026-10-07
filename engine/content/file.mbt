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
  /// 中文人话的名字（界面用它；`slug` 只给机器）。
  title : String
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
  out.push(pad + "  title: \"" + esc(d.title) + "\",")
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

// ── 页脚那三个值（DESIGN-site.md §5 页脚那一行） ──────────────────────────────

///|
/// 生成侧要填的页脚值。
///
/// ⚠️ 这里**没有 `generated_at`**：时间戳**不进内容包** —— 内容包要逐字节可复现
///    （`press --check` 拿同一份内容重跑必须一致），塞一个"生成那一刻"进去会让它每次变红。
///    真源是**宿主**（构建脚本），运行期读 `globalThis.__skillpress_build`。
///    理由与三个字段的空值语义写在 `shell/types.mbt` 的 `Footer`（一处定义，两处引用）。
pub struct FooterLit {
  license : String
  fingerprint : String
}

///|
/// **内容根摘要**：把每个内容文件的结构指纹归拢成一个 sha256 摘要。
///
/// 口径**复用 G8 那一套**（`@gates.fingerprint`：行数 / 字节 / 表格行 / 围栏块）——
/// 这里只多做"把多份揉成一个可展示的值"这一步，**不是另立一套内容哈希**（两处口径 = 迟早对不上）。
///
/// ⚠️ **不排序**：这个顺序本身已经是确定性的 —— `dirs` 按 slug 排（生成物就是这么承诺的），
///    每个 skill 里是 `SKILL.md` → refs → scripts（引导层的枚举顺序；js/native 两头给出同一顺序
///    本来是既有的硬要求）。再加一道排序只会多一个口径，收益是 0。
///
/// ⚠️ 拼接形态要**带分隔符**（每段之间用制表符、每条之间用换行）：
///    否则两条相邻的字段会粘在一起，而那种碰撞**不会报错** ——
///    它只会让「两份不同的内容」显示成同一个指纹（最坏的一种安静）。
pub fn footprint_of(pairs : Array[(String, @gates.Fingerprint)]) -> String {
  let buf = StringBuilder()
  for pair in pairs {
    let (path, fp) = pair
    // 长度前缀 + 数字之间逗号 + 记录之间分号：**不需要任何转义**，也不可能因为拼接而撞摘要。
    // （为什么不用制表符/换行当分隔符：那样得往字符串字面量里塞转义，而"转义写错"会让分隔符
    //   悄悄变成别的字符 —— 摘要照样算得出来，只是它已经不代表这份内容了。这一版是踩完之后改的。）
    buf.write_string(path.length().to_string())
    buf.write_string(":")
    buf.write_string(path)
    buf.write_string("|")
    buf.write_string(fp.lines.to_string())
    buf.write_string(",")
    buf.write_string(fp.bytes.to_string())
    buf.write_string(",")
    buf.write_string(fp.rows.to_string())
    buf.write_string(",")
    buf.write_string(fp.codeBlocks.to_string())
    buf.write_string(";")
  }
  @crypto.bytes_to_hex_string(@crypto.sha256(buf.to_string().to_bytes()))
}

///|
/// 页脚那一段的发射（`generated_at` 固定空串 —— 它的真源在宿主侧，见 `FooterLit`）。
fn footer_lit_lines(f : FooterLit) -> Array[String] {
  [
    "///| 页脚要交代的出处（DESIGN-site.md §5）：许可 / 生成时间 / 内容根指纹。",
    "///",
    "/// ⚠️ 空串 = 拿不到 ⇒ 页脚那一项**不画**（不写「许可 —」这种占位）。",
    "///    三个字段各自为什么可能空，写在 `shell/types.mbt` 的 `Footer` 里（一处定义）。",
    "pub fn footer() -> " + REC + "Footer {",
    "  {",
    "    license: \"" + esc(f.license) + "\",",
    "    generated_at: \"\",   // 由宿主构建脚本注入（内容包必须逐字节可复现）",
    "    root_fingerprint: \"" + esc(f.fingerprint) + "\",",
    "  }",
    "}",
    "",
  ]
}

///|
/// **`llms.txt` 的正文**（Agent 出口之一，DESIGN-site.md §5「Agent 出口」那一行）。
///
/// 形状照原型 `_scratch/ui-ref/demo.html` 里那份（每份 skill 一段：中文 `title` + 一行 `desc` +
/// **原文路径**；子页逐条）—— 不另发明一套：那个形态是可点的、也是 Agent 真能照着走的形式。
///
/// ⚠️ **原文路径从 `slug` / `name` 现拼**（`skills/<slug>/SKILL.md`、`skills/<slug>/references/<name>.md`、
///    脚本那类是 `skills/<slug>/scripts/<name>`）—— 与站点 URL 方案（`#/s/<slug>/<kid>/`）**同一套命名**，
///    别再各造一份（两份路径口径 = 迟早对不上，而 Agent 拿到的是一个走不通的地址）。
///
/// ⚠️ 这份文本要**逐字节可复现**（`press --check` 拿它跟磁盘那份逐行比）⇒ **不许写时间戳**。
pub fn llms_lines(home : HomeLit?, docs : Array[DocLit]) -> Array[String] {
  let out : Array[String] = []
  out.push("# llms.txt")
  out.push("")
  out.push("> 给 Agent 的整站索引：每一份 skill 一段，`原文` 就是它的路径（逐字节等于内容源那份文件）。")
  if home is Some(h) {
    out.push("")
    out.push("## 首页（" + h.title + "）")
    out.push("- 原文: skills/skillpress/WEBSITE.md")
  }
  for d in docs {
    out.push("")
    out.push("## " + d.title + " (" + d.slug + ")")
    out.push("- " + d.desc)
    out.push("- 原文: skills/" + d.slug + "/SKILL.md")
    for k in d.kids {
      let path = if k.kind == "script" {
        "skills/" + d.slug + "/scripts/" + k.name
      } else {
        "skills/" + d.slug + "/references/" + k.name + ".md"
      }
      out.push("- " + k.title + "：" + path)
    }
  }
  out.push("")
  out
}
