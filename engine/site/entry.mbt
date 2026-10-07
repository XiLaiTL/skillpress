///|
/// **站点判据（P8.3）的入口** —— 自起静态服务 + 起无头 Chrome + 走 CDP 跑那 23 条断言。
///
/// ⚠️ 这个包是**库**（不是可执行件）：入口在 **`cmd/skillpress-native`**（`verify` / `dump-corpus`
///    两个子命令），因为分发必须落在可执行件那一层 —— moon 没有条件 import，而共享的
///    `cmd/skillpress/cli` 是 `+js +native` 的，import 不了这个 native-only 的包。
///
/// 用法（先编一次 native）：
///   moon build cmd/skillpress-native --target native
///   <程序根>/_build/native/debug/build/cmd/skillpress-native/skillpress-native ///     verify [--app <站点实例>] [--skills <内容根>] [--repo <仓库根>] [--home <首页源>] [--shot <png>] [--keep]
///   … skillpress-native dump-corpus <内容根> [--repo <仓库根>] [--home <文件>]
///
/// ⚠️ **只能 native**（js 上没有 http server / websocket / process 的 async 实现），
///    而且本机要一段 `win_compat.c`（见 `engine/site/moon.pkg` 的文件头）。
///
/// ⚠️ **收尾必须显式 `@sys.exit`**：`@http.Server::run_forever` 那条后台任务既不随
///    `Server::close()` 返回、也不响应取消 ⇒ 走"正常收尾"会卡在 `with_task_group` 退出处。
///    旧实现也是 `process.exit(...)`，口径相同。

///|

