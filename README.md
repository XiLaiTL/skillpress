# skillpress —— 把一堆 skill 印成一个站点

**一份内容源 → 多个投影**：同一批 skill（给 AI 用）被印成一个站点（给人看）。
站点的**首页就是其中一份 skill** —— 它自己也是这个集合里的一员。

这里是**程序本身**（将来发 npm 包 / moonbit 包）：内容管线、构建期上色、三道门、站点判据。
它是**自己的一个 git 仓库**，与内容仓**平级**（兄弟）：内容仓 = 旁边的 `../moobile/`。
**内容不在这里**（内容住 `<内容仓>/.agents/skills/`，站点实例住那份 skill 的 `scripts/` 里）。

## 三个根（先认清再动手）

| 根 | 在哪 | 是什么 |
|---|---|---|
| **程序** | 本仓库根（`interest/skillpress`） | 引擎 + 门 + 语法资产（能拿走、能发布的那份） |
| **内容** | `../moobile/.agents/skills/`（**旁边的兄弟**，不是本仓库） | 7 份 skill（`SKILL.md` + `references/`）。harness 也扫这个根 |
| **实例** | `<内容>/skillpress/scripts/.skillpress/` | 一个"**用**程序"的 MoonBit 工程（它的 `content/` 是生成物） |

三个根怎么定位（`--repo` / `--skills` / `--app` 与对应环境变量）见
[`../moobile/.agents/skills/skillpress/references/layout.md`](../moobile/.agents/skills/skillpress/references/layout.md)。

## 三条命令（在**程序根**跑）

```bash
node bin/skillpress.mjs check         # 门：skill 自己（G1–G8）
node bin/skillpress.mjs press         # 内容源 → 实例的内容包
node bin/skillpress.mjs verify        # 判据：真 Chrome 无头，自起服务
```

> 在**内容仓根**（`moobile/`）跑同一份程序就多一层：`node ../skillpress/bin/skillpress.mjs check`。
> 内容仓不在兄弟位置时用 `--repo <仓库根>` 或 `SKILLPRESS_REPO` 指定 —— **它不猜**
> （猜错的表现是"站点没更新"，最难查的一类症状）。

其余子命令：`facts`（查事实来源：docs 有没有撒谎）｜`audit`（上色的闸门：召回率 / 漏色比例）
｜`check --selftest`（门自己的证伪：造诱饵，必须全被点名）｜`press --check`（生成物与源一致吗）
｜`verify --shot f.png`（顺手截首页首屏）。

看一眼站点（站点实例在**内容仓**里）：

```bash
cd ../moobile/.agents/skills/skillpress/scripts/.skillpress
npm install && npm run build && npm run serve      # → http://127.0.0.1:8123/
```

## 目录

| 路径 | 是什么 |
|---|---|
| `bin/skillpress.mjs` | 门面：子命令转发的唯一入口（**换实现不改文档**） |
| `skills/` | **程序自己的 skill**（见下节）—— `.agents/skills` 是"给别人看的内容"，不是这里 |
| `lib/gen-content.mjs` | 内容管线：markdown → 类型化数据（解析边界见它文件头） |
| `lib/highlight.mjs` | 构建期上色：tree-sitter → 色号；`--audit` 是它的闸门 |
| `lib/check.mjs` | 门：G1–G8（含 `--selftest` 证伪、`--update-lock` 落锁） |
| `lib/docfacts.mjs` | 门：事实来源对账（只查算得出来的） |
| `lib/verify-site.mjs` | 站点判据（真 Chrome 无头 + CDP 真鼠标事件） |
| `grammars/` | vendor 的语法资产（wasm + `highlights.scm`），出处与 sha256 见它的 `PROVENANCE.md` |
| `SPEC.md` / `SKILLS.md` / `DRIFT.md` | 投影规范 / 集合划分 / 漂移政策（跟着程序走 = 对外契约） |
| `PLAN.md` | **计划**（会变）：还没做的、已定的决定、要探的未知 |
| `claims.txt` / `done-claims.txt` / `skills.lock.json` | 禁语表 / 已落地台账 / 体量指纹（每条指纹记着**属于哪个内容根**） |

## 程序自己的 skill（`skills/`）

按**身份**拆成两份 —— 一份给"用这套工具的人"，一份给"改这套程序的人"：

| skill | 读者 | 管什么 |
|---|---|---|
| `skillpress-user` | 用它做站点的人 | 一份 / 多份 skill → 站点、主页怎么写、配色与字号改哪儿、加一块新构造、验收 |
| `skillpress-dev` | 改这套程序的人 | 四个根、改什么跑哪条门、怎么加判据与诱饵、落锁、会安静咬人的坑 |

为什么是 `skills/` 而不是 `.agents/skills/`：后者是**内容** —— 会被印成站点、给别人看的那份
（由内容仓持有）；而这个 `skills/` 是**给用这个仓库的人**看的那份（用它的、改它的）。

⚠️ 顺带一件好事：`skills/` 的形状和内容根**一模一样**（`skills/<名字>/SKILL.md`）——
所以将来"自举"（把程序自己的 skill 也印成站点）时，它天然就是那个内容根。

跑门要**显式指这个根**（默认那个根是内容仓的）：

```bash
node bin/skillpress.mjs check --skills skills
node bin/skillpress.mjs check --skills skills --update-lock   # 复核体量后落锁
```

⚠️ **还没自举**：`press` 只往内容仓那个实例写，所以这两份 skill **暂时上不了站点**。

## 门与判据（现状，2026-10-06 复核；**这些会漂 —— 要准数就跑一遍**）

```bash
node bin/skillpress.mjs check            # 7 份 skill 全过
node bin/skillpress.mjs check --selftest # 13 个诱饵全被点名（+1 个正例不许被误杀）
node bin/skillpress.mjs audit            # 召回 97.2% / 未上色 13.9%（闸门 ≥90% / ≤40%）
node bin/skillpress.mjs facts            # 内容仓侧：硬 0 / 软 2
node bin/skillpress.mjs verify           # 20 条全过（真 Chrome 无头）
```

## 诚实清单

1. **还没发布**：现在靠**源码路径**调用（`node bin/skillpress.mjs …`）。发 npm 包 / moonbit 包
   是计划里的事，不是现状。
2. **界面还没抽成包**：站点壳的代码现在**住在实例里**（`app.mbt`），目标是把界面变成程序里的一个
   MoonBit 包（`shell`），实例只剩几行 `@skillpress.site(...)` —— 零复制、升包即升级。
3. **`pack` / `attach` 还没做**：命令存在，但会明说"还没做"并以非零退出（不做"看着像跑了"的假动作）。
4. **锚点 / 目录 / 搜索还没做**（语法树已经在手上）；窄屏没做折叠菜单。
5. **打的是 dev 模式 bundle**（约 6 MB，大头是 react-native-web）：上生产要换 `NODE_ENV=production` + `minify`。
