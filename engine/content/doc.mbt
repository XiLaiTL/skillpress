///|
/// 一份 `SKILL.md` → **那段 `blocks` 的原文行**（`dump-blocks` 的判据接口）。
///
/// 唯一比旧实现多知道的一件事：**代码块的高亮要现算**（旧实现在生成物里已经贴好了 runs）。
/// 口径必须与它一致 —— 空块跳过、没配语法的语言跳过，两者都不算错（照原文渲染）。
///
/// ⚠️ 旧实现那句 `if (b.k !== "Code" || !b.text.trim()) continue;` 里的 `!b.text.trim()`
/// 是**必要的**：空白块不给 runs，生成物里写的是 `([] : Array[(String, Int)])`。

///|
/// 代码块贴 runs（认不出语言 / 空块 ⇒ 不贴）。
fn with_runs(lang : String, text : String) -> Block raise {
  if trim(text) == "" {
    return Code(lang, text, [])
  }
  let spec = match @hl.lang_spec(lang) {
    Some(s) => s
    None => return Code(lang, text, [])
  }
  match @hl.highlight(text, lang, @hl.caps_of(spec.wasm)) {
    None => Code(lang, text, [])
    Some(h) => Code(lang, text, h.runs)
  }
}

///|
/// 一份 markdown → 它的 `blocks` 行（每行含 `pad` 缩进与行尾逗号）。
pub fn doc_block_lines(md : String, pad : String) -> Array[String] raise {
  let blocks = parse_blocks(frontmatter_body(md))
  let out : Array[String] = []
  for b in blocks {
    match b {
      Code(lang, text, _) => out.push(emit_block(with_runs(lang, text), pad))
      _ => out.push(emit_block(b, pad))
    }
  }
  out
}
