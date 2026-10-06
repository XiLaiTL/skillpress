# skillpress —— 把一堆 skill 印成一个站点

**一份内容源 → 多个投影**：同一批 skill（给 AI 用）被印成一个站点（给人看）。
站点的**首页就是其中一份 skill** —— 它自己也是这个集合里的一员。

这里是**程序本身**（将来发 npm 包 / moonbit 包）：内容管线、构建期上色、三道门、站点判据。
它是**自己的一个 git 仓库**，与内容仓**平级**（兄弟）：内容仓 = 旁边的 `../moobile/`。
**内容不在这里**（内容住 `<内容仓>/skills/`，站点实例住那份 skill 的 `scripts/` 里）。

## 三个根（先认清再动手）

| 根 | 在哪 | 是什么 |
|---|---|---|
| **程序** | 本仓库根（`interest/skillpress`） | 引擎 + 门 + 语法资产（能拿走、能发布的那份） |
| **内容** | `../moobile/skills/`（**旁边的兄弟**，不是本仓库） | 7 份 skill（`SKILL.md` + `references/`）。harness 也扫这个根 |
| **实例** | `<内容>/skillpress/scripts/.skillpress/` | 一个"**用**程序"的 MoonBit 工程（它的 `content/` 是生成物） |

三个根怎么定位（`--repo` / `--skills` / `--app` 与对应环境变量）见
[`../moobile/skills/skillpress/references/layout.md`](../moobile/skills/skillpress/references/layout.md)。

## 三条命令（在**程序根**跑）

```bash
npm run press          # 内容源 → 实例的内容包（**P6 起走新引擎**：tools/press.mjs → cmd/skillpress gen-file）
npm run press:check    # 门：实例里那份生成物与**新引擎现跑**一致吗
npm run check          # 门：skill 自己（G1–G8）—— **今天仍由冻结的 Node 版 `lib/check.mjs` 提供**
npm run verify         # 站点判据：真 Chrome 无头，自起服务（**同上**）
```

> ⚠️ `check` / `verify` / `facts` / `audit` 这四道**今天**还是旧实现（`lib/*.mjs`）——
> 新引擎的通用门正在 `engine/gates/` 里长（P8.2），搬完才会换过来。`press` 那条**已经换了**。
> 在**内容仓根**（`moobile/`）跑同一份程序就多一层：`node ../skillpress/bin/skillpress.mjs check`。
> 内容仓不在兄弟位置时用 `--repo <仓库根>` 或 `SKILLPRESS_REPO` 指定 —— **它不猜**
> （猜错的表现是"站点没更新"，最难查的一类症状）。

其余子命令：`facts`（查事实来源：docs 有没有撒谎）｜`audit`（上色的闸门：召回率 / 漏色比例）
｜`check:selftest`（门自己的证伪：造诱饵，必须全被点名）。`pack` / `attach` **还没做**（用法里就这么写）。
`npm run package-check` = 发布包内容复核（见下节 ⑧）。

看一眼站点（站点实例在**内容仓**里）：

```bash
cd ../moobile/skills/skillpress/scripts/.skillpress
npm install && npm run press && npm run build && npm run serve   # → http://127.0.0.1:8123/
```

## 目录

