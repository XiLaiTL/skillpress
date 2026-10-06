///|
/// **js 宿主的真身**：门要看的那几件事，全都落到 `node:fs` / `node:path` 上。
///
/// ## 为什么宿主是注入的
///
/// 门的逻辑（哪个 token 算路径、命令里引用了哪个脚本、锁里的指纹变了没有…）是纯函数；
/// "磁盘上到底有没有"才是运行时的事。分开之后：
///   · `gates_test.mbt` 可以用**假宿主**喂诱饵（不需要真文件、跑得飞快）；
///   · 真宿主只有这一份（换 target 只换这个文件）。
///
/// ## 每一条都必须与旧实现**同一套系统调用**
///
/// 这不是洁癖：判据是"输出逐字节一致"，而下面几条都会**改变判定结果**——
///   · `readdirSync` **不排序**（旧实现直接用原始顺序，顺序会打印出来）；
///   · 读不到文件给**空串**（旧实现 try/catch 吞掉）、列不到目录给**空表**；
///   · `resolve` = `path.resolve`（锁里记的 `root` 是绝对路径，Windows 上是反斜杠，
///     它决定了"这条锁记录属不属于当前内容根"）。
extern "js" fn fs_exists(p : String) -> Bool =
  #|(p) => { try { return require("node:fs").existsSync(p); } catch (e) { return false; } }

///|
extern "js" fn fs_is_dir(p : String) -> Bool =
  #|(p) => { try { return require("node:fs").statSync(p).isDirectory(); } catch (e) { return false; } }

///|
extern "js" fn fs_read(p : String) -> String =
  #|(p) => { try { return require("node:fs").readFileSync(p, "utf8"); } catch (e) { return ""; } }

///|
extern "js" fn fs_read_dir(p : String) -> FixedArray[String] =
  #|(p) => { try { return require("node:fs").readdirSync(p); } catch (e) { return []; } }

///|
extern "js" fn path_resolve(p : String) -> String =
  #|(p) => require("node:path").resolve(p)

///|
extern "js" fn fs_write(p : String, text : String) -> Unit =
  #|(p, text) => { require("node:fs").writeFileSync(p, text); }

///|
extern "js" fn proc_cwd() -> String =
  #|() => process.cwd()

///|
/// 把上面几个拼成宿主。
pub fn js_host() -> @gates.Host {
  @gates.Host::new(
    fs_exists,
    fs_is_dir,
    fs_read,
    fn(p) {
      let out : Array[String] = []
      for name in fs_read_dir(p) {
        out.push(name)
      }
      out
    },
    path_resolve,
    fs_write,
    proc_cwd,
  )
}
