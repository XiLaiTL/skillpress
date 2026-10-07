///|
/// 脚手架要用的**方法与常量**：占位符名字、模板文件名的映射、相对路径、模块名清洗。
///
/// 为什么把这些集中在一个文件：生成器的产物里**不能剩占位符**（替换漏了不会报错，只会静静
/// 编不过），所以"有哪些占位符"必须只有一处答案 —— 判据拿它逐条查产物。

///|
/// 模板里的占位符（**全部**；加一个就要在 `template/README.md` 的表里加一行）。
pub let tok_module : String = "{{MODULE}}"

///|
pub let tok_engine_rel : String = "{{ENGINE_REL}}"

///|
pub let tok_host_dep : String = "{{HOST_DEP}}"

///|
pub let tok_site_title : String = "{{SITE_TITLE}}"

///|
pub let tok_skillpress_version : String = "{{SKILLPRESS_VERSION}}"

///|
/// 全部占位符（判据"产物里一个都不剩"要遍历它）。
pub fn all_tokens() -> Array[String] {
  [
    tok_module,
    tok_engine_rel,
    tok_host_dep,
    tok_site_title,
    tok_skillpress_version,
  ]
}

///|
/// 宿主包 `moobile-host` 的默认依赖值：**从 registry 装**，不是 `file:` 指某个本机目录。
///
/// 为什么默认是这个：生成出来的实例是要**给别人的**，`file:` 路径在别人机器上不存在。
/// 想对着本地宿主开发（改 moobile-host 的同时看效果）就 `--host-dep file:../moobile/npm/moobile-host`。
///
/// ⚠️ 这个常量**随包发**（住在 `engine/`，不是 `tools/`）—— 生成器跑在**使用者的机器**上，
///    配置留在 `tools/` 里等于使用者拿不到。
pub let host_dep_default : String = "^0.5.0"

///|
/// 模板文件名 → 写出时的文件名。
///
/// 唯一一条映射：模板里的 `gitignore`（**没有点**）写出时叫 `.gitignore`。
/// 理由是一条实测教训：`npm pack` **永远不打 `.gitignore`**（即使把它单独列进 `files` 白名单，
/// tarball 里依然没有它）—— 所以真源里不能带那个点，映射只能放在生成器里。
pub fn out_name(name : String) -> String {
  if name == "gitignore" {
    ".gitignore"
  } else {
    name
  }
}

///|
/// 路径切段（正斜杠化之后按 `/` 切，丢掉空段与 `.`）。
/// ⚠️ 不要在这里排任何序：段序就是路径语义。
fn segs(p : String) -> Array[String] {
  let out : Array[String] = []
  for s in @gates.to_slash(p).split("/") {
    let t = s.to_owned()
    if t != "" && t != "." {
      out.push(t)
    }
  }
  out
}

///|
/// **`from` 目录 → `to` 目录**的相对路径（正斜杠；同一个目录给 `.`；跨盘给 `to` 的绝对形式）。
///
/// 为什么要自己算：生成物里的 `moon.work` / `package.json` / `verify.mjs` 都要"实例 → 程序根"
/// 这条相对路径，而实例落在哪儿由使用者决定 —— 写死一个层数（比如 `../../../..`）在别处就是错的，
/// 而且**错了不会当场报错**，只会在别人 `moon build` 时才发现。
pub fn rel_path(from : String, to : String) -> String {
  let a = segs(from)
  let b = segs(to)
  let mut i = 0
  while i < a.length() && i < b.length() && a[i] == b[i] {
    i = i + 1
  }
  // 跨盘（`C:` vs `D:`）没有相对路径可算 —— 如实给绝对路径，别给一个看着像对的假值。
  if i == 0 && a.length() > 0 && b.length() > 0 {
    return @gates.to_slash(to)
  }
  let out : Array[String] = []
  let mut j = i
  while j < a.length() {
    out.push("..")
    j = j + 1
  }
  let mut k = i
  while k < b.length() {
    out.push(b[k])
    k = k + 1
  }
  if out.length() == 0 {
    return "."
  }
  let mut s = ""
  for part in out {
    s = if s == "" { part } else { s + "/" + part }
  }
  s
}

///|
/// 路径最后一段（`/a/b` → `b`；`/a/b/` → `b`）。
pub fn base_name(p : String) -> String {
  let s = @gates.to_slash(p)
  let trimmed = if s.has_suffix("/") { s[:s.length() - 1].to_owned() } else { s }
  match trimmed.rev_find("/") {
    Some(i) => trimmed[i + 1:].to_owned()
    None => trimmed
  }
}

///|
/// **moon 模块名**：目标仓目录名 + `-site`，清洗成合法标识符。
///
/// 清洗规则（宁可保守，别生成一个编不过的名字）：小写、`[a-z0-9]` 与 `-` 留下，
/// 其它（空格、点、中文…）一律压成 `-`，连续 `-` 合并，首尾 `-` 去掉；结果为空就用 `site`。
pub fn module_name_for(repo_base : String) -> String {
  let lower = repo_base.to_lower()
  let mut out = ""
  let mut last_dash = false
  for ch in lower {
    let keep = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-'
    if keep {
      out = out + ch.to_string()
      last_dash = ch == '-'
    } else if !last_dash {
      out = out + "-"
      last_dash = true
    }
  }
  while out.has_prefix("-") {
    out = out[1:].to_owned()
  }
  while out.has_suffix("-") {
    out = out[:out.length() - 1].to_owned()
  }
  if out == "" {
    out = "site"
  }
  out + "-site"
}

///|
/// 单个 skill 的目录名是否合法（判据与内容侧同一套：kebab-case）。
///
/// 这里只用它**给我们自己排一下序与识别**：真判据在门上（G1），`attach` 不重复判它 ——
/// 复制一份规则就会漂一份。
pub fn is_skill_dir(name : String) -> Bool {
  if name == "" {
    return false
  }
  if name.has_prefix(".") || name.has_prefix("_") {
    return false
  }
  if name == "node_modules" || name == "_build" || name == "dist" {
    return false
  }
  true
}
