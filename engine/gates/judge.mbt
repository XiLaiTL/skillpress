///|
/// **通用门的一次判定** —— 这是旧实现 `lib/check.mjs` 的 `judge()` 的逐条搬运。
///
/// 搬过来的门（PLAN 的 D18 决定）：
///   · G1 frontmatter（三字段 + `name` 与目录名一致 + 多余字段提示）
///   · G2 体量（行数 / 字节数 / CR / 代码块行数 / 表格行数）
///   · G3 路径引用对账（行内代码里的"仓库内路径"必须真的存在）
///   · G4 命令块里引用的脚本必须真的存在
///   · G7 禁语（`claims.txt` 的话不许说成已支持；否定语境放行）
///
/// **没搬**（按 D18 留在内容仓自己）：
///   · G5 `.mbt` API 对账 —— 只有讲 MoonBit 源码的内容才需要它，通用产品不该依赖"源里有哪些名字"；
///   · G6 `docs` §N 节号对账 —— 同上，是那个仓库的文档约定；
///   · `lib/docfacts.mjs`（moobile 的 docs 有没有撒谎）—— 更彻底的内容仓专属。
///
/// 判据 = **fail / note 的文字与顺序逐字节一致**、退出码一致。所以下面每一处
/// "看起来可以写得更好"的地方都注了为什么**不能**改（改了就不是搬运，是改判据）。

///|
/// 判定一次要用的全部上下文（旧实现的 `ctx`）。
pub struct Ctx {
  /// 宿主能力（`dev/host_js.mbt` 或测试里的假宿主）。
  host : Host
  /// G3 / G4 的前两个根：**内容仓根**、**程序根**（旧实现 `[MOOBILE, ROOT]`）。
  /// 第三个根（这个 skill 自己的目录）由 `skill_roots` 补 —— 这里存的是"还没补"的那份。
  roots : Array[String]
  /// 内容根（`<内容仓>/skills`）：`skill_roots` 拼"skill 自己目录"要用。
  skills_dir : String
  /// G7 禁语表（`claims.txt` 的内容，逐行 trim 后的顺序）。
  claims : Array[String]
  /// 源码名字索引 —— 现在**只喂报告的第二行**（`… 个名字（供 G5 对账）`）。
  /// G5 本身按 D18 没搬；这个字段留在 Ctx 里是为了"搬 G5 的那天只改 judge 一处"。
  index : Index
}

///|
/// 组装一份上下文（跨包不能直接写字面量 —— dev/main.mbt 就是这么用的）。
pub fn Ctx::new(
  host : Host,
  roots : Array[String],
  skills_dir : String,
  claims : Array[String],
  index : Index,
) -> Ctx {
  { host, roots, skills_dir, claims, index }
}

///|
/// 一个文件的判定结果（旧实现 `{ fails, notes, stats }`）。
pub struct Judged {
  /// **硬**判据的原文（顺序 = 门判定的顺序 = 报告里打印的顺序）。
  fails : Array[String]
  /// 提示（不判红）。
  notes : Array[String]
  /// 行数（报告里"主文档 N 行"用它）。
  lines : Int
  /// `(bytes / 1024).toFixed(1)` —— 报告里 `N 行 / K KB` 的那个 K。
  kb : String
}

///|
/// `(bytes / 1024).toFixed(1)` 的同口径实现。
///
/// 能这么写是因为**除以 1024 在二进制浮点里是精确的**：`bytes / 1024` 与
/// `bytes * 10 / 1024` 都是精确值（整数 < 2^53），所以"四舍五入到 1 位小数"
/// 等价于整数运算 `floor(bytes * 10 / 1024 + 0.5)`。**别改成先算 KB 再格式化**
/// （那会引进浮点误差，边界上与旧实现分岔）。
pub fn kb_of(bytes : Int) -> String {
  let scaled = ((bytes.to_double() / 1024.0) * 10.0 + 0.5).floor().to_int()
  (scaled / 10).to_string() + "." + (scaled % 10).to_string()
}

///|
/// 按固定分隔符拼接（旧实现 `Array.join`）。
pub fn join_with(items : Array[String], sep : String) -> String {
  let mut out = ""
  let mut first = true
  for it in items {
    out = if first { it } else { out + sep + it }
    first = false
  }
  out
}

