///|
/// **语料侧的读数** —— 站点判据要拿"内容源应该是什么样"去核对"渲染出来是什么样"。
///
/// 这一层是 `lib/verify-site.mjs` 那几段（`plain` / `pickProbe` / `fencedBlocks` /
/// `readSource` / frontmatter 取值）的**逐条搬运**。
///
/// ⚠️ **为什么照搬而不是改成调 `engine/content`**：断言比的是"页面上那段字"，
///    而"从源里挑哪一句当探针"决定了断言**比的是不是同一句**。引擎那边（`read_home` / `parse_blocks`）
///    产的是**另一套形状**（`SectionLit` 的 `title` 是 `Array[Span]`、探针不落盘），
///    硬映射过去会悄悄换掉被比较的字符串 ⇒ 判据的**含义**变了而没人看得出来。
///    所以这一层保持"取法与旧实现逐字一致"；唯一用引擎的地方是纯链接节的**目标解析**
///    （见 `docs.mbt` 的 `resolve_link_target`：那一条旧实现自己都写了"要跟引擎同一套"）。
///
/// ⚠️ **下标口径**：JS 的字符串下标是 **UTF-16 码元**。MoonBit 的 `String[i]` 给的也是码元
///    （`UInt16`），但那样每个判定都要跟 `UInt16` 打交道；所以这里统一转成 `Array[Char]`
///    再扫 —— 两头都在同一套下标里，切出来的子串与 JS **逐字节相同**。
///    唯一**不能**用 `chars.length()` 的地方是"探针够不够长"（JS 数的是码元，
///    非 BMP 字符算 2）⇒ 那种比较一律走 `utf16_len`。

///|
/// 字符串 → 字符数组（扫描用）。
fn chars_of(s : String) -> Array[Char] {
  s.to_array()
}

///|
/// **UTF-16 码元数**（= JS 的 `s.length`）。非 BMP 字符算 2。
///
/// ⚠️ 探针长度的阈值（`>= 24` / `>= 30`）就是按这个数的 —— 用 `chars.length()` 会在
///    带 emoji 的行上悄悄换掉"哪一句被选中"。
pub fn utf16_len(s : String) -> Int {
  let mut n = 0
  for ch in s {
    n = n + (if ch.to_int() > 0xFFFF { 2 } else { 1 })
  }
  n
}

///|
/// JS `\s`（够我们用的那一档）：空格 / `\t` / `\n` / `\r` / `\v` / `\f` / 不换行空格 / 全角空格。
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u{0b}' || c == '\u{0c}' ||
  c == '\u{00a0}' || c == '\u{3000}'
}

///|
/// JS 的 `\s`：空白一律压成一个空格，两端去掉。
///
/// ⚠️ 判据里"两边都归一化"全靠它 —— 页面的 `innerText` 会把换行与缩进压成空格，
///    而源里的段落是整行文本。**不归一化就会永远找不到**（不是"宽松"，是"对不上"）。
pub fn norm(s : String) -> String {
  let out : Array[String] = []
  let mut pending = false
  for ch in s {
    if is_space(ch) {
      pending = out.length() > 0
      continue
    }
    if pending {
      out.push(" ")
      pending = false
    }
    out.push(ch.to_string())
  }
  out.join("")
}

///|
/// 两端去空白（用**同一套** `is_space`，不借 `String::trim` —— 它认的集合不保证一致）。
fn trim_ws(s : String) -> String {
  let c = chars_of(s)
  let mut a = 0
  let mut b = c.length()
  while a < b && is_space(c[a]) {
    a = a + 1
  }
  while b > a && is_space(c[b - 1]) {
    b = b - 1
  }
  @content.slice(c, a, b)
}

///|
/// 按行切（保留空行）。
pub fn lines_of(s : String) -> Array[String] {
  s.split("\n").map(fn(l) { l.to_owned() }).collect()
}

///|
/// `^[#>|`]` —— 标题 / 引用 / 表格 / 围栏起头。
fn is_struct_head(t : String) -> Bool {
  let c = chars_of(t)
  if c.length() == 0 {
    return false
  }
  let h = c[0]
  h == '#' || h == '>' || h == '|' || h == '`'
}

///|
/// `^[-*]\s` —— 无序列表项。
fn is_bullet(t : String) -> Bool {
  let c = chars_of(t)
  if c.length() < 2 {
    return false
  }
  (c[0] == '-' || c[0] == '*') && is_space(c[1])
}

///|
/// `^\d+[.)]\s` —— 有序列表项。
fn is_ordered(t : String) -> Bool {
  let c = chars_of(t)
  let mut i = 0
  while i < c.length() && c[i].is_ascii_digit() {
    i = i + 1
  }
  if i == 0 || i + 1 >= c.length() {
    return false
  }
  (c[i] == '.' || c[i] == ')') && is_space(c[i + 1])
}

///|
/// 这一行是不是"不能当探针"的结构行（标题 / 表格 / 代码 / 引用 / 列表 / 空行）。
fn skip_probe_line(t : String) -> Bool {
  t == "" || is_struct_head(t) || is_bullet(t) || is_ordered(t)
}