| 路径 | 是什么 |
|---|---|
| `bin/skillpress.mjs` | **旧**门面：`check` / `facts` / `audit` / `verify` 今天仍由它提供（换实现不改文档） |
| `skills/` | **程序自己的 skill**（见下节）—— `skills` 是"给别人看的内容"，不是这里 |
| `lib/gen-content.mjs` | **冻结的旧实现**（真相参照物）：内容管线 —— 判据拿它现场印基准 |
| `lib/highlight.mjs` | 同上：构建期上色（tree-sitter → 色号；`--audit` 是它的闸门） |
| `lib/check.mjs` | 同上：门 G1–G8（含 `--selftest` 证伪、`--update-lock` 落锁） |
| `lib/docfacts.mjs` | 同上：门：事实来源对账（只查算得出来的；按 D18 要搬去内容仓） |
| `lib/verify-site.mjs` | 同上：站点判据（真 Chrome 无头 + CDP 真鼠标事件） |
| `grammars/` | vendor 的语法资产（wasm + `highlights.scm`），出处与 sha256 见它的 `PROVENANCE.md` |
| `SPEC.md` / `SKILLS.md` / `DRIFT.md` | 投影规范 / 集合划分 / 漂移政策（跟着程序走 = 对外契约） |
| `PLAN.md` | **计划**（会变）：还没做的、已定的决定（D1–D26）、要探的未知 |
| `claims.txt` / `done-claims.txt` / `skills.lock.json` | 禁语表 / 已落地台账 / 体量指纹（每条指纹记着**属于哪个内容根**）。⚠️ 前两份是**门要读的数据**（随包发）；`skills.lock.json` 里是本机绝对路径，**不随包发** |
| `tools/*.sh` | **判据**（见下节）：对账 / 夹具 / R9 / 诊断账本 / 干净克隆 / 包内容 |
| `engine/highlight/` | **MoonBit 版引擎的第一块**（P8.1）：调色板 / 包装候选 / 薄垫片 —— 见下节「对账」 |
| `engine/content/` + `cmd/skillpress/` | 内容管线与 CLI 的 MoonBit 版（P6/P8）：生成物由 `cmd/skillpress` 的 `gen-file` 吐到 stdout |
| `shell/` | **站点界面包**（P6）：顶栏 / 分栏下拉 / 侧栏树 / 正文渲染 + 公开契约（那 7 个类型）—— 实例只依赖它 |
| `tools/press.mjs` | 内容源 → 实例的 `content/`（**新引擎**那条日常路径；`--check` 是门）。先写临时文件成功才替换：引擎有问题时**不吐产物**，别让一次失败顺手毁掉上一份 |
| `tools/baseline/` | 旧形状生成物的**冻结基线**（旧引擎印的）+ `EXPECTED.sha256` + 刷新步骤 —— 见它的 `README.md` |
| `tools/normalize-gen.mjs` | 把"旧形状 / 新形状"化到同一条基准线（三条规则），带 `--selftest` 钉住"值改一个字符必须红"的边界 |
| `tools/dom-dump.mjs` | 真 Chrome 抓**渲染后的 DOM**（P6 搬界面的对账仪器）：`--repeat 2` 先自证仪器稳定，再比搬前搬后 |
| `tools/run-js.mjs` | js 那条图的**引导层**：先 `await` 装好 tree-sitter 与 5 份语法，再进 MoonBit（CJS 不能顶层 await） |
| `tools/spike/` | P8.0 探针 + 对账的**基准生成器**（不进发布包，`.moonignore` 已排掉） |

## 对账与验收（判据都写在明处）

引擎正在从 Node 版搬进 MoonBit（`PLAN.md` 的 P8）。搬的过程**只认一条**：
新实现的输出要与旧实现的产物**逐字节一致** —— "看着差不多"不算数。
⚠️ P6 起这句话有个限定：生成物的**形状**换了（类型搬进包 `shell`、值带 `@shell.` 前缀），
所以 ① 的口径是"**归一化后**逐字节一致"—— 归一化只抹**形状差**（三条规则，见 D26），
映射差一个字节都不许有；基线自己被旧形状判据 + sha256 钉子 + 旧引擎现场重印三重钉住。

```bash
export SKILLPRESS_CORPUS=../moobile/skills     # 下面的命令都按这个内容根跑
bash tools/file-parity.sh         # ① 整份生成物：与**基线**（旧引擎现场印出来的那份，冻在 tools/baseline/）归一化后逐字节一致
bash tools/highlight-parity.sh    # ② 上色：与旧实现（lib/highlight.mjs）在全语料上逐字节一致（**空集合不许通过**）
bash tools/blocks-parity.sh       # ③ 文档块：与旧实现已产出的 content.generated.mbt 逐字节一致
bash tools/blocks-fixtures.sh     # ④ 夹具：现场用旧生成器造基准，专打 7 份真内容覆盖不到的边界
bash tools/line-budget.sh         # ⑤ R9：每个源文件 ≤400 行（默认全覆盖 + 显式豁免；--selftest 造 401 行的诱饵证明它会红）
bash tools/diagnostics-ledger.sh  # ⑥ 诊断口径账本：旧实现 76 条诊断逐条"有对应物"或"记了账"（--selftest 改坏锚点即红）
bash tools/fresh-clone-check.sh   # ⑦ 干净克隆自查：把 HEAD 克隆到临时目录（只有 tracked 文件）、现装现编，再跑上面几条 + R9 + 账本
bash tools/package-check.sh       # ⑧ 发布包内容复核：该含的缺一个也红、不该含的多一个也红（--selftest 三向诱饵）
bash tools/mbt-traps.sh           # ⑨ MoonBit 坑位（第一条：`Array::sort()` 排字符串**不是字典序**；--selftest 两向诱饵）
bash tools/site-source.sh         # ⑩ 首页源（R2：WEBSITE.md 优先 / 回退 SKILL.md / --home）+ 忽略清单（R4：站点与门都跳过）
bash tools/acceptance.sh          # ⑪ 验收：按 PLAN §6 的 A1/A2/A3 逐条查（红在哪 = 还差什么）
```

