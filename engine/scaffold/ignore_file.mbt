///|
/// **忽略清单**（`skillpress.ignore.md`）的文本生成。
///
/// 它住**内容仓根**（内容根的上一级）—— 位置由 R4 定死，`@ig.parse` 是唯一的口径。
/// 这里只做两件事：把"人给的（名字, 理由）"写成那个形状、并**拿 `@ig.parse` 自己验一遍**。
///
/// ⚠️ 为什么要自己验：清单的坏形状**不报错**（名字打错、漏写理由）—— 那份 skill 照常上桌，
///    而你以为它被藏起来了。所以生成器不能"写完就算"，它得跑一遍**同一套解析**，
///    把问题当场摆出来（这正是 `site-source.sh` 里那四种坏清单的形状）。

///|
pub struct IgEntry {
  name : String
  reason : String
}

///|
/// 跨包**不能直接写字面量**（MoonBit 的读-only 类型规则，`Host::new` 就是为这条存在的），
/// 所以每条要构造的类型都配一个构造函数。
pub fn IgEntry::new(name : String, reason : String) -> IgEntry {
  { name, reason }
}

///|
/// 用 `@ig.parse` 验一遍：返回逐条问题（空表 = 这份清单是好的）。
///
/// `known` = 内容根里**真实存在**的 skill 目录名（判"名字打错"要靠它）。
pub fn check_ignore_text(text : String, known : Array[String]) -> Array[String] {
  let parsed = @ig.parse(text, known)
  let out : Array[String] = []
  for p in parsed.problems {
    out.push(p)
  }
  out
}

///|
/// 清单文本：头一行是为什么有这份文件的注释，之后每条一行 `- <名字> —— <理由>`。
///
/// 理由**必须写**（没有理由的条目 `@ig.parse` 会点名）—— 所以这里宁可不生成，
/// 也不生成一条"占位理由"：占位理由会让人以为这条忽略是有人想过才加的。
pub fn ignore_text(entries : Array[IgEntry], site_note : String) -> String {
  let out : Array[String] = []
  out.push("# skillpress.ignore.md —— 不上桌的 skill")
  out.push("")
  out.push("# 每条**必须带理由**（没写理由当场红）：忽略是「把东西藏起来」的机制，")
  out.push("# 它坏掉的样子是**不报错** —— 所以每次跑门或生成都会把「跳过了几份 + 逐条理由」打出来。")
  if site_note != "" {
    out.push("#")
    out.push("# " + site_note)
  }
  out.push("")
  for e in entries {
    out.push("- " + e.name + " —— " + e.reason)
  }
  out.fold(init="", fn(acc, l) { if acc == "" { l } else { acc + "\n" + l } }) + "\n"
}

///|
/// 逐条检查人给的忽略项：名字要在内容根里真的存在、理由不能空。
/// 问题逐条返回（调用方**退 2 且一个字都不写** —— "半套用"是最难查的状态）。
pub fn check_entries(entries : Array[IgEntry], known : Array[String]) -> Array[String] {
  let problems : Array[String] = []
  let km : Map[String, Bool] = Map([])
  for k in known {
    km.set(k, true)
  }
  for e in entries {
    if !km.contains(e.name) {
      problems.push("`--ignore " + e.name + "`：内容根里没有这份 skill（打错名字的清单会**静默失效**）")
    }
    if e.reason.trim() == "" {
      problems.push("`--ignore " + e.name + "`：没写理由 —— 清单里每条都必须带理由（SPEC §6 / R4）")
    }
  }
  problems
}
