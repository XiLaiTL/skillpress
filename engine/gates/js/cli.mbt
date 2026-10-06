///|
/// **门这一侧的 CLI 公共件**：参数取值 + 两个根默认值。
///
/// 为什么放在**库**里而不是可执行包（`dev/`）里：`cmd/skillpress` 的 `check` 也要用同一套
/// 默认值（"先找兄弟 `moobile/`，找不到退回往上三层"），而可执行包不能被别人 import。
/// 两处各写一遍，那就是两个会漂的真相 —— 而这两个默认值恰恰决定"查的是谁"。
/// 口径与旧实现 `defaultRepo` / `defaultSkills` 一致（P8.1 逐条对过）。
pub fn arg_value(args : Array[String], key : String) -> String? {
  let mut i = 0
  while i + 1 < args.length() {
    if args[i] == key {
      return Some(args[i + 1])
    }
    i = i + 1
  }
  None
}

///|
/// 默认仓库根（旧实现 `defaultRepo`）：先找兄弟 `moobile/`，找不到退回往上三层。
pub fn default_repo(host : @gates.Host, program : String) -> String {
  let sibling = host.resolve(@gates.join_path(@gates.join_path(program, ".."), "moobile"))
  if host.exists(@gates.join_path(sibling, "skills")) ||
    host.exists(@gates.join_path(sibling, ".agents/skills")) {
    return sibling
  }
  host.resolve(
    @gates.join_path(@gates.join_path(@gates.join_path(program, ".."), ".."), ".."),
  )
}

///|
/// 默认内容根（旧实现 `defaultSkills`）：`<仓库>/skills`，没有才退回老约定。
pub fn default_skills(host : @gates.Host, repo : String) -> String {
  let plain = @gates.join_path(repo, "skills")
  if host.exists(plain) {
    return plain
  }
  let legacy = @gates.join_path(@gates.join_path(repo, ".agents"), "skills")
  if host.exists(legacy) {
    return legacy
  }
  plain
}

///|
/// 进程参数按行切开（`process.argv`；引导层把 CLI 参数原样放在 argv 里）。
pub fn argv_lines() -> String {
  argv_lines_js()
}

///|
extern "js" fn argv_lines_js() -> String =
  #|() => process.argv.join("\n")

///|
/// 退出码（**别用 `process.exit()`**：那会在 wasm 句柄还挂着时强行收摊）。
pub fn set_exit_code(code : Int) -> Unit {
  set_exit_code_js(code)
}

///|
extern "js" fn set_exit_code_js(code : Int) -> Unit =
  #|(code) => { process.exitCode = code }

///|
/// stderr（旧实现那条"找不到根"的错是 `console.error` —— 通道也是判据的一部分）。
pub fn eprintln(text : String) -> Unit {
  eprintln_js(text)
}

///|
extern "js" fn eprintln_js(text : String) -> Unit =
  #|(text) => { process.stderr.write(text + "\n"); }
