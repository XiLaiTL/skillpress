///|
/// js target 上读文件：直接调 Node 的 `fs`。
///
/// ⚠️ 这**只服务探针**（P8.0）。正式实现（P8.1+）会用 `moonbitlang/async/fs` —— 那才是
/// 同时覆盖 js / native 的路。这里之所以肯写 extern：这一步要回答的是
/// "markdown AST 与 tree-sitter 够不够用"，不是"MoonBit 怎么读文件"。
pub fn read_text(path : String) -> String {
  read_text_js(path)
}

///|
extern "js" fn read_text_js(path : String) -> String =
  #|(path) => require("node:fs").readFileSync(path, "utf8")
