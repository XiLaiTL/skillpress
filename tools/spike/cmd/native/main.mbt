///|
/// **native 那条图**：读内嵌样本（`probe/io.native.mbt`）→ 解析 → 取第一个 ```bash 块 → 上色。
///
/// `native-build.bat run cmd/native --target native`
fn main {
  let src = @probe.read_text("(native 用内嵌样本)")
  let result = @markdown.parse(src)
  let acc : Map[String, Int] = Map([])
  @probe.tally(result.document.children, acc)
  @probe.print_tally("markdown 解析（同一份样本）", acc)
  for b in result.document.children {
    match b {
      @markdown.FencedCode(info~, code~, ..) => {
        let lang = info.split(" ").next().unwrap_or("")
        println("围栏块：语言 = \{lang}")
        if lang == "bash" {
          @hl.highlight_bash(code)
        }
        break
      }
      _ => ()
    }
  }
}