**P6 补的两台自证过的仪器**（判据不只看"产物对不对"，还看"判据自己会不会红"）：

```bash
node tools/normalize-gen.mjs --selftest                      # 归一化只抹形状：值 / 顺序 / 缩进 / 正文空行改一处都必须红
bash tools/file-parity.sh --selftest                         # 五条：1 绿 + 4 红（含"只在归一化看不见的地方改基线 ⇒ 必须红"）
node tools/dom-dump.mjs --app <实例> --out a.html --repeat 2  # 真 Chrome 抓 DOM：先自证仪器（两次逐字节相同），再比搬前/搬后
node tools/press.mjs --check                                 # 实例里的生成物与**新引擎现跑**逐字节一致（= 旧 `press --check` 的位置）
```

前几条会把两边的原始输出与 diff 落在 `_build/parity/`（产物目录，不进仓）。

**为什么 ⑥ 与 ⑦ 是后来才长出来的**（两笔老账，写在明处）：

- **⑦ 干净克隆**：本机绿**不算数** —— 本机有 `_build/`、`node_modules/`、各种缓存，克隆里都没有。
  实测两笔：① 四条对账判据要"编出来的 js"，而 `_build/` 不进版本库 ⇒ 克隆里**全红**、本机一直绿；
  ② 更狠：已提交的引擎里**根本没有**「图片 / 原始 HTML / 表格缺分隔行 / 围栏没闭合」这四条点名规矩
  （`parse_blocks` 的签名里没有 problems 参数，移植时按注释把它摘了）⇒ 认不出的构造被**咽下去**、
  照吐一份坏产物、退出码还是 0。**本机之所以没看出来，是因为本机编的是工作区，不是 HEAD。**
- **⑥ 诊断账本**：四种对账判据盯的都是**产物**，而"诊断"是另一条线 —— 一句话没了、退出码反了、
  该走 stderr 的走了 stdout，产物照样逐字节一致、判据全绿。76 条里实测逮到：未知子命令新实现
  `rc=0`（旧 `rc=2` 且点名）、「（N/M 个代码块没配语法或为空）」今天就在触发却已静默丢、
  首页两条问题丢了定位前缀。账本是**自销账**的：欠账补上了那一行就红，逼着改成"钉住新句子"。

⚠️ `acceptance.sh` 的 A1 那几条、以及 ⑤⑥⑦⑧ 里吃 `moon` 的判据，都要**编译本模块** ⇒
它们的读数只在"本模块没人在改"时可信（有别的进程/子代理正在改时，你会看到"20 个错误"这种**别人的半成品**读数）。

## 程序自己的 skill（`skills/`）

按**身份**拆成两份 —— 一份给"用这套工具的人"，一份给"改这套程序的人"：

| skill | 读者 | 管什么 |
|---|---|---|
| `skillpress-user` | 用它做站点的人 | 一份 / 多份 skill → 站点、主页怎么写、配色与字号改哪儿、加一块新构造、验收 |
| `skillpress-dev` | 改这套程序的人 | 四个根、改什么跑哪条门、怎么加判据与诱饵、落锁、会安静咬人的坑 |

为什么是 `skills/` 而不是 `skills/`：后者是**内容** —— 会被印成站点、给别人看的那份
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

1. **还没发布**：现在靠**源码路径**调用（`node bin/skillpress.mjs …`）。
   ⚠️ 发布形态已改（`PLAN.md` 的 D15）：**不单独发 npm 引擎包** —— 引擎要从这 3404 行 `.mjs`
   迁到 MoonBit，最后由**一个月亮包**装下引擎 + 站点界面 + skills，CLI 用 `moon install` 装。
   迁移的阶段与判据见 `PLAN.md` 的 **P8**（**还没动手**）。
2. **界面还没抽成包**：站点壳的代码现在**住在实例里**（`app.mbt`），目标是把界面变成程序里的一个
   MoonBit 包（`shell`），实例只剩几行 `@skillpress.site(...)` —— 零复制、升包即升级。
3. **`pack` / `attach` 还没做**：命令存在，但会明说"还没做"并以非零退出（不做"看着像跑了"的假动作）。
4. **锚点 / 目录 / 搜索还没做**（语法树已经在手上）；窄屏没做折叠菜单。
5. **打的是 dev 模式 bundle**（约 6 MB，大头是 react-native-web）：上生产要换 `NODE_ENV=production` + `minify`。
