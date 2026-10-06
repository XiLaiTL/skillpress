///|
/// G8：**体量 / 条目数变化必须人复核**（指纹进锁）。
///
/// 为什么这门存在：skill 的失效方式不是"写错一个字"，而是**悄悄膨胀**
/// （每次补一条、每次加一版，半年后从 100 行涨到 600 行，而没人注意到）。
/// 所以判据不是"不许改"，而是"**改了要有人说一声**"：指纹对不上就红，复核后用 `--update-lock` 落锁。
///
/// ⚠️ 三条照抄的口径：
///   · 指纹算的是**一个 skill 的全部文本文件**（`SKILL.md` + `references/*.md` + `FAQ.md`）——
///     只算主文档等于给"塞进 refs 就没人管"开一道后门；
///   · 行数/字节数按**整份文件**算（含 frontmatter），表格行/代码块按**正文**算；
///   · 锁里每条记录带 `root`（它属于哪个内容根）—— 程序可以面对多个内容根，
///     不记根的话查 A 根会把 B 根的条目报成"已删除的 skill"，真提示就被淹了。

///|
/// 一份文件的指纹。
pub struct Fingerprint {
  lines : Int
  bytes : Int
  rows : Int
  codeBlocks : Int
}

///|
/// 一个 skill 的合计指纹（**多加一个 `files`**）。
pub struct SkillFingerprint {
  files : Int
  lines : Int
  bytes : Int
  rows : Int
  codeBlocks : Int
}

///|
/// 锁里的一条记录（字段顺序与旧实现写出来的一致：files → lines → bytes → rows → codeBlocks → root）。
pub struct LockEntry {
  files : Int
  lines : Int
  bytes : Int
  rows : Int
  codeBlocks : Int
  root : String?
}

///|
/// 锁文件（`skills.lock.json`）。
pub struct Lock {
  /// 记的是**哪个内容根**（旧实现会顺手清掉"根已经不在磁盘上"的条目）。
  note : String?
  skills : Array[(String, LockEntry)]
}

///|
/// 一份文本的指纹（**正文**由调用方先切出来 —— 与旧实现的 `fingerprint(text)` 同口径）。
pub fn fingerprint(text : String) -> Fingerprint {
  let (_, body) = parse_frontmatter(text)
  let mut rows = 0
  for line in split_lines(body) {
    if trim(line).has_prefix("|") {
      rows = rows + 1
    }
  }
  {
    lines: split_lines(text).length(),
    bytes: utf8_bytes(text),
    rows,
    codeBlocks: fenced_blocks(body).length(),
  }
}

///|
/// 一个 skill 的文本文件清单（`rel` 相对**内容根**；`kind` 是 `skill` / `aux`）。
///
/// ⚠️ `references/` 里的文件**要排序**（旧实现 `.sort()`），而目录项本身不排序 —— 顺序进判据。
pub fn skill_files(host : Host, skills_dir : String, d : String) -> Array[(String, String)] {
  let base = join_path(skills_dir, d)
  let out : Array[(String, String)] = []
  if host.exists(join_path(base, "SKILL.md")) {
    out.push((d + "/SKILL.md", "skill"))
  }
  let refs = join_path(base, "references")
  if host.exists(refs) {
    let names : Array[String] = []
    for f in host.read_dir(refs) {
      if f.has_suffix(".md") {
        names.push(f)
      }
    }
    // ⚠️ 用 `sort_utf16`（JS `.sort()` 的码元序），**不要**用 `Array::sort()`（不是字典序）
    sort_utf16(names)
    for f in names {
      out.push((d + "/references/" + f, "aux"))
    }
  }
  if host.exists(join_path(base, "FAQ.md")) {
    out.push((d + "/FAQ.md", "aux"))
  }
  out
}

