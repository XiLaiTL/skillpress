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
npm run check          # 门：skill 自己（G1–G8）—— 走新 CLI（tools/run-js.mjs check → cmd/skillpress）
npm run verify         # 站点判据：真 Chrome 无头，自起服务 —— `cmd/skillpress-native verify`（见下）
npm run audit          # 上色的回归闸门（召回率 / 未上色比例）—— `tools/run-js.mjs audit`
npm run check:selftest # 门自己的证伪：22 条 wbtest（`moon test engine/gates`），造诱饵必须全被点名
```

> ⚠️ **四条 `npm run` 入口都已经换成新引擎**（`press` P6、`check`/`audit` 2026-10-07、`verify` P8.3 收口）。
> `lib/` 与 `bin/` 已**整体退役**（PLAN 的 D43，2026-10-07）：迁移期那五条"拿冻结旧实现现场跑基准"的
> 对账脚本（`file-parity` / `blocks-parity` / `highlight-parity` / `site-parity` / `site-corpus-parity`）
> **同批删掉了**，参照物的职责改由**入库 golden**（`tools/fixtures/expected/`）接管。
> ⇒ 仓库里再见到 `lib/xxx.mjs` / `bin/skillpress.mjs`，读作**历史坐标**（迁移记录里的出处），不是活文件。
> ⚠️ **`verify` 那条路只能 native**：站点判据要 async 的 http server / websocket / process，
> 而它们在 `moonbitlang/async` 的 js 目标上**没有实现** ⇒ 要一次 C 工具链；js 那份 CLI 遇到
> `verify` 会**明说"只有 native 有"并退 2**。
> 在**内容仓根**（`moobile/`）跑同一份程序就多一层：`node ../skillpress/tools/run-js.mjs check`。
> 内容仓不在兄弟位置时用 `--repo <仓库根>` 或 `SKILLPRESS_REPO` 指定 —— **它不猜**
> （猜错的表现是"站点没更新"，最难查的一类症状）。
脚手架那条 `attach` **已落地**（见下节）；`pack` **还没做**（命令存在，但会明说"还没做"并以非零退出）。
⚠️ `facts`（查 docs 有没有撒谎）按 **D18 已搬去内容仓自己**：`moobile/tools/skillpress-gates.mjs --gate facts`
（连同 G5 / G6 两道"只对 moobile 有意义"的门与台账 `done-claims.txt`）。
`npm run package-check` = 发布包内容复核（见下节 ⑧）。

看一眼站点（站点实例在**内容仓**里）：

```bash
cd ../moobile/skills/skillpress/scripts/.skillpress
npm install && npm run press && npm run build && npm run serve   # → http://127.0.0.1:8123/
```

## 脚手架：给一份 `skills/` 直接生成一个站点

```bash
node tools/run-js.mjs attach --repo . --skills skills     # 本仓自己就是一份语料（自举）
node tools/run-js.mjs attach --skills <别人的内容根> --ignore "某份=它的理由"
```

它扫内容根 → 问（或按 `--ignore` 收）哪几份**不上书架**（每条都要**理由**，没理由就红）→
首页源取目标仓的 `README.md`（**复制 + 改写**：能对上账的链接改成站点口径，对不上的**降级并打印**）
→ 写整套 `skills/skillpress/{SKILL.md, WEBSITE.md, scripts/.skillpress/**}` 与仓根的 `skillpress.ignore.md`。

⚠️ 三条要记住的：**幂等**（连跑两遍产物逐字节不变）、**不覆盖人写的东西**（要覆盖加 `--force`）、
**算不出来就一个字节都不写**（退 2 + 逐条点名 —— 写的是别人的仓库，半成品最坏）。
模板真源是 `template/instance/**`（带占位符）—— **别在别处再摆一份实例文件**。
判据：`bash tools/attach-check.sh`（①–⑨ + 诱饵）。

## 目录

| 路径 | 是什么 |
|---|---|
| ~~`lib/`~~ ~~`bin/`~~ | **已整体退役**（2026-10-07，PLAN 的 D43）：它们是迁移期的**冻结旧实现**（真相参照物），现役实现全在 `engine/**` + `cmd/**`。参照物的职责由 `tools/fixtures/expected/` 里的**入库 golden** 接管。⚠️ 仓库里凡是提 `lib/xxx.mjs` / `bin/skillpress.mjs` 的地方，现在都是**历史坐标**（对账与迁移记录里的出处），不是活文件 |
| `skills/` | **程序自己的 skill**（见下节）—— `skills` 是"给别人看的内容"，不是这里 |
| `engine/site/` | **站点判据的本体**（P8.3）：进程内静态服务 + 起无头 Chrome + 走 CDP 跑 22 条断言（语料侧读数 / 页面侧读数 / 断言编排 / 报告）。⚠️ **native-only**：要 async 的 http server / websocket / process，而它们在 `moonbitlang/async` 的 js 目标上**没有实现** ⇒ 这条路上要一次 native 编译 |
| `grammars/` | vendor 的语法资产（wasm + `highlights.scm`），出处与 sha256 见它的 `PROVENANCE.md` |
| `vendor/web-tree-sitter/` | vendor 的 tree-sitter **运行时**（MIT：一个 ESM 入口 + 一个 wasm）—— 与 `grammars/` 一起**随包发** ⇒ 拿到包的人**一个 npm 依赖都不用装**（见它的 `PROVENANCE.md`） |
| `launcher/skillpress.mjs` | 随包发的**启动器**（**js 那条路**的）**，也是引导层的唯一实现**：`Parser.init()` 是 Promise 而 js 产物是 CJS ⇒ 需要一个能 await 的 Node 启动器（`check` 那条路上连 tree-sitter 都不 import）。开发期的 `tools/run-js.mjs` 转发到它（D35）。**native 那条路不需要它** —— 见 `cmd/skillpress-native/` |
| `cmd/skillpress-native/` | **native CLI**（P10）：与 js 那份**同一套 CLI 逻辑**（`cmd/skillpress/cli/`），只是宿主换成 `engine/gates/native` ⇒ `moon install ./cmd/skillpress-native` 装出来的是**本机可执行件，使用者零 Node**。两个 target 的产物**逐字节一致**由 `bash tools/native-parity.sh` 钉着 |
| `SPEC.md` / `SKILLS.md` / `DRIFT.md` | 投影规范 / 集合划分 / 漂移政策（跟着程序走 = 对外契约） |
| `PLAN.md` | **计划**（会变）：还没做的、已定的决定（D1–D26）、要探的未知 |
| `claims.txt` / `skills.lock.json` | 禁语表（G7 用，**随包发**）/ 体量指纹锁（每条指纹记着**属于哪个内容根**；锁**不随包发**）。⚠️ 已落地台账 `done-claims.txt` 与 `facts` 那道门按 D18 **搬去内容仓自己**了（`moobile/tools/skillpress-gates.mjs`） |
| `tools/*.sh` | **判据**（见下节）：对账 / 夹具 / R9 / 诊断账本 / 干净克隆 / 包内容 |
| `engine/highlight/` | **MoonBit 版引擎的第一块**（P8.1）：调色板 / 包装候选 + **两份薄垫片**（`ts_shim.mbt` 走 js 引导层，`ts_shim.native.mbt` 走我们 vendor 的 tree-sitter C + 内嵌 query）—— 见下节「对账」 |
| `cmd/skillpress/cli/gen_queries.mbt` | **`gen-queries` 子命令**：把 `grammars/*.scm` **嵌进** `engine/highlight/queries.generated.mbt`（native 没有引导层读盘）；`--check` 是门，判据 `tools/queries-check.sh`。⚠️ 2026-10-07 从 `tools/gen-queries.mjs` 换成这个（② 的第一件） |
| `engine/content/` + `cmd/skillpress/` | 内容管线与 CLI 的 MoonBit 版（P6/P8）：生成物由 `cmd/skillpress` 的 `gen-file` 吐到 stdout |
| `shell/` | **站点界面包**（P6）：顶栏 / 分栏下拉 / 侧栏树 / 正文渲染 + 公开契约（那 7 个类型）—— 实例只依赖它 |
| `engine/scaffold/` + `cmd/skillpress/cli/attach.mbt` | **脚手架**（P9）：扫语料 / 把 README 改写成首页 / 拼忽略清单 / 替换模板占位符 —— 纯逻辑在 `engine/scaffold/`（可单测），碰磁盘那半在 CLI 里 |
| `template/instance/` | **站点实例模板的真源**（带 `{{占位符}}`）：`attach` 生成的就是它逐文件替换出来的 |
| `tools/press.mjs` | 内容源 → 实例的 `content/`（**新引擎**那条日常路径；`--check` 是门）。先写临时文件成功才替换：引擎有问题时**不吐产物**，别让一次失败顺手毁掉上一份 |
| `tools/baseline/` | 只剩一件事：**P6 搬界面前的 DOM 取证**（历史证据，不参与判据）。旧的"对账基线"已退役 —— 见它的 `README.md` 与 PLAN 的 D29 |
| `tools/normalize-gen.mbtx`（壳子 `tools/normalize-gen.sh`） | 把"旧形状 / 新形状"化到同一条基准线（三条规则），带 `--selftest` 钉住"值改一个字符必须红"的边界。⚠️ 2026-10-07 从 `.mjs` 换成 `.mbtx`（② 的第三件）：纯文本变换 = `.mbtx` 的甜区 |
| `tools/shell-traps.mbtx`（壳子 `tools/shell-traps.sh`） | 双引号里的反引号 = **会真的执行**；`--selftest` 四向诱饵。⚠️ 同上，从 `.mjs` 换成 `.mbtx`（② 的第二件） |
| `tools/dom-dump.mjs` | 真 Chrome 抓**渲染后的 DOM**（P6 搬界面的对账仪器）：`--repeat 2` 先自证仪器稳定，再比搬前搬后 |
| `tools/run-js.mjs` | js 那条图的**引导层**，开发期入口 —— **只有一行转发**（实现在随包发的 `launcher/skillpress.mjs`：`/tools/` 不进包 ⇒ 一份实现只能落在 `launcher/`。见 D35） |
| `tools/fixtures/` | **冻结夹具语料 + 入库 golden**：引擎的语料级回归网（判据 `tools/engine-fixtures.sh`）。设计与边角见它的 `README.md` |
| `tools/spike/` | P8.0 探针 + 对账的**基准生成器**（不进发布包，`.moonignore` 已排掉） |

## 对账与验收（判据都写在明处）

引擎已经搬完了（Node → MoonBit，`PLAN.md` 的 P8）。搬的过程**只认一条**：
新实现的输出要与旧实现的产物**逐字节一致** —— 「看着差不多」不算数。
⚠️ 旧实现（`lib/` + `bin/`）**已整体退役**（D43）：参照物换成了 `tools/fixtures/expected/` 里的入库 golden。
⚠️ P6 起这句话有个限定：生成物的**形状**换了（类型搬进包 `shell`、值带 `@shell.` 前缀），
所以 ① 的口径是"**归一化后**逐字节一致"—— 归一化只抹**形状差**（三条规则，见 D26），
映射差一个字节都不许有；基线自己被旧形状判据 + sha256 钉子 + 旧引擎现场重印三重钉住。

```bash
export SKILLPRESS_CORPUS=../moobile/skills     # 下面的命令都按这个内容根跑
# ① ② ③（迁移期的三条对账判据：整份生成物 / 上色 / 文档块）**已随 `lib/` 退役**（D43）——
#    它们的职责现在由 ⑫ 承担（参照物从「现场跑的旧实现」换成了入库 golden）。
bash tools/blocks-fixtures.sh     # ④ 夹具：残缺的围栏 / 缺分隔行的表格 / 图片与原始 HTML / 空内容根 —— 与入库 golden 逐字节比
bash tools/line-budget.sh         # ⑤ R9：每个源文件 ≤400 行（默认全覆盖 + 显式豁免；--selftest 造 401 行的诱饵证明它会红）
bash tools/diagnostics-ledger.sh  # ⑥ 诊断口径账本：旧实现 76 条诊断逐条"有对应物"或"记了账"（--selftest 改坏锚点即红）
bash tools/fresh-clone-check.sh   # ⑦ 干净克隆自查：把 HEAD 克隆到临时目录（只有 tracked 文件）、现装现编，再跑上面几条 + R9 + 账本
bash tools/package-check.sh       # ⑧ 发布包内容复核：该含的缺一个也红、不该含的多一个也红（--selftest 三向诱饵）
bash tools/mbt-traps.sh           # ⑨ MoonBit 坑位（第一条：`Array::sort()` 排字符串**不是字典序**；--selftest 两向诱饵）
bash tools/site-source.sh         # ⑩ 首页源（R2：WEBSITE.md 优先 / 回退 SKILL.md / --home）+ 忽略清单（R4：站点与门都跳过）
bash tools/shell-traps.sh         # ⑪ shell 坑位（双引号里的反引号 = **会真的执行**；--selftest 四向诱饵）
bash tools/published-check.sh     # ⑫ 发布后（§7 第 7 条）：从 registry 装下来、在别的工程里编过（没发布时会明说）
bash tools/attach-check.sh        # ⑬ 脚手架：产物齐全 / 幂等 / 不覆盖手写 / 坏输入不落盘 / 首页改写（+ 诱饵）
bash tools/queries-check.sh       # ⑭ 内嵌 query（native 用）与 grammars/*.scm 逐字节同源（+ 诱饵）
                                  #    加 `--build` 再加一档：生成出来的实例**真的能编**（要拷依赖，慢）
bash tools/native-parity.sh       # ⑮ 两个 target：同一份语料上 native 与 js 的产物**逐字节一致**
                                  #    （gen-file 921 行 / dump-blocks 224 行 / batch 读数）；前提守卫：两份
                                  #    runtime 必须同版本、PROVENANCE 记的 sha256 必须对得上盘上文件
bash tools/engine-fixtures.sh     # ⑱ 引擎在**冻结夹具语料**上的读数 == 入库 golden（迁移期那三条的永久替代品：
                                  #    语料与期望都冻结 ⇒ 不会像 D29 那次那样"基线自己腐掉"）
bash tools/acceptance.sh          # ⑪ 验收：按 PLAN §6 的 A1/A2/A3 逐条查（红在哪 = 还差什么）
```

**P6 补的两台自证过的仪器**（判据不只看"产物对不对"，还看"判据自己会不会红"）：

```bash
bash tools/normalize-gen.sh --selftest                       # 归一化只抹形状：值 / 顺序 / 缩进 / 正文空行改一处都必须红
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
node tools/run-js.mjs check --skills skills
node tools/run-js.mjs check --skills skills --update-lock   # 复核体量后落锁
```

✅ **已经自举**（2026-10-06）：程序仓的 `skills/` 自己就是一份语料，实例在
`skills/skillpress/scripts/.skillpress/` —— 它由脚手架生成：
`node tools/run-js.mjs attach --repo . --skills skills`（`--repo` 要显式给：默认那个根是旁边的 `moobile/`）。

## 门与判据（现状，2026-10-06 复核；**这些会漂 —— 要准数就跑一遍**）

```bash
node tools/run-js.mjs check            # 门：skill 自己（G1–G8）
moon test engine/gates                 # 门自己的证伪：22 条 wbtest（诱饵全被点名）
node tools/run-js.mjs audit            # 上色的回归闸门（召回率 / 未上色比例）
bash tools/verify.sh                   # 站点判据：22 条（真 Chrome 无头；**要一次 native 编译**）
moobile/tools/skillpress-gates.mjs --gate facts   # 事实来源对账（按 D18 住在**内容仓**）
```

> ⚠️ 上面那几行是**入口**，不是读数；要准数就跑一遍（判据会自己打读数）。

## 诚实清单

1. **还没发布**：现在靠**源码路径**调用（`node tools/run-js.mjs …` / `bash tools/verify.sh`）。
   ⚠️ 发布形态已改（`PLAN.md` 的 D15）：**不单独发 npm 引擎包** —— 引擎从这 3404 行 `.mjs`
   迁到 MoonBit（P8.0–P8.2 **已落地**：`engine/content` / `engine/gates` / `engine/highlight` + `cmd/skillpress`），
   最后由**一个月亮包**装下引擎 + 站点界面 + skills，CLI 用 `moon install` 装。
   ✅ **站点判据也搬完了**（P8.3，2026-10-07）：本体在 `engine/site/` + `cmd/skillpress-native verify`，
   22 条与旧实现在**同一份站点产物上各跑一遍、逐行 diff 一致**（D38 的读数）。
   ⚠️ 出这条读数的 `tools/site-parity.sh` **已随 D43 退役**（同一批里 `site-corpus-parity.sh` 也一样）
   ⇒ 今天仓里**没有能复跑它**的判据，这句请当**历史读数**读；现役那条路是自己跑 `bash tools/verify.sh`。
2. **native CLI 能 `moon install` 装上、产物与 js 逐字节一致**（P10，2026-10-07 实测）：
   `moon install ./cmd/skillpress-native --bin <目录>` 装出来的是**本机可执行件（使用者零 Node）**，
   跑 `gen-file` 的产物与 js **逐字节一致**（921 行；判据 `tools/native-parity.sh`，含 `--selftest` 六条诱饵）。
   ⚠️ 三条写在明处的账：① **吃到 `check` / `attach` 时程序根必须显式给**
   （`--program` 或 `SKILLPRESS_PROGRAM`）—— `moon install` 把可执行件放进 `~/.moon/bin/`，
   那里没有 `claims.txt` / `skills.lock.json` / `template/`，而 **native 不猜**（不给会先打一句
   「程序根没给（native 不猜）」，然后门照常红）；② **日常那条路仍是 Node**（`tools/run-js.mjs`）—— `moon install` 走 release 构建，慢一档（站点判据已经搬完了，它自己就是 native 那条路）；
   ③ 两条**已知口径差**：js 的 `md_kids` 用 `localeCompare`（分语言环境）而 native 用 UTF-16 码元序
   （同一层里既有大写又有小写开头的名字会排得不同）；native 没有 `process.exitCode`，退出码记在 `Ref` 里由可执行件收摊时用。
3. ✅ **界面已抽成包**（P6 起）：站点壳住在 `shell/`（tokens / theme / layout / sidebar / toc / blocks /
   article / pages / topbar / mobile / route…），实例 `app.mbt` 只剩几行接线。形状、验收读数与
   "哪些还没做"在 `DESIGN-site.md §11–§12`，施工单在 `PLAN-ui.md`。
4. **`pack` 还没做**（`attach` **已落地**，见「脚手架」一节）：`pack` 命令存在，但会明说"还没做"并以非零退出
   （不做"看着像跑了"的假动作）。
5. **还没做的三件**（每件的卡点与归属都写在 `DESIGN-site.md §12.2`）：
   **搜索 ⌘K**（要构建期索引 + 浮层 —— portal / 遮罩 / 点击穿透，`@style` 今天给不了）；
   **目录可点 + 跟读高亮**（缺 moobile 的"滚到节点 + 元素测量" ⇒ 目录今天是**纯文字行**，
   故意不做成假链接）；**页面内 `#section` 深链**（同一层原因，`shell/` 里今天没有 id/锚点通道）。
   ✅ 已经还掉的两笔旧账：**窄屏入口**（三个贴边按钮 + 两级交互 + 遮罩互斥，`shell/mobile.mbt`）；
   **URL 路由**（hash ⇄ 状态双向 + 后退 + 深链 + 404 有到达路径，`shell/route.mbt`）。
6. **打的是 dev 模式 bundle**（约 6 MB，大头是 react-native-web）：上生产要换 `NODE_ENV=production` + `minify`。
