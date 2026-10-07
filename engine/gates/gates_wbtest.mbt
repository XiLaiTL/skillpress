///|
/// **门自己的证伪** —— 每条判据都要有一个"必须被点名"的诱饵。
///
/// 假宿主的两条理由：
///   · 诱饵是**故意的坏**（缺 frontmatter、死路径、CRLF…），不该往磁盘上写这些脏东西；
///   · 门是纯逻辑，用内存树跑得快，而且**测试自己就能造出旧实现造不出的边界**
///     （比如"代码块第一行是空行"——那一处曾经真的判少一行）。
///
/// 诱饵名单与旧实现 `lib/check.mjs --selftest` 的 14 条**一一对应**（编号见下）。
/// 两条例外：`bad-api`（G5）与 `bad-section`（G6）**没搬**（PLAN D18 → 内容仓自己），
/// 所以这里没有它们的位置 —— 缺的是判据，不是测试。

///|
/// 内存文件树 → 宿主。`dirs` 给出"某个目录下有哪些直接子项"，**顺序原样保留**
/// （真实宿主的 `readdirSync` 也不排序，顺序是输出的一部分）。
fn mk_host(files : Array[(String, String)], dirs : Array[(String, Array[String])]) -> Host {
  let fm : Map[String, String] = Map([])
  for p in files {
    fm.set(p.0, p.1)
  }
  let dm : Map[String, Array[String]] = Map([])
  for d in dirs {
    dm.set(d.0, d.1)
  }
  Host::new(
    fn(p) { fm.contains(p) || dm.contains(p) },
    fn(p) { dm.contains(p) },
    fn(p) {
      match fm.get(p) {
        Some(v) => v
        None => ""
      }
    },
    fn(p) {
      match dm.get(p) {
        Some(v) => v
        None => []
      }
    },
    fn(p) { p },
    fn(_p, _t) { () },
    fn() { "/fake/cwd" },
    // 脚手架那三件：假宿主上"建目录"是空操作（内存树里没有真目录）、
    // **不是终端**（默认不问人）、**没有答案**（每次给空串 ⇒ 走默认值那条路）。
    // ⚠️ 这三条是**门用不到**的注入点，所以这里给的是最笨的合法值，不是"门的假数据"。
    fn(_p) { () },
    fn() { false },
    fn(_prompt) { "" },
  )
}

///|
let fake_repo = "/fake/moobile"

///|
let fake_program = "/fake/program"

///|
let fake_skills = "/fake/moobile/skills"

///|
/// 组装一次判定用的上下文（默认：空禁语表、空索引）。
fn mk_ctx(files : Array[(String, String)], dirs : Array[(String, Array[String])]) -> Ctx {
  {
    host: mk_host(files, dirs),
    roots: [fake_repo, fake_program],
    skills_dir: fake_skills,
    claims: [],
    index: { files: 0, names: [] },
  }
}

///|
/// 合法 frontmatter 的壳（旧实现 `selftest` 里那个 `fm()`）。
fn fm_of(name : String) -> String {
  "---\nname: " + name + "\ndescription: d\nwhenToUse: w\n---\n\n"
}

///|
/// 有没有哪条判据以 `p` 开头（旧实现是用正则"命中"来判的，这里等价）。
fn hit(fails : Array[String], p : String) -> Bool {
  for f in fails {
    if f.has_prefix(p) {
      return true
    }
  }
  false
}

///|
/// `Frontmatter?` 是不是 `Some`。
fn is_some_fm(f : Frontmatter?) -> Bool {
  match f {
    Some(_) => true
    None => false
  }
}

///|
/// 一个"标准环境"：内容仓根下只有两个**存在的**真引用（`docs/STATUS.md`、`tools/verify_all.sh`），
/// 别的路径一律不存在 —— G3 / G4 的诱饵靠的就是"其余都不存在"。
fn env_ok() -> Ctx {
  mk_ctx(
    [("/fake/moobile/docs/STATUS.md", "x"), ("/fake/moobile/tools/verify_all.sh", "x")],
    [],
  )
}

///|
/// 正例：**不许误杀**。这是与诱饵同等重要的一半 —— 门报红很便宜，
/// 但误杀会让人去删真引用（旧实现的注释原话：误杀比漏报更伤）。
test "正例 good 不被误杀（含 G3/G4 真引用）" {
  let ctx = env_ok()
  let text = fm_of("good") +
    "见 `docs/STATUS.md`，也见 `CONTRIBUTING.md`（没有斜杠 ⇒ 不当路径）。\n\n```bash\nbash tools/verify_all.sh\n```\n"
  let r = judge(ctx, text, "good", "skill")
  assert_eq(r.fails.length(), 0)
  assert_eq(r.notes.length(), 0)
}

