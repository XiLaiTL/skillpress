///|
/// tree-sitter 的**薄垫片**（js target 专用）。
///
/// ## 为什么不直接用上游那层绑定
///
/// `tonyfettes/tree_sitter` 声明 `supported-targets: "+native"`（P8.0 实测：js 那张构建图
/// 直接被 moon 拒掉），而 native 那边卡在**上游缺 C 源**（`tree-sitter.c` include 了包里
/// 没有的 `tree-sitter/lib/src/lib.c`）。它在 js 上本来也只是 `await import("web-tree-sitter")`
/// —— 跟我们旧实现用的是**同一个包**。
///
/// ## 形状：异步留在"引导层"，逻辑留在 MoonBit
///
/// `web-tree-sitter` 的 `Parser.init()` / `Language.load()` 都是 Promise，而
/// `moon run --target js` 产出的是 **CJS**（顶层 await 不成立）。所以：
///   · **引导层**（`tools/run-js.mjs`）先 `await` 装好 tree-sitter、5 份 wasm 语法与 5 份 query，
///     挂在 `globalThis.__skillpress_ts` 上；
///   · **这里只做同步调用**，把 capture 压成"名字\t起点\t终点"三列文本；
///   · 色号、优先级、包装挑选、片段拼装**全在 MoonBit**（`hl.mbt` / `wrap.mbt`）。
///
/// ⚠️ 语言句柄由引导层按 wasm 基名预装（`moonbit` / `bash` / `json` / `javascript` / `toml`）。

///|
/// 引导层装好了吗？（没装好就**明说**，不要静默给一份"全不上色"的结果）
pub fn ready() -> Bool {
  ts_ready()
}

///|
/// 引导层认得的语法（逗号分隔的 wasm 基名）。
pub fn languages() -> String {
  ts_languages()
}

///|
/// 跑一次解析：对给定的**整段文本**（可能是包装过的）取 capture。
/// 认不出语言 / query 报错 ⇒ **抛**，由调用方明说（不许静默降级）。
pub fn captures_raw(lang_name : String, source : String) -> String raise {
  let out = ts_captures(lang_name, source)
  if out.has_prefix("ERR:") {
    raise Failure(out)
  }
  out
}

///|
/// 把三列文本解析成 `Capture`（**色号优先级在这里就填好**）。
pub fn parse_captures(text : String) -> Array[Capture] {
  let out : Array[Capture] = []
  for line in text.split("\n") {
    if line == "" {
      continue
    }
    let parts = line.split("\t").collect()
    if parts.length() == 3 {
      let start = to_int_or(parts[1], -1)
      let end = to_int_or(parts[2], -1)
      if start >= 0 && end > start {
        out.push(with_palette({ name: parts[0].to_owned(), start, end, prio: 0 }))
      }
    }
  }
  out
}

///|
/// 给 `wrap.mbt` 的 `caps_of` 用：绑定语言，拿到"文本 → capture 表"。
pub fn caps_of(lang_name : String) -> (String) -> Array[Capture] raise {
  fn(source) raise { parse_captures(captures_raw(lang_name, source)) }
}

///|
/// 解析失败给 `fallback`（坏行会被 `start >= 0 && end > start` 筛掉，不静默降级：
/// 筛掉多少，`captures_raw` 那一侧是数得出来的）。
fn to_int_or(text : StringView, fallback : Int) -> Int {
  try {
    @string.parse_int(text)
  } catch {
    _ => fallback
  }
}

///|
extern "js" fn ts_ready() -> Bool =
  #|() => !!(globalThis.__skillpress_ts && globalThis.__skillpress_ts.langs)

///|
extern "js" fn ts_languages() -> String =
  #|() => Object.keys(globalThis.__skillpress_ts.langs).sort().join(",")

///|
extern "js" fn ts_captures(lang_name : String, source : String) -> String =
  #|(langName, source) => {
  #|  const g = globalThis.__skillpress_ts;
  #|  const lang = g.langs[langName];
  #|  if (!lang) return "ERR: 没装这个语言的语法：" + langName + "（已装：" + Object.keys(g.langs).join(",") + "）";
  #|  const scm = g.scms[langName];
  #|  if (!scm) return "ERR: 没装这个语言的 query：" + langName;
  #|  try {
  #|    const parser = new g.ts.Parser();
  #|    parser.setLanguage(lang);
  #|    const tree = parser.parse(source);
  #|    const query = new g.ts.Query(lang, scm);
  #|    return query.captures(tree.rootNode)
  #|      .map((c) => c.name + "\t" + c.node.startIndex + "\t" + c.node.endIndex)
  #|      .join("\n");
  #|  } catch (e) {
  #|    return "ERR:" + (e && e.message ? e.message : String(e));
  #|  }
  #|}