///|
/// 判定一个文件。`kind` 是 `"skill"`（主文档 SKILL.md）或 `"aux"`（`references/**`、`FAQ.md`）。
///
/// 顺序**必须**是 G1 → G2 → G3 →（G5 没搬）→ G4 →（G6 没搬）→ G7：
/// 报告里打印的正是这个顺序，换一处就是"输出变了"。
pub fn judge(ctx : Ctx, text : String, name : String, kind : String) -> Judged {
  let fails : Array[String] = []
  let notes : Array[String] = []
  let lines = split_lines(text).length()
  let bytes = utf8_bytes(text)
  let (fm, body) = parse_frontmatter(text)
  let is_skill = kind == "skill"
  // ── G1 frontmatter：主文档必须有；`references/` 与 `FAQ.md` 是可选（有就检查，不强制）
  match fm {
    None =>
      if is_skill {
        fails.push("G1 frontmatter 缺失或未闭合（必须是文件开头的 --- … ---）")
      }
    Some(f) => {
      if is_skill {
        for k in required_fields() {
          // 旧实现是 `!data[k] || !data[k].trim()`：**没有**与**有但空**都红
          match field_of_front(f, k) {
            None => fails.push("G1 frontmatter 缺 " + k)
            Some(v) => if trim(v) == "" { fails.push("G1 frontmatter 缺 " + k) }
          }
        }
        // 旧实现是 `data.name && data.name.trim() !== name`：**空 name 不走这条**
        // （它已经在上面红了），所以这里也要排除空串。
        match f.name {
          Some(n) =>
            if n != "" && trim(n) != name {
              fails.push("G1 name=\"" + n + "\" 与目录名 \"" + name + "\" 不一致")
            }
          None => ()
        }
      }
      let extra : Array[String] = []
      for pair in f.all {
        if !required_fields().contains(pair.0) {
          extra.push(pair.0)
        }
      }
      if extra.length() > 0 {
        notes.push("G1 提示：字段 " + join_with(extra, ", ") + " 注册表不读（可留作打包元数据，见 SPEC §3）")
      }
    }
  }
  // ── G2 体量（行数 / 字节 / CR / 代码块 / 表格；顺序照抄 limits.mbt）
  for f in limits_fails(text, body) {
    fails.push(f)
  }
  // ── G3 路径（扫行内代码；G5 的 API 名对账也在这个循环里，按 D18 没搬）
  let roots = skill_roots(ctx.roots, ctx.skills_dir, name)
  for tok in inline_codes(body) {
    if looks_like_path(tok) {
      let r = resolve_path(ctx.host, roots, tok)
      if !r.ok {
        fails.push("G3 路径不存在：" + tok)
      } else {
        match r.note {
          Some(n) => notes.push(n)
          None => ()
        }
      }
    }
  }
  // ── G4 命令块里引用的脚本（同 G3：三个根都认）
  let cmd_langs = ["bash", "sh", "console", "shell", ""]
  for b in fenced_blocks(body) {
    if !cmd_langs.contains(b.lang) {
      continue
    }
    for f in command_files(b.code) {
      let mut hit = false
      for r in roots {
        if ctx.host.exists(join_path(r, f)) {
          hit = true
        }
      }
      if !hit {
        fails.push("G4 命令引用的脚本不存在：" + f)
      }
    }
  }
  // ── G7 禁语
  for f in forbidden_fails(body, ctx.claims) {
    fails.push(f)
  }
  { fails, notes, lines, kb: kb_of(bytes) }
}

///|
/// 三字段的取值（`name` / `description` / `whenToUse`）。
///
/// ⚠️ 只认这三个**标量**字段 —— 与 DSH 注册表同口径：别的字段注册表读不到
/// （读了也没用），所以 G1 只提示、不判红。
fn field_of_front(f : Frontmatter, k : String) -> String? {
  if k == "name" {
    f.name
  } else if k == "description" {
    f.description
  } else if k == "whenToUse" {
    f.whenToUse
  } else {
    None
  }
}