///|
/// 读内容源：**先剥掉 frontmatter**（那是给注册表看的，不是正文）。
///
/// ⚠️ 边角照抄旧实现（`indexOf` 返回 -1 时 `slice(0, -1)` 会**切掉最后一个字符**）——
///    合法内容上走不到，但"我改得更合理"就等于把对照物的口径换了。
/// ⚠️ MoonBit 的 `String::find` **没有起始下标参数** ⇒ 从起点切一段再找、再加回偏移。
pub fn read_source(text : String) -> String {
  if !text.has_prefix("---") {
    return text
  }
  match text[3:].find("\n---") {
    Some(rel) => {
      let end = rel + 3
      match text[end + 1:].find("\n") {
        Some(rel2) => text[end + 2 + rel2:].to_owned()
        None => text
      }
    }
    None => text
  }
}

///|
/// frontmatter 那一段（`text.slice(0, text.indexOf("\n---", 4))`）—— 只在里面找键。
pub fn frontmatter_slice(text : String) -> String {
  if text.length() <= 4 {
    return text
  }
  match text[4:].find("\n---") {
    Some(rel) => text[:rel + 4].to_owned()
    None =>
      if text.length() == 0 {
        text
      } else {
        text[:text.length() - 1].to_owned()
      }
  }
}

///|
/// frontmatter 里 `^<key>:\s*(.*)$`（多行模式 = 只看行首）的第一处取值，trim 过。
///
/// ⚠️ `.*` **不吃换行** ⇒ 只取本行剩下的部分。
pub fn fm_value(text : String, key : String) -> String {
  for raw in lines_of(text) {
    if raw.has_prefix(key + ":") {
      return trim_ws(raw[(key.length() + 1):].to_owned())
    }
  }
  ""
}

///|
/// 围栏语言标识允许的字符（`[a-zA-Z0-9+#-]`）。
fn is_lang_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '+' || c == '#' || c == '-'
}

///|
/// 一份 markdown 里**所有围栏代码块的正文**（`/```[a-zA-Z0-9+#-]*\n([\s\S]*?)```/g`）。
///
/// ⚠️ 语言标识只认 `[a-zA-Z0-9+#-]`、**不认空格** ⇒ ```` ``` moonbit ````（标识前有空格）
///    这条正则**根本不匹配**。照抄这个"抠门"：它决定了"这份 skill 里算不算有代码块"。
/// ⚠️ 每块结尾的那个换行要**去掉一个**（`replace(/\n$/,"")`）；匹配完从收尾围栏之后继续
///    （所以不会重叠）。
pub fn fenced_blocks(text : String) -> Array[String] {
  let cs = chars_of(text)
  let out : Array[String] = []
  let n = cs.length()
  let mut i = 0
  while i + 2 < n {
    if !(cs[i] == '`' && cs[i + 1] == '`' && cs[i + 2] == '`') {
      i = i + 1
      continue
    }
    let mut j = i + 3
    while j < n && is_lang_char(cs[j]) {
      j = j + 1
    }
    if j >= n || cs[j] != '\n' {
      i = i + 1
      continue
    }
    let body_start = j + 1
    let mut k = body_start
    let mut close = -1
    while k + 2 < n {
      if cs[k] == '`' && cs[k + 1] == '`' && cs[k + 2] == '`' {
        close = k
        break
      }
      k = k + 1
    }
    if close < 0 {
      break
    }
    let mut body = @content.slice(cs, body_start, close)
    if body.has_suffix("\n") {
      body = body[:body.length() - 1].to_owned()
    }
    out.push(body)
    i = close + 3
  }
  out
}

///|
/// 从一份**内容源**里取一句"够长的正文行"当探针（纯链接节那条判据用）。
///
/// 跳过标题 / 表格 / 代码 / 引用 / 列表 / 围栏内部，取第一句长度够的普通段落 ——
/// 它一定是"渲染出来能看见的字"，于是能同时验"跳对了页"与"渲染的是这份文件"。
pub fn pick_probe(md : String) -> String {
  let mut in_fence = false
  for raw in lines_of(md) {
    let t = trim_ws(raw)
    if t.has_prefix("```") {
      in_fence = !in_fence
      continue
    }
    if in_fence {
      continue
    }
    if skip_probe_line(t) {
      continue
    }
    let p = plain(t)
    if utf16_len(p) >= 24 {
      return p
    }
  }
  ""
}

///|
/// 一个子页的探针：名字 + 一句话（用来断言"点子页后正文换成它"）。
pub struct KidProbe {
  name : String
  probe : String
}

///|
/// 书架上的一份 skill（旧实现 `docs()` 的读数）。
pub struct Doc {
  slug : String
  when : String
  desc : String
  kids : Array[KidProbe]
}

///|
/// 首页的一栏：栏名 + 探针句 + 纯链接目标（不是纯链接节就给空串）。
pub struct Sec {
  label : String
  probe : String
  link : String
}
