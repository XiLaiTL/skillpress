///|
/// 那一节的**第一个** `Ul`（旧实现 `sec.blocks.find(x => x.k === "Ul")`）。
/// Array 没有 `find`，这里手写一个 —— 语义一样：第一个就返回。
fn first_ul(blocks : Array[Block]) -> Array[UlItem] {
  for b in blocks {
    match b {
      Ul(items) => return items
      _ => ()
    }
  }
  []
}

///|
/// 片段序列里**第一个**等于 `target` 的 `Code` 下标（没有给 -1）—— 旧实现用 `findIndex`。
fn code_pos(spans : Array[Span], target : String) -> Int {
  let mut i = 0
  while i < spans.length() {
    match spans[i] {
      Code(v) => if v == target {
        return i
      }
      _ => ()
    }
    i = i + 1
  }
  -1
}

///|
/// `from` 之后**全是空白**吗（旧实现 `spans.slice(at+1).every(s => !s.v.trim())`）。
fn tail_blank(spans : Array[Span], from : Int) -> Bool {
  for i = from; i < spans.length(); i = i + 1 {
    if trim(plain_of([spans[i]])) != "" {
      return false
    }
  }
  true
}

///|
/// 链接**之前**的那些片段 → 下拉菜单上显示的名字（旧实现 `plainOf(at > 0 ? spans.slice(0, at) : [])`）。
fn label_of(spans : Array[Span], at : Int) -> String {
  if at <= 0 {
    return ""
  }
  // Array 没有 `[:n]` 切片（那是 String/SringView 的），手抄前 at 个
  let head : Array[Span] = []
  for i = 0; i < at && i < spans.length(); i = i + 1 {
    head.push(spans[i])
  }
  plain_of(head)
}

///|
/// 首页：`<内容根>/skillpress/SKILL.md` → 首屏（`lede`）+ 分栏（`sections`）。
///
/// 移植对象是旧实现的 `pageKeys` / `pageIndex` / `readHome`（`lib/gen-content.mjs` 312–474）。
/// 切法只有一条规矩：**每个 `##` 起一个新分栏**（它下面的内容都归那一栏），第一个 `##` 之前是首屏，
/// H1 抽成 `title` 不再当块 ⇒ 顶栏有几条完全由那份内容源决定。
///
/// 三处**刻意严**的判定（旧实现的注释里写着"实测踩过"，一条都不许放宽）：
///   ① **纯链接节**：只有 `[名字](目标)` 占满整条 `##` 才算；目标要能认成站点上收了的页，
///      认不出就**点名**（不给静默的死链），并把它当普通分栏；
///   ② **下拉菜单**：那一节的**第一个** `Ul`，且每一项**恰好一个链接**、且"链接目标之后没有别的散文"；
///   ③ 连接口都对上才会写进生成物 —— 密钥对不上宁可没有菜单，也不猜。

///|
/// 相对路径归一化（旧实现靠 Node 的 `resolve` + `relative` 两下；这里只在**相对内容根**的坐标里做）：
/// 去掉 `.` 段、把 `..` 回退掉一层。`a/b/../c` → `a/c`；退到根外面时保留前导 `..`（于是查不到 ⇒ 报错）。
pub fn normalize_rel(path : String) -> String {
  let out : Array[String] = []
  for seg in path.split("/") {
    let s = seg.to_owned()
    if s == "" || s == "." {
      continue
    }
    if s == ".." {
      if out.length() > 0 && out[out.length() - 1] != ".." {
        out.pop() |> ignore
      } else {
        out.push("..")
      }
      continue
    }
    out.push(s)
  }
  out.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "/" + s } })
}

///|
/// 一个分栏（生成物里的 `Section`）。
pub struct SectionLit {
  title : Array[Span]
  link : String
  nav : Array[(String, String)] // (label, key)
  blocks : Array[Block]
}

///|
/// 首页（生成物里的 `Home`）。
pub struct HomeLit {
  title : String
  lede : Array[Block]
  sections : Array[SectionLit]
}

