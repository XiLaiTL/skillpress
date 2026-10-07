// 由 `skillpress` 生成（P6 起是 MoonBit 引擎：`cmd/skillpress gen-file`）—— **别手改**。
//
// 类型**不在这里**：它们在包 `XiLaiTL/skillpress/shell`（`Span` / `Block` / `Kid` / `Doc` /
// `NavItem` / `Section` / `Home`）。这份文件只**填值**，所以每个构造器都带 `@shell.` 前缀 ——
// 为什么必须带，见 `engine/content/emit.mbt` 里 `REC` 的注释。
//
// 内容源：`skills/skillpress/SKILL.md`（首页）+ `skills/<name>/{SKILL.md,references/*.md,scripts/*}`。
// 为什么在构建期解析 markdown：见 `tools/gen-content.mjs` 的文件头（映射的**参照实现**还在那边）。

///| 首页（来自 `skills/skillpress/SKILL.md`）。
pub fn home() -> @shell.Home {
  {
    title: "夹具语料（parity fixture）",
    lede: [
      @shell.P([@shell.Txt("这是"), @shell.Bold("逐字节对账"), @shell.Txt("用的一小份"), @shell.Bold("冻结"), @shell.Txt("语料：它自己住在程序仓里 （"), @shell.Code("tools/fixtures/corpus/"), @shell.Txt("），不随内容仓变化 —— 拿它当基准的判据"), @shell.Bold("不会腐"), @shell.Txt("。")]),
    ],
    sections: [
      { title: [@shell.Txt("一、这份语料里有什么")], link: "", nav: ([] : Array[@shell.NavItem]), blocks: [
        @shell.Ul([(0, "", [@shell.Code("alpha-skill"), @shell.Txt("：有子页（含一层更深的子目录）、有 "), @shell.Code("scripts/")]), (0, "", [@shell.Code("beta-skill"), @shell.Txt("：有表格，以及多种语言的代码块")]), (0, "", [@shell.Code("gamma-skill"), @shell.Txt("：有跨 skill 的链接与行内标记")])]),
      ] },
      { title: [@shell.Txt("二、从哪一份开始")], link: "", nav: ([] : Array[@shell.NavItem]), blocks: [
        @shell.P([@shell.Txt("intro"), @shell.Code("references/intro.md")]),
      ] },
      { title: [@shell.Txt("三、一段带行内标记的正文")], link: "", nav: ([] : Array[@shell.NavItem]), blocks: [
        @shell.P([@shell.Txt("读的时候先看 "), @shell.Bold("加粗的那个结论"), @shell.Txt("，再回头看 "), @shell.Code("行内代码"), @shell.Txt(" 里的参数 —— 它们描述的是同一件事， 只是一个是结论、一个是证据。这一段刻意够长，好让\"探针句子\"有东西可选。")]),
      ] },
      { title: [@shell.Txt("四、去哪看")], link: "", nav: ([] : Array[@shell.NavItem]), blocks: [
        @shell.Table([[@shell.Txt("想做什么")], [@shell.Txt("去哪")]], [[[@shell.Txt("建一个应用")], [@shell.Txt("alpha"), @shell.Code("alpha-skill/references/notes.md")]], [[@shell.Txt("看多种语言的例子")], [@shell.Code("beta-skill")]]]),
      ] },
    ],
  }
}

