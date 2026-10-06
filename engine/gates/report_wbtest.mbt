///|
/// **锁（G8）与报告组装**的证伪 —— 与 `gates_wbtest.mbt` 共用同一套假宿主与夹具壳。
///
/// 为什么单独一个文件：R9（每个源文件 ≤400 行）。这里量的是"**哪一行**被点红"
/// —— 报告的文字与顺序也是判据（`tools/line-budget.sh` 把这一条变成了可执行的量尺）。
///
///|
/// G8：指纹变了 ⇒ **硬**（`fails`），新增 / 已删 ⇒ **提示**（`notes`），
/// 别的内容根的条目 ⇒ 不比对也不算删除。
test "G8 指纹变了 / 新增 / 已删 / 别的内容根" {
  let entry = fn(extra : String) {
    " { \"files\": 1, \"lines\": 999, \"bytes\": 1, \"rows\": 0, \"codeBlocks\": 0, " + extra + " }"
  }
  let lock = "{\n  \"_note\": \"x\",\n  \"skills\": {\n    \"alpha\": " +
    entry("\"root\": \"" + fake_skills + "\"") +
    ",\n    \"ghost\": " +
    entry("\"root\": \"" + fake_skills + "\"") +
    ",\n    \"foreign\": " +
    entry("\"root\": \"/other/skills\"") +
    "\n  }\n}\n"
  let host = mk_host(
    [
      (fake_skills + "/alpha/SKILL.md", fm_of("alpha") + "正文\n"),
      (fake_skills + "/delta/SKILL.md", fm_of("delta")),
      (fake_program + "/skills.lock.json", lock),
    ],
    [
      (fake_skills, ["alpha", "delta"]),
      (fake_skills + "/alpha", ["SKILL.md"]),
      (fake_skills + "/delta", ["SKILL.md"]),
    ],
  )
  let dirs = skill_dirs(host, fake_skills)
  assert_eq(dirs, ["alpha", "delta"])
  let (fails, notes) = check_lock(host, fake_skills, fake_program, dirs)
  assert_eq(fails.length(), 1)
  assert_true(hit(fails, "G8 指纹变了：alpha（"))
  assert_true(
    fails[0].has_suffix("—— 复核这次体量变化，然后 `node ../skillpress/bin/skillpress.mjs check --update-lock`"),
  )
  assert_eq(notes, [
    "G8 新增 skill：delta（7 行 / 0 表格行）—— 确认后用 --update-lock 落锁",
    "G8 锁里还有已删除的 skill：ghost —— 复核后 --update-lock",
  ])
}

///|
/// 没有锁文件时的原文（旧实现的**第一句**，也是 G8 的门槛）。
test "G8 没有 skills.lock.json" {
  let host = mk_host([(fake_skills + "/alpha/SKILL.md", fm_of("alpha"))], [(fake_skills, ["alpha"])])
  let (fails, notes) = check_lock(host, fake_skills, fake_program, skill_dirs(host, fake_skills))
  assert_eq(fails, [
    "G8 没有 skills.lock.json —— 跑一次 `node ../skillpress/bin/skillpress.mjs check --update-lock`",
  ])
  assert_eq(notes.length(), 0)
}