///|
/// 建"**文件路径（相对内容根）→ 页面键**"的表。
///
/// 为什么不能拿路径直接比页面键：页面键用的是**站点上的显示名**（md 去掉 `.md`；脚本保留扩展名），
/// 而纯链接节写的是**文件路径**（`references/layout.md`）—— 差一层映射，靠字符串猜一定会错。
///
/// `home_rel` = 首页源的内容根相对路径（如 `skillpress/WEBSITE.md`）—— **它不进索引**（D20）：
/// 否则同一个文件**既当首页、又当书架里的一页**，两套渲染规矩打架，纯链接节还能指向首页自己。
/// ⚠️ 回退那一路（首页是 `skillpress/SKILL.md`）本来就进不了索引 ⇒ 这一步在旧形状语料上是**空转**，
/// `file-parity` 的对账因此不受影响。
pub fn build_index(
  dirs : Array[String],
  refs_of : (String) -> Array[(String, String)],
  scripts_of : (String) -> Array[String],
  home_rel : String,
) -> Map[String, String] {
  let index : Map[String, String] = Map([])
  for d in dirs {
    index.set(d + "/SKILL.md", d)
    for (name, rel) in refs_of(d) {
      if d + "/" + rel == home_rel {
        continue
      }
      index.set(d + "/" + rel, d + "/ref/" + name)
    }
    for rel in scripts_of(d) {
      // 脚本的页面键里用的是**文件名本身**（`scripts/probe.mjs` → `probe.mjs`）
      index.set(d + "/" + rel, d + "/script/" + rel[8:].to_owned())
    }
  }
  index
}

///|
/// 一份 markdown 里**每个 `##` 的纯链接目标**（不是纯链接节的位置给空串）。
/// 与 `parse_blocks` 同口径：围栏内的行不算，标题判定打在 `trim()` 过的行上。
pub fn heading_links(body : String) -> Array[String] {
  let out : Array[String] = []
  let mut in_fence = false
  for raw in split_lines(body) {
    let t = trim(raw)
    if t.has_prefix("```") {
      in_fence = !in_fence
      continue
    }
    if in_fence {
      continue
    }
    // ⚠️ 复用 `blocks.mbt` 的 `heading()`：自己再写一遍 `##` 的判定就会漏掉
    // "`##` 后面允许多个空白"、"`###` 不算"这类细节（实测踩过：判定写成看下标 3 的空格 ⇒ 一条都认不出）
    match heading(t) {
      Some((2, head)) => match pure_link(head) {
        Some((_, target)) => out.push(target)
        None => out.push("")
      }
      _ => ()
    }
  }
  out
}

///|
/// 首页解析的结果：首页本体 + **首页源的内容根相对标签**（进生成物的注释与问题清单）+ 问题。
pub struct HomeResult {
  home : HomeLit?
  source : String
  problems : Array[String]
}

///|
/// 首页**源**的选择（R2 / D19 / D20）：`WEBSITE.md` 优先，没有就**回退** `SKILL.md`，并打印用了哪个。
///
/// 为什么回退要**打印**：没有这句，"首页怎么一直是旧内容"会变成一道没人查得出来的谜。
/// 为什么优先 `WEBSITE.md`：`SKILL.md` 原先**同时**当主页和当 skill —— 一份文件混两种规矩
/// （顶栏栏名要短 vs skill 门禁要自足）；拆开之后 `skillpress/SKILL.md` 只讲 skillpress 本身。
///
/// ⚠️ `--home <路径>` 覆盖：那个路径**直接**当源（绝对路径或相对内容根的路径都行），标签就用给的这条。
///
/// ⚠️ 这个选择**必须在建索引之前算出来**（`gen_content` 就是这么做的）：索引与 kids 都要用它
/// 把首页源**排除出去**（D20：首页不算子页）。
pub struct HomePick {
  label : String
  text : String
}

///|
pub fn pick_home(
  root : String,
  home_file : String,
  read : (String) -> String,
  note : (String) -> Unit,
) -> HomePick {
  if home_file != "" {
    note("· 首页源：`" + home_file + "`（--home 指定）")
    return { label: home_file, text: read(home_file) }
  }
  let website = read(root + "/skillpress/WEBSITE.md")
  if website != "" {
    note("· 首页源：`skillpress/WEBSITE.md`")
    return { label: "skillpress/WEBSITE.md", text: website }
  }
  let skill = read(root + "/skillpress/SKILL.md")
  if skill != "" {
    note("· 首页源：`skillpress/SKILL.md`（没有 `WEBSITE.md` ⇒ 按 R2 回退；想换源就写一份 `WEBSITE.md`）")
  }
  { label: "skillpress/SKILL.md", text: skill }
}

