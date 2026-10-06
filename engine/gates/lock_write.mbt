///|
/// G8 的**写侧**（落锁）—— 从 `lock.mbt` 切出来的一件独立的事：
/// 那边是"读锁 + 比指纹 + 组装报告"（每次跑门都要），这边只在 `--update-lock` 时走一次。
/// R9：一个文件一件事（拆开之前 407 行，超了 7 行）。
/// **落锁**（旧实现 `writeLock`）：把当前指纹写进 `<程序根>/skills.lock.json`。
///
/// 返回值 `(指名的名字?, 锁里一共几条)`：
///   · 第一个非 `None` = 调用方指了一个**不存在**的 skill（旧实现退 2 并点名）；
///   · 第二个 = 落锁后锁里的条目总数（旧实现打印 `N 个 skill` 用的就是它 —— 是**总数**，
///     不是"这次锁了几条"）。
///
/// ⚠️ `only` 非空时**只锁那一份**：多代理并行改不同 skill 时，整文件重写会把别人正在改的指纹
/// 一起锁掉，等他们改完 G8 就无辜地红（旧实现注释里写着"实测踩过"）。
/// ⚠️ 别的内容根的条目**原样保留**（锁是一份共用的：程序可以面对内容仓的 `skills` 与它自己的 `skills/`）。
pub fn update_lock(
  host : Host,
  skills_dir : String,
  program_dir : String,
  only : String,
) -> (String?, Int) {
  let targets : Array[String] = if only != "" {
    [only]
  } else {
    skill_dirs(host, skills_dir)
  }
  for d in targets {
    if !host.exists(join_path(join_path(skills_dir, d), "SKILL.md")) {
      return (Some(d), 0)
    }
  }
  // 锁读进来后**原位覆盖**、缺的**追加** —— 旧实现是 JS 对象（`lock.skills[d] = …`）：
  // 已有键保留**原来的位置**，新键追加。顺序进判据（锁文件要被逐字节比），所以不能重排。
  // ⚠️ 也别用 `.sort()`：MoonBit 里它不是字典序（PLAN 的 D27 / tools/mbt-traps.sh）。
  let entry_of = fn(d : String) -> LockEntry {
    let now = fingerprint_skill(host, skills_dir, d)
    {
      files: now.files,
      lines: now.lines,
      bytes: now.bytes,
      rows: now.rows,
      codeBlocks: now.codeBlocks,
      root: Some(skills_dir),
    }
  }
  // ── 首页源（R2 / D20 的另一半）：**它也要进指纹** ────────────────────────────────
  // 只在"锁全部"（没指名具体 skill）时带上它 —— 指名的意思是"我只复核这一份"，别顺手改别的。
  let home_key = "skillpress/WEBSITE.md"
  let home_abs = join_path(join_path(skills_dir, "skillpress"), "WEBSITE.md")
  let also_home = only == "" && host.exists(home_abs)
  let home_entry_of = fn() -> LockEntry {
    let fp = fingerprint(host.read(home_abs))
    {
      files: 1,
      lines: fp.lines,
      bytes: fp.bytes,
      rows: fp.rows,
      codeBlocks: fp.codeBlocks,
      root: Some(skills_dir),
    }
  }
  let entries : Array[(String, LockEntry)] = []
  let written : Map[String, Unit] = Map([])
  match load_lock(host, program_dir) {
    Some(l) =>
      for pair in l.skills {
        if also_home && pair.0 == home_key {
          entries.push((pair.0, home_entry_of()))
          written[pair.0] = ()
          continue
        }
        let mut hit = false
        for d in targets {
          if pair.0 == d {
            hit = true
          }
        }
        if hit {
          entries.push((pair.0, entry_of(pair.0)))
          written[pair.0] = ()
        } else {
          entries.push(pair)
        }
      }
    None => ()
  }
  for d in targets {
    if !written.contains(d) {
      entries.push((d, entry_of(d)))
    }
  }
  if also_home && !written.contains(home_key) {
    entries.push((home_key, home_entry_of()))
  }
  host.write(join_path(program_dir, "skills.lock.json"), lock_text(lock_note(), entries))
  (None, entries.length())
}
