# skillpress

> **写给 AI 看的 skill，印成给人看的站点。**

skill 是一种给 AI 读的文档集合（[Anthropic 的 Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) 那个意思）：
一个目录一份 `SKILL.md`，深水区放 `references/*.md`。
问题是它**只考虑机器读者** —— 几十个目录、没有导航、没有搜索，人要通读一遍很痛苦。

skillpress 不改内容、不发明语法：它把**同一份 markdown** 印成**一个站点**，
顺手再出两份给 agent 用的产物（整站索引 + 每页原文）。
一份内容源，一次解析，三个投影 —— 站点只是它的一种排法。

| | |
|---|---|
| **MoonBit 包** | `moon add XiLaiTL/skillpress@0.1.1` |
| **宿主（JS）** | `npm install moobile-host`（站点界面是个 moobile 应用，构建时用 esbuild 打包） |
| **已实测** | 自举站点 ✅（程序自己的 `skills/` 印成站）｜内容仓 ✅（6 份 skill / 34 页原文，站点判据 23 条全绿）｜从 registry 装下来按 README 走一遍 ✅ |
| **产物形态** | 纯静态（`dist/`：HTML + 一个 bundle + 图片），扔进任何静态服务器就能跑；hash 路由 |
| **站点判据** | 23 条（起真 Chrome 无头 + 自起服务，走 CDP 真鼠标）—— ⚠️ 只能跑 native，要一次 C 工具链 |
| **许可** | Apache-2.0（内含 vendor 的 tree-sitter 运行时与五门语法资产，见 [`THIRD-PARTY-NOTICE.md`](THIRD-PARTY-NOTICE.md)） |

> ⚠️ **它今天最明显的短板**：整站**客户端渲染**，`#root` 里是空壳 —— 无 JS 打不开，
> 搜索引擎看不到正文。预渲染还没做（`PLAN.md` 里记着）。另外行内图片（不独占一行的
> `![alt](x.png)`）会被当成一条链接，整行一条才收成图片。

---

## 1. 我们自己的理念

**① 内容源就是标准 markdown，一个字节都不改。**
不发明 frontmatter 扩展、不发明 `:::` 容器、不要求你在正文里写站点才懂的东西。
换来的好处很实在：同一份 md 在 GitHub 上、在编辑器里、在 agent 手里都还是它自己；
站点上每条都留着「看原文」那条出口（`md/**` 就是逐字节拷贝）。

**② 一次解析，三个投影 —— 一个事实只允许有一个副本。**
站点内容包、`llms.txt`、每页原文出自**同一次解析**；书架树、右栏目录、搜索索引都在构建期
从同一批内容算出来。所以"站点上看到的"和"agent 读到的"结构上不可能对不上；
改了内容源只跑一条 `press`。

**③ 判据要能自己变红。**
这套东西的产物是**文字** —— 少一个空格、链接指到 404、图片静默不显示、导航少一条，
编译器不报、控制台不报。所以每条"应该成立的事"都写成一条能变红的判据，
而且尽量让判据**自己也被验过**（造一个必须红的诱饵，看它红不红）。仓库里判据比功能代码还多，
是刻意的。

**④ 不画点了没反应的东西。**
首页、上一页/下一页、书架每一行 —— 每一格都真的能到某处；算不出目标就**不画那一格**
（画一个灰箭头等于骗读者）。同理，认不出的内容构造**点名报错**，不静默吞掉。

**⑤ 界面住在包里，站点工程只接线。**
生成出来的工程 `app.mbt` 只有 19 行（把内容包交给 `@shell.site`）。
于是升级 skillpress = **所有站点一起升级**，而不是每个站点各自抄一份界面。

---

## 2. 快速上手

三段：**生成站点工程** → **装依赖并印内容** → **看**。

### 2.1 一个 `skills/` 文件夹（最常见）

