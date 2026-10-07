///|
/// **js 可执行件**：这一类入口只做两件事 —— 接上 js 那一侧的宿主、把引导层给的程序根递进去，
/// 然后把活儿交给与 target 无关的 `cli` 包。
///
/// ⚠️ 为什么要拆成"薄可执行件 + 共享包"：moon 今天**没有条件 import**（实测，见 P10 第 ⑦ 条）⇒
///    同一个包不能"js 用这一套依赖、native 用另一套"。而 CLI 那 800 行逻辑两个 target 一字不差，
///    所以分叉只放在这一层（native 那一份在 `cmd/skillpress-native/`）。
///
/// ⚠️ 产物路径**必须保持** `_build/js/debug/build/cmd/skillpress/skillpress.js`：
///    `tools/run-js.mjs` 与 `launcher/skillpress.mjs`（随包发的那份启动器）都按这条路径找它。
fn main {
  let args = @env.args()
  // ── `verify` 只有 native 那份有 ⇒ 这里**明说**，不许静默当成"没这个命令" ────────────
  // 站点判据要 async 的 http server / websocket / process，而它们在 `moonbitlang/async` 的
  // **js 目标上没有实现**（那些文件只编 native/wasm，实测过它的 moon.pkg）。所以那个子命令
  // 住在 `engine/site`（native-only 的库），分发落在**可执行件**这一层。
  // ⚠️ 命令词要**扫**出来，不能认 `args[1]`：js 这条路上 argv 前面还挂着
  //    node 与编出来的 `skillpress.js`（`cli.run` 里找命令词也是同一个口径）。
  let mut has_verify = false
  for a in args {
    if a == "verify" {
      has_verify = true
    }
  }
  if has_verify {
    println("✗ verify 只有 native 那份有 —— 站点判据要 async 的 http server / websocket / process，")
    println("  而它们在 moonbitlang/async 的 **js 目标上没有实现**（见 engine/site/moon.pkg 的文件头）。")
    println("  用 native 那支：")
    println("    moon build cmd/skillpress-native --target native")
    println("    ./_build/native/debug/build/cmd/skillpress-native/skillpress-native verify --skills ./skills")
    @content.set_exit_code(2)
    return
  }
  @cli.run(@gjs.js_host(), program_root())
}

///|
/// **引导层给的程序根**（`tools/run-js.mjs` / `launcher/skillpress.mjs` 都会挂上 `root`）。
///
/// 为什么门需要它：指纹锁（`<程序根>/skills.lock.json`）与禁语表（`<程序根>/claims.txt`）都是
/// **跟着程序走**的东西，而 `check` 常常是从**内容仓**里跑的 ⇒ 拿 cwd 当程序根会去内容仓找锁。
/// ⚠️ 拿不到（例如 `moon run engine/gates/dev` 那条路没有引导层）就给空串，调用方退回 cwd。
/// ⚠️ native 那一侧没有引导层 —— 提示改由 `SKILLPRESS_PROGRAM` 环境变量给（见那边的注释）。
extern "js" fn program_root() -> String =
  #|() => (globalThis.__skillpress_ts && globalThis.__skillpress_ts.root) || ""
