///|
/// **页面侧的读数** —— 在真页面上跑的那几段注入 JS（旧实现 `lib/verify-site.mjs` 的原样搬运）。
///
/// ⚠️ 这一层的每一段 JS 都对应一条"会真的坏"的失败模式，注释写在各自函数上。
///    共同的一条：**读的是渲染出来的东西**（`innerText` / `getComputedStyle` / 几何），
///    而不是我们以为写进去的东西 —— 否则判据只是在重复实现自己。

///|
/// 屏幕上的一个点（元素中心）。
pub struct Box {
  x : Double
  y : Double
}

///|
/// "行内流"的读数。
pub struct InlineProbe {
  found : Bool
  count : Int
  spans : Int
}

///|
/// 文档区的几何（树在左、正文在右）。
pub struct Geo {
  side_x : Int
  pane_x : Int
}

///|
/// 把一段文字嵌进注入的 JS 当**字符串字面量**（转义 `\` `"` 与三种控制字符）。
///
/// ⚠️ 不能直接拼引号：探针句里就有全角引号与反引号，一个没转义整段 JS 就语法错，
///    而语法错的症状是"页面里那句 JS 抛了" —— 会被误读成页面有问题。
pub fn js_lit(s : String) -> String {
  let out : Array[String] = []
  for ch in s {
    if ch == '\\' {
      out.push("\\\\")
    } else if ch == '"' {
      out.push("\\\"")
    } else if ch == '\n' {
      out.push("\\n")
    } else if ch == '\r' {
      out.push("\\r")
    } else if ch == '\t' {
      out.push("\\t")
    } else {
      out.push(ch.to_string())
    }
  }
  "\"" + out.join("") + "\""
}

///|
/// 整页可见文本（`document.body.innerText`）—— 后面几乎所有比较的基准。
pub async fn body_text(cdp : Cdp) -> String raise {
  cdp.eval_str("document.body.innerText")
}

///|
/// 按**元素整条文本**精确匹配找元素、取其中心点（找不到给 `None`，**不点**）。
///
/// ⚠️ 口径必须是"某个元素的整条文本"，不能是"整页里有这个子串" —— 旧实现踩过：
///    首页中部那个 CTA 写着「文档 / SKILL →」，整页子串**永远成立** ⇒ 那条判据假绿；
///    而 `click_text` 用精确匹配 ⇒ 找不到元素、**后面 3 条判据被静默跳过**（总数 19，不是 22）。
/// ⚠️ 取 `.pop()`（最后一个匹配）：外层的容器常常也"整条文本等于它"。
pub async fn find_center(cdp : Cdp, selector : String, label : String, trim : Bool) -> Box? raise {
  let cmp = if trim {
    "(e.innerText||\"\").trim() === " + js_lit(label)
  } else {
    "e.innerText === " + js_lit(label)
  }
  let js = "(() => {" +
    " const els = [...document.querySelectorAll(" + js_lit(selector) + ")].filter(e => " + cmp + ");" +
    " const el = els[els.length - 1];" +
    " if (!el) return null;" +
    // ⚠️ **先滚进视口再取中心点**（2026-10-07 加）：CDP 的真鼠标事件按**视口坐标**打，
    //    元素在视口外时那个坐标打在别的东西上（或者什么都没打），症状是"点了没反应" ——
    //    而真因是**页面变长了**。实测：把首页源写长之后（多了一段列表 + 一个代码块），
    //    "点首页那张『从哪开始』卡片"这条判据当场红，而卡片本身完全正常（位置在折叠线以下）。
    //    ⇒ 一律先 `scrollIntoView({block:'center'})` 再量中心点；顺带把滚动容器也照顾到。
    " el.scrollIntoView({ block: 'center', inline: 'center' });" +
    " const r = el.getBoundingClientRect();" +
    " return { x: r.x + r.width / 2, y: r.y + r.height / 2 };" +
    " })()"
  box_of(cdp.eval_json(js))
}

///|
/// 把 `{x,y}` 或 `null` 解成 `Box?`。
fn box_of(j : Json) -> Box? {
  match j_get(j, "x") {
    Some(_) => {
      let x = match j_get(j, "x") {
        Some(v) => match j_num(v) {
          Some(d) => d
          None => 0.0
        }
        None => 0.0
      }
      let y = match j_get(j, "y") {
        Some(v) => match j_num(v) {
          Some(d) => d
          None => 0.0
        }
        None => 0.0
      }
      Some({ x, y })
    }
    None => None
  }
}

