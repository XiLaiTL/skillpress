///|
/// tree-sitter 的**薄垫片（js target 专用）**。
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
/// ⚠️ **native 那一侧是另一份文件**（`ts_shim.native.mbt`）：它没有引导层，query 是编进二进制的
/// （`queries.generated.mbt`）。两份垫片必须给出**同样的三列文本** —— 那是 P10 的判据。

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
/// 原生那一侧的同名函数在 `ts_shim.native.mbt`：这里取引导层装好的语言与 query，
/// 把 capture 压成三列文本（认不出 / query 报错都写成 `ERR:` 前缀，由 `captures.mbt` 抛出去）。
pub fn captures_text(lang_name : String, source : String) -> String {
  ts_captures(lang_name, source)
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
