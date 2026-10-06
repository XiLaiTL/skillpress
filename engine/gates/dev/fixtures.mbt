///|
/// **对账用的夹具树**（只在开发/对账时写盘，写进 `_build/` —— 那儿是 gitignore 的）。
///
/// 为什么要有它：判据是"与旧实现逐字节一致"，而"一致"只能用**同一棵树跑两遍**来证明。
/// 所以这里造一棵**故意的坏**树：每个 skill 专打一条判据（or 一条注释里说明的偏差），
/// 然后：
///
/// ```bash
/// node _build/js/debug/build/engine/gates/dev/dev.js --emit-fixtures _build/gates-fixtures
/// node lib/check.mjs --repo _build/gates-fixtures > old.txt 2>&1   # 基线（现场生成，不许手抄）
/// node _build/js/debug/build/engine/gates/dev/dev.js --repo _build/gates-fixtures --program . > new.txt 2>&1
/// diff old.txt new.txt
/// ```
///
/// 两条**故意留着**的偏差（G5 / G6，按 PLAN D18 没搬）：`bad-api` 与 `bad-section`
/// 这两份 skill 就是给它们准备的 —— 旧实现会对它们各点一条红，新实现不会。
/// 对账时**应该**在 diff 里看到这两行，别的行不许有差异。

///|
/// 建目录（`--emit-fixtures` 用；门本身不需要写盘能力，所以这条不进 `Host`）。
extern "js" fn mkdir_p_js(p : String) -> Unit =
  #|(p) => { require("node:fs").mkdirSync(p, { recursive: true }); }

///|
/// 路径的父目录。
fn parent_of(p : String) -> String {
  let c = @gates.chars(p)
  let mut i = c.length() - 1
  while i >= 0 {
    if c[i] == '/' {
      return @gates.slice(c, 0, i)
    }
    i = i - 1
  }
  ""
}

///|
/// 写一个文件（顺带建父目录）。
pub fn put(host : @gates.Host, root : String, rel : String, text : String) -> Unit {
  let full = @gates.join_path(root, rel)
  mkdir_p_js(parent_of(full))
  host.write(full, text)
}

///|
/// 重复 `n` 遍。
fn rep(unit : String, n : Int) -> String {
  let mut out = ""
  for _i = 0; _i < n; _i = _i + 1 {
    out = out + unit
  }
  out
}

///|
/// 合法 frontmatter（`name` 就是目录名）。
fn fm_fixture(name : String) -> String {
  "---\nname: " + name + "\ndescription: 对账夹具\nwhenToUse: 只在 gates 对账时用\n---\n\n"
}

