///|
/// **宿主能力**：门要看的四件事（存不存在、是不是目录、读文件、列目录项），
/// 加上写侧与被问侧的三件事（建目录、问人、读一行答案）—— 后三件是**脚手架 `attach`** 要的。
///
/// 为什么做成注入的：门的判据是纯逻辑（哪条 token 算路径、命令里引用了哪个脚本…），
/// 而"磁盘上有没有"是运行时的事。分开之后：
///   · 纯逻辑可以在 `moon test` 里用**假宿主**喂夹具（不需要真文件）；
///   · 真宿主只有 js 一份（`engine/gates/js/host.mbt`），将来换 target 只换那一份。
///
/// ⚠️ 加 `mkdir_p` / `is_tty` / `read_line` 时**没有另起一个"脚手架宿主"**：那样磁盘与终端
///    就有两套抽象，而"同一个目录存不存在"两个答案的那天，没人知道该信哪个。
///    代价照实说：这一包从此不只有"门要读的东西"，注释也跟着改了（原先写的是"只有四件事"）。
pub struct Host {
  /// 路径存不存在（文件或目录都算）。
  exists : (String) -> Bool
  /// 是不是目录（不存在给 false）。
  is_dir : (String) -> Bool
  /// 读文本；**读不到给空串**（旧实现是 try/catch 吞掉 —— 这里同口径，由调用方判"空是不是真的空"）。
  read : (String) -> String
  /// 列目录项名（**不排序**：旧实现在这些门里用的是 `readdirSync` 的原始顺序，
  /// 只有 `references/` 那里显式排过序 —— 顺序也是判据的一部分）。
  read_dir : (String) -> Array[String]
  /// 按宿主的规矩把一个路径**规范化成绝对路径**（js：`path.resolve`）。
  /// ⚠️ 这条不是装饰：锁文件里记的 `root` 就是绝对路径，而它**必须与旧实现写的那份逐字符一样**
  /// （Windows 上是反斜杠）—— 否则"这条锁记录属不属于当前内容根"会判错，G8 的输出就变了。
  resolve : (String) -> String
  /// 写文件（G8 的 `--update-lock` 用；验证不会碰真锁）。
  write : (String, String) -> Unit
  /// 当前工作目录（`display_path` 的最后兜底要用）。
  cwd : () -> String
  /// **递归建目录**（脚手架要写 `skills/skillpress/scripts/.skillpress/…` 这种多层新路径）。
  /// 已经存在就当成功（幂等：`attach` 跑第二遍不该因为"目录已经在了"而红）。
  mkdir_p : (String) -> Unit
  /// stdin 是不是**终端**。脚手架的交互式提问只在这条为真时默认开启 ——
  /// 在管道/CI 里默认问人等于**卡死**，而"卡住不返回"比"用默认值并打印一句"难查得多。
  is_tty : () -> Bool
  /// 问一句、读**一行**答案（提问走 stderr；EOF/读不到给空串，由调用方判"空 = 用默认值"）。
  /// ⚠️ 真宿主在**非终端**上把 stdin 整个读进来再按行切 —— 于是"管道喂答案"这条路可以写判据。
  read_line : (String) -> String
}

///|
/// 组装一个宿主（10 个注入点，顺序与字段声明一致）。
/// 有它是因为**跨包不能直接写字面量**，而且"注入点有哪几个"应该只有一处答案。
pub fn Host::new(
  exists : (String) -> Bool,
  is_dir : (String) -> Bool,
  read : (String) -> String,
  read_dir : (String) -> Array[String],
  resolve : (String) -> String,
  write : (String, String) -> Unit,
  cwd : () -> String,
  mkdir_p : (String) -> Unit,
  is_tty : () -> Bool,
  read_line : (String) -> String,
) -> Host {
  { exists, is_dir, read, read_dir, resolve, write, cwd, mkdir_p, is_tty, read_line }
}

///|
/// 字段的**方法壳**：MoonBit 里 `host.read(p)` 会当成方法调用解析（`host.read` 只当值用），
/// 所以每个注入点配一个同名方法 —— 否则每个调用点都得写成 `(host.read)(p)`。
/// 注意：`host.read`（不带括号）= 取函数值；`host.read(p)` = 调这个方法。
pub fn Host::exists(self : Host, p : String) -> Bool {
  (self.exists)(p)
}

///|
pub fn Host::is_dir(self : Host, p : String) -> Bool {
  (self.is_dir)(p)
}

///|
pub fn Host::read(self : Host, p : String) -> String {
  (self.read)(p)
}

///|
pub fn Host::read_dir(self : Host, d : String) -> Array[String] {
  (self.read_dir)(d)
}

///|
pub fn Host::resolve(self : Host, p : String) -> String {
  (self.resolve)(p)
}

///|
pub fn Host::write(self : Host, p : String, text : String) -> Unit {
  (self.write)(p, text)
}

///|
pub fn Host::cwd(self : Host) -> String {
  (self.cwd)()
}

///|
pub fn Host::mkdir_p(self : Host, p : String) -> Unit {
  (self.mkdir_p)(p)
}

///|
pub fn Host::is_tty(self : Host) -> Bool {
  (self.is_tty)()
}

///|
pub fn Host::read_line(self : Host, prompt : String) -> String {
  (self.read_line)(prompt)
}

///|
/// 用 `/` 拼路径。js 的 fs 认正斜杠（Windows 上也认）；"绝对路径长什么样"由 `resolve` 说了算。
pub fn join_path(a : String, b : String) -> String {
  if a == "" {
    return b
  }
  let last = a[a.length() - 1:]
  if last == "/" || last == "\\" {
    a + b
  } else {
    a + "/" + b
  }
}

///|
/// 正斜杠化的路径（报错信息里用；旧实现是 `split("\\").join("/")`）。
pub fn to_slash(p : String) -> String {
  let mut out = ""
  for ch in p {
    // ⚠️ 反斜杠在 MoonBit 字符字面量里必须写 `'\\'`（写 `'\'` 是词法错误）
    out = out + (if ch == '\\' { "/" } else { ch.to_string() })
  }
  out
}

///|
/// **打印用的路径**（旧实现 `displayPath`）：先相对内容仓根、再相对程序根，都不在就相对 cwd。
/// ⚠️ 旧实现排除了"算出来是绝对路径"的情况（跨盘时 `relative` 会给绝对路径）——
/// 这里用"前缀是否匹配"表达同一件事。
pub fn display_path(host : Host, bases : Array[String], abs : String) -> String {
  let a = to_slash(abs)
  for base in bases {
    let b = to_slash(base)
    if b == "" || a == b {
      continue
    }
    if a.has_prefix(b + "/") {
      return a[b.length() + 1:].to_owned()
    }
  }
  let cwd = to_slash(host.cwd())
  if cwd != "" && a.has_prefix(cwd + "/") {
    return a[cwd.length() + 1:].to_owned()
  }
  a
}
