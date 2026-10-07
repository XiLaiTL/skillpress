# vendor/tree-sitter-grammars —— vendor 进来的**语法 C 源**（**不是我们的代码**）

原生（native）上色链需要**能编进本机二进制**的语法。这里放五门语法的 `parser.c` / `scanner.c` / ABI 头。

## 出处：与 `grammars/*.wasm` **严格同版**

`grammars/PROVENANCE.md` 里钉着每份 `.wasm` 来自哪个 npm 包、哪个版本；这里的 `parser.c`/`scanner.c`
就是**同一个包、同一个版本**里的同名文件 ⇒ "native 与 js 用的是同一门语法"是**可复算**的，
不是"看起来差不多"。（实测证据：两边 capture 逐字节一致，见 `PLAN.md` P10。）

## 资产表

| 语法 | 来自（npm 包@版本） | 许可 | sha256（前 16 位） |
|---|---|---|---|
| `json/parser.c` | `tree-sitter-json@0.24.8` | MIT | `e8e1ff5df0d73e3b` |
| `bash/parser.c` ｜ `bash/scanner.c` | `tree-sitter-bash@0.25.1` | MIT | `0021866dd2a7fccd` ｜ `7cc25d70626f8939` |
| `javascript/parser.c` ｜ `javascript/scanner.c` | `tree-sitter-javascript@0.25.0` | MIT | `67209ca7ef6e1a4f` ｜ `b3d3f64284d97bf8` |
| `moonbit/parser.c` ｜ `moonbit/scanner.c` | `tree-sitter-moonbit@0.1.0`（**官方**：moonbitlang/tree-sitter-moonbit） | Apache-2.0 | `8a84b06db22c7b73` ｜ `0e869d34406f7bf0` |
| `toml/parser.c` ｜ `toml/scanner.c` | `@tree-sitter-grammars/tree-sitter-toml@0.7.0` | MIT | `1991a2608e6f0214` ｜ `b25ff3b5034f4004` |

每门语法还带它**自己的** `tree_sitter/{parser,alloc,array}.h`（`json` 无 `scanner.c`）。

## 三条踩过的坑（都实测过，别省）

1. **每门语法必须用它自己的 ABI 头**：五个包的 `tree_sitter/parser.h` **互不相同**（sha256 分三组），
   混用会报 `TSLanguage` 没有某个字段（`max_reserved_word_set_size` / `metadata` 那类）。
   所以这里是**按语法分目录**摆的，不是一个扁平目录。
2. **`native-stub` 里的文件基名必须唯一**：五个都叫 `parser.c` 会让 **`moon` 直接 panic**
   （`execution action inputs must be declared once`）。使用方（`engine/highlight`）声明 stub 时
   要么改名，要么只声明一份 —— 见那边的注释。
3. **stub 是"就地编译"的**（不拷进 `_build`）⇒ 引号包含按**各文件自己所在目录**解析，
   所以 `parser.c` 旁边的 `tree_sitter/` 必须跟着走，且不需要 `-I`。

## 复查方式

```bash
cd skillpress
for f in vendor/tree-sitter-grammars/*/parser.c; do sha256sum "$f" | cut -c1-16; done
```
