// engine/content/links.mbt —— 正文里的链接：**目标尽量折成"页面键"**。
//
// ## 为什么需要这一步（站点那边踩到的实情）
//
// 内容里的链接写的是**文件路径**（`moobile-app-development/SKILL.md`、`references/x.md`），
// 而站点认的是**页面键**（`moobile-app-development`、`<slug>/ref/<name>`）——
// 两者差一层映射，靠字符串猜一定会错。站点那边第一版就是拿裸路径去 `find_page`，
// 认不出 ⇒ 被当成"站外链接"走了 `open_url`（点一下开新窗口，而不是站内跳页）。
//
// ⇒ 折键放在**引擎**这一层：它对"内容怎么排"知道得最全（索引就是它建的），
//    而站点不该再抄一份路径解析（同一件事两个副本 = 迟早分叉）。
//
// ## 折不动怎么办：**原样留着**（那不是失败）
//
// 折不动 == 这条链接不指向本站的任何一页（站外 `https://…`、`mailto:`、锚点、或者内容里写错的路）
// ⇒ 站点对"折不动"的处理是**开新窗口**（`@sub.open_url`）。所以这里**不报错、不丢信息**，
// 只是不动那个目标。（"内容里写错的路"另有 G3/G4 两道门在管 —— 它们查的是"引用的路径存不存在"。）

///|
/// 把一条链接目标折成页面键：折得出给键，折不出给**空串**。
///
/// 两种写法都要认（内容里两种都有）：
/// ① **相对本文件所在目录**（`../alpha-skill/SKILL.md`、`references/x.md`）；
/// ② **相对内容根**（`moobile-app-development/SKILL.md`）。
///
/// ⚠️ 标签（`label`）里那层 `skills/` 前缀要**先剥掉**：索引的键是 `<slug>/…`（不含 `skills/`），
///    而 `parse_blocks` 拿到的标签是 `skills/<slug>/SKILL.md` —— 不剥的话"相对本文件"那一支
///    算出来是 `skills/alpha-skill/SKILL.md`，永远匹配不上（本仓实测：第一条链接就是这么不跳的）。
pub fn link_key(index : Map[String, String], raw : String, label : String) -> String {
  if raw == "" {
    return ""
  }
  let base = if label.has_prefix("skills/") {
    label[7:].to_owned()
  } else {
    label
  }
  resolve_page(index, raw, base)
}

///|
/// 一串行内片段 → 折过键的那一串（只动 `Link` 的**目标**字段：标签与"是不是路径"都不动）。
fn links_in_spans(
  spans : Array[Span],
  label : String,
  index : Map[String, String],
) -> Array[Span] {
  let out : Array[Span] = []
  for sp in spans {
    match sp {
      Link(text, target, mono) => {
        let key = link_key(index, target, label)
        out.push(if key == "" { sp } else { Link(text, key, mono) })
      }
      _ => out.push(sp)
    }
  }
  out
}

///|
/// 一串块 → 折过键的那一串（P / 各级标题 / 引用 / 列表项 / 表格单元格都走到）。
pub fn resolve_block_links(
  blocks : Array[Block],
  label : String,
  index : Map[String, String],
) -> Array[Block] {
  let out : Array[Block] = []
  for b in blocks {
    out.push(match b {
      H2(sp) => H2(links_in_spans(sp, label, index))
      H3(sp) => H3(links_in_spans(sp, label, index))
      H4(sp) => H4(links_in_spans(sp, label, index))
      P(sp) => P(links_in_spans(sp, label, index))
      Quote(sp) => Quote(links_in_spans(sp, label, index))
      Ul(items) => {
        // `Ul` 的载荷是 `UlItem` **结构体**（`indent` / `num` / `spans` / `links`）——
        // 发射成生成物时**只发前三个**（`links` 是首页那条下拉菜单要的，不进契约）。
        let its : Array[UlItem] = []
        for it in items {
          its.push({
            indent: it.indent,
            num: it.num,
            spans: links_in_spans(it.spans, label, index),
            links: it.links,
          })
        }
        Ul(its)
      }
      Table(header, rows) => {
        let hd : Array[Array[Span]] = []
        for c in header {
          hd.push(links_in_spans(c, label, index))
        }
        let rs : Array[Array[Array[Span]]] = []
        for r in rows {
          let cells : Array[Array[Span]] = []
          for c in r {
            cells.push(links_in_spans(c, label, index))
          }
          rs.push(cells)
        }
        Table(hd, rs)
      }
      // 代码块与分隔线里没有行内片段
      other => other
    })
  }
  out
}
