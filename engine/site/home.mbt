///|
/// **首页（内容源）的读数**：分栏 / 每栏的探针 / 首屏引言段落。
///
/// 切法与 `gen-content.mjs` 的 `readHome()` 同源（旧实现 `homeSections()` / `homeParagraph()`）。

///|
/// `^##\s+(.*)$` —— 二级标题，返回标题正文（`\s+` 全吃、两端 trim 过）。
///
/// ⚠️ `###` **不算**（`#` 后面不是空白）；`##` 后面**必须**有空白。
fn heading2(t : String) -> String? {
  let c = chars_of(t)
  if c.length() < 3 || c[0] != '#' || c[1] != '#' {
    return None
  }
  if !is_space(c[2]) {
    return None
  }
  let mut i = 2
  while i < c.length() && is_space(c[i]) {
    i = i + 1
  }
  Some(trim_ws(@content.slice(c, i, c.length())))
}

///|
/// `^\[([^\]]+)\]\(([^)]+)\)$` —— **整行就是一个链接**（纯链接节的栏位名）。
///
/// ⚠️ 两端都锚定、目标至少一个字符。返回 `(方括号里的名字, 括号里的目标)`。
///
/// ⚠️ 栏位名必须取**方括号里**那部分：`plain()` 会把 `[名字](目标)` 整条剥成空串
///    （它只认行内标记，链路被当标记去掉了）—— 旧实现实测的代价是"纯链接节在顶栏消失"。
fn pure_link_only(t : String) -> (String, String)? {
  let c = chars_of(t)
  let n = c.length()
  if n == 0 || c[0] != '[' {
    return None
  }
  let mut k = 1
  while k < n && c[k] != ']' {
    k = k + 1
  }
  if k >= n || k == 1 || k + 1 >= n || c[k + 1] != '(' {
    return None
  }
  let mut m = k + 2
  while m < n && c[m] != ')' {
    m = m + 1
  }
  // 目标至少一个字符，且 `)` 必须是**整行最后一个字符**（锚定 `$`）
  if m >= n || m == k + 2 || m != n - 1 {
    return None
  }
  Some((@content.slice(c, 1, k), @content.slice(c, k + 2, m)))
}

///|
/// 官网首页：**分栏**（`##` 的标题）+ 每一栏的探针句子。
///
/// ⚠️ 三个"简化了就出假绿"的点，逐条对照旧实现的注释：
///    ① 纯链接节**没有可比对的正文** —— 点它应当**换页**，所以这里只记住目标，
///       判据落在"正文变成目标页的内容"上；
///    ② **围栏里的行不算探针**：代码块里的缩进渲染时原样保留，而探针比较是把空白压成一个空格的
///       ⇒ 拿它当探针会"永远找不到"（旧实现实测踩过）；
///    ③ 一栏只取**第一句**够长的（`probe` 一旦有值就不再改）。
pub fn home_sections(md : String) -> Array[Sec] {
  let out : Array[Sec] = []
  let mut in_fence = false
  let mut cur = -1
  for raw in lines_of(md) {
    let t = trim_ws(raw)
    if t.has_prefix("```") {
      in_fence = !in_fence
      continue
    }
    match heading2(t) {
      Some(rest) => {
        match pure_link_only(rest) {
          Some((name, target)) => {
            out.push({ label: plain(name), probe: "", link: trim_ws(target) })
          }
          None => out.push({ label: plain(rest), probe: "", link: "" })
        }
        cur = out.length() - 1
        continue
      }
      None => ()
    }
    if cur < 0 {
      continue
    }
    if out[cur].probe != "" || out[cur].link != "" {
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
      let s = out[cur]
      out[cur] = { label: s.label, probe: p, link: s.link }
    }
  }
  out
}

///|
/// 首屏的一段"含加粗"的正文 —— 用来断言**行内流**与"首屏真是这份首页源"。
///
/// 只在第一个 `##` 之前找（首屏 = H1 + 引言），因为首屏只渲染这一段。
/// 取法：去掉 markdown 标记后整段文字应当能在**一个** `[dir=auto]` 里原样找到；
/// 而那个元素里还要有嵌套 `span`（= 加粗 / 行内代码与正文在同一行里流）。
/// 片段被铺成兄弟节点（经典 bug）时，**没有任何一个**元素能装下整段。
///
/// ⚠️ 这里**刻意不跟围栏**、也不排除有序列表 —— 与旧实现逐字一致（`homeParagraph()` 里就没有这两条）。
///    "顺手补上"会改变被比较的字符串。
pub fn home_paragraph(md : String) -> String {
  let mut best = ""
  for raw in lines_of(md) {
    let t = trim_ws(raw)
    if heading2(t) is Some(_) {
      break
    }
    if t == "" || is_struct_head(t) || is_bullet(t) {
      continue
    }
    if !t.contains("**") {
      continue
    }
    let p = plain(t)
    if utf16_len(p) >= 30 && (best == "" || utf16_len(p) > utf16_len(best)) {
      best = p
    }
  }
  best
}
