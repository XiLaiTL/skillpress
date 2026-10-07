# vendor/tree-sitter —— vendor 进来的 **tree-sitter C 库**（**不是我们的代码**）

原生（native）CLI 的构建期上色链要用它：`engine/highlight` 的 js 垫片走 `web-tree-sitter`（wasm），
而 **native 垫片**必须有一份**能编进本机二进制的 tree-sitter C 库**。

## 为什么要 vendor 进仓库（而不是装成依赖）

1. **上游那个 MoonBit 绑定在 native 上不可用**（2026-10-06 实测，见 `PLAN.md` P10）：`tonyfettes/tree_sitter@0.4.6`
   的 `src/tree-sitter.c` 第一行就 `#include "tree-sitter#lib#src#lib.c"`，而 C 库在它上游是 **git submodule**
   —— 发布 tarball 只带 `src/`，连那个本该生成单体 C 的 `scripts/prepare.py` 都没进包（发布版 `moon.mod.json` 里没有 `scripts`）。
2. **moon 没有条件 import**（实测报错原文：「Conditional imports are not yet supported by the build system.」）⇒
   同一份包里**不能**"js 用一套依赖、native 用另一套"。而 js 那条路今天撑着全部判据与 `press`，
   且对账判据要求 **native 与 js 都在**。所以要用 native 依赖，就得全 vendor。
3. **可复现**：生成物要能逐字节复算 —— 语法/运行时来自"本机装了什么"就会出两种内容。

## 资产表

| 文件 | 来自 | 许可 | sha256（前 16 位） |
|---|---|---|---|
| `lib/src/lib.c`（单体入口，include 同目录其余 C） | PyPI sdist `tree-sitter==0.26.0`，包内路径 `tree_sitter/core/lib/` | MIT | `4e28f87edb86e513` |
| `lib/include/tree_sitter/api.h` | 同上 | MIT | `9abe4cd0c3920510` |
| `lib/src/tree_sitter/api.h`（我们的副本，见下） | 同上 | MIT | `9abe4cd0c3920510` |
| `LICENSE` | 同上 | MIT | `1af0790543fffac9` |

sdist 本体：`tree_sitter-0.26.0.tar.gz`，sha256（全 64 位）
`b40c219edccc4564530c96f8f1556f6202b37cda964d1cbd7bd2b7e68b40a245`。

⚠️ 这是**上游自己的单体构建方式**（`lib.c` include 同目录的 `parser.c` / `lexer.c` / `query.c` …）——
我们只是把它原样搬进来，编成一个目标文件（和上游、以及 `tonyfettes/tree_sitter` 的做法一致）。

⚠️ **体积**：整棵 vendor 树未压缩 17 MB，`tar.gz` 压完 **0.91 MB**（生成码表极度可压）——
所以"进包"的代价是约 0.9 MB 下载量，不是 17 MB。

## ⚠️ 为什么是 **PyPI 的 sdist**，以及为什么版本钉在 **0.26.0**

native 编不过的第一次尝试是从 npm 找 C 库，实测（2026-10-06）：**npm 上带 C 的那条线最高 0.25.x**，
0.26+ 与 0.27.0 都只发 wasm；crates.io 403、GitHub 直连不通（代理关着）。
于是唯一**离线够得到**的 C 源码是 **PyPI 的 sdist**：`pip download tree-sitter==0.26.0 --no-deps --no-binary :all:`
（里面 `tree_sitter/core/lib/{src,include}` 就是那份 C 库），而它到 0.26.0 为止。

**版本必须与 js 那侧的 `web-tree-sitter` 完全一致** —— 这是产物对账的前提，理由与实测写在
`../web-tree-sitter/PROVENANCE.md` 的"版本"那一节（0.27.0 wasm 配 0.26.0 C 时，产物恰好差 6 行）。
一句话：**只升一边 = 产物差几行、而两边看上去都还绿**。

## 复查方式（谁能证明这份东西还是它自己）

```bash
cd skillpress
sha256sum vendor/tree-sitter/lib/src/lib.c | cut -c1-16     # 应当等于 4e28f87edb86e513
sha256sum vendor/tree-sitter/lib/include/tree_sitter/api.h | cut -c1-16  # 9abe4cd0c3920510
```

想从零复算（在一台能上 PyPI 的机器上）：

```bash
pip download tree-sitter==0.26.0 --no-deps --no-binary :all: -d /tmp/tsp
cd /tmp/tsp && tar xzf tree_sitter-0.26.0.tar.gz
sha256sum tree_sitter-0.26.0/tree_sitter/core/lib/src/lib.c   # 4e28f87e… 与仓库里那份逐字节相同
```

## ⚠️ 我们加的一条：`lib/src/tree_sitter/api.h` 是**副本**

上游用 `-I lib/include` 让源码找到 `tree_sitter/api.h`。而 MoonBit 的 `native-stub` 是**就地编译**
（不拷进 `_build`、也不接受随构建目录漂的相对 `-I`）⇒ 我们按上游那条 `-I` 的口径，把
`lib/include/tree_sitter/api.h` **复制**到 `lib/src/tree_sitter/api.h`，让引号包含按"相邻"解析成功。
副本与正本逐字节相同（`9abe4cd0c3920510`）；**改了正本就要同步这一份**（否则 native 编不过，
而 js 那边照样绿 —— 又是一条静默差异）。

## 怎么更新（换版本时）

1. **先确认新版本的 C 源码拿得到**（`pip download … --no-binary :all:` / GitHub tarball；
   拿不到就别升 —— 见上面"为什么是 PyPI 的 sdist"）；
2. 覆盖 `lib/src/**` 与 `lib/include/**`（**只拷 `src/` 与 `include/`**：sdist 里还有
   Python 绑定与 `queries/`，那些不是这份 C 库的一部分）；
3. **同步 `lib/src/tree_sitter/api.h` 这份副本**，并重跑上面两条 sha256、更新这张表；
4. `../web-tree-sitter/` 那一侧一起换到**同一个版本**，`THIRD-PARTY-NOTICE.md` 里的版本号跟着改；
5. 跑 native↔js 的产物对账（逐字节）与四条上色判据 —— 换版本**必须**在这两条上都验一遍。
