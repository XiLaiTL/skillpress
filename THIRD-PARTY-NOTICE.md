# THIRD-PARTY-NOTICE —— 第三方资产与署名

本模块（`XiLaiTL/skillpress`）**随包分发第三方资产**：vendor 进来的 tree-sitter 语法
（编译好的 `.wasm` 与查询 `.scm`）。按各自许可的要求，这里保留出处与许可声明。

> **会漂的数字不抄进本文**：版本、sha256、文件条数一律以 [`grammars/PROVENANCE.md`](grammars/PROVENANCE.md)
> 为准（那是一张机器可核对的表）。本文只写"是谁的、什么许可、分发形态"。

---

## 1. 语法资产（**随包分发**，`grammars/`）

`grammars/` 里的 `.wasm` 是**第三方编译产物**，我们**原样 vendor、未做修改**；`.scm` 是它们自带的查询文件。
运行期用的解析库是 `web-tree-sitter` —— 它**与语法一起随包 vendor**（`vendor/web-tree-sitter/`）。
逐文件的出处、版本与 sha256 见 `grammars/PROVENANCE.md` 与 `vendor/web-tree-sitter/PROVENANCE.md`。

| 项目 | 上游 | 许可 |
|---|---|---|
| **tree-sitter-moonbit** | <https://github.com/moonbitlang/tree-sitter-moonbit>（官方） | **Apache License 2.0** |
| **tree-sitter-bash** | <https://github.com/tree-sitter/tree-sitter-bash> | MIT |
| **tree-sitter-json** | <https://github.com/tree-sitter/tree-sitter-json> | MIT |
| **tree-sitter-javascript** | <https://github.com/tree-sitter/tree-sitter-javascript> | MIT |
| **@tree-sitter-grammars/tree-sitter-toml** | <https://github.com/tree-sitter-grammars/tree-sitter-toml> | MIT |

分发形态：
- **源码分发**：本仓库**含**这些资产（与 moobile 那边的第三方 fork 不同 —— 那些是生成物、不进仓；
  这几份是**必须逐字节稳定**的输入：生成物要与内容源逐字节对齐，语法资产的来源不能"看本机装了什么"）。
- **制品分发**：`moon package` 打出的包**包含** `grammars/**`，消费者拿到的仍是上述各家的许可物。

## 2. 编译期依赖（**不随本站包分发**，由注册表解析）

| 项目 | 上游 | 许可 | 说明 |
|---|---|---|---|
| **mizchi/markdown** | <https://github.com/mizchi/markdown> | MIT | 内容管线的 markdown 解析（`SPEC` 里"解析边界"那套的底层） |
| **web-tree-sitter**（npm，**已随包 vendor**） | <https://github.com/tree-sitter/tree-sitter> | MIT | js target 的**运行期**：薄垫片透过它跑查询（见 `engine/highlight/ts_shim.mbt`）。**原样 vendor 未修改**（`vendor/web-tree-sitter/`，含它自己的 LICENSE + sha256），所以"0 npm"成立 |

⚠️ 前一条（`mizchi/markdown`）是**依赖**：由 mooncakes 按 `moon.mod` 的声明解析。
后一条（`web-tree-sitter`）从 2026-10-06 起**随包分发**了（原样 vendor）⇒ 拿到包的人**一个 npm 依赖都不用装**。
（`package.json` 里那条依赖今天只为**本仓的旧实现**留着：判据要跑冻结的 `lib/*.mjs` 现场产出基准。）

## 3. 我们自己的东西

其余全部为原创：`engine/**`（内容管线 / 上色 / 薄垫片）、`cmd/**`、`lib/*.mjs`（旧实现，冻结中）、
`skills/**`（程序自己的两份 skill）、`SPEC.md` 等规范与账本。许可见根上的 [`LICENSE`](LICENSE)（Apache-2.0）。
