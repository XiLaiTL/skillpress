///|
/// **语料侧读数的转储** —— 给"新解析器 vs 旧实现"的逐字节对账用（`tools/site-corpus-parity.sh`）。
///
/// ⚠️ 为什么要专门做这个：语料侧那几百行是**新写的解析器**（`plain` 的三步行内标记、
///    探针挑选、围栏切分、frontmatter 取值），而它决定了"断言的探针是**哪一句**"。
///    它写错了**不会崩、不会红**，只会让断言比另一句、甚至永远绿。
///    转储 + 逐字节比是唯一能在**没有浏览器**的情况下把这一大块验掉的办法。
///
/// 格式（两边同一套，`\t` 分列；`\` / `\t` / `\n` / `\r` 转义成 `\\` / `\t` / `\n` / `\r`）：
///
///   home-source<TAB><首页源标签>
///   home-para<TAB><首屏那段含加粗的正文>
///   sec<TAB><栏名><TAB><探针><TAB><纯链接目标>
///   doc<TAB><slug><TAB><whenToUse><TAB><description>
///   kid<TAB><slug><TAB><子页名><TAB><子页标题/探针>
///   fenced<TAB><slug><TAB><序号><TAB><代码块正文>
///
/// 顺序是固定的：首页两行 → 全部 `sec` → 逐份 skill 的 `doc` + 它的 `kid` → 逐份 skill 的 `fenced`。
/// ⚠️ 顺序也是判据的一部分（`docs` 用的是码元序排序），所以**两边都别自己再排一次**。

///|
/// 一行化转义（`\` 先转，否则后面的转义会被二次转义）。
fn esc_line(s : String) -> String {
  let out : Array[String] = []
  for ch in s {
    if ch == '\\' {
      out.push("\\\\")
    } else if ch == '\t' {
      out.push("\\t")
    } else if ch == '\n' {
      out.push("\\n")
    } else if ch == '\r' {
      out.push("\\r")
    } else {
      out.push(ch.to_string())
    }
  }
  out.join("")
}

///|
/// 把语料侧的全部读数转成一行一条的文本（**末尾带一个换行**）。
pub fn dump_corpus(
  host : @gates.Host,
  root : String,
  home_label : String,
  home_file : String,
  docs : Array[Doc],
) -> String {
  let out : Array[String] = []
  let home_text = read_source(host.read(home_file))
  out.push("home-source\t" + esc_line(home_label))
  out.push("home-para\t" + esc_line(home_paragraph(home_text)))
  for s in home_sections(home_text) {
    out.push("sec\t" + esc_line(s.label) + "\t" + esc_line(s.probe) + "\t" + esc_line(s.link))
  }
  for d in docs {
    out.push("doc\t" + esc_line(d.slug) + "\t" + esc_line(d.when) + "\t" + esc_line(d.desc))
    for k in d.kids {
      out.push("kid\t" + esc_line(d.slug) + "\t" + esc_line(k.name) + "\t" + esc_line(k.probe))
    }
  }
  for d in docs {
    let f = @gates.join_path(@gates.join_path(root, d.slug), "SKILL.md")
    let mut i = 0
    for b in fenced_blocks(host.read(f)) {
      out.push("fenced\t" + esc_line(d.slug) + "\t" + i.to_string() + "\t" + esc_line(b))
      i = i + 1
    }
  }
  out.join("\n") + "\n"
}
