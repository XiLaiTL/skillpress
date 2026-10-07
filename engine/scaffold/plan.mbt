///|
/// **`attach` 的计划**：把"要写哪些文件、每个文件里是什么"先**在内存里算完**，再落地。
///
/// 为什么分两步（算完再写）：这套东西要写的是**别人仓库**里的文件。如果一边算一边写，
/// 中途发现"这个语料生成不出站"（认不出的构造、没有首页、清单名字打错）就会留下一个
/// **半成品实例** —— 而那正是最坏的状态：它看着像装好了，其实缺一半，而且下次再跑会被
/// "不覆盖已有文件"挡住。所以规矩是：**算得出全部产物才开始写；算不出就退 2 且一个字节都不写。**

///|
/// 一个文件的两种身份 —— 决定"已经存在时怎么办"。
pub enum WriteKind {
  /// 人写的东西（首页源、门口那份 SKILL.md、忽略清单、实例的工程文件）：
  /// **已存在就跳过**（`--force` 才覆盖）—— 那是使用者的东西，不是我们的产物。
  Authored
  /// 生成物（`content/content.generated.mbt`）：**每次都写**，它的新鲜度由 `press --check` 保证。
  Derived
}

///|
pub struct Write {
  path : String
  text : String
  kind : WriteKind
  what : String
}

///|
/// 跨包不能直接写字面量 ⇒ 构造函数。`Derived` 那一条由调用方在**算完内容包之后**追加
/// （内容包的文本来自 js 专用的内容管线，所以它不在这套纯逻辑里生成）。
pub fn Write::new(path : String, text : String, kind : WriteKind, what : String) -> Write {
  { path, text, kind, what }
}

///|
/// **生成物**那一条的构造函数。
///
/// ⚠️ 跨包连**枚举变体**都不能构造（实测：`Cannot create values of the read-only type: Derived`），
///    变体只能**匹配**、不能构造 —— 所以"生成物"这个身份也必须由这一包自己给出来。
pub fn derived_write(path : String, text : String, what : String) -> Write {
  { path, text, kind: Derived, what }
}

///|
pub struct Inputs {
  repo : String
  skills : String
  /// 内容根相对仓根的路径（`skills` / `.agents/skills`）—— 用来把 README 口径的链接折成站点口径。
  corpus_rel : String
  program : String
  /// 实例目录 → 程序根 的相对路径（占位符 `{{ENGINE_REL}}`）。
  engine_rel : String
  /// 实例目录 → **内容根** 的相对路径（占位符 `{{SKILLS_REL}}`）—— 站点工程的
  /// `npm run press` 要靠它显式指内容根（不带的话会走到"程序根旁边的 moobile/skills"那个
  /// **开发机默认值**上，在用户那边会印错内容，见 `names.mbt` 里 `tok_skills_rel` 的记录）。
  skills_rel : String
  mod_name : String
  host_dep : String
  /// 首页来源的文本（空串 = 没有 README ⇒ 走生成的模板首页）。
  home_text : String
  /// 首页来自哪份文件（打印用；空串 = 没有）。
  home_from : String
  /// 站名兜底（仓目录名）。
  fallback_name : String
  entries : Array[IgEntry]
}

///|
/// 脚手架的输入（**跨包不能直接写字面量** ⇒ 配这个构造函数，与 `Host::new` 同一个理由）。
pub fn Inputs::new(
  repo : String,
  skills : String,
  corpus_rel : String,
  program : String,
  engine_rel : String,
  skills_rel : String,
  mod_name : String,
  host_dep : String,
  home_text : String,
  home_from : String,
  fallback_name : String,
  entries : Array[IgEntry],
) -> Inputs {
  { repo, skills, corpus_rel, program, engine_rel, skills_rel, mod_name, host_dep, home_text, home_from, fallback_name, entries }
}

///|
pub struct Plan {
  site_name : String
  app_dir : String
  writes : Array[Write]
  notes : Array[String]
  problems : Array[String]
}

///|
/// 内容根下**带 `SKILL.md` 的目录名**（排序用「JS 的码元序」—— 顺序会进产物，读盘顺序不行）。
pub fn list_skill_dirs(host : @gates.Host, skills : String) -> Array[String] {
  let names : Array[String] = []
  for n in host.read_dir(skills) {
    names.push(n)
  }
  @gates.sort_utf16(names)
  let out : Array[String] = []
  for n in names {
    if !is_skill_dir(n) {
      continue
    }
    let dir = skills + "/" + n
    if host.is_dir(dir) && host.read(dir + "/SKILL.md") != "" {
      out.push(n)
    }
  }
  out
}

