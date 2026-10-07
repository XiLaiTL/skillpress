# vendor/web-tree-sitter —— vendor 进来的 tree-sitter **运行时**（**不是我们的代码**）

站点的高亮在**构建期**做：用 tree-sitter 解析代码块，再按语法自带的 `queries/highlights.scm`
把节点映射到我们自己的调色板。语法资产（`*.wasm` + `*.scm`）在 `../../grammars/`，
这里放的是**运行时**（`web-tree-sitter`：把 wasm 语法喂进 JS 的那一层）。

## 为什么把它也 vendor 进来（R6 那一问的最后一块）

**为了让这个包不再需要任何 npm 依赖。** 在此之前，运行时是使用者自己 `npm i web-tree-sitter` ——
那是"js target + 树剖析"这条路的账。但那条账**不是必须**的：运行时是 MIT、只有**两个文件**
（一个 ESM 入口 + 一个 wasm），而且**我们已经用同一套做法 vendor 了语法**。
于是 `grammars/` 与这里一起随包发 ⇒ 拿到包的人 `moon build` 一次就能跑 `gen-file`，
**不必碰 npm**（判据 `tools/consumer-check.sh` 就钉着这一条：在**解析不到任何 node_modules 的
干净目录**里，`check` 与 `gen-file` 都必须跑通）。

⚠️ 这与 `grammars/PROVENANCE.md` 里那三条理由同源（可复现 / 绕开 node-gyp / 一份事实一个家）——
它说的"运行时是 `package.json` 里那一个依赖"是 2026-10-06 之前的事，现在运行时也在这儿了。

⚠️ 还有一条**只有 native 出现之后才成立**的理由，见下面"版本"那一节：
这份运行时和 `../tree-sitter/` 那份 C 库**必须是同一个版本**，否则两个 target 的产物会差几行。

## 这些文件从哪来（**唯一出处**，含 sha256）

| 文件 | 来自（npm 包@版本） | 许可 | sha256（前 16 位） |
|---|---|---|---|
| `web-tree-sitter.js` | `web-tree-sitter@0.26.0`（`exports.import.default`） | MIT | `1edb5af94969588e` |
| `web-tree-sitter.wasm` | 同上（`exports["./web-tree-sitter.wasm"]`） | MIT | `91969d212a02174c` |
| `LICENSE` | 同上 | MIT | `c5cfb43042b6b720` |

核对方式（在这个目录里跑）：

```bash
node -e "const c=require('crypto'),f=require('fs');for(const x of f.readdirSync('.').sort())console.log(x.padEnd(26),c.createHash('sha256').update(f.readFileSync(x)).digest('hex').slice(0,16))"
```

`package.json`（只有 `{"type":"module"}`）是**我们加的**，不在上游包里 —— 上游那个包靠
自己的 `package.json` 声明 ESM，我们只拷了两个文件，所以要自己补一句（`PROVENANCE.md`
本身也不在上游包里）。

## ⚠️ 版本：为什么钉在 **0.26.0**（而不是更新的 0.27.0）

**因为 native 那条路要和它同版本，而 0.26.0 是两个 target 都够得到的最后一版。** 三条实测：

1. **npm 上带 C 库的那条线（`tree-sitter` 包 / `web-tree-sitter` 的 C 出口）最高只到 0.25.x**
   —— 0.26+ / 0.27.0 都只发 wasm。我们 native 要的正是 C 库 ⇒ C 侧只能从 **PyPI 的 sdist**
   取（`tree-sitter==0.26.0`，见 `../tree-sitter/PROVENANCE.md`），而它到 0.26.0 为止。
   GitHub 直连不通（代理关着）、crates.io 403 ⇒ 更新的 C 库拿不到，只能两边一起停在 0.26.0。
2. **0.25.1 会打破冻结的旧实现**：旧实现（`lib/*.mjs`，它是对账的**参照物**，不能改）在
   `web-tree-sitter@0.25.1` 下当场报 `Error: Dynamic require of "fs/promises" is not supported`；
   0.26.0 不报 ⇒ 0.26.0 是"旧实现跑得动"与"C 库拿得到"的交集。
3. **版本不齐会静默改产物**：0.27.0 的 wasm 配 0.26.0 的 C 库时，同一份语料上 native 与 js 的
   产物**恰好差 6 行** —— 一处 `moonbit` 代码块多出一个 `type` 捕获。隔离实验：js 0.25.1 + 我们的
   `.wasm` 与 native 0.25.1 + `parser.c` 读数**完全一致**（54 个捕获），而 js 0.27.0 是 53
   ⇒ 差异来自**运行时版本**，不是语法表。

所以 `tools/highlight-parity.sh`（旧实现 vs 新引擎）与 native↔js 的产物对账**共用这一条前提**：
js 的 wasm 与 native 的 C 库同版本。**换版本必须两边一起换**，换完两条判据都要重跑；
只换一边 = 产物差几行而两边看上去都还"绿"。

## 怎么更新（换版本时）

1. **先确认 C 库那一版拿得到**（见 `../tree-sitter/PROVENANCE.md` 的"怎么更新"）——
   只升这一侧、C 侧跟不上，就会掉进上面第 3 条；
2. `npm i web-tree-sitter@<新版本>`（或在临时目录里 `npm pack` 一份）；
3. 覆盖 `web-tree-sitter.js` / `web-tree-sitter.wasm` / `LICENSE`（**LICENSE 也要一起换**：
   实测 0.26.0 与 0.27.0 的 MIT 文本版权行不同，混着放就是"表里写一版、盘上是另一版"）；
4. 重跑上面那条 sha256，**更新这张表**；
5. `THIRD-PARTY-NOTICE.md` 里的版本号跟着改；
6. 跑 `node tools/consumer-check.sh`（它会证明"没有 npm 也能跑"仍然成立）
   与四条对账判据（上色产物必须仍与旧实现逐字节一致）。

⚠️ 只拷**用得到的那两个文件**：同一个 npm 包里还有 `*.map`、`*.d.ts`、`debug/`（另一个构建），
它们对运行时没有用，进来只会让包变大、让"从哪来"变糊。