///|
/// 诱饵 1 —— G1：`name` 与目录名不一致。
test "诱饵 name-mismatch：G1 点名" {
  let r = judge(env_ok(), fm_of("别的名字") + "正文\n", "name-mismatch", "skill")
  assert_true(hit(r.fails, "G1"))
}

///|
/// 诱饵 2 —— G1：少一个必需字段（`whenToUse`）。
test "诱饵 missing-field：G1 点名" {
  let r = judge(env_ok(), "---\nname: missing-field\ndescription: d\n---\n\n正文\n", "missing-field", "skill")
  assert_eq(r.fails, ["G1 frontmatter 缺 whenToUse"])
}

///|
/// 诱饵 3 —— G1：整份 frontmatter 缺失。
test "诱饵 no-frontmatter：G1 点名" {
  let r = judge(env_ok(), "# 没有 frontmatter\n", "no-frontmatter", "skill")
  assert_eq(r.fails, ["G1 frontmatter 缺失或未闭合（必须是文件开头的 --- … ---）"])
}

///|
/// 诱饵 4 —— G2：体量超行数。
test "诱饵 too-big：G2 点名" {
  let mut body = ""
  for _i = 0; _i < 410; _i = _i + 1 {
    body = body + "填充\n"
  }
  let r = judge(env_ok(), fm_of("too-big") + body, "too-big", "skill")
  assert_true(hit(r.fails, "G2 体量"))
}

///|
/// 诱饵 5 —— G2：代码块超 15 行。
test "诱饵 big-codeblock：G2 点名" {
  let mut code = ""
  for _i = 0; _i < 17; _i = _i + 1 {
    code = code + "x\n"
  }
  let r = judge(env_ok(), fm_of("big-codeblock") + "```moonbit\n" + code + "```\n", "big-codeblock", "skill")
  assert_eq(r.fails, ["G2 代码块 17 行 > 15 行（长示例指向 examples/apps/**）"])
}

///|
/// **边界（旧实现的诱饵里没有这一条）**：代码块的**第一行就是空行**时，
/// 行数照样要数对 —— 拼接时若把"空串"当"还没拼过"就会少算一行。
test "边界：代码块首行是空行，行数不能少算" {
  let mut code = ""
  for _i = 0; _i < 15; _i = _i + 1 {
    code = code + "\n"
  }
  let r = judge(env_ok(), fm_of("blank-first") + "```moonbit\n" + code + "x\n```\n", "blank-first", "skill")
  assert_eq(r.fails, ["G2 代码块 16 行 > 15 行（长示例指向 examples/apps/**）"])
}

///|
/// 诱饵 6/7/8 —— G3：三种"查不到"的路径（内容仓里没有的 docs、tools，以及程序根里没有的 bin）。
test "诱饵 bad-path / bad-path-skillpress / bad-program-path：G3 点名" {
  let ctx = env_ok()
  let a = judge(ctx, fm_of("bad-path") + "见 `docs/这份文档不存在.md`\n", "bad-path", "skill")
  assert_eq(a.fails, ["G3 路径不存在：docs/这份文档不存在.md"])
  let b = judge(ctx, fm_of("bad-path-skillpress") + "见 `tools/没有这个工具.mjs`\n", "bad-path-skillpress", "skill")
  assert_eq(b.fails, ["G3 路径不存在：tools/没有这个工具.mjs"])
  let c = judge(ctx, fm_of("bad-program-path") + "见 `bin/没有这个门面.mjs`\n", "bad-program-path", "skill")
  assert_eq(c.fails, ["G3 路径不存在：bin/没有这个门面.mjs"])
}

///|
/// G3 的**宽出**：尾部粘了行文残留（`docs/STATUS.md的补记`）时，
/// 剥掉残留还能查到 ⇒ **只记提示、不判红**。
test "G3 尾部行文残留只提示不判红" {
  let r = judge(env_ok(), fm_of("tail") + "见 `docs/STATUS.md的补记`\n", "tail", "skill")
  assert_eq(r.fails.length(), 0)
  assert_eq(
    r.notes,
    ["G3 提示：`docs/STATUS.md的补记` 尾部有行文残留，建议写成 `docs/STATUS.md`"],
  )
}