///|
/// 一个 skill 的合计指纹。
pub fn fingerprint_skill(host : Host, skills_dir : String, d : String) -> SkillFingerprint {
  let mut agg : SkillFingerprint = { files: 0, lines: 0, bytes: 0, rows: 0, codeBlocks: 0 }
  for f in skill_files(host, skills_dir, d) {
    let fp = fingerprint(host.read(join_path(skills_dir, f.0)))
    agg = {
      files: agg.files + 1,
      lines: agg.lines + fp.lines,
      bytes: agg.bytes + fp.bytes,
      rows: agg.rows + fp.rows,
      codeBlocks: agg.codeBlocks + fp.codeBlocks,
    }
  }
  agg
}

///|
/// 读锁（读不出、解析不了都给 `None` —— 旧实现是 `try/catch` 吞掉）。
pub fn load_lock(host : Host, program_dir : String) -> Lock? {
  let f = join_path(program_dir, "skills.lock.json")
  if !host.exists(f) {
    return None
  }
  let parsed = try {
    parse_json(host.read(f))
  } catch {
    _ => return None
  }
  let skills_val = match parsed.field("skills") {
    Some(v) => v
    None => return None
  }
  let pairs = match skills_val {
    JObj(ps) => ps
    _ => return None
  }
  let skills : Array[(String, LockEntry)] = []
  for pair in pairs {
    let entry = match pair.1 {
      JObj(_) => {
        let num = fn(k : String) -> Int {
          match pair.1.field(k) {
            Some(v) =>
              match v.as_int() {
                Some(n) => n
                None => 0
              }
            None => 0
          }
        }
        let root = match pair.1.field("root") {
          Some(v) => v.as_str()
          None => None
        }
        {
          files: num("files"),
          lines: num("lines"),
          bytes: num("bytes"),
          rows: num("rows"),
          codeBlocks: num("codeBlocks"),
          root,
        }
      }
      _ => { files: 0, lines: 0, bytes: 0, rows: 0, codeBlocks: 0, root: None }
    }
    skills.push((pair.0, entry))
  }
  let note = match parsed.field("_note") {
    Some(v) => v.as_str()
    None => None
  }
  Some({ note, skills })
}

///|
/// 这条锁记录属于**当前这个内容根**吗？（老格式没记根 ⇒ 按当前根算，与从前行为一致）
pub fn belongs_here(entry : LockEntry, skills_dir : String) -> Bool {
  match entry.root {
    None => true
    Some(r) => r == skills_dir
  }
}

///|
/// G8 的失败与提示（旧实现 `checkLock`）。
pub fn check_lock(
  host : Host,
  skills_dir : String,
  program_dir : String,
  kept : Array[String],
  all : Array[String],
) -> (Array[String], Array[String]) {
  let lock = load_lock(host, program_dir)
  match lock {
    None =>
      return (
        [
          "G8 没有 skills.lock.json —— 跑一次 `node ../skillpress/bin/skillpress.mjs check --update-lock`",
        ],
        [],
      )
    Some(l) => {
      let fails : Array[String] = []
      let notes : Array[String] = []
      let seen : Array[String] = []
      // ⚠️ 两份名单：`kept` 是**过门**的那些（R4 之后忽略清单里的不在里面），
      //    `all` 是内容根下**真有的**所有 skill。分开是必须的 —— 用 `kept` 去判"锁里还有已删除的"
      //    会把**被忽略**的 skill 误报成"已删除"（假红），而它其实还在仓库里、只是不上桌。
      for a in all {
        if host.exists(join_path(join_path(skills_dir, a), "SKILL.md")) {
          seen.push(a)
        }
      }
      for d in kept {
        let now = fingerprint_skill(host, skills_dir, d)
        let mut was : LockEntry? = None
        for pair in l.skills {
          if pair.0 == d {
            was = Some(pair.1)
          }
        }
        match was {
          Some(entry) => {
            if !belongs_here(entry, skills_dir) {
              continue
            }
            let detail : Array[String] = []
            if entry.files != now.files {
              detail.push("files " + entry.files.to_string() + " → " + now.files.to_string())
            }
            if entry.lines != now.lines {
              detail.push("lines " + entry.lines.to_string() + " → " + now.lines.to_string())
            }
            if entry.bytes != now.bytes {
              detail.push("bytes " + entry.bytes.to_string() + " → " + now.bytes.to_string())
            }
            if entry.rows != now.rows {
              detail.push("rows " + entry.rows.to_string() + " → " + now.rows.to_string())
            }
            if entry.codeBlocks != now.codeBlocks {
              detail.push(
                "codeBlocks " + entry.codeBlocks.to_string() + " → " + now.codeBlocks.to_string(),
              )
            }
            if detail.length() > 0 {
              fails.push(
                "G8 指纹变了：" +
                d +
                "（" +
                detail.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "；" + s } }) +
                "）—— 复核这次体量变化，然后 `node ../skillpress/bin/skillpress.mjs check --update-lock`",
              )
            }
          }
          None => {
            notes.push(
              "G8 新增 skill：" +
              d +
              "（" +
              now.lines.to_string() +
              " 行 / " +
              now.rows.to_string() +
              " 表格行）—— 确认后用 --update-lock 落锁",
            )
          }
        }
      }
      for pair in l.skills {
        if seen.contains(pair.0) || !belongs_here(pair.1, skills_dir) {
          continue
        }
        notes.push("G8 锁里还有已删除的 skill：" + pair.0 + " —— 复核后 --update-lock")
      }
      (fails, notes)
    }
  }
}

