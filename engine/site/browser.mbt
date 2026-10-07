///|
/// **无头 Chrome**：去哪找它、怎么起、profile 落在哪。
///
/// ⚠️ 旧实现那条「**不写字面的安装目录路径**」的规矩照抄：写死 C:\Program Files\... 
///    既会被泄漏门判成「本机绝对路径」，在系统盘不是 C 的机器上也本来就是错的。
/// 环境变量（拿不到给 `fallback`）。
fn env_or(name : String, fallback : String) -> String {
  match @env.get_env_var(name) {
    Some(v) => v
    None => fallback
  }
}

///|
/// 去环境变量里拿一个目录（`ProgramFiles` 那类）。空串当没给。
fn env_dir(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(v) =>
      if v == "" {
        None
      } else {
        Some(v)
      }
    None => None
  }
}

///|
/// 去哪找 Chrome：`SKILLPRESS_CHROME` 优先，其次按系统盘拼几个常见位置。
///
/// ⚠️ 旧实现那条"**不写字面的安装目录路径**"的规矩照抄：写死 `C:\Program Files\...`
/// 既会被泄漏门判成"本机绝对路径"，在系统盘不是 C 的机器上也本来就是错的。
/// 所以从环境变量拿安装目录（`ProgramFiles` / `ProgramFiles(x86)` / `LOCALAPPDATA`），拿不到再用系统盘拼。
async fn find_chrome() -> String? {
  match @env.get_env_var("SKILLPRESS_CHROME") {
    Some(p) =>
      if @fs.exists(p) {
        return Some(p)
      }
    None => ()
  }
  let tail = "\\Google\\Chrome\\Application\\chrome.exe"
  let bases : Array[String?] = [
    env_dir("ProgramFiles"),
    env_dir("ProgramFiles(x86)"),
    env_dir("LOCALAPPDATA"),
  ]
  let mut found : String? = None
  let mut i = 0
  while i < bases.length() {
    match bases[i] {
      Some(base) => {
        let p = base + tail
        if @fs.exists(p) {
          found = Some(p)
        }
      }
      None => ()
    }
    i = i + 1
  }
  match found {
    Some(p) => return Some(p)
    None => ()
  }
  let fallback = env_or("SystemDrive", "C:") + "\\Program Files" + tail
  if @fs.exists(fallback) {
    return Some(fallback)
  }
  None
}

///|
/// 给这次运行开一个临时 profile 目录（Chrome 的 profile 与它的 stderr 都落在这儿）。
///
/// ⚠️ 与旧实现 `mkdtempSync(tmpdir() + "skillpress-chrome-")` 同口径：**每轮一个唯一目录** ——
///    复用同一个 profile 会让上一轮的会话与缓存渗进这一轮，"这一轮的页面"就不再干净。
async fn make_profile_dir() -> String {
  @fs.tmpdir(prefix="skillpress-chrome-")
}

///|
