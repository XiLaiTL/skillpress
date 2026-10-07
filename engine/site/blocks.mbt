///|
/// **代码块、侧栏树、吸顶**这三组读数 —— 都是"坏了也不报错"的那一类。
///
/// 旧实现 `lib/verify-site.mjs` 里对应 `hl` 那一段、展开箭头/子页取点、以及 `stick` 那段。

///|
/// 代码块的读数：几个块、最花的那个有几种颜色、每块的正文（归一化过）。
pub struct CodeBlocks {
  boxes : Int
  colors : Int
  texts : Array[String]
}

///|
/// 吸顶的读数（`why` 非空 = 量不到，那条断言要判红并说明原因）。
pub struct Stick {
  why : String
  room : Int
  got : Int
  moved : Int
  page_room : Int
}

///|
/// 页面上所有代码块（底色 = 主题里的 `c_code`）与它们的配色数。
///
/// 用途：① "代码块里有高亮（不止一种颜色 —— 上色链路没断）"；
///       ② "渲染出来的代码块与内容源逐字一致" —— 这是这类改动最容易**悄悄**坏的地方：
///          上色把代码切成几十个 span，"少了一个空格/换行"编译器不拦、控制台不报，
///          只有对着源逐字比才看得见。
pub async fn code_blocks(cdp : Cdp) -> CodeBlocks raise {
  // ⚠️ 认代码块**不许认颜色**（2026-10-07 换血）：旧写法认的是当年那个暖色主题的
  //    `code_bg` 字面量 `rgb(240, 233, 218)` —— 主题一换（现在是浅色 `#f7f7f8`）就**一个盒子都认不出来**，
  //    而症状是"页面上没有代码块"这种看着像**站点坏了**的假红（实测：那条红了整整一轮）。
  //    ⇒ 改成认**结构**：代码块的工具条里有「复制」按钮，而它有具名节点（`#copy-<i>`），
  //      从按钮往上两层正是那个块。判据要量的东西（块数与配色数）与"底色偏暖还是偏冷"无关。
  let js = "(() => {" +
    " const btns = [...document.querySelectorAll('[id^=copy-]')];" +
    " const boxes = btns.map(b => b.parentElement && b.parentElement.parentElement).filter(Boolean);" +
    " const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();" +
    " const texts = boxes.map(b => norm(b.innerText));" +
    " let colors = 0;" +
    " for (const b of boxes) colors = Math.max(colors, new Set([...b.querySelectorAll('span')].map(s => getComputedStyle(s).color)).size);" +
    " return { boxes: boxes.length, colors: colors, texts: texts };" +
    " })()"
  let j = cdp.eval_json(js)
  let boxes = match j_get(j, "boxes") {
    Some(v) =>
      match j_int(v) {
        Some(n) => n
        None => 0
      }
    None => 0
  }
  let colors = match j_get(j, "colors") {
    Some(v) =>
      match j_int(v) {
        Some(n) => n
        None => 0
      }
    None => 0
  }
  let texts : Array[String] = []
  match j_get(j, "texts") {
    Some(Json::Array(items)) =>
      for it in items {
        match it {
          Json::String(s) => texts.push(s)
          _ => ()
        }
      }
    _ => ()
  }
  { boxes, colors, texts }
}

///|
/// 某个 skill 那一行的**展开箭头**（`▸` / `▾`）中心点。
///
/// ⚠️ 归属靠"它自己或它的祖先里出现过这个 slug"来认领 —— **不靠坐标猜**
///    （坐标一改布局就错，而且错了看不出来）。祖先最多往上走 **4** 层（旧实现同口径）。
pub async fn arrow_box(cdp : Cdp, slug : String) -> Box? raise {
  let js = "(() => {" +
    " const slug = " + js_lit(slug) + ";" +
    " const arrows = [...document.querySelectorAll('*')].filter(e => [\"\\u{25b8}\",\"\\u{25be}\"].includes((e.innerText||\"\").trim()));" +
    " const mine = arrows.find(a => {" +
    " let p = a;" +
    " for (let k = 0; k < 4 && p; k++) {" +
    " if ((p.innerText||\"\").includes(slug)) return true;" +
    " p = p.parentElement;" +
    " }" +
    " return false;" +
    " });" +
    " if (!mine) return null;" +
    " const r = mine.getBoundingClientRect();" +
    " return { x: r.x + r.width / 2, y: r.y + r.height / 2 };" +
    " })()"
  box_of(cdp.eval_json(js))
}

