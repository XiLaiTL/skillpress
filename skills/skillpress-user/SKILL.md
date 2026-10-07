---
name: skillpress-user
description: 用 skillpress 把一份或多份 skill 印成一个站点：起站点、写主页、改配色与字号、加一块新内容构造、预览与验收。这是「用这套工具的人」那一侧。
whenToUse: 你要**用** skillpress 做站点（一份 skill 变网站 / 多份 skill 变网站、写首页、换配色与字体、加一块新构造或新页面、跑起来看效果、验收改完的站点），而不是改 skillpress 本身（那一侧是另一份 skill：`skillpress-dev`）。
---

# skillpress 用户 —— 把 skill 印成站点

**一句话**：内容只有一份（一堆 `SKILL.md`），站点是它的投影 —— 而**首页也是其中一份 skill**。

三条命令（在**内容仓根**跑；程序是它旁边的兄弟 `../skillpress/`）：

```bash
node ../skillpress/tools/press.mjs press              # 内容源 → 站点的内容包（生成物）
node ../skillpress/tools/press.mjs --check            # 门：生成物与源一致吗
bash ../skillpress/tools/verify.sh                   # 判据：23 条（真 Chrome；要一次 native 编译）
```

站点判据的**现役**那一份是 `skillpress-native verify`（真 Chrome 无头 + CDP，23 条）——
⚠️ **只有 native 那份有**（要一次 C 工具链）：站点判据要 async 的 http server / websocket /
process，而它们在 `moonbitlang/async` 的 js 目标上没有实现。**实例里最省事的是 `npm run verify`**
（实例的 `verify.mjs` 会把"引擎在哪、本实例在哪"接上去，找不到就明说 SKIP）。

> 在**程序仓根**跑同一份程序就是 `node tools/run-js.mjs …` / `bash tools/verify.sh`。内容仓不在兄弟位置时，
> 用 `--repo <内容仓根>` 或 `SKILLPRESS_REPO` 显式指定 —— **它不猜**（猜错的表现是"站点没更新"）。

⚠️ **今天要不要 Node**：日常要 —— 上面这三条走的是**源码路径 + Node 启动器**。
native 那一侧**已经验过**：`moon install ./cmd/skillpress-native` 装出来的是**本机可执行件（零 Node）**，
装出来的那支 release 二进制跑 `gen-file`，产物与 js **逐字节一致**（判据 `bash tools/native-parity.sh` 钉着）。
⚠️ 但它有**两处必须显式给的东西**：吃到 `check` / `attach` 时**要给程序根**
（`--program <程序根>` 或 `SKILLPRESS_PROGRAM=<程序根>`）—— `moon install` 把可执行件放进 `~/.moon/bin/`，
程序数据（`claims.txt` / `skills.lock.json` / `template/`）不在它旁边，而 **native 不猜**；
不给会先说一句「程序根没给（native 不猜）」再照常跑门。两条路今天都能走，日常仍以 Node 这条为准
（`moon install` 走的是 release 构建，慢一档）。

## 一、怎么落一个站点

**一条命令**（脚手架，P9 已落地）：

```bash
node tools/run-js.mjs attach --repo <仓根> --skills <内容根>      [--ignore "<名字>=<理由>"]… [--home <README 路径>] [--force] [--dry-run]
```

它扫内容根 → 问（或按 `--ignore` 收）哪几份**不上书架**（每条都要**理由**）→ 首页源取
`<仓根>/README.md`（复制 + 改写）→ 写整套 `skills/skillpress/{SKILL.md, WEBSITE.md, scripts/.skillpress/**}`。
**幂等**、**不覆盖人写的东西**（要覆盖加 `--force`）、**算不出来就一个字节都不写**。
⚠️ `pack`（打成便携目录）**还没做**。

要**特化**那个实例（换模块名、加能力包）时才手工改下面这些 —— 它们都由脚手架生成，别再抄一份：

| 实例里的东西 | 是什么 | 你要动它吗 |
|---|---|---|
| `app.mbt` | **只剩接线**（界面 P6 起住在程序包的 `shell/` 里） | 基本不用动；改外观看 `shell/theme.mbt` |
| `content/` | **生成物**（`press` 写的），别手改 | 不动 |
| `index.html` / `index.js` / `App.js` | 静态宿主三件 | 一般不动 |
| `build-web.mjs` / `serve-web.mjs` | esbuild 打包 / 零依赖静态服务 | 一般不动 |
| `moon.mod` / `moon.pkg` | 独立 MoonBit 模块（依赖 `XiLaiTL/moobile`） | 换依赖时动 |
| `package.json` | `file:` 依赖宿主 + `SKILLPRESS_ENGINE` 指向程序 | 换机器/换路径时动 |

现成的一份在：`<内容仓>/skills/skillpress/scripts/.skillpress/`。
一个 skill / 多个 skill 各自要动什么、哪些名字写死 —— 见 `references/make-a-site.md`。

## 二、内容怎么组织（站点结构 = 目录结构）

| 你放什么 | 站点上变成什么 |
|---|---|
| `<内容根>/skillpress/SKILL.md` | **首页**（**回退**那一档）：H1 = 站名与大标题，首个 `##` 之前 = 首屏引言。✅ R2 已落地：首页源**优先** `<内容根>/skillpress/WEBSITE.md`，没有它才回退到 `SKILL.md`（`--home` 可显式指一份；判据 `tools/site-source.sh`）。首页那份 `SKILL.md` 讲工具本身。 |
| 首页里 **`## [名字](目标)`**（整条是链接） | 顶栏的**一条导航**：点了**跳页**，直接渲染目标那一份（认不出目标就报错） |
| 首页里**普通 `##`**（不是链接） | ⚠️ **不进顶栏**，正文今天**也不上首页**：想让人看到就写进首屏（首个 `##` 之前），或做成一页再用链接节指过去 |
| `<内容根>/<别的名字>/SKILL.md` | 文档区里的**一份 skill**（侧栏按名字排序） |
| `references/*.md` ｜ `FAQ.md` ｜ `scripts/*` | 那份 skill 的**子页**（树上展开） |