///|
/// 点一个"整条文本等于 `label`"的元素。**返回是否找到了**（找不到时判据要判红，不许静默跳过）。
pub async fn click_text(cdp : Cdp, label : String) -> Bool raise {
  match find_center(cdp, "div,button,span", label, true) {
    Some(b) => {
      cdp.click_at(b.x, b.y)
      true
    }
    None => false
  }
}

///|
/// 顶栏有没有「文档 / SKILL」那一条（换模式的入口）。
///
/// ⚠️ 严格相等 ⇒ 首页中部那个 CTA「文档 / SKILL →」**不会**命中它。
pub async fn has_docs_tab(cdp : Cdp) -> Bool raise {
  cdp.eval_bool(
    "[...document.querySelectorAll('div,button,span')].some(e => (e.innerText||\"\").trim() === \"文档 / SKILL\")",
  )
}

///|
/// 顶栏导航那一排**逐条读出来**（`#topnav` 的直接子元素自己的文字）。
///
/// ⚠️ 为什么要**指到 `#topnav`** 而不是整页找文字（2026-10-07 换血时定的）：
///    旧判据按"整页里有没有这几个字"来判"顶栏列了哪些分栏"，于是
///    ① **正文里的同名文字会冒充顶栏**（首页那张 CTA 卡片上就写着「文档 / SKILL」⇒ 假绿过一次）；
///    ② 顶栏**少一条**只要正文里恰好有那几个字就看不出来。
///    现在只量这一排：多了少了都当场红。
pub async fn nav_labels(cdp : Cdp) -> Array[String] raise {
  // ⚠️ 内层 JS 一律用**单引号**：MoonBit 的字符串是双引号，混着写就要一层转义（踩过）。
  let js = "(() => {" +
    " const box = document.getElementById('topnav');" +
    " if (!box) return [];" +
    " return [...box.children].map(e => (e.innerText || '').trim()).filter(t => t !== '');" +
    "})()"
  let j = cdp.eval_json(js)
  let out : Array[String] = []
  match j {
    Array(items) =>
      for it in items {
        match it {
          String(t) => out.push(t)
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
/// 顶栏里**有没有这一条**（`#topbar` 范围内、按元素整条文本严格相等）。
pub async fn topbar_has(cdp : Cdp, label : String) -> Bool raise {
  let js = "(() => {" +
    " const box = document.getElementById('topbar');" +
    " if (!box) return false;" +
    " return [...box.querySelectorAll('div,button,span')].some(e => (e.innerText||'').trim() === " +
    js_lit(label) +
    ");" +
    "})()"
  cdp.eval_bool(js)
}

///|
/// 给一组标签取它们各自元素的 `y`（同一个元素口径）；**缺一个就给 `None`**。
///
/// 用途：断言"顶栏的分栏排在**同一行**里"。RN 里换行、挤掉、被压在下面**都是静默的**
/// （编译器不拦、控制台不报），而"顶栏"这个形态恰恰全靠这一条。
pub async fn nav_ys(cdp : Cdp, labels : Array[String]) -> Array[Int]? raise {
  let mut arr = "["
  let mut first = true
  for l in labels {
    if !first {
      arr = arr + ","
    }
    arr = arr + js_lit(l)
    first = false
  }
  arr = arr + "]"
  let js = "(() => {" +
    " const labels = " + arr + ";" +
    " const ys = [];" +
    " for (const L of labels) {" +
    " const box = document.getElementById('topnav');" +
    " if (!box) return null;" +
    " const el = [...box.querySelectorAll('div,button,span')].filter(e => (e.innerText||'').trim() === L).pop();" +
    " if (!el) return null;" +
    " ys.push(Math.round(el.getBoundingClientRect().y));" +
    " }" +
    " return ys;" +
    " })()"
  match cdp.eval_json(js) {
    Json::Array(items) => {
      let out : Array[Int] = []
      for it in items {
        match j_int(it) {
          Some(n) => out.push(n)
          None => ()
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// 页面上有几个"侧栏容器"（底色 = 主题里的 `c_side`）。
///
/// ⚠️ 判据**不能**是"skill 名一个都没露"：首页**本身就是**一份 skill ⇒ 那样永远不成立。
///    所以改成认侧栏那个容器的**底色** —— 那才是"两个模式真分开"的判据。
pub async fn sidebar_count(cdp : Cdp) -> Int raise {
  cdp.eval_int(
    "[...document.querySelectorAll('div')].filter(d => getComputedStyle(d).backgroundColor === 'rgb(234, 227, 213)').length",
  )
}

///|
/// "行内流"读数：整段文字能不能装进**一个** `[dir=auto]` 里，且那个元素里有嵌套 `span`。
///
/// `[dir=auto]` 是 RNW 给 `Text` 的标记。出 bug 时每个片段是**各自**一个 Text（兄弟节点），
/// 于是**没有任何一个**元素能包含整段文字 —— 这条判据恰好把两种形态分开。
///
/// ⚠️ 用 `textContent`（不是 `innerText`）：这里比的是"节点里装得下多少字"，
///    与旧实现同一个选择。
pub async fn inline_probe(cdp : Cdp, probe : String) -> InlineProbe raise {
  let js = "(() => {" +
    " const probe = " + js_lit(probe) + ";" +
    " const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();" +
    " const hits = [...document.querySelectorAll('[dir=\"auto\"]')].filter(el => norm(el.textContent).includes(probe));" +
    " if (!hits.length) return { found: false, count: 0 };" +
    " const spans = hits.map(el => el.querySelectorAll('span').length).sort((a, b) => b - a)[0];" +
    " return { found: true, count: hits.length, spans: spans };" +
    " })()"
  let j = cdp.eval_json(js)
  let found = match j_get(j, "found") {
    Some(v) => match j_bool(v) {
      Some(b) => b
      None => false
    }
    None => false
  }
  let count = match j_get(j, "count") {
    Some(v) => match j_int(v) {
      Some(n) => n
      None => 0
    }
    None => 0
  }
  let spans = match j_get(j, "spans") {
    Some(v) => match j_int(v) {
      Some(n) => n
      None => 0
    }
    None => 0
  }
  { found, count, spans }
}

///|
/// 文档区的几何：侧栏标题（`SKILL 文档`）与正文里第一份 skill 名字的 `x`。
///
/// 用途：断言"树在左、正文在右"。**RN 里顺序/尺寸错了也是静默的**。
pub async fn docs_geo(cdp : Cdp, slug : String) -> Geo? raise {
  // ⚠️ 两个容器都用**具名节点**：`#sidebar`（侧栏根）与 `#prose`（正文那一栏）。
  //    旧实现是按**文字**找的（"哪个元素的内容以 `SKILL 文档` 开头"、以及"哪个元素正好写着这个 slug"）——
  //    新 IA 里那句标题没了、渲染的也是 title 不是 slug ⇒ 两条都量不到东西（实测"找不到侧栏或正文"）。
  //    判据要量的东西（左右两栏的位置）与"栏里的字是什么"无关 ⇒ 指到**容器**就好。
  let _ = slug
  let js = "(() => {" +
    " const side = document.getElementById('sidebar');" +
    " const pane = document.getElementById('prose');" +
    " if (!side || !pane) return null;" +
    " return { sideX: Math.round(side.getBoundingClientRect().x), paneX: Math.round(pane.getBoundingClientRect().x) };" +
    " })()"
  let j = cdp.eval_json(js)
  match (j_get(j, "sideX"), j_get(j, "paneX")) {
    (Some(a), Some(b)) =>
      match (j_int(a), j_int(b)) {
        (Some(sx), Some(px)) => Some({ side_x: sx, pane_x: px })
        _ => None
      }
    _ => None
  }
}

///|
/// 等正文里出现某段文字（两边都归一化空白）—— **"点了要换内容"才是事件通道通了的证据**。
///
/// 与旧实现同口径：`tries` 次、每次 100ms。
pub async fn wait_text(cdp : Cdp, sub : String, tries : Int) -> Bool raise {
  let mut i = 0
  while i < tries {
    @async.sleep(100)
    let t = norm(body_text(cdp) catch { _ => "" })
    if t.contains(sub) {
      return true
    }
    i = i + 1
  }
  false
}