///|
/// **报告的组装**：逐行断言（顺序、缩进、`·` 与 `✗` 的用法、结尾空行、退出码）。
/// 期望值的每一条都手算过：alpha 的 SKILL.md 是 8 行 / 70 字节 ⇒ `0.1 KB`，
/// 三个 aux 各 2 行（`一篇参考\n` = 13 字节 ⇒ `0.0 KB`），所以 `4 个文件 / 14 行`。
test "报告：多文件 skill 的逐行输出与退出码" {
  let good = fm_of("alpha") + "见 `docs/STATUS.md`\n"
  let aux = "一篇参考\n"
  let bad = fm_of("beta") + "见 `docs/没有这个.md`\n"
  let host = mk_host(
    [
      (fake_skills + "/alpha/SKILL.md", good),
      (fake_skills + "/alpha/references/b.md", aux),
      (fake_skills + "/alpha/references/a.md", aux),
      (fake_skills + "/alpha/FAQ.md", aux),
      (fake_skills + "/beta/SKILL.md", bad),
      ("/fake/moobile/docs/STATUS.md", "x"),
    ],
    [
      (fake_skills, ["alpha", "beta"]),
      (fake_skills + "/alpha", ["SKILL.md", "references", "FAQ.md"]),
      (fake_skills + "/alpha/references", ["b.md", "a.md"]),
      (fake_skills + "/beta", ["SKILL.md"]),
    ],
  )
  let ctx : Ctx = {
    host,
    roots: [fake_repo, fake_program],
    skills_dir: fake_skills,
    claims: [],
    index: { files: 3, names: ["foo", "Bar"] },
  }
  let out = run(ctx, fake_repo, fake_program, "moobile")
  assert_eq(out.lines, [
    "skillpress check —— moobile 根：/fake/moobile",
    "索引：3 个 .mbt 文件 / 2 个名字（供 G5 对账）",
    "✓ alpha  4 个文件 / 14 行（主文档 8 行）",
    "    · skills/alpha/SKILL.md  8 行 / 0.1 KB",
    "    · skills/alpha/references/a.md  2 行 / 0.0 KB",
    "    · skills/alpha/references/b.md  2 行 / 0.0 KB",
    "    · skills/alpha/FAQ.md  2 行 / 0.0 KB",
    "✗ beta  1 个文件 / 8 行",
    "    ✗ G3 路径不存在：docs/没有这个.md",
    "    ✗ G8 没有 skills.lock.json —— 跑一次 `node ../skillpress/bin/skillpress.mjs check --update-lock`",
    "\n2 项不合格",
  ])
  assert_eq(out.code, 1)
}

///|
/// 空内容根：旧实现的那句提示 + **退出码 0**（没东西可查不算不合格）。
test "报告：空内容根的提示与退出码 0" {
  let host = mk_host([], [(fake_skills, [])])
  let ctx : Ctx = {
    host,
    roots: [fake_repo, fake_program],
    skills_dir: fake_skills,
    claims: [],
    index: { files: 0, names: [] },
  }
  let out = run(ctx, fake_repo, fake_program, "moobile")
  assert_eq(out.lines.length(), 3)
  assert_eq(out.lines[2], "（skills/ 下还没有 skill —— 先写一个，门才有东西可查）")
  assert_eq(out.code, 0)
}

///|
/// 没有 `SKILL.md` 的目录：单独一条红（`✗ <名字>` + `缺 SKILL.md`），而且**不计数到别处**。
test "报告：目录里没有 SKILL.md" {
  let host = mk_host([], [(fake_skills, ["ghost"]), (fake_skills + "/ghost", ["README.md"])])
  let ctx : Ctx = {
    host,
    roots: [fake_repo, fake_program],
    skills_dir: fake_skills,
    claims: [],
    index: { files: 0, names: [] },
  }
  let out = run(ctx, fake_repo, fake_program, "moobile")
  assert_true(out.lines.contains("✗ ghost"))
  assert_true(out.lines.contains("    ✗ 缺 SKILL.md"))
  assert_eq(out.code, 1)
}

///|
/// 排序口径：`references/` 里的文件名要按 JS `.sort()`（UTF-16 码元序）排。
test "references 的排序是字典序（UTF-16 码元序）" {
  let a : Array[String] = ["styles.md", "structure.md", "events-and-subs.md", "FAQ.md"]
  sort_utf16(a)
  assert_eq(a, ["FAQ.md", "events-and-subs.md", "structure.md", "styles.md"])
  // 反例钉住：MoonBit 的 `Array::sort()` **不是**字典序（实测按长度先比），
  // 所以这一门谁都不许改回 `.sort()`
  let b : Array[String] = ["styles.md", "structure.md", "events-and-subs.md", "FAQ.md"]
  b.sort()
  assert_true(utf16_compare(b[1], b[2]) > 0)
}
