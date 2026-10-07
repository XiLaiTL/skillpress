///|
/// **CDP 客户端** —— 发一条命令、等到 id 对上的那一条答复；中间的 `method` 事件收进缓冲。
///
/// ⚠️ 事件缓冲**不是可有可无的**：第 ㉒ 条断言"控制台没有 error"就是数 `Log.entryAdded`
///    与 `Runtime.consoleAPICalled` —— 旧实现在这两个事件上挂了一整条判据。
///    所以 `Log.enable` **必须发**（不发就一个 `Log.entryAdded` 都收不到），
///    而 `call` 里"顺手把非答复的消息丢掉"是**错的**：丢掉的正是那两类。
///
/// ⚠️ 坐标一律走 `Input.dispatchMouseEvent`（真鼠标），**不是** `element.click()`：
///    RN 的 `Pressable` 在 web 上走 responder 事件，合成的 `click()` **不一定**能触发
///    ⇒ 那样"点了没反应"这类判据会变成**永远绿**（旧实现文件头专门写了这条）。

///|
/// 从 `Json` 取一个键（不是对象或没有这个键就给 `None`）。
pub fn j_get(j : Json, key : String) -> Json? {
  match j {
    Json::Object(m) => m.get(key)
    _ => None
  }
}

///|
/// 从 `Json` 取一个下标（不是数组或越界就给 `None`）。
pub fn j_at(j : Json, i : Int) -> Json? {
  match j {
    Json::Array(a) => if i >= 0 && i < a.length() { Some(a[i]) } else { None }
    _ => None
  }
}

///|
/// `Json` → 字符串（不是字符串就给 `None`）。
pub fn j_str(j : Json) -> String? {
  match j {
    Json::String(s) => Some(s)
    _ => None
  }
}

///|
/// `Json` → 数字（`Json::Number` 是 `Double`；整数也给得出来）。
pub fn j_num(j : Json) -> Double? {
  match j {
    Json::Number(d, ..) => Some(d)
    _ => None
  }
}

///|
/// `Json` → 布尔。
pub fn j_bool(j : Json) -> Bool? {
  match j {
    Json::True => Some(true)
    Json::False => Some(false)
    _ => None
  }
}

///|
/// `Json` → 整数（从数字截断）。
pub fn j_int(j : Json) -> Int? {
  match j_num(j) {
    Some(d) => Some(d.to_int())
    None => None
  }
}

///|
/// `Json` 是不是空（`null` / 缺省）—— 页面里"没找到元素"就是这一种。
pub fn j_is_null(j : Json) -> Bool {
  match j {
    Json::Null => true
    _ => false
  }
}

///|
/// 一次 CDP 会话：一条 WebSocket + 自增的 id + **事件缓冲**。
pub struct Cdp {
  conn : @websocket.Conn
  mut next_id : Int
  /// 只装"带 `method` 的消息"（事件）。第 ㉒ 条断言读它。
  events : Array[Json]
}

///|
/// 连上一条 CDP WebSocket（`ws://127.0.0.1:<port>/devtools/page/<id>`）。
pub async fn Cdp::connect(ws_url : String) -> Cdp {
  { conn: @websocket.Conn::connect(ws_url), next_id: 1, events: [] }
}