///|
/// 侧栏树里某个子页那一行（`§ 名字` 或 `⌗ 名字`）的中心点。
///
/// ⚠️ 两个前缀都要认：`script` 类的子页用的是 `⌗`（出处 `shell/docs.mbt`）。
pub async fn kid_box(cdp : Cdp, name : String) -> Box? raise {
  let js = "(() => {" +
    " const n = " + js_lit(name) + ";" +
    // ⚠️ 三种形态都认（2026-10-07）：新 IA 里子页那一行**就是它的标题**（层级靠缩进表达），
    //    旧形态是 `§ 名字` / `⌗ 名字`（script 类用 `⌗`）。只认旧形态 ⇒ "找到子页那一行"**永远红**
    //    （实测：树明明展开了、那一行就在眼前，判据却说找不到 —— 而这看着像"站点坏了"）。
    " const el = [...document.querySelectorAll('div,button')].find(e => {" +
    " const t = e.innerText.trim();" +
    " return t === n || t === \"\\u{00a7} \" + n || t === \"\\u{2317} \" + n;" +
    " });" +
    " if (!el) return null;" +
    " const r = el.getBoundingClientRect();" +
    " return { x: r.x + r.width / 2, y: r.y + r.height / 2 };" +
    " })()"
  box_of(cdp.eval_json(js))
}

///|
/// **吸顶**：长内容下滚的是正文容器、顶栏不动。
///
/// 为什么值得单列一条：这里的坏法是**静默的** —— 样式层里没有 sticky，吸顶全靠**结构**，
/// 而结构对不对取决于**宿主 HTML**（`#root` 若不是 flex 容器，应用根会长到内容高
/// ⇒ 滚动容器被撑满 ⇒ 滚的是整个 document ⇒ 顶栏跟着滚出去）。代码一个字没错、控制台也不报。
///
/// 判据三条一起（缺一条就假绿）：① 滚动容器**真的有得滚**；② 滚它之后**它真的滚了**；
/// ③ 顶栏的 `y` **一点没动**。为了让 ① 成立，临时把装内容那层撑到 3000px（量完还原）。
pub async fn stick_probe(cdp : Cdp) -> Stick raise {
  let js = "(() => {" +
    " const vw = document.documentElement.clientWidth;" +
    " const bar = [...document.querySelectorAll(\"div\")].filter(e => {" +
    " const r = e.getBoundingClientRect();" +
    " return r.y < 120 && r.height > 20 && r.height <= 90 && r.width >= vw * 0.6 && e.children.length >= 2;" +
    " }).sort((a, b) => a.getBoundingClientRect().y - b.getBoundingClientRect().y)[0];" +
    " const box = [...document.querySelectorAll(\"*\")].find(e => {" +
    " const oy = getComputedStyle(e).overflowY;" +
    " return oy === \"auto\" || oy === \"scroll\";" +
    " });" +
    " if (!bar || !box) return { why: \"找不到顶栏或滚动容器\" };" +
    " const panel = box.children[0] && box.children[0].children[0];" +
    " if (panel) panel.style.height = \"3000px\";" +
    " void box.offsetHeight;" +
    " const room = box.scrollHeight - box.clientHeight;" +
    " const y0 = Math.round(bar.getBoundingClientRect().y);" +
    " box.scrollTop = 300;" +
    " const y1 = Math.round(bar.getBoundingClientRect().y);" +
    " const got = Math.round(box.scrollTop);" +
    " box.scrollTop = 0;" +
    " if (panel) panel.style.height = \"\";" +
    " return { room: room, got: got, moved: y1 - y0, pageRoom: document.documentElement.scrollHeight - document.documentElement.clientHeight };" +
    " })()"
  let j = cdp.eval_json(js)
  match j_get(j, "why") {
    Some(Json::String(w)) => { why: w, room: 0, got: 0, moved: 0, page_room: 0 }
    _ => {
      let n = fn(key : String) -> Int {
        match j_get(j, key) {
          Some(v) =>
            match j_int(v) {
              Some(x) => x
              None => 0
            }
          None => 0
        }
      }
      { why: "", room: n("room"), got: n("got"), moved: n("moved"), page_room: n("pageRoom") }
    }
  }
}

