///|
/// **书架（内容源）的读数** —— 旧实现 `docs()` 的搬运：哪些 skill 上桌、每份的
/// 一句 `whenToUse` / 一句 `description` / 有哪些子页。
///
/// ⚠️ 读盘一律走**注入的宿主**（`@gates.Host`）：这一层只做规矩，IO 归宿主。
///    好处是它**同步**（native 那份宿主是 `moonbitlang/x` + 一小段 C）——
///    判据的读取路径不必是异步的，异步只留给"起服务 / 起浏览器 / 走 CDP"。

///|
/// 内容根下**带 `SKILL.md` 的目录**（按 **UTF-16 码元序**排 —— 侧栏顺序就是它，旧实现用的是 JS `.sort()`）。
pub fn skill_dirs(host : @gates.Host, root : String, report : (String) -> Unit) -> Array[String] {
  let names : Array[String] = []
  for d in host.read_dir(root) {
    if host.is_dir(@gates.join_path(root, d)) &&
      host.exists(@gates.join_path(@gates.join_path(root, d), "SKILL.md")) {
      names.push(d)
    }
  }
  if names.length() == 0 {
    report("✗ 内容根下没有带 `SKILL.md` 的目录：\{root}")
  }
  @gates.sort_utf16(names)
  names
}

///|
/// 一份 skill 的 `description` / `whenToUse` / 子页。
///
/// 子页发现与 `gen-content` 同一套（**任何子目录里的 md**，走 `@content` 那份已经过对账的实现）；
/// 子页探针取它的 `title:`，没有就退到第一个 `# ` 标题，再没有就用名字。
///
/// ⚠️ 顺序（`md_kids` 的遍历与排序）也是判据的一部分 —— 所以**不在这儿再排一次**。
pub fn docs_of(
  host : @gates.Host,
  root : String,
  kept : Array[String],
  report : (String) -> Unit,
) -> Array[Doc] {
  let out : Array[Doc] = []
  for slug in kept {
    let dir = @gates.join_path(root, slug)
    let text = host.read(@gates.join_path(dir, "SKILL.md"))
    let fm = frontmatter_slice(text)
    let when = fm_value(fm, "whenToUse")
    let desc = fm_value(fm, "description")
    let kids : Array[KidProbe] = []
    for pair in @content.name_kids(@content.md_kids(dir)) {
      let (name, rel) = pair
      let rt = host.read(@gates.join_path(dir, rel))
      let title = fm_value(rt, "title")
      let h1 = first_h1_line(rt)
      let probe = if title != "" {
        title
      } else if h1 != "" {
        h1
      } else {
        name
      }
      kids.push({ name, probe })
    }
    out.push({ slug, when, desc, kids })
  }
  out
}

///|
/// 第一个 `^#\s+(.*)$`（多行模式 = 只看行首），trim 过；没有给空串。
///
/// ⚠️ `^#\s` 是**恰好一个** `#` 后面跟空白 ⇒ `## 标题` 不算（`#` 后面还是 `#`）。
fn first_h1_line(text : String) -> String {
  for raw in lines_of(text) {
    let c = chars_of(raw)
    if c.length() >= 2 && c[0] == '#' && is_space(c[1]) {
      return trim_ws(@content.slice(c, 2, c.length()))
    }
  }
  ""
}

///|
/// 纯链接节的**目标解析** —— 这一条**必须跟引擎同一套**（旧实现自己就是这么写的）：
///   ① 先按**首页目录相对**；② 不中再按**内容根相对**。
///
/// 为什么必须有 ②：R2 之后首页从"那份 skill"里拆了出来，而 skillpress 那份 skill 自己进了忽略清单
/// ⇒ 它的 `references/**` 从站点上消失了 —— 只认 ① 的话，首页就再也指不到任何一页。
/// 旧版工具只认 ①，所以这里不跟着改就会**崩在 ENOENT**（旧实现实测踩过）。
///
/// ⚠️ 与旧实现的一处**有意差别**：它拿 `existsSync(homeRel)` 选、选完直接 `readFileSync`
///    （文件不在就抛异常、整个判据崩）。这里**两个候选都试存在**，都不在就返回空串 ⇒
///    那条断言会**判红并点名**，而不是把工具崩掉。"崩掉"不是读数，"红了并说是哪一条"才是。
pub fn resolve_link_target(
  host : @gates.Host,
  home_dir : String,
  root : String,
  link : String,
) -> String {
  let home_rel = host.resolve(@gates.join_path(home_dir, link))
  if host.exists(home_rel) {
    return home_rel
  }
  let root_rel = host.resolve(@gates.join_path(root, link))
  if host.exists(root_rel) {
    return root_rel
  }
  ""
}
