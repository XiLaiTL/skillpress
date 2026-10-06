///|
/// **js 那条图**：只跑 markdown 那一半。
///
/// `moon run cmd/js --target js -- <markdown 文件>`
///
/// 为什么与 native 分开：`hl`（tree-sitter）声明 `supported-targets: +native`，
/// 一旦 `cmd` 同时 import 两边，**js 这张图就编不出来**（moon 的报错很明确：
/// `Selected backend 'js' is incompatible with the dependency graph`）。
/// 这不是缺陷，是 P8.0 的一条结论：**两条 target 是两张构建图**。
fn main {
  let args = @env.args()
  let file = args[args.length() - 1]
  let src = @probe.read_text(file)
  if src == "" {
    println("✗ 读不到内容：\{file}")
    return
  }
  println("输入 = \{file}（\{src.length()} 字符）")
  let result = @markdown.parse(src)
  let blocks = result.document.children
  let acc : Map[String, Int] = Map([])
  @probe.tally(blocks, acc)
  @probe.tally_all_inline(blocks, acc)
  @probe.print_tally("markdown 解析（mizchi/markdown）", acc)
  let fm = @probe.frontmatter_raw(result.document)
  let fm_head = match fm.split("\n").next() {
    Some(line) => line.to_owned()
    None => ""
  }
  println("frontmatter = \{if fm == "" { "（无）" } else { fm_head + " …" }}")
}
