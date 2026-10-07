---
title: 从一份 / 多份 skill 到一个站点
description: 站点怎么从内容源长出来：一个 skill 的最小站点、多份 skill 的侧栏树、子页的收录规矩、实例要准备什么、构建与验收的命令，以及"换个全新仓库今天为什么要手抄实例"。
---

# 从一份 / 多份 skill 到一个站点

**什么时候读它**：你要**新建**一个站点（自己的 skill 目录 → 一个能打开的网站），
或者想知道"我把第 2 份 skill 放上去会变成什么"。

## 一、站点 = 一个实例 + 三个根

| 根 | 在哪 | 谁提供 |
|---|---|---|
| **程序** | 旁边的 `skillpress/`（`cmd/skillpress`） | 这套工具本身 |
| **内容** | `<内容仓>/skills/`（可以换成任何目录：`--skills`） | **你写的 skill** |
| **实例** | 一个 MoonBit 工程（现成的在 `skills/skillpress/scripts/.skillpress/`） | 界面 + 宿主 + 生成物 |

`press` 把**内容**读出来、写进**实例**的 `content/content.generated.mbt`；界面住在实例的 `app.mbt` 里。
三个根怎么定位（`--repo` / `--skills` / `--app` 与环境变量）见 `skills/skillpress/references/layout.md`。

## 二、一份 skill 的最小站点

1. 内容根里建 `<内容根>/skillpress/SKILL.md` —— ⚠️ **首页那份的名字写死是 `skillpress`**（⚠️ **已定要改（D19/D20，还没落地）**：首页的内容源要改成 `skillpress/WEBSITE.md`，`SKILL.md` 只讲工具本身 —— 今天仍读 `SKILL.md`。）：
   生成器直接取 `join(SKILLS, "skillpress", "SKILL.md")`，名字不对**报错**，不会静默给你一个空首页。
2. 写它 —— H1 = 站名与首屏大标题，首个 `##` 之前 = 首屏引言，每个 `##` = 顶栏一条栏位。
3. `press` → `press --check`。
4. 实例里 `npm install && npm run build && npm run serve` → 打开 `http://127.0.0.1:8123/`。

```
<内容根>/
└── skillpress/
    └── SKILL.md        ← 首页：H1 + 引言 + 每个 ## 一栏
```

## 三、多份 skill：文档区自己长出来

再加一份 = **再加一个目录**，不需要任何配置：

```
<内容根>/
├── skillpress/SKILL.md          ← 首页（名字写死）
├── my-thing/SKILL.md            ← 文档区里的第 1 份（侧栏按名字排序）
└── other-thing/
    ├── SKILL.md
    ├── references/gates.md      ← 它的子页
    └── notes/deep.md            ← 也是子页（位置不限）
```

侧栏树 = skill → 它的子页；顶栏那条「文档 / SKILL」切过去就是文档区（它换的是**整个模式**）。

**子页怎么来的**（规矩在 `engine/content/kids.mbt`，生成器 / 门 / 判据三处共用）：

- 那个 skill 目录下**任何子目录里的 `.md`** 都收（`references/` 只是**推荐**位置，不是硬性位置）；
- `scripts` 子目录里**直接放着的非 md 文件**按可跑脚本收（站点上以代码块展示）；
- **产物目录与点开头的目录一律跳过**（依赖目录、构建产物、任何以 `.` 开头的）；
- 侧栏上的名字：`references/` 下的文件去掉前缀与扩展名（`references/` 里的 gates.md → `gates`）；
  其余按相对路径去掉扩展名；**名字撞了就都退回全路径**（宁可长一点，也不要两个同名的子页）。

## 四、实例：怎么准备一个

**先跑脚手架**（它把整套实例写出来，含首页源与忽略清单）：

```bash
node tools/run-js.mjs attach --repo <仓根> --skills <内容根>
```

只有要**特化**它时才手工改这几处（改的都是**生成出来的**那份，不是另抄一份）：

| 要改的 | 改成什么 |
|---|---|
| `package.json` 的 `name` | 你的站点名 |
| `package.json` 里的宿主依赖 | 指向你本机的宿主（`file:` 路径） |
| `package.json` 的 `SKILLPRESS_ENGINE` | 指向程序（默认值 `../../../../../skillpress` 正是"兄弟"布局） |
| `moon.mod` 的模块名与依赖版本 | 你的模块名 / 你要的库版本 |
| `index.html` 的标题 | 浏览器标签上的标题（首屏 H1 来自**内容**，不是这里） |
| `app.mbt` | 想改外观才动 —— 见 `references/home-and-styles.md` |

⚠️ **宿主是 `file:` 依赖**（这套东西的老规矩）：改了宿主之后，`node_modules` 里那份副本要刷新，
否则**验证脚本会悄悄测旧代码**（症状是"两次跑出来的结果一模一样"）。

## 五、验收

| 命令 | 在哪跑 | 它证明什么 |
|---|---|---|
| `press --check` | 内容仓根 | 生成物与内容源一致（"改了内容忘了 press"会被抓，并指出第一处差异） |
| `npm run build` | 实例目录 | 内容包能编译、界面能打包出 `dist/bundle.js` |
| `verify` | 内容仓根（或实例里那份薄壳 `verify.mjs`） | 真 Chrome 无头：顶栏 / 两种模式 / 点击切换 / 上色 / 吸顶 / 无 console error |
| `check` | 内容仓根 | skill 自己合格（G1–G8）：frontmatter、LF、路径、预算、体量指纹 |

⚠️ `verify` **要求实例里先有 `dist/bundle.js`**：没有它会直接说"先在 site/ 里跑 `npm run build`"
（它不猜、也不替你构建）。

## 六、还没做（别当成已支持）

- `pack`：把一个 / 一组 skill 打成**便携目录**（自带程序副本 + 生成的首页 skill）。
- 锚点 / 目录 / 搜索；窄屏折叠菜单；生产 bundle（现在是 dev 模式，大头是 react-native-web）。

这些会变，**别当契约**：去程序的 `PLAN.md` 看。