///| 全部 skill（按 slug 排序，保证生成物稳定）。
pub fn skills() -> Array[@shell.Doc] {
  [
    {
      slug: "alpha-skill",
      title: "alpha-skill",
      desc: "夹具里的第一份 skill：有子页、有更深一层的子目录、还有 scripts/。",
      full_desc: "夹具里的第一份 skill：有子页、有更深一层的子目录、还有 scripts/。",
      when: "你要在夹具里验\"子页发现与侧栏树\"时用这一份。",
      blocks: [
        @shell.P([@shell.Txt("这一份用来验"), @shell.Bold("子页发现"), @shell.Txt("："), @shell.Code("references/"), @shell.Txt(" 下的 md、以及 "), @shell.Code("references/deep/"), @shell.Txt(" 里更深一层的 md 都应当被收进来，顺序按 UTF-16 码元序。")]),
        @shell.H2([@shell.Txt("一段正文")]),
        @shell.P([@shell.Txt("普通段落里可以有 "), @shell.Bold("加粗"), @shell.Txt("、"), @shell.Code("行内代码"), @shell.Txt("、以及 指向另一个 skill 的链接"), @shell.Code("../beta-skill/SKILL.md"), @shell.Txt("。 段落要够长，这样探针句子才有得挑 —— 不然对账时\"挑哪一句\"会变成一件碰运气的事。")]),
        @shell.H2([@shell.Txt("代码")]),
        @shell.Code("bash", "# 一段 bash：验上色与\"围栏切分\"\nset -euo pipefail\necho \"hello from the fixture\"", [("# 一段 bash：验上色与\"围栏切分\"", 3), ("\n", 0), ("set", 6), (" ", 0), ("-euo", 4), (" pipefail\n", 0), ("echo", 6), (" ", 0), ("\"hello from the fixture\"", 2)]),
        @shell.H2([@shell.Txt("列表")]),
        @shell.Ul([(0, "", [@shell.Txt("第一条")]), (0, "", [@shell.Txt("第二条，带 "), @shell.Code("行内代码")]), (0, "", [@shell.Txt("第三条")])]),
      ],
      kids: [
        {
          kind: "ref",
          name: "deep/nested",
          title: "更深一层的子页",
          desc: "# 更深一层的子页",
          blocks: [
            @shell.P([@shell.Txt("这一页"), @shell.Bold("没有 frontmatter"), @shell.Txt("，所以它的标题会退到第一个 "), @shell.Code("#"), @shell.Txt(" 标题 —— 这正是要验的那条规矩。 路径在 "), @shell.Code("references/deep/"), @shell.Txt(" 里，验的是\"任何子目录里的 md 都收\"。")]),
          ],
        },
        {
          kind: "ref",
          name: "notes",
          title: "alpha 的细则",
          desc: "这一页是子页，用来验\"标题取 title、没有 title 就取第一个 # 标题\"。",
          blocks: [
            @shell.P([@shell.Txt("子页的"), @shell.Bold("标题"), @shell.Txt("取 frontmatter 里的 "), @shell.Code("title"), @shell.Txt("；没有才退到第一个 "), @shell.Code("#"), @shell.Txt(" 标题。")]),
            @shell.H2([@shell.Txt("一个表格")]),
            @shell.Table([[@shell.Txt("字段")], [@shell.Txt("含义")]], [[[@shell.Txt("name")], [@shell.Txt("页面键里用的显示名")]], [[@shell.Txt("probe")], [@shell.Txt("用来断言\"点进去换页了\"的那句话")]]]),
          ],
        },
        {
          kind: "script",
          name: "probe.mjs",
          title: "probe.mjs",
          desc: "随这个 skill 一起发的可跑脚本",
          blocks: [
            @shell.Code("javascript", "// 一个非 md 的脚本文件：它应当作为一个 kid 出现在侧栏里（名字带扩展名）。\nconsole.log(\"fixture probe\");", [("// 一个非 md 的脚本文件：它应当作为一个 kid 出现在侧栏里（名字带扩展名）。", 3), ("\n", 0), ("console", 8), (".", 9), ("log", 6), ("(", 9), ("\"fixture probe\"", 2), (");", 9)]),
          ],
        },
      ],
    },
    {
      slug: "beta-skill",
      title: "beta-skill",
      desc: "夹具里的第二份 skill：表格与多种语言的代码块。",
      full_desc: "夹具里的第二份 skill：表格与多种语言的代码块。",
      when: "你要验\"表格渲染\"或\"多语言上色\"时用这一份。",
      blocks: [
        @shell.P([@shell.Txt("这一份用来验"), @shell.Bold("表格"), @shell.Txt("与"), @shell.Bold("多种语言的代码块"), @shell.Txt("（上色那条判据要按语言分别读数）。 代码块刻意写得"), @shell.Bold("有东西可上色"), @shell.Txt("（关键字 / 字符串 / 注释 / 数字）—— 都是同一段空壳代码的话， \"上色退步\"这件事在读数上看不出来。")]),
        @shell.H2([@shell.Txt("表格")]),
        @shell.Table([[@shell.Txt("语言")], [@shell.Txt("用途")], [@shell.Txt("备注")]], [[[@shell.Txt("bash")], [@shell.Txt("脚本")], [@shell.Txt("判据脚本自己就是 bash")]], [[@shell.Txt("json")], [@shell.Txt("数据")], [@shell.Txt("注册表与锁")]], [[@shell.Txt("toml")], [@shell.Txt("配置")], [@shell.Txt("语法资产")]], [[@shell.Txt("moonbit")], [@shell.Txt("引擎")], [@shell.Txt("引擎与界面都是它")]]]),
        @shell.H2([@shell.Txt("JSON")]),
        @shell.Code("json", "{\n  \"name\": \"beta-skill\",\n  \"version\": \"1.0.0\",\n  \"keywords\": [\"fixture\", \"parity\"],\n  \"count\": 42,\n  \"enabled\": true\n}", [("{\n  ", 0), ("\"name\"", 2), (": ", 0), ("\"beta-skill\"", 2), (",\n  ", 0), ("\"version\"", 2), (": ", 0), ("\"1.0.0\"", 2), (",\n  ", 0), ("\"keywords\"", 2), (": [", 0), ("\"fixture\"", 2), (", ", 0), ("\"parity\"", 2), ("],\n  ", 0), ("\"count\"", 2), (": ", 0), ("42", 4), (",\n  ", 0), ("\"enabled\"", 2), (": ", 0), ("true", 4), ("\n}", 0)]),
        @shell.H2([@shell.Txt("TOML")]),
        @shell.Code("toml", "[package]\nname = \"fixture\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n\n[deps]\nengine = \"1.2.3\"", [("[", 9), ("package", 5), ("]", 9), ("\n", 0), ("name", 5), (" = ", 8), ("\"fixture\"", 2), ("\n", 0), ("version", 5), (" = ", 8), ("\"0.1.0\"", 2), ("\n", 0), ("license", 5), (" = ", 8), ("\"Apache-2.0\"", 2), ("\n\n", 0), ("[", 9), ("deps", 5), ("]", 9), ("\n", 0), ("engine", 5), (" = ", 8), ("\"1.2.3\"", 2)]),
        @shell.H2([@shell.Txt("MoonBit")]),
        @shell.Code("moonbit", "///|\n/// 一段有函数、有匹配、有字符串的 MoonBit。\npub fn classify(n : Int) -> String {\n  match n {\n    0 => \"zero\"\n    x if x > 0 => \"positive\"\n    _ => \"negative\"\n  }\n}\n\n///|\npub fn main {\n  println(classify(42))\n}", [("///|", 3), ("\n", 0), ("/// 一段有函数、有匹配、有字符串的 MoonBit。", 3), ("\n", 0), ("pub", 1), (" ", 0), ("fn", 1), (" ", 0), ("classify", 6), ("(", 9), ("n", 8), (" ", 0), (":", 9), (" ", 0), ("Int", 5), (")", 9), (" ", 0), ("->", 9), (" ", 0), ("String", 5), (" ", 0), ("{", 9), ("\n  ", 0), ("match", 1), (" ", 0), ("n", 8), (" ", 0), ("{", 9), ("\n    ", 0), ("0", 4), (" ", 0), ("=>", 9), (" ", 0), ("\"zero\"", 2), ("\n    ", 0), ("x", 8), (" ", 0), ("if", 1), (" ", 0), ("x", 8), (" ", 0), (">", 9), (" ", 0), ("0", 4), (" ", 0), ("=>", 9), (" ", 0), ("\"positive\"", 2), ("\n    _ ", 0), ("=>", 9), (" ", 0), ("\"negative\"", 2), ("\n  ", 0), ("}", 9), ("\n", 0), ("}", 9), ("\n\n", 0), ("///|", 3), ("\n", 0), ("pub", 1), (" ", 0), ("fn", 1), (" ", 0), ("main", 6), (" ", 0), ("{", 9), ("\n  ", 0), ("println", 6), ("(", 9), ("classify", 6), ("(", 9), ("42", 4), ("))", 9), ("\n", 0), ("}", 9)]),
        @shell.H2([@shell.Txt("JavaScript")]),
        @shell.Code("javascript", "// 一段有注释、模板串与函数的 JS\nexport function greet(name) {\n  const who = String(name ?? \"world\");\n  return `hello, ${who}!`;\n}", [("// 一段有注释、模板串与函数的 JS", 3), ("\n", 0), ("export", 1), (" ", 0), ("function", 1), (" ", 0), ("greet", 6), ("(", 9), ("name", 8), (")", 9), (" ", 0), ("{", 9), ("\n  ", 0), ("const", 1), (" ", 0), ("who", 8), (" ", 0), ("=", 9), (" ", 0), ("String", 5), ("(", 9), ("name", 8), (" ", 0), ("??", 9), (" ", 0), ("\"world\"", 2), (");", 9), ("\n  ", 0), ("return", 1), (" ", 0), ("`hello, ${who}!`", 2), (";", 9), ("\n", 0), ("}", 9)]),
        @shell.H2([@shell.Txt("Bash")]),
        @shell.Code("bash", "# 一段有变量、有函数、有条件的 bash\nset -euo pipefail\nroot=\"${1:-.}\"\nif [ -d \"$root/skills\" ]; then\n  echo \"skills root: $root/skills\"\nfi", [("# 一段有变量、有函数、有条件的 bash", 3), ("\n", 0), ("set", 6), (" ", 0), ("-euo", 4), (" pipefail\n", 0), ("root", 8), ("=", 0), ("\"${1:-.}\"", 2), ("\n", 0), ("if", 1), (" [ -d ", 0), ("\"$root/skills\"", 2), (" ]; ", 0), ("then", 1), ("\n  ", 0), ("echo", 6), (" ", 0), ("\"skills root: $root/skills\"", 2), ("\n", 0), ("fi", 1)]),
      ],
      kids: [
      ],
    },
    {
      slug: "gamma-skill",
      title: "gamma-skill",
      desc: "夹具里的第三份 skill：跨 skill 的链接与行内标记。",
      full_desc: "夹具里的第三份 skill：跨 skill 的链接与行内标记。",
      when: "你要验\"链接解析（首页目录相对 / 内容根相对两条规矩）\"时用这一份。",
      blocks: [
        @shell.P([@shell.Txt("这一份用来验"), @shell.Bold("链接解析"), @shell.Txt("："), @shell.Code("[alpha](../alpha-skill/SKILL.md)"), @shell.Txt(" 是"), @shell.Bold("相对本文件所在目录"), @shell.Txt("的一跳， 而 "), @shell.Code("[alpha 的细则](alpha-skill/references/notes.md)"), @shell.Txt(" 是"), @shell.Bold("相对内容根"), @shell.Txt("的一跳 —— 两条都要能解开。")]),
        @shell.H2([@shell.Txt("行内标记")]),
        @shell.P([@shell.Txt("一段话里可以有 "), @shell.Bold("加粗"), @shell.Txt("、"), @shell.Code("行内代码"), @shell.Txt("、*斜体*、以及 一个链到别处的链接"), @shell.Code("../alpha-skill/references/notes.md"), @shell.Txt("。 行内标记剥掉之后应当与页面上 "), @shell.Code("innerText"), @shell.Txt(" 对得上。")]),
        @shell.H2([@shell.Txt("收尾")]),
        @shell.P([@shell.Txt("最后一段也是正文，用来验\"文件末尾的块与空行\"。")]),
      ],
      kids: [
      ],
    },
    {
      slug: "skillpress",
      title: "夹具语料（parity fixture）",
      desc: "夹具语料的首页源：这份语料里有什么、从哪一份开始读。",
      full_desc: "夹具语料的首页源：这份语料里有什么、从哪一份开始读。",
      when: "",
      blocks: [
        @shell.P([@shell.Txt("这是"), @shell.Bold("逐字节对账"), @shell.Txt("用的一小份"), @shell.Bold("冻结"), @shell.Txt("语料：它自己住在程序仓里 （"), @shell.Code("tools/fixtures/corpus/"), @shell.Txt("），不随内容仓变化 —— 拿它当基准的判据"), @shell.Bold("不会腐"), @shell.Txt("。")]),
        @shell.H2([@shell.Txt("一、这份语料里有什么")]),
        @shell.Ul([(0, "", [@shell.Code("alpha-skill"), @shell.Txt("：有子页（含一层更深的子目录）、有 "), @shell.Code("scripts/")]), (0, "", [@shell.Code("beta-skill"), @shell.Txt("：有表格，以及多种语言的代码块")]), (0, "", [@shell.Code("gamma-skill"), @shell.Txt("：有跨 skill 的链接与行内标记")])]),
        @shell.H2([@shell.Txt("二、从哪一份开始")]),
        @shell.P([@shell.Txt("intro"), @shell.Code("references/intro.md")]),
        @shell.H2([@shell.Txt("三、一段带行内标记的正文")]),
        @shell.P([@shell.Txt("读的时候先看 "), @shell.Bold("加粗的那个结论"), @shell.Txt("，再回头看 "), @shell.Code("行内代码"), @shell.Txt(" 里的参数 —— 它们描述的是同一件事， 只是一个是结论、一个是证据。这一段刻意够长，好让\"探针句子\"有东西可选。")]),
        @shell.H2([@shell.Txt("四、去哪看")]),
        @shell.Table([[@shell.Txt("想做什么")], [@shell.Txt("去哪")]], [[[@shell.Txt("建一个应用")], [@shell.Txt("alpha"), @shell.Code("alpha-skill/references/notes.md")]], [[@shell.Txt("看多种语言的例子")], [@shell.Code("beta-skill")]]]),
      ],
      kids: [
        {
          kind: "ref",
          name: "intro",
          title: "从哪一份开始",
          desc: "三份 skill 各自负责什么，以及建议的阅读顺序。",
          blocks: [
            @shell.P([@shell.Txt("先说结论："), @shell.Bold("先读 `alpha-skill`"), @shell.Txt("，它是这套夹具的入口；"), @shell.Code("beta-skill"), @shell.Txt(" 用来验\"表格与代码块\"， "), @shell.Code("gamma-skill"), @shell.Txt(" 用来验\"跨 skill 的链接\"。")]),
            @shell.H2([@shell.Txt("顺序")]),
            @shell.Ul([(0, "1. ", [@shell.Code("alpha-skill/SKILL.md"), @shell.Txt(" —— 主文档")]), (0, "2. ", [@shell.Code("alpha-skill/references/notes.md"), @shell.Txt(" —— 细则")]), (0, "3. ", [@shell.Code("beta-skill/SKILL.md"), @shell.Txt(" —— 例子")])]),
          ],
        },
      ],
    },
  ]
}

