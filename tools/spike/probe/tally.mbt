///|
/// P8.0 探针：**用 `mizchi/markdown` 解析一份真 skill，数它的块结构** ——
/// 数出来的东西要能跟"按 markdown 标记直接数"的真值对账（照 `docfacts` 那套：真值 = 纯正则数出来的）。
///
/// 为什么先做这一半：管线（P8.1）整块的形状取决于"解析器给的 AST 够不够我们映射成
/// `Block` / `Span`"。够 → P8.1 只是写映射；不够 → 得自己补解析。

///|
/// 计数：往 `Map` 里加一（没有就从 1 开始）。
fn bump(acc : Map[String, Int], key : String, by : Int) -> Unit {
  acc.set(key, acc.get_or_default(key, 0) + by)
}

///|
/// 数一组块。递归进容器（引用 / 列表项 / alert / 脚注）—— 与 Node 版 `gen-content` 的口径一致：
/// **容器里的块也算块**，但列表本身另外记一笔（对账时要能分开看）。
pub fn tally(blocks : Array[@markdown.Block], acc : Map[String, Int]) -> Unit {
  for b in blocks {
    match b {
      @markdown.Heading(level~, ..) => bump(acc, "h\{level}", 1)
      @markdown.Paragraph(..) => bump(acc, "p", 1)
      @markdown.FencedCode(info~, ..) => {
        bump(acc, "fenced", 1)
        let lang = info.split(" ").next().unwrap_or("")
        bump(acc, "fenced:\{lang}", 1)
      }
      @markdown.IndentedCode(..) => bump(acc, "code_indented", 1)
      @markdown.BulletList(items~, ..) => {
        bump(acc, "ul", 1)
        bump(acc, "ul_items", items.length())
        for it in items {
          tally(it.children, acc)
        }
      }
      @markdown.OrderedList(items~, ..) => {
        bump(acc, "ol", 1)
        bump(acc, "ol_items", items.length())
        for it in items {
          tally(it.children, acc)
        }
      }
      @markdown.Table(rows~, ..) => {
        bump(acc, "table", 1)
        bump(acc, "table_rows", rows.length())
      }
      @markdown.Blockquote(children~, ..) => {
        bump(acc, "quote", 1)
        tally(children, acc)
      }
      @markdown.ThematicBreak(..) => bump(acc, "hr", 1)
      @markdown.HtmlBlock(..) => bump(acc, "html", 1)
      @markdown.Alert(children~, ..) => {
        bump(acc, "alert", 1)
        tally(children, acc)
      }
      @markdown.FootnoteDefinition(children~, ..) => {
        bump(acc, "footnote", 1)
        tally(children, acc)
      }
      @markdown.Directive(children~, ..) => {
        bump(acc, "directive", 1)
        tally(children, acc)
      }
      @markdown.DefinitionList(..) => bump(acc, "deflist", 1)
      @markdown.MathBlock(..) => bump(acc, "math", 1)
      @markdown.Attributed(block~, ..) => {
        bump(acc, "attributed", 1)
        tally([block], acc)
      }
      @markdown.BlankLines(..) => ()
    }
  }
}

///|
/// 数行内片段（`Inline`）—— ⚠️ 键名与块级**分开**：`span_code` 是行内 `` `code` ``，
/// `fenced` 才是围栏代码块。曾经两者共用一个键，于是 `code = 21`（6 个围栏 + 15 个行内），
/// 看着像解析器给多了 —— 那是最费时间的一类假象（真值一量就露）。
///—— 只数我们真正会映射的那几类（`Text` / `Code` / `Strong` / `Link`）。
/// 我们的 `Span` 只有 `Txt` / `Code` / `Bold` 三种，所以这里要回答的是：
/// **AST 里的行内结构，够不够我们那三种表达**（多余的要降级，缺的才要补）。
pub fn tally_inline(inlines : Array[@markdown.Inline], acc : Map[String, Int]) -> Unit {
  for i in inlines {
    match i {
      @markdown.Text(..) => bump(acc, "text", 1)
      @markdown.Code(..) => bump(acc, "span_code", 1)
      @markdown.Strong(children~, ..) => {
        bump(acc, "strong", 1)
        tally_inline(children, acc)
      }
      @markdown.Emphasis(children~, ..) => {
        bump(acc, "em", 1)
        tally_inline(children, acc)
      }
      @markdown.Link(children~, ..) => {
        bump(acc, "link", 1)
        tally_inline(children, acc)
      }
      @markdown.SoftBreak(..) | @markdown.HardBreak(..) => bump(acc, "break", 1)
      _ => bump(acc, "inline_other", 1)
    }
  }
}

///|
/// 把一组块里的**所有行内片段**也数一遍（段落 / 标题 / 列表项里的）。
pub fn tally_all_inline(blocks : Array[@markdown.Block], acc : Map[String, Int]) -> Unit {
  for b in blocks {
    match b {
      @markdown.Heading(children~, ..) | @markdown.Paragraph(children~, ..) =>
        tally_inline(children, acc)
      @markdown.BulletList(items~, ..) | @markdown.OrderedList(items~, ..) => {
        for it in items {
          tally_all_inline(it.children, acc)
        }
      }
      @markdown.Blockquote(children~, ..)
      | @markdown.Alert(children~, ..)
      | @markdown.FootnoteDefinition(children~, ..)
      | @markdown.Directive(children~, ..) => tally_all_inline(children, acc)
      _ => ()
    }
  }
}

///|
/// 打印一张计数的表（键排序，输出稳定 —— 好跟 Node 侧 diff）。
pub fn print_tally(title : String, acc : Map[String, Int]) -> Unit {
  let keys = acc.keys().to_array()
  keys.sort()
  println("== \{title} ==")
  for k in keys {
    println("  \{k} = \{acc.get_or_default(k, 0)}")
  }
}
