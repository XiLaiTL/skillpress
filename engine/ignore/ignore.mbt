///|
/// 忽略清单（`skillpress.ignore.md`）—— **哪些 skill 不上桌**（R4）。
///
/// 住**内容仓根**（与内容根同级）。⚠️ **不进**内容根里：那里散落的 `.md` 会被当成
/// "缺 frontmatter 的坏 skill"（内容仓那边踩过这类形状）。
/// 一行一条：`- <目录名> —— <理由>`。
///
/// ── 规矩（R8：**不许有静默的后门**）────────────────────────────────────────────
///   ① **理由必须写**：只写名字不写理由 ⇒ 红（"豁免必须写在文档里"）；
///   ② **认不出的行也红**：不静默容忍；
///   ③ **名字必须真的是内容根下带 `SKILL.md` 的目录** ⇒ 打错名字红。否则"忽略"**静默失效**
///      而你以为生效了 —— 这类最难查；
///   ④ **首页不是 skill，清单管不到它**：`skillpress/WEBSITE.md` 永远当首页、永远过门。
///      第 ③ 条已经**结构性**地保证了这点：写 `WEBSITE.md` 这种名字会当场红；
///   ⑤ **跳过的形状必须与通过不一样**：每次生成 / 跑门都把"跳过了几份 + 理由"打出来
///      （"总数也是读数"这条老账）。
///
/// ⚠️ 解析出问题时，调用方应当**退 2 且一份都不套用** —— "半套用"是最难查的状态。
struct Entry {
  name : String
  reason : String
}

///|
/// 条目的两个**访问器**：`Entry` 是抽象类型（跨包读不到字段，实测报
/// `This expression has type ...Entry, which is a abstract type and not a struct`）。
/// 脚手架 `attach` 要**沿用盘上那份清单** ⇒ 得把读出来的条目转成它自己那套类型，所以需要这两个。
pub fn Entry::name(self : Entry) -> String {
  self.name
}

///|
pub fn Entry::reason(self : Entry) -> String {
  self.reason
}

///|
/// 解析结果：条目 + 问题清单（问题非空 ⇒ 调用方应当逐条点名并把退出码设成 2）。
pub struct Parsed {
  entries : Array[Entry]
  problems : Array[String]
}

///|
/// 条目分隔符：` —— `（前后各一个半角空格，中间两个破折号）。
///
/// ⚠️ 下标口径是 **UTF-16 码元**（js target 上 MoonBit 字符串就是 JS 串；实测 `String::length()`
///    与 `find` 的下标是同一套）。所以这里用 `find` 给的下标 + 分隔符自己的 `length()` 去切，
///    **不要去数字节**（`——` 是 3 字节 / 1 个 UTF-16 码元，数错就切歪）。
const SEP : String = " —— "

///|
/// 解析清单文本。`known` = 内容根下**真的存在**的 skill 目录名（用来抓打错的名字）。
pub fn parse(text : String, known : Array[String]) -> Parsed {
  let entries : Array[Entry] = []
  let problems : Array[String] = []
  let known_map : Map[String, Unit] = Map(known.map(fn(n) { (n, ()) }))
  let seen : Map[String, Unit] = Map([])
  let mut lineno = 0
  for raw in text.split("\n") {
    lineno = lineno + 1
    // ⚠️ `split()` 出来的是**对临时串的视图** ⇒ 先 `to_owned()`（P8.1 在语料清单上踩过这个坑）
    let line = raw.to_owned().trim().to_owned()
    if line == "" {
      continue
    }
    if line.has_prefix("#") {
      continue
    }
    let body : StringView = match line.strip_prefix("- ") {
      Some(v) => v
      None => {
        problems.push(
          "忽略清单第 " + lineno.to_string() + " 行认不出：「" + line +
          "」—— 只认 `- <目录名> —— <理由>`、`#` 注释与空行（不静默容忍）",
        )
        continue
      }
    }
    let (name, reason) : (String, String) = match body.find(SEP) {
      Some(k) => (
        body.get_view(end=k).unwrap().trim().to_owned(),
        body.get_view(start=k + SEP.length()).unwrap().trim().to_owned(),
      )
      None => (body.trim().to_owned(), "")
    }
    if name == "" {
      problems.push("忽略清单第 " + lineno.to_string() + " 行没写目录名")
      continue
    }
    if reason == "" {
      problems.push(
        "忽略清单第 " + lineno.to_string() + " 行里的「" + name +
        "」**没写理由** —— 每一条都必须写（`- <目录名> —— <理由>`）：豁免必须写在文档里，否则这就是一条静默的后门",
      )
      continue
    }
    if !known_map.contains(name) {
      problems.push(
        "忽略清单第 " + lineno.to_string() + " 行点的名字「" + name +
        "」不是内容根下带 SKILL.md 的目录 —— 打错名字等于忽略**静默失效**（而你以为它生效了）",
      )
      continue
    }
    if seen.contains(name) {
      problems.push("忽略清单里「" + name + "」写了两次（第二次在第 " + lineno.to_string() + " 行）")
      continue
    }
    seen[name] = ()
    entries.push({ name, reason })
  }
  { entries, problems }
}

///|
/// 按清单把名字分成"留下的"与"跳过的"。**两边的顺序都保持传入顺序** —— 顺序进判据。
pub fn split_names(names : Array[String], parsed : Parsed) -> (Array[String], Array[Entry]) {
  let by_name : Map[String, Entry] = Map(parsed.entries.map(fn(e) { (e.name, e) }))
  let kept : Array[String] = []
  let skipped : Array[Entry] = []
  for n in names {
    match by_name.get(n) {
      Some(e) => skipped.push(e)
      None => kept.push(n)
    }
  }
  (kept, skipped)
}

///|
/// "跳过"的**读数行**（跳过的形状必须与通过**不一样**：`⊘` 既不与 `✓` 同形，也不与 `✗` 同形）。
/// 没有跳过就给空数组（一个字都不打 —— 免得每次生成都刷一行噪音）。
pub fn notice_lines(skipped : Array[Entry]) -> Array[String] {
  let out : Array[String] = []
  if skipped.length() == 0 {
    return out
  }
  out.push(
    "（忽略清单跳过了 " + skipped.length().to_string() +
    " 份 —— 它们**不上书架、门也不查**；理由逐条在下面）",
  )
  for e in skipped {
    out.push("  ⊘ " + e.name + " —— " + e.reason)
  }
  out
}

///|
/// 问题清单的**访问器** —— 与 `Entry::name` / `Entry::reason` 同一个理由：
/// 字段是包私有的，跨包读不到（实测报 `... which is a abstract type and not a struct`）。
///
/// ⚠️ 拿到非空就应当**逐条点名并退 2**，而且**一份都不套用** —— "半套用"是最难查的状态。
pub fn Parsed::problems(self : Parsed) -> Array[String] {
  self.problems
}

///|
/// 条目清单的**访问器**（同上）。顺序 = 盘上清单里的顺序，进判据。
pub fn Parsed::entries(self : Parsed) -> Array[Entry] {
  self.entries
}
