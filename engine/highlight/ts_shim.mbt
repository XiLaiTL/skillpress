///|
/// tree-sitter 的**薄垫片**（js target 专用）。
///
/// ## 为什么不直接用上游那层绑定
///
/// `tonyfettes/tree_sitter` 声明 `supported-targets: "+native"`（P8.0 实测：
/// js 那张构建图直接被 moon 拒掉），而 native 那边卡在**上游缺 C 源**
/// （`tree-sitter.c` include 了包里没有的 `tree-sitter/lib/src/lib.c`）。
/// 而它在 js 上本来也只是 `await import("web-tree-sitter")` —— 跟我们今天 Node 版用的是**同一个包**。
///
/// ## 形状：异步留在"引导层"，逻辑留在 MoonBit
///
/// `web-tree-sitter` 的 `Parser.init()` 与 `Language.load()` 都是 **Promise**，
/// 而 `moon run --target js` 产出的模块是 **CJS**（顶层 await 不成立）。
/// 所以分工是：
///   · **引导脚本**（Node，见 `tools/run-js.mjs`）先 `await` 把 tree-sitter 与那 5 份语法
///     （我们自己 vendor 的 `grammars/*.wasm`）装好，挂在 `globalThis.__skillpress_ts` 上；
///   · **MoonBit 这边只做同步调用**，并把结果压成一行行朴素文本（`名字\t起点\t终点`），
///     色号映射与片段拼装全在 `hl.mbt` 里 —— 那部分才是我们要搬进 MoonBit 的东西。
///
/// ⚠️ 语言句柄由引导层**按名字**预先装好（`langs["bash"]`），这里不负责加载 wasm：
/// 一旦让 MoonBit 侧去 await，就得把整个 async 运行时拖进来 —— P8.3（站点判据要起
/// Chrome、走 CDP）才值得付那个代价，上色这一步不值。

///|
/// 引导层装好了吗？（没装好就别往下走 —— 报错要**明说**，不要静默给一份"全不上色"的结果）
pub fn ready() -> Bool {
  ts_ready()
}

///|
/// 引导层认得的语法有哪些（名字，逗号分隔）。用它给"这个语言没装语法"这类情况一条明路。
pub fn languages() -> String {
  ts_languages()
}

///|
/// 跑一次：解析 `code`，用 `scm` 这份 query 取 capture。
/// 返回**朴素三列文本**：每行 `名字\t起点\t终点`（判据与拼装都在 MoonBit 侧）。
/// 认不出语言 / query 报错时**抛**，由调用方明说（不许静默降级）。
pub fn captures_raw(lang_name : String, code : String, scm : String) -> String raise {
  let out = ts_captures(lang_name, code, scm)
  if out.has_prefix("ERR:") {
    raise Failure(out)
  }
  out
}

///|
/// 把"名字\t起点\t终点"的每行解析成 `Capture`。
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
        out.push({ name: parts[0].to_owned(), start, end })
      }
    }
  }
  out
}

///|
/// 解析失败给 `fallback`（探针阶段不接受"整块丢掉"这种静默降级：坏行会被上面那两条
/// `start >= 0 && end > start` 直接筛掉，而筛掉了多少 `captures_raw` 那一侧是知道的）。
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
extern "js" fn ts_captures(lang_name : String, code : String, scm : String) -> String =
  #|(langName, code, scm) => {
  #|  const g = globalThis.__skillpress_ts;
  #|  const lang = g.langs[langName];
  #|  if (!lang) return "ERR: 没装这个语言的语法：" + langName + "（已装：" + Object.keys(g.langs).join(",") + "）";
  #|  try {
  #|    const parser = new g.ts.Parser();
  #|    parser.setLanguage(lang);
  #|    const tree = parser.parse(code);
  #|    const query = new g.ts.Query(lang, scm);
  #|    const caps = query.captures(tree.rootNode);
  #|    return caps.map((c) => c.name + "\t" + c.node.startIndex + "\t" + c.node.endIndex).join("\n");
  #|  } catch (e) {
  #|    return "ERR:" + (e && e.message ? e.message : String(e));
  #|  }
  #|}
