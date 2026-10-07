///|
/// tree-sitter 的薄垫片（**native target 专用**）。
///
/// 与 `ts_shim.mbt`（js）对称：那边靠引导层，这边**什么都不靠** ——
/// tree-sitter 的 C 库与五门语法的 C 都 vendor 在 `vendor/` 里、**编进本机二进制**，
/// query 也**编进二进制**（`queries.generated.mbt`，来自 `grammars/*.scm` 的逐字节副本）。
/// 这就是"使用者零 Node"那件事在**高亮这条链**上的落点。
///
/// ## 两条口径（都是实测踩出来的，见 `PLAN.md` P10）
///
/// 1. **偏移要折**：tree-sitter 给的是 **UTF-8 字节**偏移，而 js 侧（web-tree-sitter）与
///    MoonBit 的字符串都是 **UTF-16 码元** ⇒ 这里用 `byte_to_unit_map` 折一次；
///    不折的话，一出现非 ASCII 就整片错位（实测：含中文的 json，C 侧 `string 84 216` vs js 侧 `84 158`）。
/// 2. **谓词在 C 桩里照 web-tree-sitter 的口径实现**了（`#eq?` / `#match?` / `#any-of?` 与 `any-` 变体；
///    `#is?` / `#is-not?` / `#set!` 对 capture 列表是空操作）—— 否则会**多出** capture。

///|
/// 语言名 → C 桩那边的编号（顺序只有这一处答案；与 `tools/run-js.mjs` 的 wasm 基名一一对应）。
fn lang_id(name : String) -> Int {
  match name {
    "json" => 0
    "moonbit" => 1
    "bash" => 2
    "javascript" => 3
    "toml" => 4
    _ => -1
  }
}

///|
/// C 库与语法都是**静态链进来的** ⇒ 没有"没装好"这种状态（js 那边才需要问引导层）。
pub fn ready() -> Bool {
  true
}

///|
/// 内嵌 query 的那几门语言，**逗号分隔**（与 js 侧 `Object.keys(...).sort().join(",")` 同口径）。
pub fn languages() -> String {
  query_languages().fold(init="", fn(a, n) { if a == "" { n } else { a + "," + n } })
}

///|
/// 解析一次、返回三列文本（`名字\t起点\t终点`，偏移已折成 **UTF-16 码元**）。
/// 认不出语言 / 缺 query ⇒ 写成 `ERR:` 前缀（由 `captures.mbt` 抛出去，不静默）。
pub fn captures_text(lang_name : String, source : String) -> String {
  let id = lang_id(lang_name)
  if id < 0 {
    return "ERR: 没装这个语言的语法：" + lang_name + "（已装：" + languages() + "）"
  }
  let scm = query_of(lang_name)
  if scm == "" {
    return "ERR: 没装这个语言的 query：" + lang_name
  }
  let src_bytes = @utf8.encode(source)
  let scm_bytes = @utf8.encode(scm)
  let raw = sp_captures(id, src_bytes, src_bytes.length(), scm_bytes, scm_bytes.length())
  convert_offsets(raw, source)
}

///|
/// C 桩的入口（实现在 `ts.c`）：跑 parse + query（含谓词），返回三列 **ASCII** 文本。
#borrow(src, query)
extern "c" fn sp_captures(
  lang : Int,
  src : Bytes,
  src_len : Int,
  query : Bytes,
  query_len : Int,
) -> String = "sp_captures"

///|
/// **UTF-8 字节偏移 → UTF-16 码元偏移**（同 `ts_shim.mbt` 那条口径）。
///
/// 做法：按**码点**走一遍，累计每个码点起点的"UTF-8 字节数 / UTF-16 码元数"，
/// 得到一张换算表（capture 的边界一定落在码点边界上，查表因此是精确的）。
fn byte_to_unit_map(text : String) -> Array[(Int, Int)] {
  let map : Array[(Int, Int)] = []
  let mut bytes = 0
  let mut units = 0
  for ch in text {
    map.push((bytes, units))
    let cp = ch.to_int()
    bytes = bytes +
      (if cp < 0x80 {
        1
      } else if cp < 0x800 {
        2
      } else if cp < 0x10000 {
        3
      } else {
        4
      })
    units = units + (if cp < 0x10000 { 1 } else { 2 })
  }
  map.push((bytes, units))
  map
}

///|
/// 查表：字节偏移 → 码元偏移（落在两界之间就给前一个边界）。
fn unit_of(map : Array[(Int, Int)], byte_off : Int) -> Int {
  let mut lo = 0
  let mut hi = map.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if map[mid].0 <= byte_off {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  map[lo].1
}

///|
/// 把三列文本里的偏移整列换成 UTF-16 码元。
fn convert_offsets(text : String, src : String) -> String {
  let map = byte_to_unit_map(src)
  let out : Array[String] = []
  for line in text.split("\n") {
    let parts = line.split("\t").collect()
    let is_row = parts.length() == 3
    if is_row {
      // `@string.parse_int` 是**抛**的（不是 Result）⇒ 用 try/catch 兜住（与 `captures.mbt` 同口径）
      let start = try {
        @string.parse_int(parts[1])
      } catch {
        _ => -1
      }
      let end = try {
        @string.parse_int(parts[2])
      } catch {
        _ => -1
      }
      if start >= 0 && end >= 0 {
        out.push(
          parts[0].to_owned() +
          "\t" +
          unit_of(map, start).to_string() +
          "\t" +
          unit_of(map, end).to_string(),
        )
        continue
      }
    }
    out.push(line.to_owned())
  }
  out.fold(init="", fn(a, l) { if a == "" { l } else { a + "\n" + l } })
}
