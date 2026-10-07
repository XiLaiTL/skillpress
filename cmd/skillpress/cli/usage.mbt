// usage.mbt —— **"没给命令 / 给了个不认识的命令"这一档**怎么处理（一件小事，单独一份）。
//
// ⚠️ 为什么拆出来（2026-10-07）：`cli.mbt` 撞上了 R9 的 400 行预算 —— 而这一段本来就是
//    "**怎么把话说给用户听**"，与命令分发是两件事：
//      · 没给命令词      ⇒ 打用法，**退 0**（人只是想知道怎么用）；
//      · 给了词但不认识  ⇒ **点名 + 退 2**（`cmd1 && cmd2` 不许把拼错的当成功）；
//      · 认识但还没做    ⇒ `pack` 这条：明说"还没做" + **退 2**（不许看起来像跑过了）。
//    后两条还的是 PLAN §8 的 **DG-CLI** 那笔账（原来任何认不出的词都退 0）。

///|
/// 认不出的词 / 还没做的命令 / 裸调用 —— 三种都由这里收口。
pub fn no_command(args : Array[String]) -> Unit {
  // ⚠️ 跳过"解释器 + 脚本"那一段：js 那条路 `argv[1]` 是引导层脚本（**`.mjs`**！第一版只判了
  //    `.js` ⇒ 它被当成"认不出的子命令"，于是**裸调用也报错、退出码 2** —— 判据自己的假红）。
  //    判据用"带路径分隔符 + 脚本后缀"，不用"文件存不存在"：命令词永远不长这样。
  let mut cand = ""
  for i = 0; i < args.length(); i = i + 1 {
    let a = args[i]
    let looks_like_path = a.contains("/") || a.contains("\\")
    let looks_like_script = a.has_suffix(".js") ||
      a.has_suffix(".mjs") ||
      a.has_suffix(".cjs") ||
      a.has_suffix(".exe")
    if i == 0 || a.has_prefix("-") || (looks_like_path && looks_like_script) {
      continue
    }
    cand = a
    break
  }
  if cand != "" && cand != "pack" {
    @content.note("✗ 认不出的子命令：`" + cand + "`")
    @content.note("  已知的：hl / batch / audit / dump-blocks / gen-file / check / gen-queries / attach（+ native 那份的 verify）")
    @content.set_exit_code(2)
    return
  }
  if cand == "pack" {
    @content.note("✗ `pack` 还没做（便携目录打包）—— 今天能用的是 `attach`（生成站点工程）")
    @content.set_exit_code(2)
    return
  }
  print_usage()
}

///|
/// 用法（裸调用时打给用户看）。⚠️ 里面每一条都必须是**今天真的能跑**的命令 ——
/// 用法里写一个不存在的命令，比不写更坏。
fn print_usage() -> Unit {
    println("用法：node tools/run-js.mjs hl <markdown 文件> <语言>")
    println("      SKILLPRESS_CORPUS=<根> node tools/run-js.mjs batch")
    println("      node tools/run-js.mjs audit [<内容根>]            # 上色的回归闸门（召回率 / 未上色比例）")
    println("      node tools/run-js.mjs dump-blocks <内容根>")
    println("      node tools/run-js.mjs gen-file <内容根>      # 整份 content.generated.mbt → stdout")
    println("      node tools/run-js.mjs gen-file <内容根> --llms   # 同一份解析产出的 llms.txt → stdout")
    println("      node tools/run-js.mjs check [--repo <根>] [--skills <内容根>] [--update-lock [名字]]")
    println("      node tools/run-js.mjs gen-queries [--check]   # 把 grammars/*.scm 嵌进 engine/highlight/queries.generated.mbt")
    println("      node tools/run-js.mjs attach [--repo <根>] [--skills <内容根>] [--ignore <名字>=<理由>] [--force]")
    println("                             # 给一份 skills/ 直接生成站点（首页源来自 <仓根>/README.md）")
    println("      node tools/run-js.mjs pack                        # ⚠️ 还没做（会说清 + 退 2）")
    println("公共参数：--repo <仓根> · --skills <内容根> · --program <程序根>（都可用同名环境变量给）")
    println("      skillpress-native verify [--skills <内容根>] [--app <站点实例>] [--shot <png>]")
    println("                             # 站点判据（真 Chrome + CDP，23 条）—— **只有 native 那份有**；")
    println("                             # js 那条路上 moonbitlang/async 没有 http server / websocket / process")
    println("垫片装的语法：\{@hl.languages()}")
    return
}
