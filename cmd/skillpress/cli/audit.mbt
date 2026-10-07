///|
/// 每类的命中计数：`(整段都上过色的匹配数, 匹配总数)`。
struct TruthTally {
  covered : Int
  total : Int
}

///|
/// 每门语言的读数。
struct LangTally {
  blocks : Int
  dark : Int
  white : Int
}

///|
/// JS 的 `Number.prototype.toFixed`（够用的一档）。
///
/// ⚠️ 不追求与 JS 在"恰好半个"上的位级一致 —— 这里的数只用来**给人看**；
///    判据比的是**整数读数**（覆盖/总数 / dark/white）与**最终判决**，不是这行文字。
fn to_fixed(x : Double, digits : Int) -> String {
  let scale = if digits <= 0 {
    1.0
  } else {
    let mut s = 1.0
    for _ in 0..<digits {
      s = s * 10.0
    }
    s
  }
  let scaled = x * scale
  let rounded = if scaled >= 0.0 { (scaled + 0.5).to_int() } else { -((-scaled + 0.5).to_int()) }
  if digits <= 0 {
    return rounded.to_string()
  }
  let neg = rounded < 0
  let abs = if neg { -rounded } else { rounded }
  let s = abs.to_string()
  let padded = if s.length() <= digits {
    let mut z = ""
    for _ in 0..<(digits + 1 - s.length()) {
      z = z + "0"
    }
    z + s
  } else {
    s
  }
  let cut = padded.length() - digits
  (if neg { "-" } else { "" }) + padded[:cut].to_owned() + "." + padded[cut:].to_owned()
}

///|
/// 左侧补空格到 `width`（JS 的 `padEnd`，按**码元**数）。
fn pad_end(s : String, width : Int) -> String {
  if s.length() >= width {
    return s
  }
  let mut out = s
  for _ in 0..<(width - s.length()) {
    out = out + " "
  }
  out
}

///|
/// 闸门阈值（旧实现 `GATE`；定得松 —— 不是追求满分，而是"拦住塌方"）。
fn gate_recall() -> Double {
  0.9
}

///|
fn gate_dark() -> Double {
  0.4
}

