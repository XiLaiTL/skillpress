///|
/// **native（本机）宿主**：门与脚手架要的"磁盘 / 终端"那一面。
///
/// 与 `engine/gates/js/host.mbt` 对称 —— `Host` 当初就是按"换 target 只换这一份"设计的
/// （见它的文件头）。三条 MoonBit 侧拿不到的能力走 `host.c`：`cwd` / `is_tty` / `read_line`；
/// 其余走 `moonbitlang/x` 的 `@fs` / `@path`。
///
/// ⚠️ 这个包是 **native 专有**的，而且**只能被 native 的东西依赖**：moon 今天没有条件 import
///    （实测），所以"哪个 target 用哪份宿主"这件事只能在**可执行件**那一层分叉（P10 记着这件事）。
///
/// ⚠️ 语义要与 js 宿主**同一套**（否则两个 target 的诊断/行为会漂）：
///   · 读不到文件 ⇒ 空串（不是抛）；列不到目录 ⇒ 空表；
///   · `write` 失败也吞掉（紧接着的读会暴露它，与 js 那条一致）；
///   · `read_line` 在管道上把 stdin 读一次再逐行弹（js 宿主同款，见那边的注释）。

///|
pub fn native_host() -> @gates.Host {
  @gates.Host::new(
    fn(p) { @fs.path_exists(p) },
    fn(p) {
      try {
        @fs.is_dir(p)
      } catch {
        _ => false
      }
    },
    fn(p) {
      try {
        @fs.read_file_to_string(p)
      } catch {
        _ => ""
      }
    },
    fn(p) {
      try {
        @fs.read_dir(p).to_owned()
      } catch {
        _ => []
      }
    },
    fn(p) { @path.Path::resolve(@path.Path(p)).to_string() },
    fn(p, t) {
      try {
        @fs.write_string_to_file(p, t)
      } catch {
        _ => ()
      }
    },
    fn() { cwd() },
    fn(p) { mkdir_p(p) },
    fn() { is_tty() },
    fn(prompt) { read_line(prompt) },
  )
}

///|
/// 一个路径的上一级（只按分隔符切，与 `cmd/skillpress/cli/cli.mbt` 的 `parent_dir` 同口径）。
fn parent_of(p : String) -> String {
  let mut s = p
  while s.length() > 1 && (s.has_suffix("/") || s.has_suffix("\\")) {
    s = s[:s.length() - 1].to_owned()
  }
  // Windows 盘根（`D:` / `D:\`）：没有上一级
  if s.length() == 2 && s[1:2] == ":" {
    return ""
  }
  let cut = match s.rev_find("/") {
    Some(i) => i
    None =>
      match s.rev_find("\\") {
        Some(i) => i
        None => 0
      }
  }
  if cut == 0 {
    ""
  } else {
    s[:cut].to_owned()
  }
}

///|
/// 递归建目录（**已经存在也算成功** —— 脚手架跑第二遍不该因为"目录已经在了"而红）。
fn mkdir_p(p : String) -> Unit {
  if p == "" {
    return
  }
  if @fs.path_exists(p) {
    return
  }
  let parent = parent_of(p)
  if parent != "" {
    mkdir_p(parent)
  }
  try {
    @fs.create_dir(p)
  } catch {
    _ => ()
  }
}

///|
/// 把 stdout / stderr 切到**二进制模式**（Windows 上文本模式会把换行符翻成 CRLF）。
///
/// 为什么必须有：生成物要**逐字节**与 js 那条相同（Node 那边输出的就是单个换行），
/// 而且仓里的 G2 要求文件一律 LF。实测：不调它的时候，native 的 `gen-file` 产物整份都是 CRLF。
pub fn set_binary_stdio() -> Unit {
  sp_set_binary_stdio()
}

///|
/// 当前工作目录（拿不到给空串）。
fn cwd() -> String {
  sp_cwd()
}

///|
/// stdin 是不是终端。
fn is_tty() -> Bool {
  sp_is_tty() != 0
}

///|
/// 问一句、读一行（提问走 stderr；EOF / 读不到给空串 = "用默认值"）。
fn read_line(prompt : String) -> String {
  sp_read_line(prompt)
}

///|
extern "c" fn sp_set_binary_stdio() -> Unit = "sp_set_binary_stdio"

///|
extern "c" fn sp_cwd() -> String = "sp_cwd"

///|
extern "c" fn sp_is_tty() -> Int = "sp_is_tty"

///|
#borrow(prompt)
extern "c" fn sp_read_line(prompt : String) -> String = "sp_read_line"
