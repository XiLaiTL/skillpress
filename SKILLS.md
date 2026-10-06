# SKILLS —— 集合划分与边界

> 依据 [`SPEC.md`](SPEC.md)。**一个 skill 只解决一类问题**；边界写在这里，写的时候不许越界。
> 来源根目录：`../moobile/`（下表的相对路径都相对它）。状态符号：✅ 已产出 ｜ ⏳ 待写。

---

## 零、为什么按「谁在用」劈成两半

第一版按"功能"分（S1–S7），结果把三种读者混在同一张表里：写应用的人、接组件库的人、改库的人
在同一个 skill 里抢篇幅。**改成先分视角，再按"你现在要干的事"分场景** —— 因为 AI 的触发条件
天然就是"用户说他要干什么"，而不是"这个功能属于哪一层"。

| 家族 | 是谁 | 触发语（`whenToUse` 的实质） |
|---|---|---|
| **A. 使用者** | 拿 moobile **写东西**的人（多半由 AI 代写） | "我要做一个 App / 我要出 Android 版 / 我要把老项目搬过来" |
| **B. 维护者** | 改 **moobile 本身**的人 | "改这个库 / 加一条门 / 发版" |
| **C. 横切** | 两边都会撞上 | "编过了但不对 / 卡住了" |

⚠️ 边界纪律：**A 家族里不写"库内部怎么实现"**，B 家族里不写"应用该怎么写"。
两边都要的内容（坑、排错）放 C 家族 —— 那是**共享**，不是第三视角。

---

## 一、A. 使用者视角（按场景）

| # | skill | 场景 | 主要来源 | 状态 |
|---|---|---|---|---|
| **A1** | `moobile-setup` | **开发环境搭建**：工具链、全新 clone 的第一步、磁盘/目录联接、起一个新项目、第一次跑起来 | `DEV.md` §1/§1.5/§2/§3、`npm/moobile-host/lib/init.js`、`tools/env.sh`、`examples/apps/template/` | ⏳ |
| **A2** | `moobile-app-development` | **核心写法**：一个应用/一个页面怎么写（TEA 骨架、`@html`/`@style`/`@cmd`/`@sub`、加页面、长列表、能力边界） | `README.md` §1–§2、`examples/apps/todo-app/`、`docs/PERF-RECIPES.md` | ✅ |
| **A3** | `moobile-web` | **开发 Web 版本**：RNW 宿主、Metro、浏览器里的判据、静态站与部署 | `npm/moobile-host/hosts/rnw/`、`tools/verify_web.js`、`docs/PERF.md`（浏览器那部分） | ⏳ |
| **A4** | `moobile-android` | **开发 Android 版本**：模拟器/真机、`adb reverse`、Expo prebuild、`android_env_setup.sh`、真机判据脚本 | `DEV.md` §3、`tools/verify_android.py`、`tools/android_env_setup.sh`、`examples/apps/*/device_check.mjs` | ⏳ |
| **A5** | `moobile-desktop` | **开发桌面版**：`--host rnw` / `--host webview` / Electron 底座 | `docs/design/DESKTOP-RNW.md`、`npm/moobile-host/hosts/webview/`、`examples/apps/zhouyi-reader-desktop`·`-electron`·`-webview` | ⏳ |
| **A6** | `moobile-migrate-from-rabbita` | **从既有 rabbita 项目迁移**：`create --from-rabbita`、三件产物、报告两区、TODO 四类、`regen --styles` | `npm/moobile-host/lib/migrate/`、`docs/design/LAYERS.md`、`docs/plan/PLAN-2026Q3-yi-port.md`、各 `tools/migrate_*.mjs` | ⏳ |
| **A7** | `moobile-custom-component` | **开发自己的组件**：宿主侧 React 实现 + 注册 + 取值通道 | `npm/moobile-host/README.md`（`components` 收两种形状）、`docs/FINDINGS.md`「接一个现成的 RN 组件」补记 | ⏳ |
| **A8** | `moobile-react-library` | **使用已有的 React / RN 组件库**：`libgen` 三产物、`content`/`defaultExports`/`jsonProps`/`events`/`platforms` | `examples/apps/chat-app/libgen.config.json`、`examples/apps/antd-spike/`、`docs/design/DESIGN-COMPONENT-LIBRARY.md` | ⏳ |
| **A9** | `moobile-canvas` | **画布通道**：18 条指令、两条注册（Skia / CanvasKit）、变换每项一个键、字体 | `canvas/`、`npm/moobile-host/canvas-*.js`、`examples/apps/canvas-spike/` | ⏳ |

**A7 与 A8 的分界**（第一版混成一个 S3，是设计错误）：
- **A8 = 别人的组件已经有了**（antd、markdown 渲染器…）⇒ 你的活是**声明与生成**，不写组件代码。
- **A7 = 没人给你这个组件**（要 Skia 画布、要接一个自家原生视图）⇒ 你的活是**写一个** React 组件并注册。

**A3 / A4 / A5 的分界**：同一个应用换平台，**换的是宿主而不是库**（`README.md` §2 明说）。
所以三份分开写、各自只讲"这个平台特有的坑与判据"，公共写法一律指 A2。

**A6 是本家族里最特殊的一份**：它不是"从零写"，而是"搬运 + 报告"。它的纪律是
**报告零遗漏**而不是"自动改对多少" —— 判不了的一律进 TODO，绝不猜着改业务逻辑。

