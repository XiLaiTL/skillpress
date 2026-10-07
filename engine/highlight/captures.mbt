///|
/// **capture 那条链里"与 target 无关"的那半**：三列文本 → `Capture`、优先级、给 `wrap.mbt` 用的
/// `(文本) -> capture 表`。
///
/// 目标相关的那半只有三件事（`ready` / `languages` / `captures_text`）：
///   · **js**：走引导层（`tools/run-js.mjs` 先把 tree-sitter 与 5 份 wasm + 5 份 query 装好，
///     挂在 `globalThis.__skillpress_ts` 上），实现在 `ts_shim.mbt`；
///   · **native**：走我们自己的 C 桩 + **编进二进制**的 query（`queries.generated.mbt`），
///     实现在 `ts_shim.native.mbt`。
///
/// 为什么这一层必须分出来：native 那边**没有引导层**，但"三列文本 → Capture"的规矩两边
/// 一模一样 —— 只有把逻辑放在一处，"同一份语料上 native 与 js 逐字节一致"这条判据才谈得上。

///|
/// 跑一次解析：对给定的**整段文本**（可能是包装过的）取 capture。
/// 认不出语言 / query 报错 ⇒ **抛**，由调用方明说（不许静默降级）。
pub fn captures_raw(lang_name : String, source : String) -> String raise {
  let out = captures_text(lang_name, source)
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
