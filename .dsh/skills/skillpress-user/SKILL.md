---
name: skillpress-user
description: 用 skillpress 把一份或多份 skill 印成一个站点：起站点、写主页、改配色与字号、加一块新内容构造、预览与验收。这是「用这套工具的人」那一侧。
whenToUse: 你要**用** skillpress 做站点（一份 skill 变网站 / 多份 skill 变网站、写首页、换配色与字体、加一块新构造或新页面、跑起来看效果、验收改完的站点），而不是改 skillpress 本身（那一侧是另一份 skill：`skillpress-dev`）。
---

# skillpress 用户 —— 把 skill 印成站点

**一句话**：内容只有一份（一堆 `SKILL.md`），站点是它的投影 —— 而**首页也是其中一份 skill**。

三条命令（在**内容仓根**跑；程序是它旁边的兄弟 `../skillpress/`）：

```bash
node ../skillpress/bin/skillpress.mjs press          # 内容源 → 站点的内容包（生成物）
node ../skillpress/bin/skillpress.mjs press --check  # 门：生成物与源一致吗
node ../skillpress/bin/skillpress.mjs verify         # 判据：真 Chrome 无头，自起服务
```

> 在**程序仓根**跑同一份程序就是 `node bin/skillpress.mjs …`。内容仓不在兄弟位置时，
> 用 `--repo <内容仓根>` 或 `SKILLPRESS_REPO` 显式指定 —— **它不猜**（猜错的表现是"站点没更新"）。

## 一、今天怎么落一个站点（现状，别当成"已支持"）

⚠️ **`pack` / `attach` 还没做** —— 这两条命令存在，但会明说"还没做"并以非零退出。
今天只有一条真路：**拿现成的站点实例当模板**。

| 实例里的东西 | 是什么 | 你要动它吗 |
|---|---|---|
| `app.mbt` | 整套界面（顶栏 / 侧栏树 / 两模式状态机） | 改外观时动它 |
| `content/` | **生成物**（`press` 写的），别手改 | 不动 |
| `index.html` / `index.js` / `App.js` | 静态宿主三件 | 一般不动 |
| `build-web.mjs` / `serve-web.mjs` | esbuild 打包 / 零依赖静态服务 | 一般不动 |
| `moon.mod` / `moon.pkg` | 独立 MoonBit 模块（依赖 `XiLaiTL/moobile`） | 换依赖时动 |
| `package.json` | `file:` 依赖宿主 + `SKILLPRESS_ENGINE` 指向程序 | 换机器/换路径时动 |

现成的一份在：`<内容仓>/.agents/skills/skillpress/scripts/.skillpress/`。
一个 skill / 多个 skill 各自要动什么、哪些名字写死 —— 见 `references/make-a-site.md`。

## 二、内容怎么组织（站点结构 = 目录结构）

| 你放什么 | 站点上变成什么 |
|---|---|
| `<内容根>/skillpress/SKILL.md` | **首页**：H1 = 站名与大标题，首个 `##` 之前 = 首屏引言 |
| 它里面的每个 `##` | 顶栏的**一条栏位**（换的是正文里的哪一节） |
| `<内容根>/<别的名字>/SKILL.md` | 文档区里的**一份 skill**（侧栏按名字排序） |
| `references/*.md` ｜ `FAQ.md` ｜ `scripts/*` | 那份 skill 的**子页**（树上展开） |
| 首页里的 `## [名字](目标)` | **纯链接节**：点那一栏直接渲染目标文件（认不出目标就报错） |

三条会咬人的：

- **顶栏栏位 = 首页那份 skill 的每个 `##`** ⇒ 栏名要**短**（细则放正文第一句）；长标题会把顶栏挤爆。
- 首页 `##` 底下那个**整条是链接的列表** = 该栏的**下拉菜单**（鼠标悬停出、触摸点一下展开）。
- `#`（H1）**不进正文**：它被抽成站名与首屏大标题。

## 三、改外观：改哪儿、别改哪儿

| 想改 | 去哪 |
|---|---|
| 配色 / 字号 / 间距 | 站点应用 `app.mbt` 顶部那组颜色常量（`c_bg` `c_ink` `c_accent` `c_head` …）与各处的 `font_size` |
| 代码块**颜色** | 程序 `lib/highlight.mjs` 的 `PALETTE` ↔ 应用的 `tok_color`：**索引两边对齐，改要一起改** |
| 页面骨架（顶栏 / 侧栏 / 两模式） | `app.mbt` 的 `view()` 与 `page_of()`；顶栏栏位由内容决定，**别写死** |
| 一块**新构造**（图片 / 折叠…） | 两边一起改：`lib/gen-content.mjs` 解析 + `app.mbt` 渲染（解析边界刻意窄，见 refs） |

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

`pack`（一组 skill → 便携目录）｜ `attach`（挂进已有项目）｜ 界面抽成程序里的 `shell` 包
（那时实例只剩几行 `@skillpress.site(...)`）｜ 锚点 / 目录 / 搜索 ｜ 窄屏折叠菜单 ｜ 生产 bundle
（现在是 dev 模式，约 6 MB，大头是 react-native-web）。

这些会变，**别当契约** —— 去程序的 `PLAN.md` 看。

## 七、指针

| 要什么 | 去哪 |
|---|---|
| 一份 / 多份 skill 到站点的完整步骤、哪些名字写死 | `references/make-a-site.md` |
| 主页怎么写、样式与构造怎么改 | `references/home-and-styles.md` |
| 投影规范：收录判据 / 结构 / 预算 / 站点边界 | 程序 `SPEC.md`（§2 / §3 / §8） |
| 集合划分、产出顺序 | 程序 `SKILLS.md` |
| 计划与未做 | 程序 `PLAN.md` |
| 目录形状（程序 / 内容 / 实例三个根） | `.agents/skills/skillpress/references/layout.md` |
| 站点管线内部（数据形状、两种模式、上色细则） | `.agents/skills/skillpress/references/site-pipeline.md` |
| 改**程序本身**（引擎 / 门 / 判据） | 另一份 skill：`skillpress-dev` |
