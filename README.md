# skillpress —— 把一堆 skill 印成一个站点

**一份内容源 → 多个投影**：同一批 skill（给 AI 用）被印成一个站点（给人看）。
站点的**首页就是其中一份 skill** —— 它自己也是这个集合里的一员。

这里是**程序本身**（将来发 npm 包 / moonbit 包）：内容管线、构建期上色、三道门、站点判据。
**内容不在这里**（内容住 `<仓库>/.agents/skills/`，站点实例住那份 skill 的 `scripts/` 里）。

## 三个根（先认清再动手）

| 根 | 在哪 | 是什么 |
|---|---|---|
| **程序** | `examples/apps/skillpress/`（本目录） | 引擎 + 门 + 语法资产（能拿走、能发布的那份） |
| **内容** | `<仓库>/.agents/skills/` | 7 份 skill（`SKILL.md` + `references/`）。harness 也扫这个根 |
| **实例** | `<内容>/skillpress/scripts/.skillpress/` | 一个"**用**程序"的 MoonBit 工程（它的 `content/` 是生成物） |

三个根怎么定位（`--repo` / `--skills` / `--app` 与对应环境变量）见
[`.agents/skills/skillpress/references/layout.md`](../../../.agents/skills/skillpress/references/layout.md)。

## 三条命令（都在**仓库根**跑）

```bash
node examples/apps/skillpress/bin/skillpress.mjs check         # 门：skill 自己（G1–G8）
node examples/apps/skillpress/bin/skillpress.mjs press         # 内容源 → 实例的内容包
node examples/apps/skillpress/bin/skillpress.mjs verify        # 判据：真 Chrome 无头，自起服务
```

其余子命令：`facts`（查事实来源：docs 有没有撒谎）｜`audit`（上色的闸门：召回率 / 漏色比例）
｜`check --selftest`（门自己的证伪：造诱饵，必须全被点名）｜`press --check`（生成物与源一致吗）
｜`verify --shot f.png`（顺手截首页首屏）。

看一眼站点：

```bash
cd .agents/skills/skillpress/scripts/.skillpress
npm install && npm run build && npm run serve      # → http://127.0.0.1:8123/
```

## 目录

| 路径 | 是什么 |
|---|---|
| `bin/skillpress.mjs` | 门面：子命令转发的唯一入口（**换实现不改文档**） |
| `lib/gen-content.mjs` | 内容管线：markdown → 类型化数据（解析边界见它文件头） |
| `lib/highlight.mjs` | 构建期上色：tree-sitter → 色号；`--audit` 是它的闸门 |
| `lib/check.mjs` | 门：G1–G8（含 `--selftest` 证伪、`--update-lock` 落锁） |
| `lib/docfacts.mjs` | 门：事实来源对账（只查算得出来的） |
| `lib/verify-site.mjs` | 站点判据（真 Chrome 无头 + CDP 真鼠标事件） |
| `grammars/` | vendor 的语法资产（wasm + `highlights.scm`），出处与 sha256 见它的 `PROVENANCE.md` |
| `SPEC.md` / `SKILLS.md` / `DRIFT.md` | 投影规范 / 集合划分 / 漂移政策（跟着程序走 = 对外契约） |
| `PLAN.md` | **计划**（会变）：还没做的、已定的决定、要探的未知 |
| `claims.txt` / `done-claims.txt` / `skills.lock.json` | 禁语表 / 已落地台账 / 体量指纹 |

## 门与判据（现状）

```bash
node examples/apps/skillpress/bin/skillpress.mjs check            # 7 份 skill 全过
node examples/apps/skillpress/bin/skillpress.mjs check --selftest # 13 个诱饵全被点名
node examples/apps/skillpress/bin/skillpress.mjs audit            # 召回 97.4%（闸门 ≥90%）
node examples/apps/skillpress/bin/skillpress.mjs facts            # moobile 侧：硬 0 / 软 2
node examples/apps/skillpress/bin/skillpress.mjs verify           # 20 条全过
```

## 诚实清单

1. **还没发布**：现在靠仓库内路径调用（`node examples/apps/skillpress/bin/…`）。发 npm 包 / moonbit 包
   是计划里的事，不是现状。
2. **界面还没抽成包**：站点壳的代码现在**住在实例里**（`app.mbt`），目标是把界面变成程序里的一个
   MoonBit 包（`shell`），实例只剩几行 `@skillpress.site(...)` —— 零复制、升包即升级。
3. **`pack` / `attach` 还没做**：命令存在，但会明说"还没做"并以非零退出（不做"看着像跑了"的假动作）。
4. **锚点 / 目录 / 搜索还没做**（语法树已经在手上）；窄屏没做折叠菜单。
5. **打的是 dev 模式 bundle**（约 6 MB，大头是 react-native-web）：上生产要换 `NODE_ENV=production` + `minify`。
