# skillpress

**把一堆写给 AI 看的 skill，印成一个给人看的站点。**

出发点是一条判断：**产品文档、用户手册、内部规范，以后都会以 skill 的形态存在** ——
一个目录、一份 `SKILL.md`、深水区放 `references/`，agent 拿来即用；**不会再有"另外一份给人看的 docs"**。

这条判断一旦成立，立刻冒出一个问题：**那人怎么办？** 写这些文档的是人、复核的是人、
拿去指给同事看的也是人 —— 而 skill 天生是给 agent 的形态：几十个目录散着、没有导航、没有搜索。
现实里于是必然长出"给人另写一份手册"，两份内容源从此开始漂，而且没人知道哪份是对的。

skillpress 的主张就一句：**同一份 skill，人机共读。**
机器拿它的原形态（`SKILL.md` / 每页原文 `md/**` / 整站索引 `llms.txt`），人拿一个站点；
两边出自**同一次解析** —— 站点不是第二份内容：删掉它不丢任何东西，改内容永远只改一处。

![站点文档页：左侧书架树 / 正文 / 右栏本页目录](assets/site-doc.png)

上面这个站是拿这套工具**自己的 skill** 印的（自举实例：
[`skills/skillpress/scripts/.skillpress/`](skills/skillpress/scripts/.skillpress/)）。首页：

![站点首页](assets/site-home.png)

**它适合你，如果你**：已经（或打算）把文档写成"一个目录 + 一份 `SKILL.md`"，并且想让同事
能点开一个站看 —— 而不是为此再维护第二份"给人看的文档"。
**它不适合你，如果你要**：能被搜索引擎抓到正文的官网、博客、或者任何需要服务端的东西。
站点是整站客户端渲染的，原因与代价写在下面「今天做不到什么」。

