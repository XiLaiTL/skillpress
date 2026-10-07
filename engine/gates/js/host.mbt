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
/// 递归建目录。**已经存在也算成功**（`attach` 跑第二遍不该红）；真失败（没权限）也吞掉 ——
/// 吞掉不会造成"悄悄写错地方"：紧接着的 `write` 会抛，而那个错会当场冒出来。
extern "js" fn fs_mkdir_p(p : String) -> Unit =
  #|(p) => { try { require("node:fs").mkdirSync(p, { recursive: true }); } catch (e) {} }

///|
extern "js" fn proc_is_tty() -> Bool =
  #|() => { try { return Boolean(process.stdin.isTTY); } catch (e) { return false; } }

///|
/// 问一句、读一行（提问写 stderr，别污染 stdout 那份产物）。
///
/// **两条路，同一套"按行"语义**：
///   · `stdin` 是终端 ⇒ `readSync` 逐字节读到换行（真交互）；
///   · 不是终端（管道 / 判据喂答案）⇒ 把 stdin **整个读一次**再按行切，之后逐次弹出。
///     这条路存在的理由很实在：`printf '1\n理由\n' | skillpress attach --interactive`
///     才能被写成判据 —— 只认终端的话，交互逻辑**永远测不到**。
/// 读不到 / 出错一律给空串（调用方把它当"用默认值"，并打印出来）。
extern "js" fn stdin_read_line(prompt : String) -> String =
  #|(prompt) => { const fs = require("node:fs"); try { fs.writeSync(2, prompt); } catch (e) {} const g = globalThis; try { if (g.__sp_tty === undefined) { if (process.stdin.isTTY) { g.__sp_tty = true; } else { g.__sp_tty = false; g.__sp_lines = String(fs.readFileSync(0, "utf8")).split("\n"); g.__sp_i = 0; } } if (g.__sp_tty) { let out = ""; const b = Buffer.alloc(1); for (;;) { const n = fs.readSync(0, b, 0, 1, null); if (n === 0) break; const c = b.toString("utf8"); if (c === "\n") break; if (c !== "\r") out += c; } return out; } if (g.__sp_i >= g.__sp_lines.length) return ""; return String(g.__sp_lines[g.__sp_i++]).replace(/\r$/, ""); } catch (e) { return ""; } }

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
    fs_mkdir_p,
    proc_is_tty,
    stdin_read_line,
  )
}
