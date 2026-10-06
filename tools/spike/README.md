# P8.0 探针：markdown 解析 + tree-sitter 上色（2026-10-06 实测）

这个模块是**临时**的：它只回答"引擎迁 MoonBit 时，两处最没底的地方到底能不能站住"。
结论落地后，正式实现在 P8.1 另起模块；到时候根上的 `moon.mod` 必须用 `.moonignore` 排掉 `/tools/`，
否则探针会被打进正式包。

## 结论先说

| 问题 | 结论 |
|---|---|
| `mizchi/markdown` 够不够映射我们的 `Block` / `Span`？ | **够**。块类型齐全（标题 / 段落 / 围栏 / 表格 / 引用 / 列表 / alert / 脚注…），**还自带 YAML frontmatter 解析**（能替掉我们手写那段）。实测与"纯正则数出来的真值"逐项一致：h1=1 ｜ h2=5 ｜ 表格 3 ｜ 列表项 7 ｜ 围栏 1。跑在 **js** target 上。 |
| tree-sitter 上色链能不能跑？ | **两条路各缺一块**（§三 / §四）：js 被包的 `supported-targets` 挡住；native 被**上游缺 C 源**挡住。 |
| 走 native 还是 js？ | **js 是主路**（§四）；native 记为备选 —— 它才是"零 npm"的那条，但要等上游修。 |

## 一、native 工具链：必须先设 MSVC 环境

不设环境直接 `moon build --target native` 的报错是
`LNK1120: N unresolved externals` —— **看着像"没装工具链"，其实是 `INCLUDE` / `LIB` 没设**。
本机装的是 VS 2022 Build Tools（`cl.exe` 14.44），所以走 `native-build.bat`（用 vcvars64 包一层）。

⚠️ 那个 `.bat` **只能用 ASCII 注释**：cmd 按 OEM 代码页（这里是 GBK）读 `.bat`，
UTF-8 中文注释解出来的字节里会带 `&` `|` `>` `"`，cmd 会把它们**当命令去跑**
（实测：35 万行垃圾输出，而编译根本没开始）。

## 二、两个 target 是**两张构建图**

`tonyfettes/tree_sitter` 声明 `supported-targets: "+native"` ⇒ 只要某个入口 import 它，
**js 那张图就编不出来**：

```
Selected backend 'js' is incompatible with the dependency graph.
'XiLaiTL/skillpress-spike/hl' which supports [native]
```

所以探针拆成两个入口：`cmd/js`（markdown 那半）与 `cmd/native`（上色那半）。

## 三、native 的两个**上游**卡点

1. `tonyfettes/c@0.7.4`（`tree_sitter` 的依赖）**编不过**当前 core：`@strconv.parse_int64` 找不到。
   → 显式 `moon add tonyfettes/c`（解析到 **0.7.8**）即修好。
2. `tonyfettes/tree_sitter@0.4.6` 的 `src/tree-sitter.c` 第一行是
   `#include "tree-sitter#lib#src#lib.c"`，而**包里没带那个目录**
   （解出来的包只有 `src/`、`LICENSE`、`README.md`、`moon.mod.json`）⇒
   `fatal error C1083: 无法打开包括文件`。**上游打包缺件**，native 到此为止。

出路三选一：① 提 issue / 等修；② 自己把 tree-sitter 的 C 源 vendor 进来；
③ 走 js（下面那条，代价是多一个 npm 依赖，而那个依赖我们今天就有一个）。

## 四、js 上色那条路（当下建议的主路）

`tonyfettes/tree_sitter` 在 **js** 上的实现本来就是 `await import("web-tree-sitter")`
（见它的 `init.js.mbt`）—— **跟我们今天 Node 版用的是同一个 npm 包**。两条选择：

- 等上游把 `supported-targets` 放开到 `+js`；
- 或者我们自己写一层薄 extern 调 `web-tree-sitter`，语法用**我们已经 vendor 的 wasm**
  （`grammars/*.wasm` 与 `*.highlights.scm`）—— 与"引擎今天只有一个 npm 依赖"的现状一致，且只写一遍。

## 五、跑法

```bash
# markdown 那半（js）
moon run cmd/js --target js -- <某个 SKILL.md 的绝对路径>
# 上色那半（native，需 MSVC 环境）
native-build.bat run cmd/native --target native
# 旧实现在**同一块**上的读数 —— 迁移期对账的基准
node node-side-hl.mjs <某个 SKILL.md 的绝对路径> bash 1
```

## 六、这个探针**没**回答的（留给 P8.1，别当成已覆盖）

- **召回率对账**：探针的 query 是**精简的 4 条 pattern**，不是完整的 `grammars/bash.highlights.scm`。
  ⚠️ 上色质量（比旧实现差不差）是 P8.0 那张风险表里最要紧的一条，必须在 P8.1 用**同一块 + 同一份 scm** 量。
- **字节偏移 ↔ 字符下标**：tree-sitter 给的是 **UTF-8 字节偏移**，而 MoonBit 的 `String`
  在 js 后端是 **UTF-16**（native 是 UTF-8）⇒ 非 ASCII 内容要自己换。探针只用 ASCII 绕开了这件事。
- **文件 IO**：探针用 `extern "js"` 读文件；正式实现要用 `moonbitlang/async/fs`（那条才是 js / native 都覆盖的）。

## 七、一个顺手逮到的口径坑

第一版把**块级围栏**与**行内 `` `code` ``** 计到同一个键上，于是打印出 `code = 21`（6 个围栏 + 15 个行内），
看着像"解析器给多了"。**真值一量就露**（正则数出围栏只有 1 个）—— 现在是 `fenced` 与 `span_code` 两个键。