---

## 二、B. 维护者视角

| # | skill | 场景 | 主要来源 | 状态 |
|---|---|---|---|---|
| **B1** | `moobile-library-development` | **改库规程**：一条能力进哪层、改动→必跑的耦合、vendor/宿主包/生成物纪律、发版顺序、禁区 | `CONTRIBUTING.md`、`FORK.md`、`docs/design/LAYERS.md`、`docs/ARCHITECTURE.md` | ✅ |
| **B2** | `moobile-verification` | **造判据**：门怎么组织、怎么加一条、为什么必须带证伪、**假绿是怎么来的** | `tools/verify_all.sh`、`AGENTS.md` §2/§4、`docs/HANDOVER.md` §5、各 `*_check.mjs` | ⏳ |
| **B3** | `moobile-docs-governance` | **文档治理**：现状只有一处、`docfacts`/`claims` 两道门、写文档的负面清单、漂移怎么修 | `docs/README.md`、`CONTRIBUTING.md` §2、`../skillpress/DRIFT.md` | ⏳ |

**B1 / B2 的分界**：B1 是"**改东西**时的规矩"，B2 是"**造尺子**时的规矩"。
判据：B2 只在"你要新增/修改一条门"时才该被加载。

**B3 存在的理由**：这个仓库的文档规矩本身就是一套需要遵守的机制
（`STATUS.md` 是唯一来源、数字只写一处、结论被推翻要留痕），
而且现在多了两道门（`check.mjs` / `docfacts.mjs`）。不写下来，AI 一定会违反。

---

## 三、C. 横切（两个视角都会用）

| # | skill | 场景 | 主要来源 | 状态 |
|---|---|---|---|---|
| **C1** | `moobile-pitfalls` | **「不报错但错」的清单**（现象 → 真因 → 处置）+ 禁区 | `AGENTS.md` §3、`docs/FINDINGS.md`、`docs/design/DESIGN-COMPONENT-LIBRARY.md` §5 | ✅ |
| **C2** | `moobile-troubleshooting` | **卡住了**：跑不起来、结果不对、门红了、真机不出结果 | `DEV.md` §6、`docs/HANDOVER.md` §4、`docs/STATUS.md` | ⏳ |

**C1 / C2 的分界**：C1 是"**动手前/写代码时**该知道的坑"（预防），C2 是"**已经卡住之后**怎么定位"（急救）。
两者的条目会相邻，但**不许重复**：C1 里的条目一律不写排查步骤，C2 里的条目一律不解释设计原因。

---

## 四、D. 投影自身（用这套工具的人）

| # | skill | 场景 | 主要来源 | 状态 |
|---|---|---|---|---|
| **D1** | `skillpress` | **写一份 skill / 跑门 / 动站点**：收录判据、结构预算（门禁 vs 深水区）、两道门、站点管线 | **程序根**的 `SPEC.md` §2 / §3 / §6 / §8、`DRIFT.md` §4、`claims.txt`、`lib/check.mjs` | ✅ |

**它为什么自成一族**：A / B / C 三族讲的是 **moobile**，D 讲的是**这套投影机制本身** ——
读者是"要写/改 skill 的人"（多半也是 AI），来源不是 `docs/**` 而是**程序根**的规范与工具。
混进 B（维护者）会让人以为它在讲 moobile 的改库规程。

---

## 五、**明确不做成 skill** 的东西

| 内容 | 为什么 | 放哪 |
|---|---|---|
| `docs/STATUS.md`（版本、门分数、剩余工作） | **快变**，进 skill 必过期；且它自己声明是"唯一来源" | 让 AI 现读 |
| `docs/HANDOVER.md` §2*（"挂着的东西"） | 按轮次变化 | 让 AI 现读 |
| `PLAN.md`（124 KB） | 是计划不是知识，且频繁重排 | 让 AI 按需读 |
| `docs/FINDINGS.md`（6992 行） | 是**证据库**，不是判据集 | C1/B2 从中提炼，原文留指针 |
| 各 `README.md` 全文 | 与 skill 重复度高 | 指针 |
| antd 的 prop 清单 | 是生成物的活（`components.generated.mbt`） | 生成器 |

> 判据：**一份内容如果半年内会变，就不配进 skill 的正文。**

---

## 六、产出顺序

**已完成**：C1 `pitfalls` ｜ A2 `app-development` ｜ B1 `library-development` ｜ D1 `skillpress`

| 波次 | 做什么 | 为什么排这里 |
|---|---|---|
| **第二波** | A6 迁移 ｜ A8 用 React 库 ｜ A7 写组件 | 这三件是"拿 moobile 干真活"最常撞上的扩展动作；且互不重叠 |
| **第三波** | A3 web ｜ A4 android ｜ A5 desktop ｜ A1 setup | 三端分开写、各自只讲特有部分；A1 最后写，因为它要引用前三者 |
| **第四波** | B2 验证 ｜ B3 文档治理 ｜ C2 排错 | 面向改库的人与"已经卡住"的人；B2/B3 依赖前几波暴露出的真实判据 |

每份产出**必须跑门跑到全绿**：

```bash
cd ../moobile && node ../skillpress/bin/skillpress.mjs check
```
