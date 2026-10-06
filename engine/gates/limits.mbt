///|
/// G2 体量：行数 / 字节数 / 代码块行数 / 表格行数 / **行尾必须 LF**。
///
/// 预算写在一处（`SPEC.md` §3 是它的家，两边必须一起动）。
pub struct Limits {
  lines : Int
  bytes : Int
  codeBlock : Int
  table : Int
}

///|
/// SPEC §3 的预算。
pub fn limits() -> Limits {
  { lines: 400, bytes: 20 * 1024, codeBlock: 15, table: 12 }
}

///|
/// UTF-8 字节数（旧实现 `Buffer.byteLength(text, "utf8")`）。
pub fn utf8_bytes(text : String) -> Int {
  @utf8.encode(text).length()
}

///|
/// G2 的失败清单。`body` 是**正文**（frontmatter 之后的那段 —— 旧实现就是这么扫的）。
pub fn limits_fails(text : String, body : String) -> Array[String] {
  let lim = limits()
  let fails : Array[String] = []
  let lines = split_lines(text).length()
  let bytes = utf8_bytes(text)
  if lines > lim.lines {
    fails.push("G2 体量 " + lines.to_string() + " 行 > " + lim.lines.to_string() + " 行")
  }
  if bytes > lim.bytes {
    fails.push("G2 体量 " + bytes.to_string() + " B > " + lim.bytes.to_string() + " B")
  }
  let cr = count_cr(text)
  if cr > 0 {
    fails.push("G2 行尾含 CR（" + cr.to_string() + " 处）—— skill 文件一律 LF")
  }
  for b in fenced_blocks(body) {
    // 旧实现：`b.code.replace(/\n$/, "").split("\n").length` —— 只剥**一个**尾部换行
    let code = b.code
    let stripped = if code.length() > 0 && code[code.length() - 1:] == "\n" {
      code[:code.length() - 1]
    } else {
      code
    }
    let n = split_lines(stripped.to_owned()).length()
    if n > lim.codeBlock {
      fails.push(
        "G2 代码块 " + n.to_string() + " 行 > " + lim.codeBlock.to_string() + " 行（长示例指向 examples/apps/**）",
      )
    }
  }
  let body_lines = split_lines(body)
  let mut table_start = -1
  for i = 0; i <= body_lines.length(); i = i + 1 {
    // 旧实现 `/^\s*\|/` = "第一个非空白字符是 |"
    let is_row = i < body_lines.length() && trim(body_lines[i]).has_prefix("|")
    if is_row && table_start == -1 {
      table_start = i
    }
    if !is_row && table_start != -1 {
      let n = i - table_start
      if n > lim.table {
        fails.push(
          "G2 表格 " +
          n.to_string() +
          " 行 > " +
          lim.table.to_string() +
          " 行（正文 L" +
          (table_start + 1).to_string() +
          " 起，拆两节）",
        )
      }
      table_start = -1
    }
  }
  fails
}