///|
/// 首页那一份**源文件**的解析（H1 标题 + 首屏 + 分栏）。
///
/// 返回 `HomeResult`：问题清单**不静默丢**（旧实现逐条点名，并让退出码非零）。
/// ⚠️ 源**由调用方先选好**（`pick_home`）再传进来：选源要早于建索引（索引/kids 都要排除首页源），
/// 而"选源时打印一句用了哪个"只该打印一次。
pub fn read_home(
  pick : HomePick,
  index : Map[String, String],
) -> HomeResult {
  let problems : Array[String] = []
  if pick.text == "" {
    problems.push(
      "找不到首页：`skillpress/WEBSITE.md` 与 `skillpress/SKILL.md` 都没有 —— 站点的首页**就是**它" +
      "（H1 = 站名、首个 `##` 之前 = 首屏、每个 `##` = 顶栏一栏）。便携目录由 pack 生成它；" +
      "项目里也可以自己写一份（见内容侧的 references/layout.md）。",
    )
    return { home: None, source: "", problems }
  }
  let body = frontmatter_body(pick.text)
  // 首页正文里认不出的构造（图片 / 原始 HTML / 围栏没闭合 / 表格缺分隔行）同样**点名**。
  // ⚠️ 旧实现这里给的标签是"相对**程序仓**的路径"（`relative(REPO, readme)`）—— 跑在不同机器上
  // 长得都不一样（P8.1 实测：探针语料下打出 `..\..\..\tmp\...`）。这里统一成内容根口径
  // `skillpress/SKILL.md`（或 `WEBSITE.md`），与本文件其它几条首页问题的写法一致。
  let blocks = parse_blocks(body, pick.label, fn(p) { problems.push(p) })
  let links = heading_links(body)
  let lede : Array[Block] = []
  let sections : Array[SectionLit] = []
  let mut seen = 0
  for i = 0; i < blocks.length(); i = i + 1 {
    match blocks[i] {
      H2(spans) => {
        let raw = if seen < links.length() { links[seen] } else { "" }
        seen = seen + 1
        sections.push({ title: spans, link: "", nav: [], blocks: [] })
        // 纯链接节：把目标折成页面键
        if raw != "" {
          let key = index.get(normalize_rel("skillpress/" + raw)).unwrap_or("")
          if key != "" {
            let s = sections[sections.length() - 1]
            sections[sections.length() - 1] = { title: s.title, link: key, nav: s.nav, blocks: s.blocks }
          } else {
            problems.push(
              "纯链接节「" + summarize(plain_of(spans), 20) + "」的目标 `" + raw +
              "` 认不出对应站点上的哪一页 —— 只能指向已收录的 skill 主文档（`<slug>`）或它的子页（如 `references/layout.md`）。",
            )
          }
        }
      }
      b => {
        if sections.length() > 0 {
          let s = sections[sections.length() - 1]
          s.blocks.push(b)
        } else {
          lede.push(b)
        }
      }
    }
  }
  if sections.length() == 0 {
    problems.push("skillpress/SKILL.md 里没有 `##` 标题 —— 官网首页的分栏就是它们，一条都没有就只剩首屏了")
  }
  // 纯链接节还带着正文：说一声（正文只在"不跳"时才看得到）—— 诊断走 note（不是生成物）
  for i = 0; i < sections.length(); i = i + 1 {
    if sections[i].link != "" && sections[i].blocks.length() > 0 {
      note(
        "（纯链接节「" + summarize(plain_of(sections[i].title), 20) + "」还带着 " +
        sections[i].blocks.length().to_string() + " 块正文 —— 点它会跳到 " + sections[i].link +
        "，正文只在\"不跳\"时才看得到）",
      )
    }
  }
  // 下拉菜单：那一节的**第一个** Ul，每一项恰好一个链接、且链接目标之后没有别的散文
  for i = 0; i < sections.length(); i = i + 1 {
    let s = sections[i]
    let items = first_ul(s.blocks)
    if items.length() == 0 {
      continue
    }
    let mut ok = true
    for it in items {
      if it.links.length() != 1 {
        ok = false
        break
      }
      let at_pos = code_pos(it.spans, it.links[0])
      if at_pos < 0 || !tail_blank(it.spans, at_pos + 1) {
        ok = false
        break
      }
    }
    if !ok {
      continue
    }
    let nav : Array[(String, String)] = []
    let mut bad = ""
    for it in items {
      let target = it.links[0]
      let key = index.get(normalize_rel("skillpress/" + target)).unwrap_or("")
      if key == "" {
        bad = target
        break
      }
      nav.push((label_of(it.spans, code_pos(it.spans, target)), key))
    }
    if bad != "" {
      problems.push(
        "分栏「" + summarize(plain_of(s.title), 20) + "」里那个列表看着像**下拉菜单**，但 `" + bad +
        "` 认不出对应站点上的哪一页 —— 要么改成真能跳的页（skill 主文档 / 它的子页），要么在它前面加一句别的文字，让它**不当菜单**。",
      )
      continue
    }
    sections[i] = { title: s.title, link: s.link, nav, blocks: s.blocks }
  }
  let title = summarize(first_h1(body), 200)
  {
    home: Some({ title: if title == "" { "首页" } else { title }, lede, sections }),
    source: pick.label,
    problems,
  }
}
