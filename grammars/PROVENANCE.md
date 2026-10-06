# tools/grammars —— vendor 进来的 tree-sitter 语法（**不是我们的代码**）

站点的高亮在**构建期**做（`../highlight.mjs`）：用 tree-sitter 解析代码块，再按语法自带的
`queries/highlights.scm` 把节点映射到我们自己的调色板。这个目录只放**语法资产**（wasm + 查询），
运行时（`web-tree-sitter`）**也 vendor 进来了** —— 在 `../vendor/web-tree-sitter/`（2026-10-06 起；
在那之前它是 `../package.json` 里那一个 npm 依赖）。

## 为什么要 vendor 进仓库（而不是装成依赖）

1. **可复现**：生成物（`site/content/content.generated.mbt`）要能被 `gen-content.mjs --check` 逐字节复算。
   如果语法来自"本机装了什么"，同一个源在两台机器上就会出两种内容 —— `--check` 会变成假红假绿。
2. **绕开 node-gyp**：`tree-sitter-*` 这些 npm 包默认会编原生绑定（`binding.gyp`），
   在没有 MSVC/编译器的机器上 `npm install` 直接失败；我们只要 wasm。
3. **一份事实一个家**：下面这张表就是"这些二进制从哪来"的唯一出处（含 sha256）。

## 资产表

| 文件 | 来自（npm 包@版本） | 许可 | sha256（前 16 位） |
|---|---|---|---|
| `moonbit.wasm` ｜ `moonbit.highlights.scm` | `tree-sitter-moonbit@0.1.0`（**官方**：moonbitlang/tree-sitter-moonbit） | Apache-2.0 | `adc5bb9d0d995c46` ｜ `4b17f7ef5aac7e5d` |
| `bash.wasm` ｜ `bash.highlights.scm` | `tree-sitter-bash@0.25.1` | MIT | `8292919c88a0f7d3` ｜ `b74220d954f485b7` |
| `json.wasm` ｜ `json.highlights.scm` | `tree-sitter-json@0.24.8` | MIT | `d2119fb98d591271` ｜ `0511524465b56aed` |
| `javascript.wasm` ｜ `javascript.highlights.scm` | `tree-sitter-javascript@0.25.0` | MIT | `5fb488d0cabb4775` ｜ `d3630ae6dc9b2b27` |
| `toml.wasm` ｜ `toml.highlights.scm` | `@tree-sitter-grammars/tree-sitter-toml@0.7.0` | MIT | `1ac6a83826c35a68` ｜ `2fb5c61d33a70389` |

整目录 **~2.2 MB**（bash 那份最大：1.3 MB）。想核对指纹：

```bash
cd skillpress/tools/grammars
node -e "const c=require('crypto'),f=require('fs');for(const x of f.readdirSync('.').sort())console.log(x.padEnd(26),c.createHash('sha256').update(f.readFileSync(x)).digest('hex').slice(0,16))"
```

## 怎么更新（换版本时）

```bash
cd /tmp && for p in tree-sitter-moonbit tree-sitter-bash tree-sitter-json tree-sitter-toml tree-sitter-javascript; do npm pack $p; done
# 解包后只取两个文件：<包>/tree-sitter-<语言>.wasm 与 <包>/queries/highlights.scm
```

替换后**必须**做两件事：① 重跑 `node ../highlight.mjs --audit` 看召回率有没有掉；
② 重跑 `node ../gen-content.mjs` 并按 G8 的规矩复核体量变化。

> 语言到文件的映射写在 `../highlight.mjs` 的 `LANGS` 里（那是配方的家，这里是资产的家）。