///|
/// 落锁用的 note 原文（旧实现里那一句，逐字符照抄）。
pub fn lock_note() -> String {
  "由 `node ../skillpress/bin/skillpress.mjs check --update-lock [名字]` 生成。改动 skill 后必须重跑并复核（SPEC §6 G8）。"
}

///|
/// 把锁**序列化回文件里那份文本**：2 空格缩进、键序 `_note → skills`、
/// 每条记录 `files → lines → bytes → rows → codeBlocks → root`（旧实现 `JSON.stringify(x, null, 2) + "\n"`）。
pub fn lock_text(note : String, skills : Array[(String, LockEntry)]) -> String {
  let out : Array[String] = []
  out.push("{")
  out.push("  \"_note\": \"" + json_escape(note) + "\",")
  out.push("  \"skills\": {")
  for idx = 0; idx < skills.length(); idx = idx + 1 {
    let (name, e) = skills[idx]
    let comma = if idx + 1 < skills.length() { "," } else { "" }
    out.push("    \"" + json_escape(name) + "\": {")
    out.push("      \"files\": " + e.files.to_string() + ",")
    out.push("      \"lines\": " + e.lines.to_string() + ",")
    out.push("      \"bytes\": " + e.bytes.to_string() + ",")
    out.push("      \"rows\": " + e.rows.to_string() + ",")
    match e.root {
      // 老格式没有 `root`，此时 `codeBlocks` 是最后一条（不带逗号）
      None => out.push("      \"codeBlocks\": " + e.codeBlocks.to_string())
      Some(r) => {
        out.push("      \"codeBlocks\": " + e.codeBlocks.to_string() + ",")
        out.push("      \"root\": \"" + json_escape(r) + "\"")
      }
    }
    out.push("    }" + comma)
  }
  out.push("  }")
  out.push("}")
  out.fold(init="", fn(acc, s) { acc + s + "\n" })
}

///|
/// JSON 字符串转义（旧实现是 `JSON.stringify` 的那套）。
fn json_escape(s : String) -> String {
  let mut out = ""
  for ch in s {
    if ch == '\\' {
      out = out + "\\\\"
    } else if ch == '"' {
      out = out + "\\\""
    } else if ch == '\n' {
      out = out + "\\n"
    } else if ch == '\t' {
      out = out + "\\t"
    } else if ch == '\r' {
      out = out + "\\r"
    } else {
      out = out + ch.to_string()
    }
  }
  out
}