| | |
|---|---|
| 要装什么 | Node ≥ 20 与 [MoonBit 工具链](https://www.moonbitlang.com/download/)；跑站点判据另需 Chrome 与一次 C 工具链 |
| 拿到什么 | 纯静态 `dist/`（HTML + 一个 bundle + 图片），hash 路由 ⇒ 扔进任何静态服务器就能跑，不需要服务端回退规则 |
| 怎么装 | `moon add XiLaiTL/skillpress@0.1.1` |
| 许可 | Apache-2.0（内含随包发的 tree-sitter 运行时与五门语法，见 [`THIRD-PARTY-NOTICE.md`](THIRD-PARTY-NOTICE.md)） |

## 快速上手

前提：你的工程里有一个 `skills/` 目录，里面**至少有一份** `SKILL.md`。

```bash
# ① 装包，并编一次 CLI（包里不带构建产物，这一步省不掉）
moon add XiLaiTL/skillpress
moon -C .mooncakes/XiLaiTL/skillpress build cmd/skillpress --target js

# ② 生成站点工程（写进 <内容根>/skillpress/scripts/.skillpress/）
node .mooncakes/XiLaiTL/skillpress/launcher/skillpress.mjs attach --repo . --skills ./skills

# ③ 印内容 → 打包 → 起服务
cd skills/skillpress/scripts/.skillpress
npm install && npm run press && npm run build && npm run serve     # → http://127.0.0.1:8123/
```

第 ③ 步里写成 `skills/…`，是因为第 ② 步给的内容根是 `./skills`；内容根换到别处，站点工程就
跟着落在那个目录下的 `skillpress/scripts/.skillpress/`。第一次 `npm install` 要下
esbuild / react / react-native-web，慢一点。

`attach` 是**幂等**的：第二次跑**不覆盖**你手改过的文件（要覆盖加 `--force`）。它还会扫一遍
内容根，把"不上书架"的那几份连同**每一条的理由**写进 `skillpress.ignore.md`（没写理由就报错）。

改完内容之后：

```bash
npm run press:check   # 产物与内容源对得上吗 —— 忘了重跑 press 时它会红，并指出第一处差异
npm run build         # 重新打包（默认 minify；开发用 npm run build:dev）
```

**部署**：把 `dist/` 整个拷过去就行（GitHub Pages / Netlify / 公司内网 nginx）—— 路由在 `#`
后面，不需要 404 回退规则。

## 它会往你的仓库里加什么

`attach` 只**新建/更新**下面这些（你自己的 `skills/` 原地不动）：

```
你的仓库/
├─ skills/                                   ← 内容根（你的，本来就有）
│  ├─ alpha/SKILL.md                         ← 一份 skill
│  └─ skillpress/                            ← attach 新建的那个目录
│     ├─ SKILL.md                            ← 门口那份：这套工具自己的说明书
│     ├─ WEBSITE.md                          ← **站点首页源**（有 README.md 就按它改写一份）
│     └─ scripts/.skillpress/                ← **站点工程**（一个独立的 MoonBit 工程）
└─ skillpress.ignore.md                      ← 哪几份不上书架 + **每一条的理由**（一份都没忽略就不写）
```

站点工程里一共 **18 个文件**：模板写出 16 个，`press` 生成 1 个，`npm install` 落 1 个。

| 文件 | 是什么 | 你会动它吗 |
|---|---|---|
| `app.mbt` `moon.pkg` `moon.mod` `moon.work` | MoonBit 工程四件（依赖 `XiLaiTL/skillpress` + `XiLaiTL/moobile`） | 几乎不动 |
| `content/moon.pkg` + `content/content.generated.mbt` | 内容包；`content.generated.mbt` 是 `press` 写的**生成物** | ❌ 别手改（下次 `press` 就抹掉） |
| `index.html` `index.js` `App.js` `registry.generated.js` | 静态宿主四件（`#root` + 挂载 + 能力注册表） | 改网页标题才动 `index.html` |
| `build-web.mjs` `serve-web.mjs` | 打包（esbuild）／零依赖静态服务 | 一般不动 |
| `engine.mjs` | 转发壳：`npm run press` 经它找程序根 | 程序搬家时才动 |
| `package.json` `package-lock.json` `.gitignore` | npm 三件（`press` / `press:check` / `build` / `serve` / `verify` 脚本在这儿） | 加依赖时动 |
| `verify.mjs` | 站点判据入口（**委托**给程序里那份 native CLI） | 一般不动 |
| `README.md` | 这个工程自己的说明（生成时就带着） | 随便改（`attach` 不覆盖已存在的） |

**哪些进版本库**：只有 `content/content.generated.mbt` 要（工程才编得起来）。
`node_modules/` `_build/` `dist/` `moobile.js` 都进了生成出来的 `.gitignore`。

## 首页源 `WEBSITE.md`：写什么 → 站上变成什么

首页也是一份 skill，只是名字固定。下面是这个仓库**自己的**首页源（真的，不是示例）：

```markdown
# skillpress —— 改它的人和用它的人        ← H1：站名（顶栏左侧 + 首页大标题 + <title>）

我们相信**文档的形态会变成 skill**……      ← 首个 ## 之前的段落 = 首页首屏（导语）

## [先读哪一份](../skillpress-user/SKILL.md)   ← 整条是链接 ⇒ 顶栏一条导航
## [怎么改这套程序](../skillpress-dev/SKILL.md)
```

它会变成：

| 首页源里的东西 | 站上变成 |
|---|---|
| `# 站名` | 顶栏左侧那一条 + 首页大标题 + 网页 `<title>` |
| 第一个 `##` 之前的段落 | 首页首屏的导语 |
| `## [标题](目标.md)`（**整条**是链接） | 顶栏多一条导航；**点它直接渲染目标那一页**（是跳页，不是换正文的哪一节） |
| 普通 `##`（不是链接） | ⚠️ **不进顶栏**，正文**也不上首页**（见「今天做不到什么」） |
| ——（自动加） | 统计行（几份 skill / 几个子页）+ 两张入口卡（从哪开始 / 书架）+ 页脚（构建时间、许可、内容根指纹） |

⚠️ 判定很严：**只有标题整条是链接**才算；目标按"相对首页那份 skill 的目录"解析，
**认不出来就报错**（不给你一个静默的死链）。首页源**不存在**时的回退链（每一步都会打印用了哪个）：
`skillpress/WEBSITE.md` → `skillpress/SKILL.md` → （`attach` 生成时）仓根 `README.md` 改写一份 → 模板首页。

首页源和别的 skill 一样，写法细节见 [`skills/skillpress-user/SKILL.md`](skills/skillpress-user/SKILL.md)。

## 正文能写什么

一份 skill = 一个目录 + `SKILL.md`（frontmatter 三字段 `name` / `description` / `whenToUse`），
深水区放 `references/*.md`，它们会变成这份 skill 的子页。

| 内容里写的 | 站上变成 | 备注 |
|---|---|---|
| `#` H1 | 页面主标题 | 子页靠它取名；在**首页源**里它被抽成站名与首屏大标题，不进正文 |
| `##` / `###` / `####` | 章节标题（三级字号） | 只有 `##` / `###` 进**右栏本页目录**（`####` 不算） |
| 段落 ｜ `-` `*` `1.` 列表 ｜ `>` 引用 | 正文段落 / 列表（支持缩进层级）/ 引用 | |
| 表格 | 表格 | ⚠️ 列宽等分、**不能横向滚**（列多会挤） |
| ` ```lang ` 代码块 | 代码块 + **工具条**（语言标签 + 复制按钮） | 构建期上色（moonbit / bash / json / javascript / toml）；长行折行 |
| `---` | 分隔线 | |
| `![alt](x.png)` **独占一行** | 图片（真 `<img>`，宽度自适应） | `press` 把图拷进 `img/` 并逐字节核对 |
| 链接 `[文字](目标.md)` | 可点链接 | 站内目标折成页面键 ⇒ **不刷新**跳页；站外 ⇒ 开新窗口 |
| 行内 `` `code` `` ｜ `**加粗**` | 行内代码 ｜ 加粗 | ⚠️ 行内代码**只有字体与颜色、没有底色** |
| `*斜体*` | **按字面显示**（不特殊处理） | 已知缺口 |
| 行首原始 HTML ｜ 表格缺分隔行 ｜ 围栏没闭合 | ❌ **点名 + 退 2 + 不吐产物** | 认不出的构造不静默 |

## 站点上有什么

| 部位 | 有什么 |
|---|---|
| 顶栏 | 站名（回首页）· 首页 / 书架 / 搜索 · 深 / 浅 / 跟随系统三态开关 |
| 首页 | 站名大标题 + 导语 + 统计行 + 两张入口卡（都**真能到某处**，到不了就不画） |
| 书架页 | 左侧一棵树：每份 skill 一行（名字 + 摘要），点箭头展开 `references/` 与 `scripts/` |
| 文档页 | 标题 + 摘要 + 「何时用它」+ 正文 + **右栏本页目录**（滚到哪高亮到哪）+ 面包屑 + 上一页 / 下一页 |
| 搜索 | `⌘K` / `Ctrl+K` 浮层，输入即筛；命中分「整页 / 某一节」，点一下切页并跳到那一节 |
| 窄屏 | 侧栏收进抽屉（贴边按钮唤出），不是把三栏硬挤进一屏 |
| URL | hash 路由：`#/`、`#/shelf/`、`#/s/<skill>/`、`#/s/<skill>/<子页>/`；刷新与后退都正常 |
| 页脚 | 构建时间（构建期注入）、许可（来自实例 `moon.mod` 的 `license`）、内容根指纹 |
| 给 agent 的两个出口 | `llms.txt`（整站索引）+ `md/**`（每页原文，逐字节拷贝），与站点**同一次解析**产出 |

## 我们的 CLI

**同一个 CLI，两个入口** —— 逻辑只有一份（`cmd/skillpress/cli/`），差别只在宿主：

| 入口 | 怎么调 | 要什么 | 多什么 |
|---|---|---|---|
| **js**（日常就用这个） | `node <包>/launcher/skillpress.mjs <命令> …`；本仓开发期是 `node tools/run-js.mjs <命令>` | Node ≥ 20 + 编一次的 js 产物 | —— |
| **native**（判据 / 零 Node） | `moon install ./cmd/skillpress-native --bin <目录>` ⇒ 跑 `skillpress-native <命令>` | 一次 C 工具链 | **`verify`**（站点判据 23 条）与 `dump-corpus` |

日常真正会用到的只有这几条（`<包>` = `.mooncakes/XiLaiTL/skillpress`）：

```bash
node <包>/launcher/skillpress.mjs check --repo . --skills ./skills   # 门：内容本身（G1–G8）
node <包>/launcher/skillpress.mjs gen-file ./skills                  # 内容包 → stdout（可以直接看）
node <包>/launcher/skillpress.mjs gen-file ./skills --llms           # 同一份解析产出的 llms.txt
node <包>/launcher/skillpress.mjs attach --repo . --skills ./skills  # 生成/更新站点工程
node <包>/launcher/skillpress.mjs gen-queries --check                # 语法资产与内嵌 query 同源吗
```

站点工程里那几条 npm 脚本就是它们的封装：`npm run press`（= `gen-file` 写进实例）、
`press:check`、`build`、`serve`、`verify`。

其余子命令（调试用的 `hl` / `batch` / `audit` / `dump-blocks` / `dump-corpus`，以及还没做的
`pack`）在上表两个入口的完整清单里 → [`CONTRIBUTING.md`](CONTRIBUTING.md) §6。
**退出码是有约定的**，别忽略：`0` 通过 ｜ `1` 门/判据有红（会列出是哪几条）｜ `2` 用法错或内容解不开
（认不出的子命令、`pack` 还没做、内容根不存在……**一律不吐产物**）。

## 改外观

配色、字号、间距都在程序包里：`shell/tokens.mbt`（设计 token 的唯一来源）与 `shell/theme.mbt`。
界面也住在程序包里（生成出来的 `app.mbt` 只有 19 行接线），所以升级 skillpress =
所有站点一起升级，而不是每个站点各自抄一份界面。

## 今天做不到什么（先看这段，再决定用不用）

| 做不到 | 代价 |
|---|---|
| **没有预渲染** | 整站客户端渲染，`#root` 里是空壳：没有 JS 打不开，搜索引擎抓不到正文 |
| **首页里普通 `##` 的正文不上首页** | 首页只渲染 H1、导语、统计行与两张入口卡。想让首页出现某段话：写进导语，或者做成一页再用链接节指过去 |
| 页内锚点的深链（`#section`） | 右栏目录能跳，但地址栏里没有那一节的位置，没法直接分享"跳到某一段"的链接 |
| `*斜体*` 与行内图片 | 按字面 / 按原文处理（内容源里不发明语法，所以宁可不支持某个效果） |
| 表格列多了会挤 | 列宽等分、不能横向滚动 |
| bundle 偏大 | minify 后约 680 KB（gzip 后约 200 KB），大头是 react-native-web |
| 搜索索引在**渲染期现算** | 内容很大时会变慢（构建期索引还没做） |
| 站点判据只有 native 那份有 | `verify` 要 Chrome + 一次 C 工具链；js 那条路会**明说"只有 native 有"并退 2** |
| `pack`（打成便携目录） | 还没做：命令会说清"还没做" + 退 2，不假装跑过 |

## 自己验证

```bash
npm run press:check   # 生成物与内容源逐字节一致
npm run verify        # 站点判据：自起服务 + 真 Chrome 无头 + 23 条断言（要一次 native 编译）
```

那 23 条每条都对应一种**会安静发生**的失败：导航少一条、图片没显示、控制台报错、代码块没上色……
产物是文字，编译器不会替你发现这些。

## 仓库里有什么

| 路径 | 是什么 |
|---|---|
| `engine/` | 引擎：markdown → 内容包、内容门（G1–G8）、构建期上色 |
| `shell/` | 站点界面：顶栏 / 书架树 / 正文渲染 / 目录 / 搜索 / 主题 / 路由 |
| `cmd/` ｜ `launcher/` | CLI；随包发的启动器与 `press` |
| `template/instance/` | 站点工程模板（`attach` 就是把它按占位符渲染出来） |
| `skills/skillpress-user/` | 「用这套工具」那份 skill（写法与验收） |
| `skills/skillpress-dev/` | 「改这套程序」那份 skill（四个根、门、管线） |
| `grammars/` ｜ `vendor/` | 五门语法资产与 tree-sitter 运行时，都随包发 |

## 更多文档

| 想干什么 | 去哪 |
|---|---|
| 用这套工具做站点 / 写首页 / 换配色 / 加构造 | [`skills/skillpress-user/SKILL.md`](skills/skillpress-user/SKILL.md) |
| 改这套程序（引擎 / 门 / 判据 / 发版） | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| 投影规范：收录判据 / 一个 skill 的固定结构 / 预算 | [`SPEC.md`](SPEC.md) |
| 集合划分：哪些内容该做成 skill | [`SKILLS.md`](SKILLS.md) |
| 做到哪儿了、为什么这么做（决定表，每条带当天读数） | [`PLAN.md`](PLAN.md) |
| 站点界面 / 版式 / 交互的设计 | [`DESIGN-site.md`](DESIGN-site.md)、[`PLAN-ui.md`](PLAN-ui.md) |
| 文档与代码不一致的账、怎么防漂 | [`DRIFT.md`](DRIFT.md) |

## 许可

Apache License 2.0，见 [`LICENSE`](LICENSE)。第三方清单在
[`THIRD-PARTY-NOTICE.md`](THIRD-PARTY-NOTICE.md)，五门语法资产的版本与 sha256 在
[`grammars/PROVENANCE.md`](grammars/PROVENANCE.md)。