三条会咬人的：

- **顶栏只有"点了真会到某处"的才画**：结构性三条（首页 / 书架 / 搜索）+ 首页里**带目标**的那些 `##`
  ⇒ 栏名要**短**（序号会被剥掉；细则放正文第一句），长标题会把顶栏挤爆。
- `#`（H1）**不进正文**：它被抽成站名与首屏大标题。

## 三、改外观：改哪儿、别改哪儿

| 想改 | 去哪 |
|---|---|
| 配色 / 字号 / 间距 | 程序的 `shell/tokens.mbt`（**设计 token 的唯一来源**：调色板 `Palette` + 字号/行高）与 `shell/theme.mbt`（明暗 × 三态偏好 → `Theme` 值）。⚠️ **不是实例的 `app.mbt`** —— 那里只剩接线，以前那组 `c_bg` / `c_ink` / `c_head` 常量**已经不存在了** |
| 代码块**颜色** | 程序 `engine/highlight/hl.mbt` 产的色号 ↔ `shell/theme.mbt` 的 `Theme::tok_color`：**索引两边对齐，改要一起改** |
| 页面骨架（顶栏 / 侧栏 / 正文） | 程序的 `shell/`（`site.mbt` 的 `view()`、`article.mbt`、`sidebar.mbt`…）；⚠️ 实例的 `app.mbt` 只剩 19 行接线（判据 A2 钉着"≤20 行"）。顶栏栏位由内容决定，**别写死** |
| 一块**新构造**（图片 / 折叠…） | 两边一起改：`engine/content/blocks.mbt` 解析 + `shell/` 渲染（解析边界刻意窄，见 refs） |

⚠️ **不许手改 `content/content.generated.mbt`**（生成物）。改了内容源就重跑 `press`；
生成物与源不一致时 `press --check` 会红，并指出**第一处差异**。

## 四、验收（改完做什么）

| 改了什么 | 跑什么 | 红了怎么办 |
|---|---|---|
| 任何内容源（`SKILL.md` / `references/**`） | `press` → `press --check` | 别手改生成物 |
| 内容源（体量 / 条目数变了） | `check`（G8 要你复核体量 → `check --update-lock <名字>`） | 复核，不是"让门变绿" |
| 站点界面（`app.mbt`） | `npm run build` → `verify` | **先修应用**，不许放宽判据 |
| 代码块多了 / 改了 | `audit`（召回率与漏色比例越线即红） | 别把阈值调松 |

看效果（实例目录里）：`npm install && npm run build && npm run serve` → `http://127.0.0.1:8123/`。

## 五、坑（都是踩出来的）

| 现象 | 真因 | 处置 |
|---|---|---|
| frontmatter 三字段"突然全没了" | 文件是 CRLF，`(.*)$` 匹配不到行尾的 `\r` | 一律 LF（程序的 G2 会拦） |
| 改了内容源，站点没变 | 忘了重跑 `press` | 跑 `press --check`，它指出第一处差异 |
| 点那一栏"没反应" | 合成 `click()` 在 web 上不触发 `Pressable`（它走 responder） | 判据要用真鼠标事件（`verify` 已这么干） |
| 顶栏挤成两行 / 有条栏位跑到屏幕外 | 首页 `##` 名字太长、条数太多（顶栏是**一行**，靠横向滚动） | 栏名写短；栏位别无限加 |
| 一大片代码块上不了色 | 片段不是合法代码，tree-sitter 落在 ERROR 区（里面拿不到 capture） | 程序会自动试几种**包装**；仍不行见 `../skillpress-dev/references/pipeline.md` |
| 内容里写图片 / 原始 HTML 直接报错 | 解析边界**刻意窄**（只收实际用到的构造，不静默丢内容） | 换写法，或按 §三 两边一起加构造 |
| 窄屏上顶栏挤 | 折叠菜单还没做 | 现状：宽屏优先 |

## 六、还没做（别当成已支持）

`pack`（一组 skill → 便携目录）｜ 首页里 `##` 的正文不上首页 ｜ 页内锚点的深链（`#section`）｜
窄屏顶栏的折叠菜单 ｜ 预渲染（整站客户端渲染，`#root` 是空壳；搜索索引也在渲染期现算）。
（本页目录 / 站内搜索 / 书架树 / `attach` / "界面抽成 `shell` 包"**都已经落地** —— 别再把它们列进"还没做"。）

这些会变，**别当契约** —— 去程序的 `PLAN.md` 看。

## 七、指针

| 要什么 | 去哪 |
|---|---|
| 一份 / 多份 skill 到站点的完整步骤、哪些名字写死 | `references/make-a-site.md` |
| 主页怎么写、样式与构造怎么改 | `references/home-and-styles.md` |
| 投影规范：收录判据 / 结构 / 预算 / 站点边界 | 程序 `SPEC.md`（§2 / §3 / §8） |
| 集合划分、产出顺序 | 程序 `SKILLS.md` |
| 计划与未做 | 程序 `PLAN.md` |
| 目录形状（程序 / 内容 / 实例四个根、两种布局） | 另一份 skill `skillpress-dev`（程序侧）：`skills/skillpress-dev/references/roots.md` |
| 站点管线内部（数据形状、两种模式、上色细则） | 同上（程序侧）：`skills/skillpress-dev/references/pipeline.md` |
| 改**程序本身**（引擎 / 门 / 判据） | 另一份 skill：`skillpress-dev` |