///|
/// **门口那份 SKILL.md**（`skills/skillpress/SKILL.md`）的起始内容。
///
/// 为什么非要有它：内容根里一旦存在 `skillpress/` 这个目录，门就会把它当一份 skill 来看 ——
/// 没有 `SKILL.md` 时门直接红「✗ 缺 SKILL.md」（实测）。所以生成器必须连它一起写，
/// 而且写的是**真内容**（不是一行占位）：它的 frontmatter 要过 G1，正文要过 G3（路径得真实存在）。
///
/// ⚠️ 生成的是**起始稿**：站名、书架是算出来的，其余请人来改 —— 但改完它仍然是这一份，
///    下次 `attach` 不会覆盖（`Authored`）。
pub fn starter_skill_md(site_name : String, shelf : Array[String]) -> String {
  let out : Array[String] = []
  out.push("---")
  out.push("name: skillpress")
  out.push(
    "description: 这个站点的门口那一份 —— 它由什么组成、书架上目前有哪几份 skill、站点工程住在哪儿。读者从这儿决定下一步去看哪一份。",
  )
  out.push(
    "whenToUse: 你刚进这个仓库、想知道站点为什么长这样、想改站点的样子（配色 / 字号 / 首页），或者想加一份新的 skill 上架。",
  )
  out.push("---")
  out.push("")
  out.push("# " + site_name)
  out.push("")
  out.push("这个目录是站点的**门口**，两样东西住在这儿：")
  out.push("")
  out.push("- `WEBSITE.md` —— **首页源**：它的 H1 是站名，每个 `##` 是顶栏的一栏；")
  out.push("- `scripts/.skillpress/` —— **站点实例**：一个「用 skillpress」的 MoonBit 工程（界面不在里面，它只接线）。")
  out.push("")
  out.push("## 书架上有哪几份")
  out.push("")
  if shelf.length() == 0 {
    out.push("（**一份都没有** —— 内容根里没有带 `SKILL.md` 的目录，或者全被忽略清单挡掉了）")
  } else {
    for s in shelf {
      out.push(if s == "skillpress" { "- `skillpress` —— **就是你现在读的这一份**" } else { "- `" + s + "`" })
    }
  }
  out.push("")
  out.push("## 怎么把它跑起来")
  out.push("")
  out.push("在 `scripts/.skillpress/` 里：")
  out.push("")
  out.push("```bash")
  out.push("npm install     # 依赖（esbuild / react / moobile-host）")
  out.push("npm run press   # 内容源 → content/ 那个包")
  out.push("npm run build   # 编出来")
  out.push("npm run serve   # 本地看一眼")
  out.push("```")
  out.push("")
  out.push("## 换皮改哪儿")
  out.push("")
  out.push("配色与字号**不在这个仓库**：它们住在程序包的 `shell/theme.mbt` 里 ——")
  out.push("所以改一次，用这份程序的每个站点一起变。")
  out.push("")
  out.fold(init="", fn(acc, l) { if acc == "" { l } else { acc + "\n" + l } }) + "\n"
}

///|
/// 没有 README 时的**模板首页**（站名 + 书架栏）。有 README 时走 `home_from_readme`。
pub fn template_home_text(site_name : String, shelf : Array[String]) -> String {
  let out : Array[String] = []
  out.push("# " + site_name)
  out.push("")
  out.push("这个站点是从本仓内容根里那批 skill 印出来的：内容只有一份，站点是它的投影。")
  out.push("")
  out.push("## 书架")
  out.push("")
  for s in shelf {
    out.push("- [" + s + "](" + s + "/SKILL.md)")
  }
  out.push("")
  out.push("## 从哪开始")
  out.push("")
  out.push("上面那一栏的每一项都能点进去；站点的形状与规矩写在 `skillpress` 那份 skill 里。")
  out.push("")
  out.fold(init="", fn(acc, l) { if acc == "" { l } else { acc + "\n" + l } }) + "\n"
}