```bash
# ① 在你的工程里加上 skillpress，并编一次 CLI（包里不带构建产物，所以要编这一次）
moon add XiLaiTL/skillpress
moon -C .mooncakes/XiLaiTL/skillpress build cmd/skillpress --target js

# ② 生成站点工程（写进 <内容根>/skillpress/scripts/.skillpress/）
node .mooncakes/XiLaiTL/skillpress/launcher/skillpress.mjs attach --repo . --skills ./skills

# ③ 装依赖、印内容、打包、起服务
cd skills/skillpress/scripts/.skillpress
npm install && npm run press && npm run build && npm run serve   # → http://127.0.0.1:8123/
```

要求：Node ≥ 20、[MoonBit 工具链](https://www.moonbitlang.com/download/)（`moon`）。
`attach` 是**幂等**的：第二次跑不覆盖你手改过的文件（要覆盖加 `--force`）；
它还会扫内容根、把"不上书架"的那几份写成 `skillpress.ignore.md`（**每条都要理由**，没理由就红）。

### 2.2 只有一份 skill（最小语料）

内容根长这样就够了 —— 一份 `SKILL.md`：

```markdown
<!-- skills/alpha/SKILL.md -->
---
name: alpha
description: 一句话说清这份 skill 干什么（会出现在书架上那一行）
whenToUse: 什么时候该用它
---

# alpha

正文。标题、列表、表格、引用、围栏代码块都认；
`![图](x.png)` 要**独占一行**才会被收成图片。
```

想让它同时当**站点首页**，再加一份首页源（没有就拿仓里的 `README.md` 改写一份；
两个都没有就用生成出来的模板首页 —— 每一步都会打印用了哪个）：

```markdown
<!-- skills/skillpress/WEBSITE.md —— 站点首页的源：H1 = 站名，第一个 ## 之前 = 首屏 -->
# 我的站

一句话说明这堆 skill 是干什么的。

## [从哪一份开始](../alpha/SKILL.md)

点这一栏会**直接渲染**目标那一页（纯链接节）。
```

### 2.3 看一眼站点 + 日常改内容

```bash
npm run serve            # http://127.0.0.1:8123/
npm run press:check      # 门：产物与现跑逐字节一致吗（改了内容忘了 press，它会红并指出第一处差异）
npm run build            # 默认 **prod 档**（minify）；开发用 `npm run build:dev`
node verify.mjs          # 站点判据：真 Chrome 无头 + 自起服务，23 条（要一次 native 编译）
```

---

## 3. 项目实例

| 实例 | 在哪 | 是什么 |
|---|---|---|
| **内容仓的站点** | [`../moobile/skills/skillpress/scripts/.skillpress/`](../moobile/skills/skillpress/scripts/.skillpress/) | 拿真语料（6 份 skill / 34 页原文）印的站；`verify.sh` 的 23 条判据就在它上面跑 |
| **自举站点** | [`skills/skillpress/scripts/.skillpress/`](skills/skillpress/scripts/.skillpress/) | 用**程序自己的** `skills/`（讲怎么写 skill、怎么跑门）当内容根 |
| **夹具站点** | 由判据**现搭**（`_scratch/image-check.mjs`） | 拿 `tools/fixtures/corpus/` 那份冻结语料印一遍，只为量"图片到底显示出来了没有" |

三个实例都走同一条路（`attach` → `press` → `build`），差别只有"内容源是哪一份" ——
这条比"再多写一个 demo"有用：**它证明内容换一份、代码一行不用改**。

---

## 4. 基本原理

```
   你的内容源（普通 markdown）       skills/<name>/SKILL.md + references/*.md
        │                            + 可选的首页源 skillpress/WEBSITE.md
        │  press：一次解析
        ▼
   三件产物   content/content.generated.mbt（站点的内容值）
        │     llms.txt（给 agent 的整站索引）
        │     md/**（每页原文，逐字节拷贝）+ img/**（内容里的图）
        │
        │  构建期：语法高亮（tree-sitter）已经算好，色号跟着一起进内容包
        ▼
   站点（一个 moobile 应用：TEA 的 Model/Msg/update/view）
        │  顶栏 / 书架树 / 文档页 / 右栏目录 / 搜索浮层 / 主题 / hash 路由
        ▼
   React 元素（react-native-web）──► 浏览器 DOM ──► dist/（静态站点）
```

**三个根**（改东西之前先认清，各自有自己的定位参数）：

| 根 | 是什么 | 在哪儿 |
|---|---|---|
| **程序** | 引擎 + 站点界面 + 语法资产（能发布的那份） | 本仓库根；用户那边是 `.mooncakes/XiLaiTL/skillpress` |
| **内容** | 那批 skill（`SKILL.md` + `references/`） | `--skills` 指定；生成出来的实例里**已经写死**在 `npm run press` 里 |
| **实例** | 一个「用程序」的 MoonBit 工程，`content/` 是生成物 | `<内容根>/skillpress/scripts/.skillpress/` |

**站点是怎么长出来的**：书架树 = 内容根的目录结构；右栏目录 = 每条 `##`/`###`（构建期给锚点，
滚动位置靠 moobile 的节点寻址订阅）；搜索 = 渲染期现算的索引（只在浮层打开时算一张分数表）；
上下页 = 内容里的**页序**。**没有一个地方需要你手工维护导航。**

**五条设计取舍**（决定了上面那张图）：

1. **只做投影，不做 CMS** —— 内容源是唯一真源，站点是产物，删了能重印。
2. **构建期能算的就不放到运行期** —— 高亮、目录锚点、页序、搜索词表都在 `press`/`build` 里算完。
3. **一个事实一个副本** —— 三件产物同源；同一件事要是有两份实现，迟早分叉（本仓为此删过不少"顺手再来一遍"）。
4. **判据是进程边界，不是仓库内外** —— 纯文本变换写成 `.mbtx`，碰进程的（起服务、开 Chrome）留 `.mjs`。
5. **不静默** —— 认不出的构造点名、产物不一致指出第一处差异、找不到程序根直接报错不猜。

---

## 5. 能力边界与诚实清单

| 项 | 现状 |
|---|---|
| 认的内容构造 | 标题（h2/h3/h4）/ 段落 / 列表（有序·无序·缩进）/ 表格 / 引用 / 围栏代码块（五门语言构建期上色）/ 分隔线 / 链接（站内折成页面键、站外开新窗口）/ **整行图片** |
| **不认**的构造 | 行首原始 HTML、表格缺分隔行、围栏没闭合 → **点名 + 退 2 + 不吐产物**（不落坏产物） |
| 行内标记 | 加粗 / 行内代码 / 链接 / 斜体按字面显示（`*斜体*` 不特殊处理） |
| 搜索 | `⌘K` / `Ctrl+K`；索引**渲染期现算**（内容大时会变慢，构建期索引还没做） |
| 主题 | 深/浅/跟随系统三态；配色与字号只在 `shell/theme.mbt` / `tokens.mbt` 一处 |
| 未做 | **预渲染**（首屏空壳）｜`#section` 深链｜行内图片｜`pack` 子命令（命令在，会明说"还没做"并退 2）｜原生 RN 上图片要自己给尺寸 |
| 站点判据 | 只能 native（`moonbitlang/async` 的 websocket / http-server / process 在 js 上没有实现）；js 那份 CLI 遇到 `verify` 会明说"只有 native 有"并退 2 |

判据清单（发版前一条都不能少跑）：`acceptance.sh`、`verify.sh`、`engine-fixtures.sh`、`blocks-fixtures.sh`、
`site-source.sh`、`attach-check.sh`、`native-parity.sh`、`package-check.sh`、`consumer-check.sh`、
`published-check.sh`、`fresh-clone-check.sh`、`line-budget.sh`、`shell-traps.sh`、`mbt-traps.sh`、
`queries-check.sh`、`diagnostics-ledger.sh`、`theme-check.sh`、`agent-exports.sh`。

---

## 6. 例子、文档与贡献

| 想做什么 | 去哪 |
|---|---|
| 看一个真站怎么长出来的 | [内容仓的实例](../moobile/skills/skillpress/scripts/.skillpress/) ｜ 自举实例 [`skills/skillpress/scripts/.skillpress/`](skills/skillpress/scripts/.skillpress/) |
| 用 skillpress 写内容（首页怎么写、忽略清单、目录规矩） | [`skills/skillpress/references/`](skills/skillpress/references/)（站点上也印出来了） |
| 改站点界面 / 版式 / 交互 | [`DESIGN-site.md`](DESIGN-site.md)、[`PLAN-ui.md`](PLAN-ui.md) |
| 门与内容规范（写 skill 的规矩） | [`SPEC.md`](SPEC.md)、[`SKILLS.md`](SKILLS.md) |
| 做到哪儿了 / 为什么这么做 | [`PLAN.md`](PLAN.md)（决定表 D1–D46，每条带当天读数） |
| CLI 与启动器（随包发的那两份） | [`launcher/skillpress.mjs`](launcher/skillpress.mjs)、`cmd/skillpress/` |
| 仓库里有什么（每个目录干什么） | 下面这张表 ⬇️ |

| 路径 | 是什么 |
|---|---|
| `engine/` | 引擎：markdown → 内容包、内容门（G1–G8）、构建期上色、忽略清单、脚手架 |
| `shell/` | 站点界面：顶栏 / 侧栏树 / 正文渲染 / 目录 / 搜索 / 主题 / 路由 |
| `cmd/` | CLI（`cmd/skillpress` 跑 js；`cmd/skillpress-native` 多一条 `verify`） |
| `launcher/` | **随包发**的启动器与 `press`（`tools/` 不进包 ⇒ 一份实现只能落在这儿） |
| `skills/` | **程序自己的 skill**（随包发）：怎么写一份 skill、怎么跑这几道门 |
| `template/instance/` | 站点工程的模板（`attach` 就是把它按占位符渲染出来） |
| `tools/` `_scratch/` | 判据与开发脚本（**不进发布包**） |

> 仓库里若见到 `lib/xxx.mjs` / `bin/skillpress.mjs`，那是**历史坐标**（迁移记录里的出处），
> 活实现已在 `engine/**` / `cmd/**`；迁移的完整账在 `PLAN.md` 的 D40–D46。

---

## 7. 许可证与第三方

**Apache License 2.0**，见 [`LICENSE`](LICENSE)。随包分发与编译期依赖的第三方清单在
[`THIRD-PARTY-NOTICE.md`](THIRD-PARTY-NOTICE.md)，语法资产的出处与 sha256 在
[`grammars/PROVENANCE.md`](grammars/PROVENANCE.md)。

| 东西 | 上游 | 许可 | 怎么进来的 |
|---|---|---|---|
| **tree-sitter 运行时** | [tree-sitter](https://github.com/tree-sitter/tree-sitter) | MIT | **原样 vendor**（`vendor/web-tree-sitter/`）⇒ 拿包的人**一个 npm 依赖都不用装**也能跑 `gen-file` |
| **五门语法**（moonbit / bash / json / javascript / toml） | 各家官方仓库 | Apache-2.0 / MIT | 随包发（`grammars/*.wasm` + `*.scm`），出处逐个记在 `PROVENANCE.md` |
| **mizchi/markdown** | <https://github.com/mizchi/markdown> | MIT | MoonBit 依赖：内容管线的 markdown 解析 |
| **XiLaiTL/moobile** | 本机另一个仓（[`../moobile`](../moobile)） | Apache-2.0 | MoonBit 依赖：站点界面本身是个 moobile 应用 |
| **React / react-native-web / esbuild** | Meta / Nicolas Gallagher / evanw | MIT | 站点工程构建期与运行期的 npm 依赖（由生成出来的 `package.json` 拉） |
