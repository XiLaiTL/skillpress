///|
/// **native 可执行件**：与 `cmd/skillpress`（js）对称的那一份 —— 这就是"使用者零 Node"的落点。
///
/// 它做三件事：
///   1. 接上 **native 宿主**（`engine/gates/native`：`moonbitlang/x` + 60 行 C）；
///   2. 把"程序根提示"递进去 —— js 那份来自引导层，**native 没有引导层**，
///      所以这一份从 `SKILLPRESS_PROGRAM` 环境变量拿（拿不到就是空串，`--program` 参数仍然优先）；
///   3. 收摊时用 `content.exit_code()` 退出 —— native 上没有 `process.exitCode`，
///      而**中途 exit 会把还在跑的事截断**，所以只在最后退一次。
///
/// ⚠️ 与 js 那份的**行为必须一字不差**：文件系统 / 终端那两面的语义由宿主保证
///    （见 `engine/gates/native/host.mbt` 的文件头），其余全是同一个 `cli` 包的代码。
///    P10 的判据就是拿这两份产物对同一份语料逐字节比。
async fn main {
  let args = @env.args()
  // ── `verify` / `dump-corpus`：**只有 native 这一份有** ─────────────────────────
  // 站点判据要 async 的 http server / websocket / process，而它们在 `moonbitlang/async` 的
  // **js 目标上没有实现**（那些文件只编 native/wasm）⇒ 那两个子命令住在 `engine/site`
  // （native-only 的库，见它的 `moon.pkg`）。**分发必须落在可执行件这一层**：
  // moon 没有条件 import，而共享的 `cmd/skillpress/cli` 是 `+js +native` 的，它 import 不了这个库。
  // （js 那份 CLI 遇到 `verify` 会**明说"只有 native 有"并退 2** —— 不许静默当成"没这个命令"。）
  let mut site_cmd = false
  for a in args {
    if a == "verify" || a == "dump-corpus" || a == "--dump-corpus" {
      site_cmd = true
    }
  }
  if site_cmd {
    @site.run(args)
    return
  }
  // ⚠️ 第一件事：把 stdout/stderr 切到二进制模式 —— 不切的话 Windows 会把换行翻成 CRLF，
  //    而生成物要逐字节等于 js 那条（Node 输出的就是单个换行），G2 也要求文件一律 LF。
  @gnative.set_binary_stdio()
  @cli.run(@gnative.native_host(), program_hint())
  let code = @content.exit_code()
  if code != 0 {
    @sys.exit(code)
  }
}

///|
/// 程序根提示：js 那份由引导层给（`globalThis.__skillpress_ts.root`）；native 这边
/// 没有引导层可问 —— 由使用者用环境变量给：
///
/// ```bash
/// SKILLPRESS_PROGRAM=<项目>/.mooncakes/XiLaiTL/skillpress skillpress check --skills ./skills
/// ```
///
/// ⚠️ **不猜**：`moon install` 把可执行件装到 `~/.moon/bin/`，那里**没有**程序的数据
///    （`claims.txt` / `skills.lock.json` / `template/`），拿可执行件的位置去反推程序根只会得到一个
///    绕远的错答案。给不出提示时仍旧优先 `--program` 参数、最后退回 cwd（与 js 那条一致）。
fn program_hint() -> String {
  match @sys.get_env_var("SKILLPRESS_PROGRAM") {
    Some(v) => v
    None => ""
  }
}
