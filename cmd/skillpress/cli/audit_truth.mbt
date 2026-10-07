///|
/// **上色审计的真值表** —— 四个匹配器：关键字 / 字符串 / 注释 / 数字。
///
/// ⚠️ 它们**不认识高亮结果**：纯扫描数出「这里本该有 N 个看得见的东西」，
///    再拿高亮结果去核对「每一个是不是都上了色」 ⇒ 召回率就是从这儿来的。
///
/// ⚠️ **语义要按 JS 正则那套照抄**（旧实现是四条 `RegExp`）—— 每条函数的注释里都写了
///    它对应哪条正则、以及哪些边角是**刻意**照抄的（比如 `#` 那条不问上下文）。
///    口径一漂，「召回率」这个数就不再是同一条了。
/// **`audit [<内容根>]`** —— **上色的回归闸门**：召回率与"漏色比例"越线就红。
///
/// ```bash
/// node tools/run-js.mjs audit            # 在程序根跑，内容根取 SKILLPRESS_CORPUS
/// node tools/run-js.mjs audit <内容根>
/// ```
///
/// ## 为什么要有它（旧实现的原话，照抄）
///
/// 高亮坏起来是**安静**的 —— 换个语法版本、包装策略失效、调色板正则改窄，
/// 页面照样渲染，只是颜色变少。这几个数字是唯一能看出来的地方。
///
/// ## 它从哪儿来
///
/// 旧实现在 `lib/highlight.mjs` 的 `--audit`（`bin/skillpress.mjs audit`）。`lib/` 退役前
/// 把它搬过来 —— 这是最后一个"不搬就会无声消失"的功能（PLAN 里记的是 `DG-audit`）。
/// ⚠️ **口径逐条照抄**（见下面各函数的注释），因为它比的是"上色有没有塌方"，
///    口径一漂，闸门拦的东西就变了。
///
/// ⚠️ 与 `batch` 的分工：`batch` 打**读数**（每块 dark/total），`audit` 打**判决**
///    （召回率/未上色比例有没有越线）。两者都跑在**同一份语料**上。
///|
/// 真值表：四类"看得见的东西"，纯扫描数出来（不认识高亮结果）。
///
/// 顺序进输出（旧实现按 `TRUTH` 的顺序打），所以**顺序是判据的一部分**。
fn truth_kinds() -> Array[String] {
  ["keyword", "string", "comment", "number"]
}

///|
/// 关键字表（旧实现在 `TRUTH` 的第一条里，一个字不改）。
fn audit_keywords() -> Array[Array[Char]] {
  let words = [
    "pub", "priv", "fn", "let", "mut", "type", "enum", "struct", "trait", "impl", "match", "if",
    "else", "while", "for", "in", "return", "break", "continue", "guard", "async", "extern", "derive",
    "test", "suberror", "raise", "try", "catch", "throw", "const", "self", "true", "false",
  ]
  words.map(fn(w) { w.to_array() })
}

///|
/// `\w`（JS 的定义：ASCII 字母数字下划线）。
fn is_word_ch(ch : Char) -> Bool {
  (ch.is_ascii_alphabetic() || ch.is_ascii_digit()) || ch == '_'
}

///|
/// 一个匹配：`[start, end)`（**按字符**，与 `runs` 拼出来的 `colored` 同一套下标）。
pub struct Hit {
  start : Int
  end : Int
}

///|
/// `\b(kw1|kw2|…)\b` 的 `/g` 语义：从左到右，每次取**最左**的一个，匹配后从它后面继续。
///
/// ⚠️ 两个 `\b` 都要（前面不是词字符、后面也不是）—— 少了任何一个，`in` 会在 `print` 里命中。
fn matches_keyword(cs : Array[Char], kws : Array[Array[Char]]) -> Array[Hit] {
  let out : Array[Hit] = []
  let n = cs.length()
  let mut i = 0
  while i < n {
    if i > 0 && is_word_ch(cs[i - 1]) {
      i = i + 1
      continue
    }
    let mut found = 0
    for k in kws {
      let kl = k.length()
      if found == 0 && i + kl <= n {
        let mut same = true
        let mut j = 0
        while j < kl {
          if cs[i + j] != k[j] {
            same = false
            break
          }
          j = j + 1
        }
        // 尾巴也得是边界
        if same && (i + kl == n || !is_word_ch(cs[i + kl])) {
          found = kl
        }
      }
    }
    if found > 0 {
      out.push({ start: i, end: i + found })
      i = i + found
    } else {
      i = i + 1
    }
  }
  out
}

///|
/// `"(?:[^"\\\n]|\\.)*"` —— 一对引号里的字符串（**跨行不算**：`.`
/// 不匹配换行，所以 `\` 后面跟换行也不算转义）。
fn matches_string(cs : Array[Char]) -> Array[Hit] {
  let out : Array[Hit] = []
  let n = cs.length()
  let mut i = 0
  while i < n {
    if cs[i] != '"' {
      i = i + 1
      continue
    }
    let mut j = i + 1
    let mut closed = -1
    while j < n {
      let ch = cs[j]
      if ch == '\\' {
        // `\\.`：反斜杠 + 一个**非换行**字符
        if j + 1 < n && cs[j + 1] != '\n' {
          j = j + 2
          continue
        }
        break
      }
      if ch == '"' {
        closed = j
        break
      }
      if ch == '\n' {
        break
      }
      j = j + 1
    }
    if closed >= 0 {
      out.push({ start: i, end: closed + 1 })
      i = closed + 1
    } else {
      i = i + 1
    }
  }
  out
}

///|
/// `\/\/[^\n]*|#[^\n]*` —— 行注释：`//` 或 `#` 起，到行尾（不含换行）。
///
/// ⚠️ `#` 那一条**不问上下文**（旧实现的正则就是这样）—— 所以 JS 字符串里的 `#`
/// 也会被当成注释。这是**刻意照抄**：口径一改，"召回率"这个数就不再是同一条了。
fn matches_comment(cs : Array[Char]) -> Array[Hit] {
  let out : Array[Hit] = []
  let n = cs.length()
  let mut i = 0
  while i < n {
    let is_slash = i + 1 < n && cs[i] == '/' && cs[i + 1] == '/'
    if is_slash || cs[i] == '#' {
      let start = i
      if is_slash {
        i = i + 2
      } else {
        i = i + 1
      }
      while i < n && cs[i] != '\n' {
        i = i + 1
      }
      out.push({ start, end: i })
    } else {
      i = i + 1
    }
  }
  out
}

///|
/// `(?<![\w.])\d+(?:\.\d+)?(?![\w.])` —— 一个数字（前面不是词字符或点、后面也不是）。
fn matches_number(cs : Array[Char]) -> Array[Hit] {
  let out : Array[Hit] = []
  let n = cs.length()
  let mut i = 0
  while i < n {
    if !cs[i].is_ascii_digit() {
      i = i + 1
      continue
    }
    if i > 0 && (is_word_ch(cs[i - 1]) || cs[i - 1] == '.') {
      i = i + 1
      continue
    }
    let mut j = i
    while j < n && cs[j].is_ascii_digit() {
      j = j + 1
    }
    // 可选的小数部分：点**后面还得有数字**才算
    if j + 1 < n && cs[j] == '.' && cs[j + 1].is_ascii_digit() {
      j = j + 1
      while j < n && cs[j].is_ascii_digit() {
        j = j + 1
      }
    }
    // 尾巴不能是词字符或点
    if j < n && (is_word_ch(cs[j]) || cs[j] == '.') {
      i = i + 1
      continue
    }
    out.push({ start: i, end: j })
    i = j
  }
  out
}

///|