///|
/// `--<名字> <值>`（没给给 `None`）。**只认两段式写法** —— 与 `cmd/skillpress/cli/args.mbt`
/// 的 `arg_value` 同口径（旧实现 `argOf` 也是这么取值）。
fn arg_of(args : Array[String], key : String) -> String? {
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

///|

///|

///|
/// 挑一个**真的绑得上**的端口。
///
/// ⚠️ 不能写死端口：Windows 会把整段端口**保留**给 Hyper-V / WSL / Docker（范围每次重启都可能变），
///    落在保留段里的端口**任何进程都绑不上**。旧实现实测钉死 9333 的后果：
///    Chrome 只在自己 stderr 里写 `bind() returned an error (0x271D)`，而脚本看到的只是
///    "连不上 CDP、页面一片空白" —— **完全不像端口问题**。所以这里真绑一次、读内核给的端口、再关掉。
async fn free_port() -> Int {
  let srv = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  let port = srv.addr().port()
  srv.close()
  port
}

///|
/// 等着某个取值成功（最多等 `timeout_ms`，每 200ms 试一次；**吞掉异常** ——
/// 连不上就是"还没起来"，不是失败）。
async fn[X] wait_for(f : async () -> X?, what : String, timeout_ms : Int) -> X raise {
  let mut waited = 0
  while waited < timeout_ms {
    match f() {
      Some(v) => return v
      None => ()
    }
    @async.sleep(200)
    waited = waited + 200
  }
  fail("等不到：\{what}（等了 \{timeout_ms} ms）")
}

///|
/// `--dump-corpus <内容根> [--repo <仓库根>] [--home <文件>]`：**只读语料**，碰都不碰浏览器。
///
/// 这是给 `tools/site-corpus-parity.sh` 用的对账口：旧实现现跑一份同格式的转储，逐字节比。
/// ⚠️ 先切**二进制 stdio**：Windows 会把换行翻成 CRLF，而输出要逐字节等于 node 那份（只有单个 LF）。
pub fn run_dump_corpus(args : Array[String]) -> Unit {
  @gnative.set_binary_stdio()
  let host = @gnative.native_host()
  let at = cmd_index(args, ["--dump-corpus", "dump-corpus"])
  let root = if at >= 0 && at + 1 < args.length() {
    host.resolve(args[at + 1])
  } else {
    host.resolve("../moobile/skills")
  }
  let repo = match arg_of(args, "--repo") {
    Some(r) => host.resolve(r)
    None => host.resolve(@gates.join_path(root, ".."))
  }
  let quiet = fn(_m : String) { () }
  let known = skill_dirs(host, root, quiet)
  if known.length() == 0 {
    println("✗ 内容根下没有带 SKILL.md 的目录：" + root)
    @sys.exit(2)
  }
  let parsed = @ig.parse(host.read(@gates.join_path(repo, "skillpress.ignore.md")), known)
  let problems = parsed.problems()
  if problems.length() > 0 {
    println("✗ 忽略清单有问题（**不静默容忍**）—— verify 拒绝跑（期望本身就不可信了）：")
    for m in problems {
      println("  ✗ " + m)
    }
    @sys.exit(2)
  }
  let (kept, _skipped) = @ig.split_names(known, parsed)
  let home_arg = match arg_of(args, "--home") {
    Some(h) => h
    None => ""
  }
  let pick = @content.pick_home(root, home_arg, host.read, quiet)
  let home_file = if home_arg != "" {
    host.resolve(home_arg)
  } else {
    root + "/" + pick.label
  }
  let docs = docs_of(host, root, kept, quiet)
  let text = dump_corpus(host, root, pick.label, home_file, docs)
  println(text[:text.length() - 1].to_owned())
  @sys.exit(0)
}

///|
/// 站点判据主流程（参数解析 → 语料 → 起服务 → 起浏览器 → 23 条断言 → 收尾退出）。
///|
/// **站点判据的入口**（两个子命令都自己 `@sys.exit`，不返回）：
///
///   · `verify [--app …] [--skills …] [--repo …] [--home …] [--shot …] [--keep]`
///   · `dump-corpus <内容根> [--repo …] [--home …]`
///
/// ⚠️ 这两个只有 **native** 那份 CLI 有（js 上 `moonbitlang/async` 的 http server /
///    websocket / process **没有实现** —— 见 `moon.pkg` 的文件头）。所以分发不在共享的
///    `cmd/skillpress/cli` 里，而在**可执行件**那一层 —— 与"哪个 target 用哪份宿主"同一条规矩。
///
/// ⚠️ `--dump-corpus` 这个旧写法仍然认（判据脚本用了它一段时间），但它与
///    `dump-corpus` 是**同一件事**，别在文档里写成两个命令。
pub async fn run(args : Array[String]) -> Unit {
  // 命令词**扫**出来（与 `cmd/skillpress/cli/cli.mbt` 找命令词同一个口径）——
  // 两个可执行件的 argv 前缀不一样，认固定下标早晚会打架。
  let mut is_dump = false
  for a in args {
    if a == "--dump-corpus" || a == "dump-corpus" {
      is_dump = true
    }
  }
  if is_dump {
    run_dump_corpus(args)
    return
  }
  run_verify(args)
}

///|
/// 命令词在 argv 里的下标（找不到给 -1）。`dump-corpus` 的**内容根**就是它后面那个参数。
fn cmd_index(args : Array[String], names : Array[String]) -> Int {
  let mut i = 0
  while i < args.length() {
    if arr_has(names, args[i]) {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// `verify`：自起静态服务 + 起无头 Chrome + 走 CDP 跑那 23 条断言。
async fn run_verify(args : Array[String]) -> Unit {
  @gnative.set_binary_stdio()
  let host = @gnative.native_host()
  let quiet = fn(_m : String) { () }

  // ── 四个根（与旧实现 `roots.mjs` 同一套默认）────────────────────────────
  // ⚠️ 默认内容根按**程序根的兄弟 `moobile/`** 算，不能按 cwd：判据常常是**从站点实例里**
  //    拉起来的（`npm run verify`），那时 cwd 在 `<内容根>/skillpress/scripts/.skillpress`，
  //    拿 cwd 去拼 `../moobile/skills` 会得到一条不存在的路（实测：报"没有带 SKILL.md 的目录"）。
  //    程序根从 `SKILLPRESS_PROGRAM` 拿（native 没有引导层），拿不到才退回 cwd。
  let program = match @env.get_env_var("SKILLPRESS_PROGRAM") {
    Some(p) => p
    None => host.cwd()
  }
  let root = host.resolve(
    match arg_of(args, "--skills") {
      Some(s) => s
      None => program + "/../moobile/skills"
    },
  )
  let repo = host.resolve(
    match arg_of(args, "--repo") {
      Some(r) => r
      None => @gates.join_path(root, "..")
    },
  )
  let app = host.resolve(
    match arg_of(args, "--app") {
      Some(a) => a
      None => root + "/skillpress/scripts/.skillpress"
    },
  )
  let shot = match arg_of(args, "--shot") {
    Some(s) => s
    None => ""
  }
  let keep = args.contains("--keep")

  // ── 前置：站点产物 ──────────────────────────────────────────────────────
  let dist = @gates.join_path(app, "dist")
  if !host.exists(@gates.join_path(dist, "bundle.js")) {
    println("✗ 没有 site/dist/bundle.js —— 先在 site/ 里跑 `npm run build`")
    @sys.exit(2)
  }

  // ── 语料侧读数（与 `--dump-corpus` 同一套）──────────────────────────────
  let known = skill_dirs(host, root, quiet)
  if known.length() == 0 {
    println("✗ 内容根下没有带 SKILL.md 的目录：" + root)
    @sys.exit(2)
  }
  let parsed = @ig.parse(host.read(@gates.join_path(repo, "skillpress.ignore.md")), known)
  let problems = parsed.problems()
  if problems.length() > 0 {
    println("✗ 忽略清单有问题（**不静默容忍**）—— verify 拒绝跑（期望本身就不可信了）：")
    for m in problems {
      println("  ✗ " + m)
    }
    @sys.exit(2)
  }
  let (kept, skipped) = @ig.split_names(known, parsed)
  for line in @ig.notice_lines(skipped) {
    println(line)
  }
  let home_arg = match arg_of(args, "--home") {
    Some(h) => h
    None => ""
  }
  let pick = @content.pick_home(root, home_arg, host.read, fn(m) { println(m) })
  let home_file = if home_arg != "" {
    host.resolve(home_arg)
  } else {
    root + "/" + pick.label
  }
  let docs = docs_of(host, root, kept, quiet)
  let home_md = read_source(host.read(home_file))
  let home_probe = home_paragraph(home_md)
  let secs = home_sections(home_md)

  // ── 浏览器 ──────────────────────────────────────────────────────────────
  let chrome_path = match find_chrome() {
    Some(p) => p
    None => {
      println("✗ 找不到 Chrome —— 这条判据要真浏览器（RNW 在 jsdom 里不可信）")
      @sys.exit(2)
      // `@sys.exit` 是 Unit，而这支 match 要出一个 String —— 补一句"永远到不了"的返回值
      ""
    }
  }
  let debug_port = free_port()
  let profile = make_profile_dir()
  let err_file = @gates.join_path(profile, "chrome.err")

  let _ : Unit = @async.with_task_group(group => {
    // ① 静态服务（**进程内** —— 旧实现是再 spawn 一个 node serve-web.mjs）
    let site = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let site_port = site.addr().port()
    let url = "http://127.0.0.1:\{site_port}/"
    // ⚠️ `no_wait=true` 是**必须的**：`run_forever` 在 `Server::close()` 之后不返回
    //    ⇒ 默认的 spawn_bg 会让 `with_task_group` 在收尾处永远等下去（实测）。
    group.spawn_bg(no_wait=true, () => {
      site.run_forever((request, _body, conn) => serve_one(conn, dist, request.path))
    })
    // ⚠️ **确认是自己在应答**：不能只看"起来了" —— 旧实现踩过"测到碰巧同端口的别人"
    let ready = wait_for(
      () => {
        let (resp, body) = @http.get(url) catch { _ => return None }
        if resp.code != 200 {
          return None
        }
        let text = body.text() catch { _ => return None }
        if text.contains("<div id=\"root\"") { Some(true) } else { None }
      },
      "静态服务在 \{url} 上应答",
      10000,
    ) catch {
      _ => false
    }
    if !ready {
      println("✗ 静态服务没起来：\{url}")
      @sys.exit(2)
    }

    // ② 无头 Chrome
    let chrome = @process.spawn(
      group,
      chrome_path,
      [
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        "--remote-debugging-port=\{debug_port}",
        "--user-data-dir=\{profile}",
        "--window-size=1500,1000",
        "about:blank",
      ],
      stderr=@process.redirect_to_file(err_file),
      no_console_window=true,
    )
    let report_err = () => {
      let tail = if @fs.exists(err_file) {
        @fs.read_file(err_file).text() catch { _ => "(读不到)" }
      } else {
        "(空)"
      }
      println("  Chrome stderr：\{tail}")
    }

    // ③ CDP 的 WebSocket 地址
    let list_url = "http://127.0.0.1:\{debug_port}/json/list"
    let ws_url = wait_for(
      () => {
        let (resp, body) = @http.get(list_url) catch { _ => return None }
        if resp.code != 200 {
          return None
        }
        let text = body.text() catch { _ => return None }
        pick_page_ws(text)
      },
      "Chrome 的调试端口",
      20000,
    ) catch {
      _ => {
        println("✗ 连不上 CDP：\{list_url}")
        report_err()
        chrome.cancel()
        site.close()
        @sys.exit(2)
        // 同上：`catch` 那支要出 `wait_for` 的返回类型（String）
        ""
      }
    }

    // ④ 连上、握手、导航，然后跑 23 条断言
    let cdp = Cdp::connect(ws_url)
    let results = Results::new()
    let ctx : Ctx = {
      cdp,
      root,
      repo,
      live_host: host,
      home_file,
      home_probe,
      secs,
      docs,
      results,
      shot,
    }
    let crashed = try {
      cdp.enable()
      cdp.navigate(url)
      run_flow(ctx)
      false
    } catch {
      e => {
        println("✗ " + e.to_string())
        true
      }
    }
    let bad = results.bad()
    if !crashed {
      println("")
      if bad == 0 {
        println("全部通过（" + results.total().to_string() + " 条）")
      } else {
        println(bad.to_string() + "/" + results.total().to_string() + " 条不过")
      }
    }

    // ⑤ 收尾（`--keep` 时不杀，留给人自己看）
    if !keep {
      cdp.conn.close()
      chrome.cancel()
      site.close()
    }
    @sys.exit(if crashed { 2 } else if bad == 0 { 0 } else { 1 })
  })
}
