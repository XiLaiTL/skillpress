///|
/// 块解析与 frontmatter 切分（旧实现 `parseBlocks` / `parseFrontmatter` 的移植）。
///
/// ⚠️ 这一层里"看着多余"的东西**都是判据要的**，逐条都有出处：
///   · 代码块用**剔除后**的行判闭合（`/^```/` 打在 `trim()` 过的行上）；
///   · 表格的续行判据是 `^\s*\|`（**允许前导空白**），但块的起始判据是 `^\|`（不许）；
///   · 段落续行的 `BREAK` 里，前四条打在**剔除后**的行上，后两条打在**原始行**上；
///   · 列表项的判定同样打在原始行上（`^\s*[-*]\s+`），取内容时才 `trim()`。

///|
/// 切掉 YAML frontmatter（`---` 包起来那段），返回**正文**。
///
/// 与旧实现同一套边界：首行 trim 后必须是 `---`；结束取**第一次**出现的 `\n---`；
/// 正文从那个 `\n---` 之后的第 4 个字符起（即跳过 `\n---`，**留下的换行也算正文**）。
pub fn frontmatter_body(text : String) -> String {
  let c = chars(text)
  let mut first_end = -1
  let mut i = 0
  while i < c.length() {
    if c[i] == '\n' {
      first_end = i
      break
    }
    i = i + 1
  }
  if first_end < 0 {
    return text
  }
  if trim(slice(c, 0, first_end)) != "---" {
    return text
  }
  let mut end = -1
  let mut j = first_end + 1
  while j + 3 < c.length() {
    if c[j] == '\n' && c[j + 1] == '-' && c[j + 2] == '-' && c[j + 3] == '-' {
      end = j
      break
    }
    j = j + 1
  }
  if end < 0 {
    return text
  }
  slice(c, end + 4, c.length())
}

///|
/// 块循环要用的一行一判，全在 `lines.mbt`（R9：一个文件一件事）。


///|
/// **认不出的构造要点名**（旧实现 `parseBlocks(body, where)` 里那四处 `problems.push`；
/// `where` 在 MoonBit 里是关键字，这里叫 `label`，口径照旧）。
///
/// 为什么非报不可：块**照收**（图/原始 HTML 直接跳过、表格照渲染、围栏没闭合就当读到文件尾），
/// 但"收下了"不等于"这份内容是对的" —— 闷声跳过会让人以为站点里那行渲染出来了。
/// 旧实现的口径正是"不静默丢"：**有问题就点名，且退出码 2、不写产物**。
///
/// `label` 用 `skills/<slug>/<文件>` 这种口径（旧实现对 skill 主文档与子页就是拼这个）。
fn report_at(label : String, line : Int, kind : String, detail : String, report : (String) -> Unit) -> Unit {
  let tail = if detail == "" { "" } else { "：" + detail }
  report(label + ":" + line.to_string() + " " + kind + tail)
}


