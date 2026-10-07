///|
/// **判据的报告**（旧实现里那个 `check()` 与收尾统计）。
///
/// ⚠️ 形状照抄：`✓ 标签  —— 详情`，详情为空就不打那一段。收尾统一打
///    `全部通过（N 条）` 或 `M/N 条不过`，**退出码由"有没有不过的"决定**。
///
/// ⚠️ 为什么每一条都要打出来（而不是只打失败的）：站点判据的读数是"**这 N 条都跑到了**"——
///    旧实现踩过"失败分支把后面几条静默跳过（总数 19 不是 22）"那次，靠的就是数总数。

///|
/// 一条判据的读数。
pub struct Item {
  ok : Bool
  label : String
  detail : String
}

///|
/// 一次运行的判据集合。
pub struct Results {
  items : Array[Item]
}

///|
pub fn Results::new() -> Results {
  { items: [] }
}

///|
/// 记一条并**立刻打印**（跑到哪一条、当场就能看见）。
pub fn Results::check(self : Results, ok : Bool, label : String, detail : String) -> Unit {
  self.items.push({ ok, label, detail })
  let mark = if ok { "✓" } else { "✗" }
  if detail == "" {
    println(mark + " " + label)
  } else {
    println(mark + " " + label + "  —— " + detail)
  }
}

///|
/// 不过的条数。
pub fn Results::bad(self : Results) -> Int {
  let mut n = 0
  for it in self.items {
    if !it.ok {
      n = n + 1
    }
  }
  n
}

///|
/// 总条数（**它是读数的一部分**：站点判据跑全了应当是 **23** 条）。
///
/// ⚠️ 这个数字**变过一次**（2026-10-07 换血）：旧 IA 那套是 22 条（29 个检查点 − 7 个失败分支），
///    换血时把「点一个有探针的分栏」拆成了"两态都验"（展开前先验收起 —— 比旧断言更强），
///    于是 22 → 23。**数字变了不是问题，悄悄变了才是** —— 这条断言守的就是这个。
pub fn Results::total(self : Results) -> Int {
  self.items.length()
}

///|
/// 一句**信息**（不是判据）—— 行首一个 `·`，与 `✓` / `✗` 不同形，
/// 免得"跳过了一条"看起来像"通过了一条"。
pub fn info(msg : String) -> Unit {
  println("    · " + msg)
}