///|
/// 发一条命令，循环收消息直到 id 对上；**中间的 `method` 事件全部收进 `events`**。
///
/// ⚠️ 有两条"看起来可以省"的东西不能省：
///    ① `params` 里的表达式要**先做 JSON 转义**（页面里那些 JS 全是引号与反斜杠）；
///    ② 答复里有 `error` 字段要**抛出去** —— CDP 的错误（方法名写错、参数不认识）
///       不会自己变成断言红，会被当成"值就是 undefined"悄悄吞掉。
pub async fn Cdp::call(self : Cdp, name : String, params : String) -> Json raise {
  let id = self.next_id
  self.next_id = id + 1
  self.conn.send_text("{\"id\":\{id},\"method\":\"\{name}\",\"params\":\{params}}")
  let mut tries = 0
  while tries < 500 {
    let msg = self.conn.recv()
    let text = msg.read_all().text() catch { _ => fail("CDP 读消息失败（\{name}）") }
    let parsed : Json = @json.parse(text) catch { _ => fail("CDP 回了一段不是 JSON 的东西：\{text}") }
    // 是答复吗？（本次的 id）
    match j_get(parsed, "id") {
      Some(Json::Number(d, ..)) =>
        if d.to_int() == id {
          match j_get(parsed, "error") {
            Some(err) => fail("CDP 报错（\{name}）：\{err.to_string()}")
            None => ()
          }
          return match j_get(parsed, "result") {
            Some(r) => r
            None => Json::null()
          }
        }
      _ => ()
    }
    // 不是答复 ⇒ 只可能是事件（带 method），收起来
    match j_get(parsed, "method") {
      Some(_) => self.events.push(parsed)
      None => ()
    }
    tries = tries + 1
  }
  fail("CDP 等不到 id=\{id} 的答复（\{name}）")
}

///|
/// 把一段 JS 表达式塞进 `params` 用的 JSON 字符串（转义 `\` 与 `"`）。
pub fn js_expr_json(expression : String) -> String {
  let esc = expression.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"")
  "{\"expression\":\"" + esc + "\",\"returnByValue\":true,\"awaitPromise\":true}"
}

///|
/// `Runtime.evaluate`（`returnByValue` + `awaitPromise`），返回 `result.result` 那个对象。
///
/// ⚠️ 页面里抛了异常时**必须把详情打全**（旧实现专门写了这条）：只报 `text` 会丢掉真因，
///    而且会让人以为是自己那段代码的问题 —— 旧实现实测的代价是 `topbar is not defined`
///    查了半天，其实是页面里抛的无关异常。
pub async fn Cdp::eval_raw(self : Cdp, expression : String) -> Json raise {
  let r = self.call("Runtime.evaluate", js_expr_json(expression))
  match j_get(r, "exceptionDetails") {
    Some(ex) => {
      let text = match j_get(ex, "text") {
        Some(Json::String(s)) => s
        _ => "(没有 text)"
      }
      let desc = match j_get(ex, "exception") {
        Some(e) =>
          match j_get(e, "description") {
            Some(Json::String(d)) =>
              match lines_of(d) {
                [] => ""
                arr => " —— " + arr[0]
              }
            _ => ""
          }
        None => ""
      }
      let place = match j_get(ex, "stackTrace") {
        Some(st) =>
          match j_at_opt(j_get(st, "callFrames"), 0) {
            Some(f) => {
              let fname = match j_get(f, "functionName") {
                Some(Json::String(s)) => if s == "" { "(匿名)" } else { s }
                _ => "(匿名)"
              }
              let ln = match j_get(f, "lineNumber") {
                Some(Json::Number(d, ..)) => (d.to_int() + 1).to_string()
                _ => "?"
              }
              "（在页面里：" + fname + " @ 行 " + ln + "）"
            }
            None => ""
          }
        None => ""
      }
      fail("页面里那句 JS 抛了：" + text + desc + place)
    }
    None => ()
  }
  match j_get(r, "result") {
    Some(v) => v
    None => Json::null()
  }
}

///|
/// `Json?` 上取第 0 个元素（`option` 套一层，省得到处 `match`）。
fn j_at_opt(j : Json?, i : Int) -> Json? {
  match j {
    Some(v) => j_at(v, i)
    None => None
  }
}

///|
/// 页面表达式 → 字符串（不是字符串/没有值就给 `raise` —— 判据要的是"确实读到了"）。
pub async fn Cdp::eval_str(self : Cdp, expression : String) -> String raise {
  let v = self.eval_raw(expression)
  match j_get(v, "value") {
    Some(Json::String(s)) => s
    Some(Json::Null) => ""
    None => ""
    _ => fail("这句 JS 没返回字符串：\{expression}")
  }
}

///|
/// 页面表达式 → 整数。
pub async fn Cdp::eval_int(self : Cdp, expression : String) -> Int raise {
  let v = self.eval_raw(expression)
  match j_get(v, "value") {
    Some(Json::Number(d, ..)) => d.to_int()
    _ => fail("这句 JS 没返回数字：\{expression}")
  }
}