///|
/// **算计划**：全部产物在内存里备好；`problems` 非空时调用方必须**一个字节都不写**。
///
/// `shelf` = 会上书架的 skill（已扣掉忽略清单），顺序沿用内容根的读法。
pub fn static_plan(
  host : @gates.Host,
  inp : Inputs,
  all_skills : Array[String],
  shelf : Array[String],
) -> Plan {
  let notes : Array[String] = []
  let problems : Array[String] = []
  let writes : Array[Write] = []
  let app_dir = inp.skills + "/skillpress/scripts/.skillpress"
  let home_path = inp.skills + "/skillpress/WEBSITE.md"
  // ── ① 忽略清单：先验（名字打错 / 没写理由都在这儿被拦下）────────────────────────
  for p in check_entries(inp.entries, all_skills) {
    problems.push(p)
  }
  // ── ② 首页源：README 改写，或模板生成 ──────────────────────────────────────────
  let home_result = if inp.home_text != "" {
    notes.push("· 首页源：来自 `" + inp.home_from + "`（复制 + 改写）")
    home_from_readme(inp.home_text, shelf, inp.corpus_rel, inp.fallback_name)
  } else {
    notes.push("· 首页源：没有找到 README ⇒ 生成一份**模板首页**（站名 + 书架栏），内容请自己补")
    {
      text: template_home_text(inp.fallback_name, shelf),
      site_name: inp.fallback_name,
      notes: [],
    }
  }
  for n in home_result.notes {
    notes.push("  · " + n)
  }
  writes.push({
    path: home_path,
    text: home_result.text,
    kind: Authored,
    what: "首页源（WEBSITE.md）",
  })
  // ── ③ 门口那份 SKILL.md ────────────────────────────────────────────────────────
  writes.push({
    path: inp.skills + "/skillpress/SKILL.md",
    text: starter_skill_md(home_result.site_name, shelf),
    kind: Authored,
    what: "门口那份（skillpress/SKILL.md）",
  })
  // ── ④ 忽略清单（一条都没有就不写这个文件 —— 空清单不如"没有清单"清楚）─────────────
  let ig_path = inp.repo + "/skillpress.ignore.md"
  if inp.entries.length() > 0 {
    let text = ignore_text(
      inp.entries,
      "由 `skillpress attach` 生成；每条的名字与理由都请人来核一遍。",
    )
    for p in check_ignore_text(text, all_skills) {
      problems.push("生成的忽略清单自己没过解析：" + p)
    }
    writes.push({ path: ig_path, text, kind: Authored, what: "忽略清单（skillpress.ignore.md）" })
  } else {
    notes.push("· 忽略清单：一份都没忽略 ⇒ **不写** `skillpress.ignore.md`（默认全部进文档区）")
  }
  // ── ⑤ 站点实例：模板逐个文件替换占位符 ──────────────────────────────────────────
  let subs : Map[String, String] = Map([])
  subs.set(tok_module, inp.mod_name)
  subs.set(tok_engine_rel, inp.engine_rel)
  subs.set(tok_skills_rel, inp.skills_rel)
  subs.set(tok_host_dep, inp.host_dep)
  subs.set(tok_site_title, home_result.site_name)
  // 程序自己的版本：从**程序根的 moon.mod** 读 —— 写死一个版本号，程序一升级生成物就编不过。
  subs.set(tok_skillpress_version, program_version(host, inp.program))
  let (tpl, tpl_problems) = read_template(
    fn(p) { host.exists(p) },
    fn(p) { host.is_dir(p) },
    fn(p) { host.read(p) },
    fn(p) { host.read_dir(p) },
    inp.program + "/template/instance",
  )
  for p in tpl_problems {
    problems.push(p)
  }
  if tpl.length() == 0 && tpl_problems.length() == 0 {
    problems.push("模板目录是空的：`" + inp.program + "/template/instance` —— 一份文件都没有，生成物会是空壳")
  }
  for f in tpl {
    let text = substitute(f.text, subs)
    let left = leftover_tokens(text)
    if left.length() > 0 {
      problems.push("模板文件 `" + f.rel + "` 里还有没替换的占位符：" + left.fold(init="", fn(a, t) { if a == "" { t } else { a + " " + t } }))
    }
    match stray_token(text) {
      Some(s) =>
        problems.push("模板文件 `" + f.rel + "` 里有个**没登记过**的占位符样子：`" + s + "`（登记表在 `engine/scaffold/names.mbt`）")
      None => ()
    }
    writes.push({
      path: app_dir + "/" + out_name(f.rel),
      text,
      kind: Authored,
      what: "站点实例：" + out_name(f.rel),
    })
  }
  { site_name: home_result.site_name, app_dir, writes, notes, problems }
}

///|
/// 程序自己的版本号（从程序根 `moon.mod` 的 `version = "…"` 读）。
///
/// 为什么非读不可：生成物里 `XiLaiTL/skillpress@<版本>` 是**工作区成员**的版本要求 ——
/// 写死的版本在程序升级之后会让生成出来的工程**直接编不过**（而那是使用者第一次跑才发现）。
/// 读不到就退 0.1.0（不猜：调用方会把这句写在说明里）。
pub fn program_version(host : @gates.Host, program : String) -> String {
  let text = host.read(program + "/moon.mod")
  for line in text.split("\n") {
    let t = line.trim()
    if t.has_prefix("version") {
      match t.find("\"") {
        Some(i) =>
          match t[i + 1:].find("\"") {
            Some(k) => return t[i + 1:i + 1 + k].to_owned()
            None => ()
          }
        None => ()
      }
    }
  }
  "0.1.0"
}
