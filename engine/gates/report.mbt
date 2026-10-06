///|
/// **报告的组装**（旧实现 `skillDirs()` + `run(ctx)` + `checkLock()` 的打印部分）。
///
/// 为什么报告也在引擎里：判据有一半是"**给人看的那几行**"——
/// 哪一行点红、红在第几个 skill、退出码是 1 还是 0，都是契约的一部分。
/// 所以这里不是 UI，是门的**输出格式**；站点界面只把它渲染成 HTML。
///
/// ⚠️ 逐字节搬运清单（改任何一处都是"输出变了"）：
///   · 第一行的仓名默认写 `moobile`（那是旧实现的口径）—— 通用起见**由参数喂**，
///     默认值原样保留，所以逐字节对比时两边一致（见报告里的"偏差"一节）；
///   · 第二行是"索引"行，讲的是 G5 对账用的名字数 —— G5 没搬（D18），
///     这行**照样打**（它的数字来自 index.mbt 的计数，不是 G5 的判定）；
///   · `✓/✗ <skill>  N 个文件 / M 行（主文档 K 行）`，括号**只在多文件时**出现；
///   · 每个文件一行 `    · <相对路径>  K 行 / J KB`，**也只在多文件时**打；
///   · 提示是 `    · `、硬判据是 `    ✗ `（前者不计数，后者计数）；
///   · 收尾 `\n<N> 项不合格` 或 `\n全部通过（<N> 个 skill）`（**前面真有一个空行**）。

///|
/// 一次运行的结果：要打印的行 + 退出码。
pub struct RunOutput {
  lines : Array[String]
  code : Int
}

///|
/// 内容根下有哪些**目录**（就是"有几个 skill"）。
/// ⚠️ **不排序** —— 旧实现用的是 `readdirSync` 的原始顺序，而顺序是输出的一部分。
pub fn skill_dirs(host : Host, skills_dir : String) -> Array[String] {
  let out : Array[String] = []
  if !host.exists(skills_dir) {
    return out
  }
  for d in host.read_dir(skills_dir) {
    if host.is_dir(join_path(skills_dir, d)) {
      out.push(d)
    }
  }
  out
}

///|
/// 跑一遍全部门，返回**要打印的每一行**与退出码（0 全过 / 1 有不合格项）。
///
/// 退出码 2（"找不到内容仓根"）不在这里 —— 那是调用方的前置检查（旧实现 `main` 里那段），
/// 见 `dev/main.mbt`：报告还没开始打就先退 2。
pub fn run(ctx : Ctx, repo : String, program_dir : String, repo_label : String) -> RunOutput {
  let out : Array[String] = []
  out.push("skillpress check —— " + repo_label + " 根：" + repo)
  out.push(
    "索引：" +
    ctx.index.files.to_string() +
    " 个 .mbt 文件 / " +
    ctx.index.names.length().to_string() +
    " 个名字（供 G5 对账）",
  )
  let dirs = skill_dirs(ctx.host, ctx.skills_dir)
  if dirs.length() == 0 {
    out.push("（skills/ 下还没有 skill —— 先写一个，门才有东西可查）")
    return { lines: out, code: 0 }
  }
  let mut bad = 0
  for d in dirs {
    if !ctx.host.exists(join_path(join_path(ctx.skills_dir, d), "SKILL.md")) {
      out.push("✗ " + d)
      out.push("    ✗ 缺 SKILL.md")
      bad = bad + 1
      continue
    }
    // 一个 skill = 主文档 + references/** + FAQ.md（SPEC §3）—— **全都过门**
    let files = skill_files(ctx.host, ctx.skills_dir, d)
    let printed : Array[(String, Judged)] = []
    let mut skill_bad = 0
    for f in files {
      let r = judge(ctx, ctx.host.read(join_path(ctx.skills_dir, f.0)), d, f.1)
      printed.push((f.0, r))
      if r.fails.length() > 0 {
        skill_bad = skill_bad + 1
      }
    }
    let mut total = 0
    for p in printed {
      total = total + p.1.lines
    }
    let head = (if skill_bad > 0 { "✗" } else { "✓" }) +
      " " +
      d +
      "  " +
      files.length().to_string() +
      " 个文件 / " +
      total.to_string() +
      " 行"
    out.push(
      if files.length() > 1 {
        head + "（主文档 " + printed[0].1.lines.to_string() + " 行）"
      } else {
        head
      },
    )
    for p in printed {
      if files.length() > 1 {
        out.push(
          "    · " +
          // ⚠️ 两个基准根是**内容仓根**与**程序根**（旧实现 `[MOOBILE, PROGRAM]`），
          //    不是内容根：所以打出来的是 `skills/<名字>/…` —— 这一处对账时抓到过一次
          display_path(ctx.host, [repo, program_dir], join_path(ctx.skills_dir, p.0)) +
          "  " +
          p.1.lines.to_string() +
          " 行 / " +
          p.1.kb +
          " KB",
        )
      }
      for n in p.1.notes {
        out.push("    · " + n)
      }
      for x in p.1.fails {
        out.push("    ✗ " + x)
      }
    }
    if skill_bad > 0 {
      bad = bad + 1
    }
  }
  let (lock_fails, lock_notes) = check_lock(ctx.host, ctx.skills_dir, program_dir, dirs)
  for n in lock_notes {
    out.push("    · " + n)
  }
  for f in lock_fails {
    out.push("    ✗ " + f)
  }
  bad = bad + lock_fails.length()
  out.push(if bad > 0 { "\n" + bad.to_string() + " 项不合格" } else { "\n全部通过（" + dirs.length().to_string() + " 个 skill）" })
  { lines: out, code: if bad > 0 { 1 } else { 0 } }
}
