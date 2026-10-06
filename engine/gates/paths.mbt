///|
/// G3 的路径判定：**什么算"仓库内路径"**、以及"在哪个根上查"。
///
/// 这一门的设计原则是**宽进严出**（旧实现的注释原话）：误杀比漏报更伤 ——
/// 红了以后人的处置通常是"把真引用删掉"，那正是最坏的结果。所以：
///   · 只有"一级目录在白名单里"的 token 才当路径查（免得把 `作者/模块` 误判）；
///   · 尾部粘了行文残留（`docs/FINDINGS.md的补记`）的，去掉残留再查一次 —— 过了就只记提示。

///|
/// 旧实现里那个 `PLACEHOLDER` 正则：`/[<>{}$*?|\\s]|^@|^https?:|^\.\.?\//`
/// （**没有 `i` 标志** ⇒ `HTTPS://` 不算外链，但它一级目录也对不上白名单，结论一样）。
fn has_placeholder(tok : String) -> Bool {
  for ch in tok {
    if ch.is_whitespace() {
      return true
    }
    if ch == '<' || ch == '>' || ch == '{' || ch == '}' || ch == '$' || ch == '*' || ch == '?' ||
      ch == '|' || ch == '\\' {
      return true
    }
  }
  if tok.has_prefix("@") || tok.has_prefix("http:") || tok.has_prefix("https:") {
    return true
  }
  tok.has_prefix("./") || tok.has_prefix("../")
}

///|
/// 仓库/程序的一级目录白名单。
///
/// ⚠️ 白名单里**有什么**就是"门覆盖到哪儿"：不在白名单里的一级目录，**一个都不查**
/// （是"静默不查"，不是"查了没问题"）。所以每加一条都要有理由，见旧实现里的逐条注释。
pub fn top_dirs() -> Array[String] {
  [
    "tools", "docs", "examples", "npm", "vendor", "canvas", "style", "html", "cmd", "sub", "http",
    "sqlite", "gesture", ".github", ".scratch", ".mooncakes", "target",
    "skills", "site", "references",
    ".agents",
    "scripts",
    "bin", "lib", "grammars",
  ]
}

///|
/// 看起来像"仓库内路径"吗？判据：有 `/`、无占位符、且**一级目录在白名单里**。
pub fn looks_like_path(tok : String) -> Bool {
  if has_placeholder(tok) {
    return false
  }
  if tok.has_prefix("-") {
    return false
  }
  if contains_str(tok, "…") || contains_str(tok, "@") {
    return false
  }
  if !contains_str(tok, "/") {
    return false
  }
  let first = first_segment(tok)
  top_dirs().contains(first)
}

///|
/// 子串包含（`String::contains` 的语义在 core 里是 `substring?` —— 这里自己写，免得两处口径不一）。
pub fn contains_str(hay : String, needle : String) -> Bool {
  index_of_from(chars(hay), chars(needle), 0) >= 0
}

///|
/// `/` 之前的那一段。
pub fn first_segment(tok : String) -> String {
  let i = index_of_from(chars(tok), chars("/"), 0)
  if i < 0 {
    tok
  } else {
    slice(chars(tok), 0, i)
  }
}

///|
/// 路径判定的结果：过 / 没过；过但"尾部有行文残留"时带一条提示。
pub struct PathVerdict {
  ok : Bool
  note : String?
}

///|
/// 去掉尾部的"行文残留"（旧实现 `tok.replace(/[^\w./-]+$/, "")`：
/// 把结尾处**不属于** `[A-Za-z0-9_./-]` 的字符全剥掉）。
pub fn strip_tail(tok : String) -> String {
  let c = chars(tok)
  let mut b = c.length()
  while b > 0 {
    let ch = c[b - 1]
    let keep = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') ||
      ch == '_' || ch == '.' || ch == '/' || ch == '-'
    if keep {
      break
    }
    b = b - 1
  }
  slice(c, 0, b)
}

///|
/// 按一组根查一个 token（旧实现 `resolvePath`）。
pub fn resolve_path(host : Host, roots : Array[String], tok : String) -> PathVerdict {
  let mut hit = false
  for r in roots {
    if host.exists(join_path(r, tok)) {
      hit = true
    }
  }
  if hit {
    return { ok: true, note: None }
  }
  let trimmed = strip_tail(tok)
  if trimmed != "" && trimmed != tok {
    let mut hit2 = false
    for r in roots {
      if host.exists(join_path(r, trimmed)) {
        hit2 = true
      }
    }
    if hit2 {
      return {
        ok: true,
        note: Some("G3 提示：`" + tok + "` 尾部有行文残留，建议写成 `" + trimmed + "`"),
      }
    }
  }
  { ok: false, note: None }
}

///|
/// G3 / G4 的候选根：**内容仓根**、**程序根**，以及**这个 skill 自己的目录**。
/// 最后那个是"skill 自带脚本"要的：skill 里写 `scripts/x.mjs` 时，它相对的是那个 skill 目录。
pub fn skill_roots(roots : Array[String], skills_dir : String, name : String) -> Array[String] {
  let out : Array[String] = []
  for r in roots {
    out.push(r)
  }
  out.push(join_path(skills_dir, name))
  out
}
