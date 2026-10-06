///|
/// 忽略清单解析的**证伪**：好文件要绿、五种坏形状都要**精确点名**（不许静默容忍）。
///
/// 为什么值得单测而不是只靠站点对账：清单是"**把东西藏起来**"的机制，它坏掉的样子是
/// **不报错**的（漏掉一条 = 那份 skill 照常上桌；名字打错 = 你以为忽略了其实没忽略）。
/// 所以这里逐条把"坏形状"钉死。
///
///|
/// 好文件：注释 + 空行 + 中文理由 + 破折号分隔 ⇒ 0 问题、条目原样。
test "好清单一：条目、理由、注释与空行" {
  let known = ["alpha", "beta", "skillpress"]
  let text = "# 注释行\n\n- skillpress —— 它是工具自己的那份 skill（讲怎么用工具），不是给别人看的主题内容\n\n- beta —— 先不上桌，等内容补齐\n"
  let p = parse(text, known)
  assert_eq(p.problems.length(), 0)
  assert_eq(p.entries.length(), 2)
  assert_eq(p.entries[0].name, "skillpress")
  assert_eq(p.entries[0].reason, "它是工具自己的那份 skill（讲怎么用工具），不是给别人看的主题内容")
  assert_eq(p.entries[1].name, "beta")
  assert_eq(p.entries[1].reason, "先不上桌，等内容补齐")
}

///|
/// 坏形状 ①：**没写理由** ⇒ 点名（这条是 R8 的核心："豁免必须写在文档里"）。
test "坏清单一：没写理由必须点名" {
  let p = parse("- alpha\n", ["alpha"])
  assert_eq(p.entries.length(), 0)
  assert_eq(p.problems.length(), 1)
  assert_true(p.problems[0].contains("没写理由"))
  assert_true(p.problems[0].contains("alpha"))
  assert_true(p.problems[0].contains("第 1 行"))
}

///|
/// 坏形状 ②：**名字打错** ⇒ 点名（否则"忽略"静默失效，而你以为生效了）。
test "坏清单二：名字打错必须点名" {
  let p = parse("- alph —— 手滑打错\n", ["alpha"])
  assert_eq(p.entries.length(), 0)
  assert_true(p.problems[0].contains("静默失效"))
}

///|
/// 坏形状 ③：**认不出的行** ⇒ 点名（不静默容忍）。
test "坏清单三：认不出的行必须点名" {
  let p = parse("这一行是散落的段落\n", ["alpha"])
  assert_eq(p.entries.length(), 0)
  assert_true(p.problems[0].contains("认不出"))
}

///|
/// 坏形状 ④：同一条写两次 ⇒ 点名。
test "坏清单四：重复条目必须点名" {
  let p = parse("- alpha —— 理由一\n- alpha —— 理由二\n", ["alpha"])
  assert_eq(p.entries.length(), 1)
  assert_true(p.problems[0].contains("写了两次"))
}

///|
/// 坏形状 ⑤：只有注释与空行 ⇒ 不算坏（0 条目 0 问题），且"跳过"的读数行一个字都不打。
test "空清单：合法，且不刷噪音" {
  let p = parse("# 只有注释\n\n", ["alpha"])
  assert_eq(p.entries.length(), 0)
  assert_eq(p.problems.length(), 0)
  assert_eq(notice_lines([]).length(), 0)
}

///|
/// 套用与读数行：留下的保持顺序、跳过的是**条目**（带理由）、`⊘` 与 `✓`/`✗` 不同形。
test "套用：分两边、保顺序、跳过要打理由" {
  let p = parse("- beta —— 先不上桌\n", ["alpha", "beta", "gamma"])
  let (kept, skipped) = split_names(["alpha", "beta", "gamma"], p)
  assert_eq(kept, ["alpha", "gamma"])
  assert_eq(skipped.length(), 1)
  assert_eq(skipped[0].name, "beta")
  let lines = notice_lines(skipped)
  assert_eq(lines.length(), 2)
  assert_true(lines[0].contains("跳过了 1 份"))
  assert_true(lines[1].contains("⊘ beta —— 先不上桌"))
  assert_false(lines[1].contains("✓"))
}