///| 页面键 → `(kind, skill 下标, 子页下标)`；认不出来给 `(-1, -1, -1)`。
///
/// 键的形状与生成器里的 `docKey` / `kidKey` **必须对账**：
/// 主文档 = `<slug>`，子页 = `<slug>/<kind>/<name>`（kind 是 `ref` / `script`）。
/// 站在**生成物**这一侧做这个查找，是为了让「第几页」这个编号只有一处定义（`skills()` 的顺序）。
pub fn find_page(key : String) -> (Int, Int, Int) {
  let ks = skills()
  for i = 0; i < ks.length(); i = i + 1 {
    let d = ks[i]
    if key == d.slug {
      return (1, i, 0)
    }
    for j = 0; j < d.kids.length(); j = j + 1 {
      let k = d.kids[j]
      if key == "\{d.slug}/\{k.kind}/\{k.name}" {
        return (2, i, j)
      }
    }
  }
  (-1, -1, -1)
}

///| 页脚要交代的出处（DESIGN-site.md §5）：许可 / 生成时间 / 内容根指纹。
///
/// ⚠️ 空串 = 拿不到 ⇒ 页脚那一项**不画**（不写「许可 —」这种占位）。
///    三个字段各自为什么可能空，写在 `shell/types.mbt` 的 `Footer` 里（一处定义）。
pub fn footer() -> @shell.Footer {
  {
    license: "",
    generated_at: "",   // 由宿主构建脚本注入（内容包必须逐字节可复现）
    root_fingerprint: "27f1ac155f17d328af5c7ac04e95e7e4ac54d54b82c034f1e3b1a1cf8f933f29",
  }
}

