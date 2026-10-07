# 夹具语料（`tools/fixtures/`）

**用途**：给引擎的语料级判据当**不会腐的参照物**。

## 为什么需要它

迁移期那几条对账判据（`file-parity` / `blocks-parity` / `highlight-parity` / `site-parity` / `site-corpus-parity`，**已随 `lib/` 退役**）比的是
"**新引擎 vs 冻结的旧实现**，现场各跑一遍"。那套做法的参照物 `lib/*.mjs` 一旦退役，
三条判据就同时失去参照物与一端 —— 而**引擎仍然需要语料级的回归覆盖**：
改了 `engine/content` 或 `engine/highlight`，总得有人盯着产物变没变。

于是参照物换成**入库的 golden**：语料冻结在本仓、期望值也冻结 ⇒
输入不变、期望不变，**不会像 D29 那次那样"基线自己腐掉"**（那次腐是因为基线绑在会变的内容仓上）。

## 三份 golden 从哪来

采 golden **之前**，先让两边在这份夹具上做过逐字节对账（都绿）：

| 读数 | 迁移期判据（**已随 `lib/` 退役**） | 夹具上的读数 |
|---|---|---|
| 整份生成物 | `file-parity` | 159 行（归一化后）逐字节一致 |
| 文档块 | `blocks-parity` | 5 段逐字节一致 |
| 上色 | `highlight-parity` | 6 个代码块逐字节一致 |

⇒ golden 采的是"**两个引擎都同意的那份产物**"，而不是"某一侧说得算"。

## 目录

| 路径 | 是什么 |
|---|---|
| `corpus/skills/` | **冻结语料**：4 份 skill / 7 个 md。刻意**不放** `WEBSITE.md`、上一级也**不放**忽略清单 —— 这样新旧两个引擎读的是同一份内容（与 `tools/mk-parity-corpus.sh` 造副本要达成的状态一致，只是这里从源头就是干净的） |
| `expected/gen-file.mbt` | `gen-file` 的期望产物（174 行） |
| `expected/dump-blocks.txt` | `dump-blocks` 的期望读数（43 行） |
| `expected/batch.txt` | `batch` 的上色读数（13 行，头一列已归一化掉本机路径） |

判据：`bash tools/engine-fixtures.sh`（`--selftest` 四向诱饵；`--capture` 重新采）。

## 语料覆盖了什么

- 首页源（`skillpress/SKILL.md`）：`##` 分栏、纯链接节、表格、带行内标记的段落
- 子页发现：`references/` + **更深一层**的 `references/deep/`（验"任何子目录里的 md 都收"）
- 子页标题的两条规矩：有 `title:` 用它、没有退到第一个 `#` 标题
- `scripts/` 下的非 md（验"脚本也是一种 kid"）
- 跨 skill 的链接，以及**两条链接解析规矩**（首页目录相对 / 内容仓相对相对）
- 五种语言的代码块（bash / json / javascript / moonbit / toml），且写得**有东西可上色**

## 诚实的边角

`javascript` 与 `toml` 这两块在**当前**这套 query 下 `dark=0`（一个 capture 都没命中）——
**新旧两个引擎在这件事上是一致的**（都 0），所以它不是这次迁移引入的偏差。
留着它有个副作用：这两门语言的"上色退步"在 `batch` 那一列上**看不出来**
（0 → 0 没有变化）。它们真正的防线是 `dump-blocks`：那里比的是**块的正文与色号逐个**，逐字节。
