///|
/// **CLI 的公共件**：宿主与"程序根提示"的注入点 + 参数取值 + 两个根的默认值。
///
/// 为什么宿主与提示要注入：moon 今天**没有条件 import**（实测，见 P10 第 ⑦ 条）⇒
/// "js 用引导层、native 用 `moonbitlang/x`"这件事**不能**在同一个包里分叉。
/// 于是所有子命令的实现都住在这个与 target 无关的包里，**宿主由可执行件传进来**：
///
/// ```
/// cmd/skillpress/main.mbt         （js）     @cli.run(@gjs.js_host(), program_root())
/// cmd/skillpress-native/main.mbt  （native） @cli.run(@gnative.native_host(), hint)
/// ```
///
/// ⚠️ 这两样东西用**进程级 Ref** 存：子命令是"一个有状态的会话"（都从 `run` 进），
///    把 host 一路当参数传下去会把 800 行里每个函数签名都改一遍，而它本来就是全局唯一的。

///|
/// 一次 CLI 会话的两样东西：宿主 + 程序根提示。
pub struct Ctx {
  host : @gates.Host
  hint : String
}

///|
/// 会话（由 `run` 在入口处设好；子命令只读）。
let ctx_ref : Ref[Ctx?] = { val: None }

///|
/// 当前会话的宿主。
fn current_host() -> @gates.Host {
  match ctx_ref.val {
    Some(c) => c.host
    None =>
      // 只有"没走 run 就调子命令"才会到这里（测试或误用）—— 明说，不静默。
      abort("CLI 没初始化：请从 cli.run(host, hint) 进")
  }
}

///|
/// 程序根提示（js：引导层给的 `globalThis.__skillpress_ts.root`；native：`SKILLPRESS_PROGRAM`）。
fn program_hint() -> String {
  match ctx_ref.val {
    Some(c) => c.hint
    None => ""
  }
}

///|
/// `--<名字> <值>`（没给给 `None`）。**只认两段式写法**，与旧实现一致。
///
/// ⚠️ 它与 `cli.mbt` 里的 `opt()`（返回空串那个）是同一件事的两种口味：老代码用空串判定，
///    新代码用 `Option` —— 两个都留着，免得为了统一把老路径的语义改掉。
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
  host.resolve(@gates.join_path(@gates.join_path(@gates.join_path(program, ".."), ".."), ".."))
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
