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
  asset_base : String,
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
      // **图片的 src 折成"站点能直接加载的 URL"**（对标表 #10）。
      // ⚠️ 这里**不是**在折"页面键"：第一版拿 `link_key` 折过，而那个函数只认**页面**——
      //    图片路径永远不在索引里 ⇒ 它一次都没命中过，src 一直是内容里那句原样的相对路径
      //    （`../assets/fixture.png`），站点照着它去加载**必然 404**：那个路径是相对**那份 md** 的，
      //    而浏览器是按**页面 URL** 解析的。折键那套"折不动就原样留着"的安全网在这儿是**反的**
      //    —— 留下来的是个一定加载不到的地址（静默失效，最难查的一类）。
      Image(alt, src) => Image(alt, asset_src(src, label, asset_base))
      // 代码块与分隔线里没有行内片段
      other => other
    })
  }
  out
}

///|
/// 一条图片目标 → **站点能直接加载的 URL**。
///
/// 两种：
///   · **站外 / `data:`**（`http://` `https://` `//` `data:`）⇒ **原样**（那是别人家的服务器，不归站点管）；
///   · **仓内相对路径** ⇒ 先按"相对那份 md"折成**相对内容根**的规范路径（`../assets/x.png` ⇒
///     `assets/x.png`），再挂上 `base`（站点上放这些图的目录，如 `img/`）⇒ `img/assets/x.png`。
///
/// ⚠️ **不做存在性检查**（那是 `press` 的活）：引擎这一层是**纯文本变换**（它只拿到 `read` 回调，
///    没有"列举目录"的能力），而 `press` 本来就要把文件**拷**进实例 —— 拷的时候顺手就能发现"少了"，
///    而且那时候报错能带上"我从哪儿拷到哪儿"两条路径。判据落在真会动手的那一层。
///
/// ⚠️ `base` 由调用方给（`--asset-base`，默认 `img/`）：**站点把图放哪儿是站点的事**，
///    引擎只负责"这一条指向内容根里的哪个文件"。
pub fn asset_src(raw : String, label : String, base : String) -> String {
  if is_external_url(raw) {
    return raw
  }
  let l = if label.has_prefix("skills/") {
    label[7:].to_owned()
  } else {
    label
  }
  let dir = match l.rev_find("/") {
    Some(i) => l[:i].to_owned()
    None => ""
  }
  let rel = if raw.has_prefix("/") {
    // 以 `/` 开头的写法是"相对**内容根**"（与链接那一路同一套口径）⇒ 不拼目录，直接规范化。
    normalize_rel(raw)
  } else if dir == "" {
    normalize_rel(raw)
  } else {
    normalize_rel(dir + "/" + raw)
  }
  base + rel
}

///|
/// 是不是"站外 / 内联"的目标（不归站点管的那些）—— 这类一律**原样**发出去。
fn is_external_url(raw : String) -> Bool {
  raw.has_prefix("http://") ||
  raw.has_prefix("https://") ||
  raw.has_prefix("//") ||
  raw.has_prefix("data:") ||
  raw.has_prefix("mailto:")
}