///|
/// 诱饵 9 —— G4：命令块里引用的脚本不存在。
test "诱饵 bad-script：G4 点名" {
  let r = judge(env_ok(), fm_of("bad-script") + "```bash\nbash tools/没有这个脚本.sh\n```\n", "bad-script", "skill")
  assert_eq(r.fails, ["G4 命令引用的脚本不存在：tools/没有这个脚本.sh"])
}

///|
/// 诱饵 12 —— G2：CRLF 行尾。
test "诱饵 crlf：G2 点名（并点出几处）" {
  let r = judge(env_ok(), "---\r\nname: crlf\r\n---\r\n\r\n正文\r\n", "crlf", "skill")
  assert_true(hit(r.fails, "G2 行尾含 CR"))
}

///|
/// 诱饵 13 —— G7：禁语；**否定语境要放行**（"还没做到 X"是老实说法）。
test "诱饵 forbidden：G7 点名；否定语境放行" {
  let ctx = { ..env_ok(), claims: ["载荷等价"] }
  let guilty = judge(ctx, fm_of("forbidden") + "已经支持载荷等价\n", "forbidden", "skill")
  assert_eq(guilty.fails, ["G7 出现禁语「载荷等价」（SPEC §6：不许把未做写成已支持）"])
  let passed = judge(ctx, fm_of("forbidden") + "还没做到载荷等价，见 `docs/STATUS.md`\n", "forbidden", "skill")
  assert_eq(passed.fails.length(), 0)
}

///|
/// G1 的"多余字段"是**提示**（注册表读不到），不是红 —— 但文字与顺序要一致。
test "G1 多余字段：提示里逐字点名、顺序照 frontmatter" {
  let text = "---\nname: extra\ndescription: d\nwhenToUse: w\nversion: 1\nlicense: MIT\n---\n\n正文\n"
  let r = judge(env_ok(), text, "extra", "skill")
  assert_eq(r.fails.length(), 0)
  assert_eq(r.notes, ["G1 提示：字段 version, license 注册表不读（可留作打包元数据，见 SPEC §3）"])
}

///|
/// `aux`（`references/**`、`FAQ.md`）**不强制** frontmatter：没有也过。
test "aux 文件没有 frontmatter 也过" {
  let r = judge(env_ok(), "就是一篇没有 frontmatter 的参考文档。\n", "alpha", "aux")
  assert_eq(r.fails.length(), 0)
}

///|
/// `kb` 的格式（`(bytes / 1024).toFixed(1)`）。
test "kb 格式" {
  assert_eq(kb_of(0), "0.0")
  assert_eq(kb_of(768), "0.8")
  assert_eq(kb_of(4462), "4.4")
  assert_eq(kb_of(20480), "20.0")
}

///|
/// frontmatter 的解析口径：CRLF 首行认得出、闭栏是 `\n---`、值两侧同款引号剥掉。
test "frontmatter 解析口径" {
  let (a, body_a) = parse_frontmatter("---\r\nname: x\r\n---\r\n\r\n正文\r\n")
  assert_true(is_some_fm(a))
  // 闭栏那行的 `\n---` 被吃掉 4 个字符 ⇒ 正文从 CRLF 的 `\r` 开始（旧实现 `slice(end + 4)`）
  assert_eq(body_a, "\r\n\r\n正文\r\n")
  let (b, body_b) = parse_frontmatter("---\nname: \"q\"\n---\n正文\n")
  // 闭栏行自己的那个 `\n` 留在正文里（旧实现 `slice(end + 4)`）—— 正文总是以空白行开头
  assert_eq(body_b, "\n正文\n")
  assert_eq(
    match b {
      Some(f) => f.name
      None => None
    },
    Some("q"),
  )
  // 只有一个引号：JS 的 `'"'.slice(1, -1)` 是空串 ⇒ 判成"有但空"
  let (c, _) = parse_frontmatter("---\nname: \"\n---\n正文\n")
  assert_eq(
    match c {
      Some(f) => f.name
      None => None
    },
    Some(""),
  )
  // 没闭栏 ⇒ 整份文本当正文
  let (d, body_d) = parse_frontmatter("---\nname: x\n正文\n")
  assert_eq(is_some_fm(d), false)
  assert_eq(body_d, "---\nname: x\n正文\n")
}