///|
/// 正文 → 块序列。
///
/// `label` + `report` 是"点名用的"：`dump-blocks` 这条命令不关心（判据是"生成物逐字节一致"），
/// 传个空标签与不吭声的回调就行；`gen-file` 那一路把它们汇进问题清单（有问题 ⇒ 退 2、不吐产物）。
pub fn parse_blocks(body : String, label : String, report : (String) -> Unit) -> Array[Block] {
  let lines = split_lines(body)
  let blocks : Array[Block] = []
  let mut i = 0
  while i < lines.length() {
    let raw = lines[i]
    let t = trim(raw)
    if t == "" {
      i = i + 1
      continue
    }
    if t.has_prefix("```") {
      let lang = trim(slice(chars(t), 3, chars(t).length()))
      let buf : Array[String] = []
      i = i + 1
      while i < lines.length() && !trim(lines[i]).has_prefix("```") {
        buf.push(lines[i])
        i = i + 1
      }
      // 围栏没闭合：旧实现报的行号是**扫描停下时的下标**（吃到文件尾 ⇒ 就等于行数），照抄
      if i >= lines.length() {
        report_at(label, i, "代码块没闭合", "", report)
      }
      i = i + 1
      blocks.push(Code(lang, buf.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "\n" + s } }), []))
      continue
    }
    if is_hr(t) {
      blocks.push(Hr)
      i = i + 1
      continue
    }
    match heading(t) {
      Some((lvl, head)) => {
        let pl = pure_link(head)
        if lvl == 2 && pl is Some(_) {
          let (label, _) = pl.unwrap()
          blocks.push(H2(inline(label)))
        } else if lvl == 2 {
          blocks.push(H2(inline(head)))
        } else if lvl == 3 {
          blocks.push(H3(inline(head)))
        } else {
          blocks.push(H4(inline(head)))
        }
        i = i + 1
        continue
      }
      None => ()
    }
    if is_h1(t) {
      i = i + 1
      continue
    }
    if t.has_prefix("|") {
      let rows : Array[String] = []
      while i < lines.length() && trim(lines[i]).has_prefix("|") {
        rows.push(trim(lines[i]))
        i = i + 1
      }
      // 行号照抄旧实现：`i - rows.length() + 1` = **表格第一行**那个 1-based 行号
      if rows.length() < 2 || !is_sep_row(rows[1]) {
        report_at(label, i - rows.length() + 1, "表格缺分隔行", "", report)
      }
      let header = cells(rows[0]).map(inline)
      let body_rows : Array[Array[Array[Span]]] = []
      for k = 2; k < rows.length(); k = k + 1 {
        body_rows.push(cells(rows[k]).map(inline))
      }
      blocks.push(Table(header, body_rows))
      continue
    }
    if t.has_prefix(">") {
      let buf : Array[String] = []
      while i < lines.length() && trim(lines[i]).has_prefix(">") {
        buf.push(strip_quote(trim(lines[i])))
        i = i + 1
      }
      blocks.push(Quote(inline(buf.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + " " + s } }))))
      continue
    }
    let as_bullet = bullet_prefix(raw)
    let as_ordered = ordered_prefix(raw)
    if as_bullet is Some(_) || as_ordered is Some(_) {
      let ordered = as_ordered is Some(_)
      let items : Array[UlItem] = []
      while i < lines.length() {
        let r = lines[i]
        let ok = if ordered { ordered_prefix(r) is Some(_) } else { bullet_prefix(r) is Some(_) }
        if !ok {
          break
        }
        let indent = if leading_ws(r) >= 2 { 1 } else { 0 }
        let num = if ordered {
          match ordered_prefix(r) {
            Some((_, digits)) => digits + ". "
            None => ""
          }
        } else {
          ""
        }
        let content = if ordered {
          match ordered_prefix(trim(r)) {
            Some((n, _)) => slice(chars(trim(r)), n, chars(trim(r)).length())
            None => trim(r)
          }
        } else {
          match bullet_prefix(trim(r)) {
            Some(n) => slice(chars(trim(r)), n, chars(trim(r)).length())
            None => trim(r)
          }
        }
        let (item_spans, item_links) = inline_with_links(content)
        items.push({ indent, num, spans: item_spans, links: item_links })
        i = i + 1
      }
      blocks.push(Ul(items))
      continue
    }
    // 认不出的构造：跳过（不渲染）但**点名** —— 旧实现的两条 `problems.push`
    if t.has_prefix("![") {
      report_at(label, i + 1, "不支持的构造（图片）", slice(chars(t), 0, 40), report)
      i = i + 1
      continue
    }
    if t.has_prefix("<") {
      report_at(label, i + 1, "不支持的构造（原始 HTML）", slice(chars(t), 0, 40), report)
      i = i + 1
      continue
    }
    let buf : Array[String] = [t]
    i = i + 1
    while i < lines.length() && !breaks(trim(lines[i]), lines[i]) {
      buf.push(trim(lines[i]))
      i = i + 1
    }
    blocks.push(P(inline(buf.fold(init="", fn(acc, s) { if acc == "" { s } else { acc + " " + s } }))))
  }
  blocks
}

///|
/// `/^\[([^\]]+)\]\(([^)]+)\)$/` —— 整条标题就是一个链接（纯链接节）。
pub fn pure_link(head : String) -> (String, String)? {
  let c = chars(head)
  if c.length() < 5 || c[0] != '[' {
    return None
  }
  let mut j = 1
  while j < c.length() && c[j] != ']' {
    j = j + 1
  }
  if j >= c.length() || j == 1 {
    return None
  }
  if j + 1 >= c.length() || c[j + 1] != '(' {
    return None
  }
  let mut k = j + 2
  while k < c.length() && c[k] != ')' {
    k = k + 1
  }
  if k >= c.length() || k == j + 2 || k != c.length() - 1 {
    return None
  }
  Some((slice(c, 1, j), trim(slice(c, j + 2, k))))
}