///|
/// 子命令本体。
fn audit(rest : Array[String]) -> Unit {
  if rest.length() > 0 {
    set_corpus(rest[0])
  }
  let raw = md_files()
  let files = raw.split("\n").filter(fn(l) { l != "" }).map(fn(l) { l.to_owned() }).collect()
  let kws = audit_keywords()
  let kinds = truth_kinds()
  let hit : Map[String, TruthTally] = Map([])
  let per_lang : Map[String, LangTally] = Map([])
  let unknown : Map[String, Unit] = Map([])
  let mut dark_total = 0
  let mut white_total = 0
  let mut blocks_seen = 0
  for file in files {
    let src = read_text(file)
    for f in fences(src) {
      let spec = match @hl.lang_spec(f.lang) {
        Some(s) => s
        None => {
          unknown.set(if f.lang == "" { "(空)" } else { f.lang }, ())
          continue
        }
      }
      let h = try {
        @hl.highlight(f.code, f.lang, @hl.caps_of(spec.wasm))
      } catch {
        _ => None
      }
      let hl = match h {
        Some(x) => x
        None => continue
      }
      blocks_seen = blocks_seen + 1
      // 每个**字符**"上过色吗"（与 `runs` 拼出来的下标同一套）
      let colored : Array[Bool] = []
      for run in hl.runs {
        let (text, idx) = run
        for _ch in text {
          colored.push(idx > 0)
        }
      }
      let cs = f.code.to_array()
      let white = @hl.solid_count(f.code)
      let dark = hl.dark
      white_total = white_total + white
      dark_total = dark_total + dark
      let cur = per_lang.get_or_default(hl.label, { blocks: 0, dark: 0, white: 0 })
      per_lang.set(hl.label, { blocks: cur.blocks + 1, dark: cur.dark + dark, white: cur.white + white })
      let per_kind : Array[Array[Hit]] = [
        matches_keyword(cs, kws),
        matches_string(cs),
        matches_comment(cs),
        matches_number(cs),
      ]
      let mut ki = 0
      while ki < kinds.length() {
        let name = kinds[ki]
        let t = hit.get_or_default(name, { covered: 0, total: 0 })
        let mut covered = t.covered
        let mut total = t.total
        for m in per_kind[ki] {
          total = total + 1
          let mut all = true
          let mut i = m.start
          while i < m.end {
            // ⚠️ 越界当"没上色"（旧实现里 `colored[i]` 越界是 `undefined` ⇒ 假值 ⇒ 同样不算全覆盖）
            if i >= colored.length() || !colored[i] {
              all = false
              break
            }
            i = i + 1
          }
          if all {
            covered = covered + 1
          }
        }
        hit.set(name, { covered, total })
        ki = ki + 1
      }
    }
  }

  // ── 空集合守卫：**不许算通过**（路径写错时一个块都收不到，而 `NaN < 阈值` 是 false
  //    ⇒ 门会**绿着**放过去 —— 假绿比红更糟）──────────────────────────────────
  let kinds_total = kinds.fold(init=0, fn(acc, k) {
    acc + (match hit.get(k) { Some(t) => t.total; None => 0 })
  })
  if blocks_seen == 0 || kinds_total == 0 {
    @content.note("✗ 一个代码块都没数到 —— 内容源的路径不对？（这条判据不允许在空集合上通过）")
    @content.set_exit_code(1)
    return
  }

  println("高亮召回复核（真值 = 关键字 / 字符串 / 注释 / 数字，纯扫描数出来的）：")
  let mut covered_sum = 0
  let mut total_sum = 0
  for k in kinds {
    match hit.get(k) {
      Some(t) => {
        covered_sum = covered_sum + t.covered
        total_sum = total_sum + t.total
        let pct = if t.total == 0 {
          0.0
        } else {
          (t.covered.to_double() / t.total.to_double()) * 100.0
        }
        println("  " + pad_end(k, 8) + " " + t.covered.to_string() + "/" + t.total.to_string() + "  " + to_fixed(pct, 0) + "%")
      }
      None => ()
    }
  }
  let recall = covered_sum.to_double() / total_sum.to_double()
  let dark_ratio = dark_total.to_double() / white_total.to_double()
  println("  " + pad_end("合计", 7) + " " + covered_sum.to_string() + "/" + total_sum.to_string() + "  " + to_fixed(recall * 100.0, 1) + "%")
  println(
    "未上色的非空白字符：" + dark_total.to_string() + "/" + white_total.to_string() + "（" +
    to_fixed(dark_ratio * 100.0, 1) + "%）",
  )
  // 按语言的顺序要固定（两边的输出要能 `diff`）
  let lang_keys = ["moonbit", "bash", "json", "javascript", "toml"]
  for key in lang_keys {
    match per_lang.get(key) {
      None => ()
      Some(v) =>
        println(
          "  " + pad_end(key, 12) + " " + v.blocks.to_string() + " 块 ｜ 未上色 " + v.dark.to_string() +
          "/" + v.white.to_string(),
        )
    }
  }
  if unknown.size() > 0 {
    let names : Array[String] = []
    for k, _ in unknown {
      names.push(k)
    }
    println("\n没有配语法的标记（按原文渲染）：" + join_comma(names))
  }

  let problems : Array[String] = []
  if recall < gate_recall() {
    problems.push("召回率 " + to_fixed(recall * 100.0, 1) + "% < " + to_fixed(gate_recall() * 100.0, 0) + "%")
  }
  if dark_ratio > gate_dark() {
    problems.push("未上色比例 " + to_fixed(dark_ratio * 100.0, 1) + "% > " + to_fixed(gate_dark() * 100.0, 0) + "%")
  }
  if problems.length() > 0 {
    @content.note("\n✗ 高亮退化了：" + join_semis(problems))
    @content.set_exit_code(1)
    return
  }
  println(
    "\n✓ 在闸门内（召回率 ≥ " + to_fixed(gate_recall() * 100.0, 0) + "%，未上色 ≤ " +
    to_fixed(gate_dark() * 100.0, 0) + "%）",
  )
}

///|
/// `、`? 不 —— 旧实现用 `", "` 连语言名。
fn join_comma(items : Array[String]) -> String {
  let mut out = ""
  let mut first = true
  for it in items {
    if !first {
      out = out + ", "
    }
    out = out + it
    first = false
  }
  out
}

///|
/// 旧实现用 `"；"` 连失败原因。
fn join_semis(items : Array[String]) -> String {
  let mut out = ""
  let mut first = true
  for it in items {
    if !first {
      out = out + "；"
    }
    out = out + it
    first = false
  }
  out
}
