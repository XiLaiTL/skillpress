///|
/// G7 禁语：`claims.txt` 里出现的短语就是"不许把未做写成已支持"。
///
/// ⚠️ 一条**否定语境放行**的规矩（旧实现原话）：命中点**前 4 个字符**里出现
/// `不` / `非` / `别` / `没` 之一就放行 —— 因为"这一条**还没**落地"是老实说法，
/// 而禁语表管的是"把没做的说成已支持"。
///
/// ⚠️ 那个"前 4 个字符"是 **UTF-16 单元**（旧实现是 `body.slice(at - 4, at)`），
/// 不是码点 —— 星平面字符（emoji）占两个单元，混在命中点前面时两种算法会分岔。
pub fn forbidden_fails(body : String, claims : Array[String]) -> Array[String] {
  let fails : Array[String] = []
  let c = chars(body)
  let negation = chars("不非别没")
  for phrase in claims {
    if phrase == "" {
      continue
    }
    let p = chars(phrase)
    let mut at = index_of_from(c, p, 0)
    let mut guilty = false
    while at >= 0 {
      let before = utf16_window_before(c, at, 4)
      let mut negated = false
      for ch in before {
        if negation.contains(ch) {
          negated = true
        }
      }
      if !negated {
        guilty = true
        break
      }
      at = index_of_from(c, p, at + p.length())
    }
    if guilty {
      fails.push("G7 出现禁语「" + phrase + "」（SPEC §6：不许把未做写成已支持）")
    }
  }
  fails
}

///|
/// 读禁语表（`claims.txt`）：逐行 trim、丢掉空行与 `#` 开头的注释行。
pub fn load_claims(host : Host, program_dir : String) -> Array[String] {
  let path = join_path(program_dir, "claims.txt")
  if !host.exists(path) {
    return []
  }
  let out : Array[String] = []
  for raw in split_lines(host.read(path)) {
    let line = trim(raw)
    if line != "" && !line.has_prefix("#") {
      out.push(line)
    }
  }
  out
}
