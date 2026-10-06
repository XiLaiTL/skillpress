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

## 这些文件从哪来（**唯一出处**，含 sha256）

| 文件 | 来自（npm 包@版本） | 许可 | sha256（前 16 位） |
|---|---|---|---|
| `web-tree-sitter.js` | `web-tree-sitter@0.27.0`（`exports.import.default`） | MIT | `7c49e3c1d87e24e0` |
| `web-tree-sitter.wasm` | 同上（`exports["./web-tree-sitter.wasm"]`） | MIT | `c03bccdc3b448a32` |
| `LICENSE` | 同上 | MIT | `c5cfb43042b6b720` |

核对方式（在这个目录里跑）：

```bash
node -e "const c=require('crypto'),f=require('fs');for(const x of f.readdirSync('.').sort())console.log(x.padEnd(26),c.createHash('sha256').update(f.readFileSync(x)).digest('hex').slice(0,16))"
```

## 怎么更新（换版本时）

1. `npm i web-tree-sitter@<新版本>`（或在临时目录里 `npm pack` 一份）；
2. 覆盖 `web-tree-sitter.js` / `web-tree-sitter.wasm` / `LICENSE`；
3. 重跑上面那条 sha256，**更新这张表**；
4. `THIRD-PARTY-NOTICE.md` 里的版本号跟着改；
5. 跑 `node tools/consumer-check.sh`（它会证明"没有 npm 也能跑"仍然成立）
   与四条对账判据（上色产物必须仍与旧实现逐字节一致）。

⚠️ 只拷**用得到的那两个文件**：同一个 npm 包里还有 `*.map`、`*.d.ts`、`debug/`（另一个构建），
它们对运行时没有用，进来只会让包变大、让"从哪来"变糊。