///|
/// 页面表达式 → 布尔（`undefined`/缺省当 false —— 与 JS 的真值判断同口径）。
pub async fn Cdp::eval_bool(self : Cdp, expression : String) -> Bool raise {
  let v = self.eval_raw(expression)
  match j_get(v, "value") {
    Some(Json::True) => true
    Some(Json::False) => false
    Some(Json::Null) => false
    None => false
    _ => fail("这句 JS 没返回布尔：\{expression}")
  }
}

///|
/// 页面表达式 → 任意 JSON 值（对象/数组那类读数走这个）。
pub async fn Cdp::eval_json(self : Cdp, expression : String) -> Json raise {
  let v = self.eval_raw(expression)
  match j_get(v, "value") {
    Some(x) => x
    None => Json::null()
  }
}

///|
/// **真鼠标点击**：`mouseMoved`（button=none）→ `mousePressed` → `mouseReleased`。
///
/// ⚠️ 三次都要发，顺序不能改（旧实现只有这一个点击入口）；坐标取元素
///    `getBoundingClientRect()` 的中心点。
pub async fn Cdp::click_at(self : Cdp, x : Double, y : Double) -> Unit raise {
  let base = "\"x\":" + x.to_string() + ",\"y\":" + y.to_string() + ",\"clickCount\":1"
  let _ = self.call("Input.dispatchMouseEvent", "{\"type\":\"mouseMoved\"," + base + ",\"button\":\"none\"}")
  let _ = self.call("Input.dispatchMouseEvent", "{\"type\":\"mousePressed\"," + base + ",\"button\":\"left\"}")
  let _ = self.call("Input.dispatchMouseEvent", "{\"type\":\"mouseReleased\"," + base + ",\"button\":\"left\"}")
}

///|
/// 握手：`Runtime.enable` + `Log.enable` + `Page.enable`。
///
/// ⚠️ `Log.enable` **不能省**：不 enable 就收不到 `Log.entryAdded`，
///    而"控制台没有 error"那条断言正是靠它 —— 省掉就是**永远绿**。
pub async fn Cdp::enable(self : Cdp) -> Unit raise {
  let _ = self.call("Runtime.enable", "{}")
  let _ = self.call("Log.enable", "{}")
  let _ = self.call("Page.enable", "{}")
}

///|
/// `Page.navigate { url }`。
pub async fn Cdp::navigate(self : Cdp, url : String) -> Unit raise {
  let esc = url.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"")
  let _ = self.call("Page.navigate", "{\"url\":\"" + esc + "\"}")
}

///|
/// `Page.captureScreenshot { format: "png" }` → base64 的 PNG（`--shot` 用；**不参与判据**）。
pub async fn Cdp::screenshot_png(self : Cdp) -> String raise {
  let r = self.call("Page.captureScreenshot", "{\"format\":\"png\"}")
  match j_get(r, "data") {
    Some(Json::String(s)) => s
    _ => fail("截图没拿到 data")
  }
}

///|
/// 从 `/json/list` 的应答里挑出 **page** 目标的 WebSocket 地址。
///
/// ⚠️ 只认 `type == "page"` 且带 `webSocketDebuggerUrl` 的那一条（与旧实现同口径）——
///    Chrome 的调试端点还会列出别的 target，抓到那些连上去是连得上的、
///    但 `Runtime.evaluate` 打的是**另一个上下文**。
pub fn pick_page_ws(text : String) -> String? {
  let parsed : Json = @json.parse(text) catch { _ => return None }
  match parsed {
    Json::Array(items) => {
      let mut found : String? = None
      let mut i = 0
      while i < items.length() {
        if found is None {
          match items[i] {
            Json::Object(obj) =>
              match (obj.get("type"), obj.get("webSocketDebuggerUrl")) {
                (Some(Json::String(t)), Some(Json::String(u))) =>
                  if t == "page" {
                    found = Some(u)
                  }
                _ => ()
              }
            _ => ()
          }
        }
        i = i + 1
      }
      found
    }
    _ => None
  }
}