///|
/// 把页面上所有元素的 `scrollTop` 复位（吸顶那条量完要还原现场）。
pub async fn reset_scroll(cdp : Cdp) -> Unit raise {
  let _ = cdp.eval_raw("[...document.querySelectorAll('*')].forEach(e => { e.scrollTop = 0; })")
}

///|
/// **控制台里的 error**（第 ㉒ 条断言的读数）。
///
/// 两类都收（与旧实现同一套）：
///   · `Log.entryAdded` 且 `entry.level === "error"` → `text`（带 `url` 就附上）；
///   · `Runtime.consoleAPICalled` 且 `type === "error"` → `JSON.stringify(args.map(a => a.value ?? a.description))`。
///
/// ⚠️ 这两类**只在 enable 之后**才来 ⇒ `Log.enable` 省不得（省了这条永远绿）。
/// ⚠️ favicon 的 404 **不算页面错了** —— 过滤是**显式**的，写在调用方（`checks.mbt`）里，
///    不在这儿悄悄吞掉（"要么永远红、要么把真错误一起吞掉"两种都糟）。
pub fn console_errors(cdp : Cdp) -> Array[String] {
  let out : Array[String] = []
  for e in cdp.events {
    let name = match j_get(e, "method") {
      Some(Json::String(m)) => m
      _ => ""
    }
    let params = j_get(e, "params")
    if name == "Log.entryAdded" {
      let entry = match params {
        Some(p) => j_get(p, "entry")
        None => None
      }
      let level = match entry {
        Some(en) =>
          match j_get(en, "level") {
            Some(Json::String(s)) => s
            _ => ""
          }
        None => ""
      }
      if level == "error" {
        let text = match entry {
          Some(en) =>
            match j_get(en, "text") {
              Some(Json::String(s)) => s
              _ => ""
            }
          None => ""
        }
        let url = match entry {
          Some(en) =>
            match j_get(en, "url") {
              Some(Json::String(s)) => s
              _ => ""
            }
          None => ""
        }
        out.push(text + (if url != "" { " [" + url + "]" } else { "" }))
      }
    } else if name == "Runtime.consoleAPICalled" {
      let kind = match params {
        Some(p) =>
          match j_get(p, "type") {
            Some(Json::String(s)) => s
            _ => ""
          }
        None => ""
      }
      if kind == "error" {
        let args = match params {
          Some(p) => j_get(p, "args")
          None => None
        }
        let mapped : Array[Json] = []
        match args {
          Some(Json::Array(items)) =>
            for it in items {
              // `a.value ?? a.description`
              match j_get(it, "value") {
                Some(v) =>
                  if !j_is_null(v) {
                    mapped.push(v)
                  } else {
                    mapped.push(match j_get(it, "description") {
                      Some(d) => d
                      None => Json::null()
                    })
                  }
                None =>
                  mapped.push(match j_get(it, "description") {
                    Some(d) => d
                    None => Json::null()
                  })
              }
            }
          _ => ()
        }
        out.push(Json::array(mapped).stringify())
      }
    }
  }
  out
}