///|
/// 造夹具树，返回**写过的相对路径**（顺序是写盘顺序，只用于打印一行确认）。
///
/// `program` 用来现场读 `claims.txt` 的第一条禁语（**不手抄** —— 手抄的夹具迟早与真表分家）。
pub fn emit_fixtures(host : @gates.Host, root : String, program : String) -> Array[String] {
  let written : Array[String] = []
  let put_all = fn(rel : String, text : String) {
    put(host, root, rel, text)
    written.push(rel)
  }
  // 树里"真的存在"的两样东西：G3 / G4 的正例要用（别的路径一律不存在）
  put_all("docs/STATUS.md", "# 夹具里的真文档\n")
  put_all("tools/verify_all.sh", "#!/bin/sh\necho ok\n")
  // 1) 正例：不许误杀
  put_all(
    "skills/ok-good/SKILL.md",
    fm_fixture("ok-good") +
    "见 `docs/STATUS.md`，也见 `CONTRIBUTING.md`（没斜杠 ⇒ 不当路径）。\n\n```bash\nbash tools/verify_all.sh\n```\n",
  )
  // 2) G1：没有 frontmatter
  put_all("skills/bad-frontmatter/SKILL.md", "# 没有 frontmatter 的 skill\n\n正文。\n")
  // 3) G1：name 与目录名不一致
  put_all("skills/bad-name/SKILL.md", fm_fixture("别的名字") + "正文。\n")
  // 4) G1：缺 whenToUse + description 空 + 两个多余字段（多余只提示）
  put_all(
    "skills/bad-fields/SKILL.md",
    "---\nname: bad-fields\ndescription:\nversion: 1\nlicense: MIT\n---\n\n正文。\n",
  )
  // 5) G2：体量超 400 行（正文 + frontmatter）
  put_all("skills/bad-size/SKILL.md", fm_fixture("bad-size") + rep("填充一行。\n", 410))
  // 6) G2：CRLF 行尾
  put_all(
    "skills/bad-crlf/SKILL.md",
    "---\r\nname: bad-crlf\r\ndescription: d\r\nwhenToUse: w\r\n---\r\n\r\n正文。\r\n",
  )
  // 7) G2：代码块 17 行（> 15）
  put_all("skills/bad-codeblock/SKILL.md", fm_fixture("bad-codeblock") + "```moonbit\n" + rep("let x = 1\n", 17) + "```\n")
  // 8) G2：表格 13 行（> 12）
  put_all(
    "skills/bad-table/SKILL.md",
    fm_fixture("bad-table") + "| 列 | 值 |\n" + rep("| a | b |\n", 12) + "\n表后正文。\n",
  )
  // 9) G3：三种查不到（内容仓的 docs / tools、程序根的 bin），外加一处"尾部行文残留"（只提示）
  put_all(
    "skills/bad-path/SKILL.md",
    fm_fixture("bad-path") +
    "见 `docs/没有这份文档.md`、`tools/没有这个工具.mjs`、`bin/没有这个门面.mjs`。\n" +
    "还有一处尾部残留：`docs/STATUS.md的补记`。\n",
  )
  // 10) G4：命令块里引用的脚本不存在
  put_all(
    "skills/bad-script/SKILL.md",
    fm_fixture("bad-script") + "```bash\nbash tools/没有这个脚本.sh\n```\n",
  )
  // 11) G7：禁语表第一条（现场从 claims.txt 读，不许手抄）
  let claims = @gates.load_claims(host, program)
  let phrase = if claims.length() > 0 { claims[0] } else { "载荷等价" }
  put_all("skills/bad-words/SKILL.md", fm_fixture("bad-words") + "已经做到" + phrase + "了。\n")
  // 11b) G7 的否定语境：**不该**被点名
  put_all("skills/ok-negation/SKILL.md", fm_fixture("ok-negation") + "还没做到" + phrase + "，见 `docs/STATUS.md`。\n")
  // 12) 多文件 skill：主文档 + references（**排序**是判据）+ FAQ.md，其中一份 aux 有死路径
  put_all("skills/multi/SKILL.md", fm_fixture("multi") + "见 `docs/STATUS.md`。\n")
  put_all("skills/multi/references/b.md", "# 参考 B\n\n正文。\n")
  put_all("skills/multi/references/a.md", "# 参考 A\n\n见 `docs/没有这份参考.md`。\n")
  put_all("skills/multi/FAQ.md", "# 常见问题\n\n正文。\n")
  // 13) 目录里没有 SKILL.md
  put_all("skills/ghost-dir/README.md", "这个目录没有 SKILL.md。\n")
  // 13b) 排序诱饵：`references/` 必须按 **UTF-16 码元序**（JS `.sort()`）打，
  //      既不是目录顺序、也不是"大小写不敏感"的顺序 —— 所以故意起 `[`、大写、数字开头的名字
  //      （`[`(0x5B) 在码元序里**在** `a`(0x61) 前面，而在大小写不敏感的排序里排在 `A`(0x41) 后面）
  put_all("skills/sorting/SKILL.md", fm_fixture("sorting") + "排序对账用。\n")
  put_all("skills/sorting/references/zz.md", "# zz\n")
  put_all("skills/sorting/references/aa.md", "# aa\n")
  put_all("skills/sorting/references/MM.md", "# MM\n")
  put_all("skills/sorting/references/10.md", "# 10\n")
  put_all("skills/sorting/references/2.md", "# 2\n")
  put_all("skills/sorting/references/[bracket].md", "# bracket\n")
  // 14) **故意留的偏差**：G5（`.mbt` API 对账）与 G6（docs §N）按 D18 没搬
  put_all("skills/bad-api/SKILL.md", fm_fixture("bad-api") + "用 `@html.没这个函数`。\n")
  put_all("skills/bad-section/SKILL.md", fm_fixture("bad-section") + "见 `docs/STATUS.md` §99。\n")
  written
}
