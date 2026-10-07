# PLAN —— skillpress 收口计划

> 本文是**计划**（会变），不是契约。契约在 [`SPEC.md`](SPEC.md)（投影规范）、
> [`SKILLS.md`](SKILLS.md)（集合划分）、[`DRIFT.md`](DRIFT.md)（漂移政策）。
> 下面所有数字都是**某次实测的快照**，要现状就去重跑对应的命令 —— 别抄。

## 0. 起点（2026-10-06 快照）

三个根已就位（细则见内容侧 `skills/skillpress/references/layout.md`）：

| 根 | 在哪 | 是什么 |
|---|---|---|
| **程序** | 程序根 = 本仓库（`interest/skillpress`，**与内容仓平级的另一个 git 仓库**） | 引擎 + 门 + 语法资产（将来发 npm / moonbit 包） |
| **内容** | `../moobile/skills/`（旁边的兄弟仓库） | 7 份 skill（harness 的扫描根，rank 200，agent 直接可加载） |
| **实例** | `skills/skillpress/scripts/.skillpress/` | 一个"用程序"的 MoonBit 工程（`content/` 是生成物） |

当时全绿：`check` 7/7 ｜ `check --selftest` 13 项 ｜ `press --check` 一致 ｜
`audit` 召回 97.4% ｜ `verify` 20/20 ｜ moobile 的 `verify_all.sh` 34/34。

**P1 落地后的现状**（2026-10-06，同样只是快照）：7 份 skill / **29 份 references** / 主文档最长 134 行
（除首页 skillpress 外，拆过的 5 份主文档 74–98 行）；站点 **29 个子页**（P1 前是 5 个）；
`check` 7/7、`check --selftest` 13 项、`press --check` 一致、`verify` 20/20、`audit` 在闸门内、
`facts` 硬 0 / 软 2、moobile 的 `verify_all.sh` **34/34**。

## 1. 已定的决定（谁定的、为什么）

| # | 决定 | 出处 / 理由 |
|---|---|---|
| D1 | 首页 = `skills/skillpress/SKILL.md`（它自己既是 skill 也是主页） | 用户定；首页内容与别的 skill 同一套规矩（体量、门） |
| D2 | 顶栏形态 **B**：分栏做成现代分段控件；**「文档」就是最右那一栏，不给独立样式** | 用户定（A 的"极简顶栏 + 全靠右栏目录"被否） |
| D3 | 首页的二级标题 = 顶栏的一栏；**某节只有链接时，点它直接跳**（链到文件就渲染那个文件） | 用户定；让首页能当"入口页"用 |
| D4 | 目录（TOC）：**空间够挂右栏；不够收进左侧对应条目下**（可选展开子树） | 用户定；左侧形态选 A（挂在条目下） |
| D5 | 侧栏**不按家族分组**；等 ref 拆完再看 | 用户定 |
| D6 | 子页位置**不限**：任何子目录里的 `.md` 都收；`references/` 只是推荐位置 | 用户定；规矩落在 `lib/kids.mjs` |
| D7 | 包的形态：将来发 **npm 包 / moonbit 包**；`.skillpress/` 是"**用**程序的工程"，不是程序 | 用户定 |
| D8 | 这一轮的改动**先不加新判据** | 用户定；验证靠现有 20 条 + 一次性探针 + 人眼 |
| D9 | 拆 ref 的**验收方式**：门只能证明"结构没坏"（体量 / 路径 / 指纹），证明不了"信息没丢" ⇒ 补一道**逐条对账**（另一个 agent 拿原版与新文件对表，产出丢失 / 改写风险 / 新增三类清单） | **执行期定的（不是用户定的）**；G3/G8 抓不到的正是"搬运时悄悄丢一条" |
| D10 | ref 文件名用**主题词**（`structure` / `styles` / `events-and-children`…），**不沿用原节的编号** | **执行期定的**；编号会被下一轮改动打乱，主题名不会 |
| D11 | 「纯链接节」的判据：**节的标题整条是一个链接**（`## [名字](目标)`；用户给的原话是 `## [这种呀]()`），不是"正文里都是链接" | 用户定（P2 执行期问的）；只有它成立时点那一栏才直接跳页 |
| D12 | 吸顶：**先探、拿不到证据就不写"已吸顶"** —— 探到底之后发现**是一行 CSS 的事**（根因在宿主 `#root` 是块盒 + 应用根是弹性项），见 P2 那一节 | 用户定（P2 执行期选的兜底档）；"探到底"这一步救了它 |
| D13 | **程序独立成一个 git 仓库**（`interest/skillpress`），与内容仓 `interest/moobile` **平级**（兄弟） | 用户定（2026-10-06）；理由：程序要能独立发布与协作（那正是"待在内容仓里"给不了的）。代价写在明处：内容里的命令多一层 `../skillpress/`；门那边补上了 G3 的**第二个根 = 程序根**（原先那个根写的是仓库根、与第一个重复 ⇒ 讲程序的指针一个都没查过），并加了诱饵 `bad-program-path` 守着它 |
| D14 | 站点应用顶栏那条**换模式的标签必须有它自己的名字**（`i == -2` ⇒ 「文档 / SKILL」），不许落到 `i < 0 ⇒ "首页"` 的兜里 | 执行期定的（2026-10-06 逮到）；代价是一次真 bug + 一条假绿判据，见 [`docs/FINDINGS.md`](https://github.com/XiLaiTL/moobile/blob/main/docs/FINDINGS.md) —— 实测：顶栏两条「首页」，`verify` 里 3 条判据被静默跳过（19 条 → 22 条） |
| D15 | **引擎迁到 MoonBit**（今天的 3404 行 `.mjs` 逐步换成 MoonBit，**不单独发 npm 引擎包**） | 用户定（2026-10-06）。⚠️ 这条**推翻了"程序将来发 npm 包"那半**（D7）：引擎原来写成 Node 是**继承既有工具链的惯性，从来没有过这个决定**（我 grep 过 SPEC/PLAN/DRIFT/README，一句理由都没有）。查实之后"MoonBit 做不到"的顾虑不成立 —— 需要的包全在（见 §5），所以按"我们本来就是 MoonBit"来。阶段与判据见 **P8** |
| D16 | **产品边界 = 通用产品**：任何人有一堆 `SKILL.md` 都能起站（不是「只给 moobile 做文档站」） | 用户定（2026-10-06）。后果：`attach` / `pack` 从「以后再说」升为**核心需求**；没有 moobile 源码时核心门**不许死**（缺什么明说跳过）；首页仍是「名为 `skillpress` 的那份 skill」这条约定**保留**（D1） |
| D17 | **忽略清单 `skillpress.ignore.md`**：列进去的 skill **站点不上桌、门也跳过** | 用户定（2026-10-06）。⚠️ 它同时是一条「让门变绿」的通道，所以必须**响**：每条带理由（没理由**就红**）、每次跑都打印「被跳过的 N 份 + 理由」、**首页不许被忽略**、清单进 git 可复核（细则在 `SPEC.md` §0.1） |
| D18 | **门分层**：核心只留通用门（G1–G4 / G7 / G8）；G5（`.mbt` API 对账）、G6（`docs` 的 `§` 号）、`facts`（docs 撒谎）**搬去内容仓自己** | 用户定（2026-10-06）。直接服务 D16：那三条读的都是 **moobile 的**源码与文档，别人没有。⚠️ **还没落地**（今天它们仍在核心里） |
| D19 | **站点首页的内容源从「那份 skill」里拆出来**：首页 = `<内容根>/skillpress/WEBSITE.md`；`skillpress/SKILL.md` 从此**只讲 skillpress 本身**（工具的用法/做法）；因此 `skillpress` 这份 skill **自己进忽略清单**（原话：「第一个 ignore 就是自己」）。另加 `--home <路径>` 可覆盖（服务 R6），没有 `WEBSITE.md` 时**回退** `SKILL.md` 并**打印**用了哪个。**落地时机**：等引擎支持（P8）后**与内容一起动**（用户定，2026-10-06）—— 今天先不动内容，免得站点的首页源与实现不一致 | 用户定（2026-10-06）。理由：`SKILL.md` 原先**同时当主页和当 skill** —— 一份文件混两种规矩（顶栏栏名要短 vs skill 门禁要自足） |
| D20 | **首页文件也过门，且不许被忽略豁免**：`WEBSITE.md` 过 G2（体量 + LF）/ G3（路径）/ G7（禁语），并进 G8 指纹；**它不算子页**（kids 必须排除它） | 用户定（2026-10-06）。两个洞都是实测出来的：① `skillFiles()` 只收 `SKILL.md` + `references/**` + `FAQ.md` ⇒ **首页今天既不过门也不进指纹**（能无限膨胀而没人复核）；② `mdFiles()` 收除 `SKILL.md` 外的所有 `.md` ⇒ 不加排除的话，同一个文件**既当首页又当书架里的一页**，两套渲染规矩打架。<br>✅ **四件事都落地了**（2026-10-06）：过门（报告里单列 `✓ skillpress/WEBSITE.md（首页源）`）、不算子页（索引 + kids 都排除）、**进指纹**（锁里一条 `"skillpress/WEBSITE.md"`：落锁写出、改一个字节当场报 `G8 首页源指纹变了`）、**不许被忽略豁免**（忽略清单里写 `WEBSITE.md` 会因"名字不是真目录"当场红 ⇒ 结构性地做不到）。判据 = `tools/site-source.sh` ⑤⑥（含"改一字节必须红"的现证）。⚠️ 落地顺序上有个坑记在这儿：指纹那一半要等**写侧**（`--update-lock`）搬进新引擎才做得了，否则旧 CLI 写的锁里永远没有这一条，新门会一直报「新增」—— 那是**假红**，比不查更糟 |
| D21 | **新引擎每个源文件 ≤ 400 行（含注释）**，与 skill 那边同一个预算；超了拆成「一个文件一件事」，**不许删注释凑数**；**由门 + 诱饵保证** | 用户定（2026-10-06，原话「转成 moonbit 后最多一个文件 400 行」）。为什么值得单列：**代码这边原先一条体量门都没有** —— 实测 3412 总行 / **2413 代码行**（注释 23%、空行 7%，不是注水），其中 4 个文件超 400（`gen-content` 636 ｜ `verify-site` 565 ｜ `check` 444 ｜ `docfacts` 401）。真因：几件事塞进同一个文件 + 手写了两样本该是包的东西（markdown 解析器、CDP 客户端）+ moobile 专属的东西混在核心里（D18 要搬走）。⚠️ Node 版**不回改**（冻结），规矩只对**新实现**生效。<br>⚠️ **2026-10-06 补记（这条判据自己的一课）**：它原先写的是 `find engine cmd`（一张**手写的"要查的目录"清单**），而 P6 抽出来的界面包 `shell/` 在**仓库根**上 ⇒ **它有生以来一次都没被量过**，判据却一直打印「✓ R9 通过：42 个文件全部 ≤ 400 行」——**42 里没有一份是 shell**（`shell/topbar.mbt` 329 行，其实合规，但"合规"这件事当时没人知道）。改法不是"再补一个目录"（那张清单下次还会烂），而是**默认全覆盖 + 显式豁免 + 把覆盖清单打出来 + 空集合守卫**：现在量到 52 个文件（`shell:10`、`engine/gates:11` 第一次进账）。教训与 D23 同源：**判据说"全绿"时，先问它到底量了什么。** |
| D22 | **诊断措辞允许一种偏差：「旧句子在新设计下成了假话」，但必须记账、并把新句子冻在判据里**。第一条实例是**空内容根**：旧实现 push `skills/ 下没有 SKILL.md`（**还会多报一条**「找不到首页」），新实现打「内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）」。**行为**（退 2、不吐产物）两边必须一致；**措辞**这处偏差由 `tools/blocks-fixtures.sh` **夹具四**冻住：整句逐字节断言 + 一条诱饵（**有内容的内容根不许出现这句**）+ 断言本条决定在 PLAN 里记着 | 实测（2026-10-06，干净克隆自查 + 静态审计）。理由：旧句把根名**写死**成 `skills/`，而内容根现在可配置（`--skills <目录>` / `SKILLPRESS_CORPUS`）—— 照抄旧句在新设计下就是**假话**；新句还交代了"目录是谁列举的"，更指得动路。⚠️ 这段还牵出下面那笔老账 |
| D23 | **判据的读数只在「干净克隆 + 现编」下算数**：新增 `tools/fresh-clone-check.sh`（把 HEAD 克隆到临时目录、**只带 tracked 文件**、现装依赖现编，再跑四条对账 + R9；带 `--selftest` 诱饵）。**本机绿不算数** | 实测两笔老账（2026-10-06）：① 四条对账判据要"编出来的 js"，而 `_build/` 不进版本库 ⇒ **干净克隆里全红**、本机一直绿（只因本机早编过）；② 更狠的一条：**已提交的引擎里根本没有**「图片 / 原始 HTML / 表格缺分隔行 / 围栏没闭合」这四条点名规矩 —— `parse_blocks(body)` 的签名里**没有 problems 参数**，移植时按我自己写的注释（"`dump-blocks` 的判据是逐字节一致 ⇒ 这条命令不用 problems"）把报错清单从 API 上摘了，而 `gen-file` 正需要它。**参数一摘，规矩就没了出口**：坏夹具上 `gen-file` 退出码 0、stdout 吐 4407 字节坏产物、stderr 全空 —— 正是旧实现刻意不做的「静默丢」。⚠️ 连带承认：`blocks-fixtures` **从出生那一刻（25046f6）起就是红的**，我上一轮报的"四条判据全绿"里那一条是**假绿** |
| D24 | **发布包的边界**：发 **新引擎（`engine/**`）+ 站点界面（`shell/**`）+ 新 CLI（`cmd/**`）+ 门要读的数据（`claims.txt`：G7 禁语表）+ 语法资产（`grammars/**`）+ 规范与账本 + 程序自己的 skill（`skills/**`）+ 许可/署名**；**不发开发期的东西**：旧 Node 引擎（`lib/`）、旧 CLI（`bin/`）、npm 清单（`package.json`/`package-lock.json`）、判据与夹具/引导层（`tools/`）、构建产物、**指纹锁**（`skills.lock.json`：里面是本机绝对路径）、草稿（`_scratch/`）。由 `.moonignore` 钉住；判据 = `tools/package-check.sh`（该含的缺一个也红、不该含的多一个也红） | 实测（2026-10-06）：`moon package --list` 里原本赫然有 `lib\*.mjs`（冻结的旧引擎 7 个文件）、`bin\skillpress.mjs`（旧 CLI）、`package.json`/`package-lock.json` —— 发出去等于让用户拿到**两个引擎，其中一个是旧版**。⚠️ **拿到包的人怎么用它**（R6 那一问，2026-10-06 有答案了）：包里带 **`launcher/skillpress.mjs`** —— 见 D33。⚠️ 诱饵刻意**不依赖本模块能编**（拿自造清单喂检查器）：把"判据自己会不会红"绑在"此刻编不编得过"上，就等于**别人一改代码诱饵先失效** |
| D25 | **数据的家搬进包**：`Span` / `Block` / `Kid` / `Doc` / `NavItem` / `Section` / `Home` 从**生成物**搬进 `shell/types.mbt`（唯一声明处），生成物**只填值**：签名与值都带 `@shell.` 前缀、结构体字面量保持**匿名**（靠字段类型推）。⚠️ 三个类型必须 `pub(all)` 而不是 `pub`（后者对别的包**只读**）。代价：`shell` 要用 moobile（`@html`/`@style`/`@cmd`/`@moobile`）⇒ `XiLaiTL/moobile` 成了**模块级**依赖，随包发布给所有用引擎的人（要拆开只能拆成两个模块） | 用户定（P6，2026-10-06）。兑现的是同一条价值观：**契约只有一处**（原来类型声明在生成物里 = 每个实例各有一份，改契约要改所有生成物）。三个"没想到"（`using` 只引类型名、限定结构体字面量不是合法语法、`pub` 只读）都是**实测**出来的，记在 P6 那节的补记里 —— 语言事实别猜 |
| D26 | **"逐字节一致"这条判据的载体换一次，但口径更严而不是更松**：旧形状的产物冻成基线（`tools/baseline/`，**只能**用旧引擎刷、sha256 钉住），新产物与它**先归一化再逐字节比**（`tools/normalize-gen.mjs` 三条规则 = 去头注释 / 去类型声明块 / 去 `@shell.` 前缀）；另加"旧引擎现场重印基线"（`acceptance.sh` A3）与两条形状守卫（基线必须旧形状、新产物必须新形状）。**判据自己必须会红**：`tools/file-parity.sh --selftest` 五条，其中"只在归一化看不见的地方改基线 ⇒ 必须红"证明 sha 钉子是**承重**的 | P6 实测（2026-10-06）。由来：生成物的形状换了（D25），原来那条"与实例里的旧产物逐字节比"**比不出东西了**（两边的形状差是**设计**，不是 bug）。两条替代路都更差：删掉判据（丢了对映射的逐字节防线）／改成"看一眼差不多"（把旧实现白干）。所以选"归一化只抹形状差 + 多层钉子"。⚠️ **边界写在明处**：归一化抹掉的正是"前缀与类型声明块"这两样 ⇒ 它们**只**由形状守卫与编译器（`@shell.` 写错就编不过）保证，不由那条 diff 保证 |
| D27 | **MoonBit 里不许用 `Array::sort()` 排字符串**（它**不是字典序**）；要排就自己写比较器 —— `engine/gates/` 里现成的 `utf16_compare`（JS `.sort()` 的 UTF-16 码元序）+ **稳定**排序 | 实测（2026-10-06，P8.2 对账逮到）：`["styles.md","structure.md","events-and-subs.md","FAQ.md"]` 被排成 `["FAQ.md","styles.md","structure.md","events-and-subs.md"]`（看着像先比长度）⇒ 真语料 `references/` 顺序**整片错位**。危险在于它**不会自己红**：编译器不管、不写测试就不炸，只会在某天"顺序又不对了"时以最难查的形式冒出来。判据 = `tools/mbt-traps.sh`（代码行里的 `.sort()` 即红；**注释里的不算** —— 否则解释这条规矩的注释会把门弄红，人就只好去删注释）；另有 `gates_wbtest.mbt` 一条测试**显式断言 `.sort()` 的结果与字典序不一致**，作为"这条规矩为真"的现场证据。⚠️ 例外只有两处且都写了理由：`report_wbtest.mbt`（就是那条测试）与 `ts_shim.mbt`（JS 源码字符串）—— 例外还被**断言仍在位**（豁免不许烂在判据里） |
| D28 | **首页源（R2）与忽略清单（R4）的落地口径**：① 首页源 = `skillpress/WEBSITE.md` 优先 → 回退 `SKILL.md` → `--home <路径>` 覆盖，**用了哪个都打印**（`· 首页源：…` 走 stderr —— stdout 是产物）；② 清单住**内容仓根**（`<内容根>/../skillpress.ignore.md`，`--ignore` 可覆盖），格式 `- <目录名> —— <理由>`：**理由必写、名字必须是真目录、认不出的行也红**；③ 站点与门**两边都跳过**，每次都打「跳过了几份 + 逐条理由」（形状 `⊘`，与 `✓`/`✗` 不同形）；④ **全被忽略 ⇒ 门判红**（"不允许在空集合上通过"）；⑤ 清单有问题 ⇒ **退 2 且一份都不套用**（"半套用"是最难查的状态） | 兑现 R2 / D19 / D20 + R4 / R8。判据 = `tools/site-source.sh`（17 条断言：三路首页源 + 四种坏清单 + 门那一侧 + 诱饵）。⚠️ 两笔边角记账：`blocks-fixtures` 比的是**问题清单**，所以它先滤掉 `· ` 信息行（R2 要求打印首页源 ⇒ stderr 多了一句**实话**，不是问题）；`gen-file` **回退**那一路在生成物的文档注释里仍写 `skills/skillpress/SKILL.md`（与冻结的旧实现逐字节一致 —— 那是 `file-parity` 的要求），只有真用了 `WEBSITE.md` 才写 `WEBSITE.md` |
| D30 | **脚手架的落地口径**：命令 `attach` 住**新 CLI**（今天在 `cmd/skillpress/cli/attach.mbt`，见 P10 ⑩ 的拆包；纯逻辑包 `engine/scaffold/`，后者**不 import 内容管线** ⇒ 任意 target 都能 `moon test` 它）；模板真源 `template/instance/**`（占位符 `{{MODULE}}` / `{{ENGINE_REL}}` / `{{HOST_DEP}}` / `{{SITE_TITLE}}` / `{{SKILLPRESS_VERSION}}`，生成器**断言产物里一个占位符都不剩**，还查"没登记过的占位符样子"）；**先算后写**（算不出就退 2 且一个字节都不写）；人写的文件**已存在就跳过并点名**、`--force` 才覆盖；**没有 `--ignore` 时沿用盘上那份清单**；首页源 = `--home` → `<仓根>/README.md`（复制 + 改写：能对上账的链接折成站点口径，对不上的**降级并打印**）→ 模板首页；交互式只在 TTY 上默认开（`--interactive` 可强制，答案可从管道喂 —— 只认终端的话，交互逻辑**永远测不到**） | 用户定（2026-10-06）+ P9 实测。判据 = `tools/attach-check.sh`（①–⑨ + 诱饵）。⚠️ 三条**实测**出来的硬约束：① 模板目录名不能以点开头（`moon package` 会整个跳过它）；② 传给内容管线的首页源必须用**内容根口径**的标签（`skillpress/WEBSITE.md`），用绝对路径会让 D20 那条"首页源不算子页"认不出来 ⇒ 第二次跑多出一页；③ 生成物里的 `XiLaiTL/skillpress@<版本>` 要从**程序根的 `moon.mod`** 读（写死会在程序升级后让生成出来的工程编不过） |
| D29 | **对账基线的载体第三次换：从"冻结旧产物"改成"两个引擎跑同一份副本"（v3）**。`tools/mk-parity-corpus.sh` 把真语料的 skill 原样拷来（去掉 `WEBSITE.md`、副本上一级不放清单）⇒ 两个引擎读同一份内容 ⇒ 仍然**整份文件逐字节**比，而内容广度不丢。三支吃语料的判据（`file-parity` / `blocks-parity` / `highlight-parity`）都走这条路；旧基线（`tools/baseline/content/content.generated.mbt` + `EXPECTED.sha256`）**退役**，那里只留 DOM 历史证据 | 2026-10-06 实测（R2 那一批）。理由：内容仓有了 `WEBSITE.md`（R2）与忽略清单（R4），而**冻结的旧实现不认识它们** ⇒ 旧产物在真语料上**必然分叉**。继续冻基线只有两个下场：判据红 ⇒ 刷基线的命令产出**仍是旧读法**（无解的死循环）；判据绿 ⇒ 只可能是新引擎产物被塞进基线（**恒真**）。⚠️ 前提不假设：`mk-parity-corpus.sh` 自己断言「副本里没有 WEBSITE.md / 上一级没有清单 / 不是空集合」，`file-parity --selftest` 还专门证「**前提被破 ⇒ 拒绝比并点名**」。⚠️ 顺带揭穿一处**旧假绿**：v1 的 `blocks-parity` 拿"实例里那份"当旧侧，而 P6 之后那份**早就是新引擎印的** ⇒ 它在比"新 vs 新"（补齐归一化并换成副本口径后才重新有含义） |
| D30 | **首页里的链接多一层"内容根相对"的回退**（旧实现只按**首页目录相对**解析）：`resolve_page` 先试 `<首页目录>/<目标>`，不中再试 `<内容根>/<目标>`。另外 `gen-file` **回退**那一路（首页 = `skillpress/SKILL.md`）在生成物注释里仍逐字节照抄旧实现 | 2026-10-06 内容侧拆分当天实测的必要条件：`skillpress` 那份 skill 进了忽略清单 ⇒ 它的 `references/**` 从站点上消失 ⇒ 只认"首页目录相对"的话，**首页再也指不到任何一页**（新建的 `WEBSITE.md` 会立刻因死链被判红）。加了回退之后首页能指向书架任意一页 —— 这也是 R6"通用产品"该有的样子（首页与书架是两个东西）。⚠️ 这是**有意的扩展**（旧实现会报"认不出哪一页"），`dev` 性质、不影响老形状语料的对账（① 命中就不走 ②）。⚠️ 同一天现役工具 `lib/verify-site.mjs` 也跟着学（否则它按旧口径解析、直接崩在 ENOENT —— 实测） |
| D31 | **`check` 搬进新 CLI（`node tools/run-js.mjs check …`），G8 的写侧（`--update-lock [名字]`）也一起搬**；新 CLI 的 `check` **不需要 tree-sitter**（门不碰高亮 ⇒ 先于"引导层装好了没有"那道检查分发）。G5 / G6 / `facts` 按 D18 **留在内容仓那一侧**（今天仍写在旧核心 `lib/check.mjs` / `lib/docfacts.mjs` 里；迁移的最后一步是内容仓自己长出那三道门、并改跑新 check） | 2026-10-06。**为什么先补写侧**：没有 `--update-lock`，新门一红就只能回旧 CLI 落锁 —— 那是一扇"半个门"，而落锁恰恰是"让门变绿"的唯一入口，它坏掉最危险（悄悄不写／把别人正在改的指纹一起锁掉）。读数：与旧门在**副本**上 `diff = 0`（75 行）、22 条 wbtest、落锁循环在**临时程序根**里四步全过（落锁 ⇒ 无「新增」⇒ 改一字节 ⇒「指纹变了」红）。⚠️ 已知差异照写：`--selftest` 没搬进 CLI（14 条诱饵已作为 `moon test` 落在 `gates_wbtest.mbt` 里）。⚠️ 顺手被 R9 逮到一次：这一批把 `cmd/skillpress/main.mbt`（459 行，今在 `cmd/skillpress/cli/cli.mbt`）与 `engine/gates/lock.mbt`（407 行）顶过 400 ⇒ 按"一个文件一件事"拆成 `check.mbt` / `lock_write.mbt`（**不许删注释凑数**） |
| D32 | **D18 / R5 落地：G5（`.mbt` API 名）、G6（docs 的 `§` 号）、`facts`（docs 撒谎）搬进**内容仓自己** —— 一个入口 `moobile/tools/skillpress-gates.mjs`（`--gate g5\|g6\|facts\|check`，带 `--selftest` 造夹具证伪）；台账 `done-claims.txt` 跟着搬进**内容仓根**。程序这边只留**冻结的旧实现**（`lib/check.mjs` 的 G5/G6 段、`lib/docfacts.mjs`、`facts` 子命令）：身份从"现役门"变成"搬走时的对照物" | 2026-10-06。**为什么是"搬"而不是"抄"**：这三道门读的是 **moobile 的源码与 docs** —— 别人的内容仓没有 `.mbt`、没有 `docs/**` ⇒ 留在核心里就是替一个特定仓库背代码（R5）。**读数**（我自己复现过，不是转述）：真仓库上 `facts` 整份与新工具 **diff 0 行**；G5/G6 切片两边都 0 行（真仓库本来就全绿 ⇒ **这条只证明"不误报"**，措辞与顺序的等价是在夹具上证的：坏夹具 6 行、**真 7 份 skill 文本 + 真 docs 的夹具 39 行**，都 diff 0 行；facts 在后者上是 647 行 diff 0）；正例夹具两边全绿（不误杀）。⚠️ **两处残留耦合，都如实记下**：① `facts` 的台账改读**内容仓根**那份（搬之前它会读程序那份 ⇒ 两边故意不一致，实测 diff 19 行）—— 所以台账必须真的搬过去（已搬）；② **G6 的第二个文档根是程序根**：内容里 `skills/skillpress/SKILL.md` 有 3 处引用程序的 `SPEC.md` §2/§3，新工具照搬这个根（消融实测：把 `--program` 指到不存在处，那 3 处会**静默不查**）⇒ 它在报告头部**印出每个文档根**、不存在的标「（**不存在** —— 这个根下的引用不会被查）」：不静默跳过 |
| D33 | **包里带一个启动器**（`launcher/skillpress.mjs`）：js target 的 CLI 本来就需要一个 Node 启动器（`web-tree-sitter` 的 `Parser.init()` 是 Promise，而 `moon build --target js` 出的是 CJS、顶层 await 不成立）。**`check` 这条路上连 tree-sitter 都不 import** —— 门与高亮没有任何依赖关系，"只想跑门的人不该被一个 npm 依赖挡住"；缺依赖时**说人话**（退 2 + 指名 `npm i web-tree-sitter` + stdout 空），不是甩一段 ENOENT 栈 | 2026-10-06，兑现 R6 那一问「用户拿到包之后怎么在本机跑 press/check」（D24 里那条"今天还没有答案"就此销账）。判据 = 新工具 `tools/consumer-check.sh`：**从 zip 出发**（解压成项目里的包 ⇒ 编一次 ⇒ 先用**没有 npm 依赖**的干净目录跑 `check` ⇒ 再装依赖跑 `gen-file`）。⚠️ 它带一条**前置断言**：消费者目录里必须**解析不到** `web-tree-sitter`，否则这轮"没装依赖"的读数不算数 —— 实测踩过：用户主目录里有一个误装的 `node_modules`，临时目录向上解析就命中了它。读数：包里产物与本地引擎在同一夹具上 **逐字节一致**（77 行）；死路径 ⇒ 门红；认不出的构造 ⇒ 退 2 且不吐产物。<br>⚠️ **消费者视角实测出的两个坑，都记在这儿、不假装没有**：① **锁放哪** —— `--program` 默认指着**包**（`.mooncakes/…`）⇒ 锁会落在包目录里（多项目共享、重装即丢）⇒ 消费者应当 `--program <自己的目录>`（判据就是这么跑的：先 `--update-lock` 落自己的锁、再 `check` 全绿；而**第一次**跑的真实读数是"退 1 并指名怎么落锁"，判据也钉着这一条）；② 把 `--program` 改成自己的目录之后，**G7 的 `claims.txt` 也读不到了**（它在包里）⇒ 想要 G7 就得让禁语表跟着走。这两条的正解是给 CLI 加 `--lock` / `--claims` 两个开关，**等真有消费者提出来再做**（今天先如实记着，别写成"已解决"） |
| D34 | **「0 npm」用 vendor 运行时达成 —— 不走 native、也不靠 MoonBit 的 tree-sitter 包**：把 `web-tree-sitter` 的**运行时**（MIT：一个 ESM 入口 + 一个 wasm，约 366 KB）连同它自己的 `LICENSE` **原样 vendor** 进 `vendor/web-tree-sitter/`（附 `PROVENANCE.md`：来源/版本/许可/sha256 + 更新步骤），随包发；启动器与开发引导层都改成**按路径导入**它（不写裸包名 —— 裸名会去 `node_modules` 找，而"没有 node_modules 也能跑"正是要保证的场景）。`package.json` 里那条依赖只为**本仓的冻结旧实现**留着（判据要跑 `lib/*.mjs` 现场产出基准） | 2026-10-06。**三条"为什么不是别的路"（都是实测）**：① **MoonBit 包帮不上** —— `tonyfettes/tree_sitter` 在 js 上的实现**就是** `await import("web-tree-sitter")`（`src/init.js.mbt` 原文；同一个 npm 包 ⇒ 去不掉，反而多一层依赖），而加载语法/query 的 `tonyfettes/tree_sitter_language` 声明 `supported-targets: "+native"` ⇒ js 目标上编不过（P8.0 那条报错就是它）；`moonbitlang/moonbit-tree-sitter` **在 registry 里根本不存在**（PLAN 里曾写过这个名字，已删）。② **native 只对「把引擎自己编成本机二进制」有用，与「站点支持多端」无关**（⚠️ 这句我自己先前写错过，改准）：moobile 的多端是**宿主层**的事（`expo` / `rnw` / `webview` —— 见 `npm/moobile-host/hosts/` 与 `tools/host_probe.mjs`；三个都是 **js 运行时**，MoonBit 那侧始终编成 `js`，站点实例的 `moon.pkg` 就写着 `supported_targets = "+js"`）；而**高亮是构建期算完的** —— 色号（runs）直接写进生成物（`content.generated.mbt` 里 `Code(lang, text, runs)` 的第三个参数）⇒ **运行的应用在任何宿主上都不需要 tree-sitter**，所以「多端」推不出「引擎必须支持 native」。native 唯一能多给的是一支**不依赖 Node 的引擎 CLI**（今天 js 那条仍要 Node 跑启动器），而它当时被上游挡住（`tree_sitter` 包里没有它 `#include` 的 `lib.c`）＋ `tonyfettes/c@0.7.4` 编不过当前 core ⇒ 记为备选。③ **vendor 是这仓库已经在用的做法** —— `grammars/` 就是同一套（PROVENANCE + sha256 + "一份事实一个家"）。**读数**：把 `node_modules` 整个移开，`gen-file`（918 行）与全语料 `batch` 都照跑；`tools/consumer-check.sh` 现在**一个 npm 依赖都不装**，断言 `check` 与 `gen-file` 都跑通、且产物与本地引擎**逐字节一致**（它那条前置断言仍然要求"解析不到 `web-tree-sitter`" ✓） |
| D35 | **两份引导层合成一份**：`tools/run-js.mjs` 从"把启动器抄一遍"改成**一行转发**（`await import("../launcher/skillpress.mjs")`）。实现只留 `launcher/skillpress.mjs`（那份**进包**；`/tools/` 被 `.moonignore` 排掉 ⇒ "一份实现"只能落在 `launcher/`），开发期保留 `run-js.mjs` 这个名字（20 处判据跑的是工作区里刚编出来的 js，而 launcher 的报错话术是写给"拿到包的人"的 —— **两个名字，一份实现**） | 2026-10-07。**起因是"抄两遍"真的付过代价**：两份 390 行里 308 行逐字相同，差的 82 行全在"报错写给谁看"上 ⇒ `launcher` 那侧的 `check` 快路径（门不碰高亮 ⇒ 连 tree-sitter 都不 import，见 D33 / D31）是**后加**的，`tools/` 那份一直没跟上：判据里每一次 `run-js.mjs check` 都白等一次 wasm 引导（`site-source.sh` 一条就调它 6 次）。**读数**（合并后逐条现跑，不是转述）：`line-budget` 104 个文件全 ≤400 行；`file-parity` 1070 行逐字节一致；`highlight-parity` 32 个代码块逐字节一致（走的正是 boot 那条路）；`blocks-parity` 8 段逐字节一致；`site-source` 全过（含 ⑧ 落锁四步与 ⑨ 从内容仓跑 —— 那两条正好覆盖 `check` 快路径）。`run-js.mjs` 175 行 → 32 行。⚠️ **顺手改掉一处旧假话**：launcher 文件头原先同时写着"运行时随包 vendor ⇒ 一个 npm 依赖都不用装"（D34）与"`web-tree-sitter` 只能由使用者 `npm i`"—— 后者是 D34 **之前**的旧账，已删（留着就是 G7 那种"把未做写成已支持"） |
| D36 | **P8.3 的形态定下来：站点判据只能跑 native，而且地基已经打通**。新包 `engine/site/`（`supported_targets = "+native"`）：**进程内**静态服务（`@http.Server`，替掉旧实现"再 spawn 一个 `node serve-web.mjs`"）+ `@process.spawn` 起无头 Chrome + `@http.get("/json/list")` 拿 CDP 地址 + `@websocket.Conn` 连上去 + `Page.navigate` + `Runtime.evaluate` 读回页面。这**不是方案，是已经跑通的探针读数**（见下面三条）。⚠️ 与"22 条断言"分开记：断言照搬是**下一步**，探针只证"链路通不通" | 2026-10-07，用户定"直接搬成 MoonBit"（我原本建议留 `.mjs`，理由是 moobile §4.2 那根轴把 CDP 类判给 node；用户否了，那就照搬）⇒ 三条**实测**约束必须记在明处：<br>① **js 那条路上根本没有这些东西** —— `moonbitlang/async` 的 `websocket`（`client.mbt`/`server.mbt` 只编 `native`/`wasm`，js 侧只有 `unimplemented.mbt` 桩）、`http` 的 **server**（同上；js 只有 http *client*）、`process`（同）⇒ 站点判据**要 C 工具链**，与"js 那条路只要 Node"是两回事。<br>② **本机 SDK 缺一个符号**：`moonbitlang/async` 的 native fs 桩引用 `GetTempPath2W`，那是 **SDK 10.0.20348+** 才有的导入符号，而本机只装到 **10.0.19041.0**（`strings kernel32.lib | grep GetTempPath2W` 命中 0）⇒ `LNK2019`。而 `@process` 依赖 `@async/fs` ⇒ 走 async 就绕不开。兜法是 `engine/site/win_compat.c`（转发到 `GetTempPathW`，六行，新 SDK 上不冲突）。<br>③ **`@http.Server::run_forever` 收不了摊**：`Server::close()` 之后它**不返回**，`Task::cancel()` 也**叫不动它** ⇒ `with_task_group` 在退出处**永远等下去**。症状极难查：整条链全跑通、读数全对、程序却永不退出，而 native 的 stdout 在管道里是**块缓冲** ⇒ 一个字节都看不到（我为这一条花了好几轮）。正解是**最后显式 `@sys.exit(code)`** —— 旧实现本来也是 `process.exit(...)`，`cmd/skillpress-native` 的「只在最后退一次」是同一口径。<br>**读数**（探针现跑，`moon run --target native engine/site`，rc=0；语料 = `../moobile/skills/skillpress/scripts/.skillpress`）：`① 静态服务 http://127.0.0.1:8256/`、`服务自证：true`（真的是我们那份 `index.html`，不是"碰巧同端口的别人"—— 旧实现踩过）；`② 调试端口 8255`（真绑过）；`③ CDP 目标 ws://…/devtools/page/E69F…`；`④ 页面读数` 拿回标题 **`moobile · SKILL`**，正文开头含**顶栏那 5 个分栏**（`一、站点的形状` / `二、书架上有什么` / `从哪一份开始` / `四、去哪看` / `五、门与判据`）与 `文档 / SKILL` —— 正是 22 条断言要打的那批东西。<br>⚠️ **代价与还没做的**：`engine/site/` 现在还是**探针**（一个可执行件，下了 0 条断言、CDP 客户端只有 send/eval、事件被丢掉 ⇒ 第 ㉒ 条"控制台没有 error"还做不了）；`.moonignore` 里也**还没**把它算进发布形状。22 条断言、`--shot`、事件缓冲、`verify` 接进 `cmd/skillpress-native`、以及把 `template/instance/verify.mjs` 改成调它 —— 全是下一步 |

| D37 | **P8.3 第 2 步：语料侧读数搬完，而且**有一条判据钉着它**。新文件 `engine/site/{corpus,inline,home,docs,dump}.mbt` = 旧实现 `plain()` / `pickProbe()` / `homeSections()` / `homeParagraph()` / `fencedBlocks()` / `readSource()` / `docs()` 的逐条搬运；对账判据 `tools/site-corpus-parity.sh` + `tools/site-dump-old.mjs`（**现场从 `lib/verify-site.mjs` 抽函数**跑同格式转储，不抄副本 —— 抄一份就成了"自己跟自己比"，D35 那笔债不再来第二次）；忽略清单改用引擎那份（`engine/ignore`），顺手给它补了 `Parsed::problems()` / `Parsed::entries()` 两个访问器（字段包私有，跨包读会报 `abstract type and not a struct`，`Entry` 当初就是这么办的） | 2026-10-07。**为什么先钉这一层**：语料侧解析**错了不会崩也不会红** —— 它只会让断言去比**另一句**、甚至永远绿，而浏览器那边看不出来（页面渲染得好好的，是"我在比什么"错了）。**读数**：51 行转储与旧实现**逐字节一致**（5 栏 / 6 份 skill / 27 个子页 / 11 个代码块）；`--selftest` 三向诱饵全被点名（新侧改一个字节 ⇒ 红；旧侧改一个字节 ⇒ 红 —— 证明比的是**两边**；空内容根 ⇒ 拒跑）。**四条实测出来的语言坑，都写进注释了**：① MoonBit 的 `String[i]` 给的是 **`UInt16`** 而不是 `Char` ⇒ 这一层统一转 `Array[Char]` 再扫，下标口径才与 JS 的码元一致；② 探针长度的阈值（`>=24`/`>=30`）必须按 **UTF-16 码元数**数（非 BMP 算 2）⇒ 专门有个 `utf16_len`，用 `chars.length()` 会在带 emoji 的行上悄悄换掉"哪一句被选中"；③ `String::find` **没有起始下标参数** ⇒ 从起点切一段再找、再加回偏移；④ `moon.pkg` 里声明了 `native-stub` 的那个包才链得上 C 桩。⚠️ R9 又逮了两次（都是"一个文件一件事"，不是删注释凑数）：`main.mbt` 471 行 ⇒ 拆出 `serve.mbt`/`cdp.mbt`/`browser.mbt`；`corpus.mbt` 402 行 ⇒ 拆出 `inline.mbt`。**还没做**：页面侧探针（注入页面的那 16 段 JS）+ 22 条断言 + CDP 事件缓冲（第 ㉒ 条"控制台没有 error"要靠它）+ `verify` 接进 `cmd/skillpress-native` |
| D38 | **P8.3 正题落地：那 22 条断言跑起来了，而且与旧实现在同一份站点上逐行一致**。新文件 `engine/site/{page,blocks,report,flow,checks,docs_area}.mbt`：`page.mbt` = 页面上那 16 段注入 JS（正文/点击取点/换模式那条/分栏同行/侧栏容器/行内流/几何）；`blocks.mbt` = 代码块读数、侧栏树取点、吸顶、**控制台事件**；`report.mbt` = `check()` 与收尾统计；`flow/checks/docs_area` = 22 条断言的编排（**label 与 detail 逐字照抄**）。CDP 客户端同时升级成正式版（`j_get`/`j_str`/… 一套 JSON 取值、`eval_str/int/bool/json`、**事件缓冲**、`click_at` 真鼠标三连、`screenshot_png`）。判据 `tools/site-parity.sh`：两边**在同一份站点产物上各跑一遍**，把 `✓`/`✗` 行逐行 diff | 2026-10-07。**为什么这是整条迁移里最强的一条读数**：两边都在真 Chrome、真渲染页面、真鼠标点击上跑，而详情里带着**从页面上读回来的数** ⇒ 逐行一致不只是"都绿"，而是"每一步读到的都是同一个东西"。**读数**：新实现 **22 条全绿、总条数正好 22**（`29 个检查点 − 7 个失败分支`，与旧实现的数法一致）；`tools/site-parity.sh` 报 **22 行逐行一致**，包括动态详情 —— `y = 20 / 20 / 20 / 20 / 20 / 20`、`1 个 Text 命中，嵌套 28 个 span`、`命中 6/6`、`侧栏 x=16，正文 x=324`、`2 个代码块，最花的那个 7 种颜色`、`2/2`、`容器可滚 2280px、实际滚了 300px，顶栏移动 0px`；`--selftest` 三向诱饵（改一行的 `✓` ⇒ 红；截到 12 条 ⇒ 条数守卫拦住；站点产物不在 ⇒ 新侧退 2 且**"跑不起来"与"判红"分开看**）。**又四条语言坑**（都写进注释）：① `Json` 的真值构造器是 **`True` / `False`**（没有 `Bool(b)`），空值**构造**用 `Json::null()`、**模式**才写 `Json::Null`；② `Json::Array` 只能当**模式**用，构造要走 `Json::array(…)`；③ **`fn` / `where` / `guard` 是保留字**，不能当变量名（我被 `fn` 咬了一次，报的是"Parse error, unexpected token `fn`"）；④ `.mbt` 文件里**不能写 `import`**（要在 `moon.pkg` 里），写了会连带把整包的包解析弄坏（报的是别处的 `@json.Json is undefined`，很绕）。⚠️ 还有一条**不体现在文件里**的账：`@sys.exit` 是 `Unit`，把它放进要出值的 `match`/`catch` 分支时要补一句"永远到不了"的返回值。**还没做**：`engine/site` 现在还是**可执行件**（`pkgtype(kind: "executable")`）⇒ `verify` 还没接进 `cmd/skillpress-native`；`template/instance/verify.mjs` 也还指着旧工具；js 那份 CLI 遇到 `verify` 应当**诚实地说"只有 native 有"** |

| D39 | **P8.3 收口：`verify` 接进 `cmd/skillpress-native`，js 那份 CLI 对 `verify` 诚实说明**。`engine/site/` 从**可执行件改成库**（`pkgtype(kind: "executable")` 去掉，`main.mbt` → `entry.mbt`，出口 `pub async fn run(args)`）；`cmd/skillpress-native` 改成 **`async fn main`**，在调 `@cli.run` **之前**拦下 `verify` / `dump-corpus`（分发必须落在**可执行件**那一层：moon 没有条件 import，而共享的 `cmd/skillpress/cli` 是 `+js +native` 的，它 import 不了 native-only 的库）；`cmd/skillpress`（js）遇到 `verify` **明说"只有 native 那份有"并退 2**（不许静默当成"没这个命令"）；`template/instance/verify.mjs` 从"委托 `lib/verify-site.mjs`"改成"委托 native CLI" | 2026-10-07。**四条实测出来的账**：① **`async fn main` 要求可执行件自己 import `moonbitlang/async`** —— 哪怕 `@site` 已经间接依赖它（报的是 "Cannot use `async fn main`: package moonbitlang/async is not imported"）；② **命令词要"扫"不能认下标** —— js 那条路上 argv 前面挂着 node 与编出来的 `skillpress.js`（`args[1]` 是路径），而 native 是 `[exe, cmd, …]` ⇒ 两边统一成"扫第一个命令词"（与 `cli.run` 找命令词同一口径）；③ **默认内容根不能按 cwd 拼** —— 判据常常是**从站点实例里**拉起来的（`npm run verify`），那时 cwd 在 `<内容根>/skillpress/scripts/.skillpress`，`../moobile/skills` 会拼出一条不存在的路（实测报"内容根下没有带 SKILL.md 的目录"）⇒ 改成按**程序根**（`SKILLPRESS_PROGRAM`，拿不到才退回 cwd）的兄弟 `moobile/`；④ **判据脚本里的产物路径要跟着换** —— 我改了 `EXE` 的路径却漏了一处（`sed` 没命中多行），于是脚本还在跑**已经不在构建图里**的旧 `engine/site/site.exe`，症状是"dump-corpus 打出的是 verify 报告"（`bash -x` 一跑就现形）。**读数**：`native-parity` 三条（gen-file 921 行 / dump-blocks 224 行 / batch 41 行）**逐字节一致**（改了 native 的 main 之后复验的）；`site-parity` 22 行逐行一致 + 三向诱饵；`site-corpus-parity` 51 行逐字节一致 + 三向诱饵；`R9` 123 文件全 ≤400 行；`package-check` 230 文件；js 那条路的 `check` / `site-source` 全过；**js 侧 `verify` 退 2 并说清怎么办**。⚠️ **第二个语料上的读数**（顺带把"写死 moobile 语料"这条验了）：从自举实例（内容根 = 程序自己的 `skills/`）跑 `node verify.mjs`，**22 条全绿**，而分栏/子页/纯链接节全是另一套（`先读哪一份`、`skillpress-user/SKILL.md`）—— 换语料不用改一行代码 |

| D40 | **② 落地：三个纯文件变换的工具都换了语言，`.mjs` 原件删掉**。① `gen-queries` → **`cmd/skillpress` 的子命令**（`cmd/skillpress/cli/gen_queries.mbt`，判据 `tools/queries-check.sh` 改调它；产物文件头那句"由谁生成"跟着换成 `skillpress gen-queries`，**产物重新生成过**，diff 只有那两行注释）；② `shell-traps` → **`tools/shell-traps.mbtx`**（+ 壳子 `tools/shell-traps.sh`）；③ `normalize-gen` → **`tools/normalize-gen.mbtx`**（+ 壳子 `tools/normalize-gen.sh`）。判据轴照抄 moobile `docs/design/SCAFFOLD.md` §4.2：**判据是进程边界，不是仓库内外** —— 纯文本变换进 `.mbtx`，跨进程的（`press` / `dom-dump` / `run-js`）留在 `.mjs` | 2026-10-07。**读数**：`queries-check` 站岗 + `--selftest` 全过（`--check` 在换头之前**先红**、重新生成之后绿 —— 证明它真的在比）；`shell-traps` 与 `--selftest` 输出与旧实现**逐字相同**（四向诱饵）；`normalize-gen --selftest` 六条全过，且在**真产物**上两边归一化结果 **912 行逐字节一致**；吃它的三条判据 `file-parity`（1070 行）/ `blocks-parity`（8 段）/ `blocks-fixtures`（夹具三/四）全绿。⚠️ **五条实测出来的账，都写进注释了**：① **`@env.args()` 的前缀长度随 target 变** —— js 是 `[node, <…>/_build/…/single.js, …]`、wasm 是 `[<…>/single.wasm, …]` ⇒ **不能认固定下标**。我第一版按 `args[1]` 取输入文件，于是在 js 上 `--selftest` 被当成"输入文件"，程序**把自己的产物读出来打了一屏**（1273 行 JS，看着像编译器抽风，其实是在读自己）；正解是"剥掉解释器 + 脚本"那一段（判据：以 `.js` 结尾**且在 `_build` 下**）。② **`const X : Array[String]` 不合法** —— 常量类型只允许不可变基本类型（实测报错），要写成函数。③ **`#|` 多行字符串不给最后一行补换行**，而且**直接当函数体是 deprecated 语法**（要 `let body = #|…` 再返回它）—— 夹具末尾那个换行得靠最后一条空的 `#|` 撑着。④ **`package.json` 里不能写 `"type": "module"`** —— moon 的 js 产物是 CJS 风格的 `.js`，写了 Node 按 ESM 解析 ⇒ 当场 `ReferenceError: require is not defined`（`check` 整条路全崩，我踩了并撤回）；那条 Node 噪声警告只能从壳子侧用 `--disable-warning=MODULE_TYPELESS_PACKAGE_JSON` 关掉。⑤ **`R9` 的枚举漏了 `.mbtx`** —— 新文件类型进了仓而判据没跟上，等于这批文件**没有任何行长约束**；已把 `*.mbtx` 加进 `line-budget.sh`（125 个文件）。另外顺手把 `tools/normalize-gen.mbtx` 的两份夹具用脚本**从旧 `.mjs` 机械抽取**（不当手抄），并去掉 JS 模板字面量那层 `\`` 转义 |

| D41 | **④ 第一步：判据脱钩 —— 参照物从"活的旧实现"换成"冻结语料 + 入库 golden"**。① `diagnostics-ledger`：扫描范围补上 `tools/*.mbtx`（D40 换了两个工具的语言，账本没跟上），**三行自销账**（`lib/verify-site.mjs` 的"没有 site/dist/bundle.js" / "要真浏览器" / "条不过" —— P8.3 落地之后它们**已经补上了**，账本照自己的规矩当场翻红逼我改成 `ok`），并把"老位置"那一列的语义写明是**历史坐标**（判据从不 grep 它 ⇒ 旧实现退役之后这些行仍然成立）。② 新建**冻结夹具语料** `tools/fixtures/corpus/skills/`（4 份 skill / 7 个 md）：它**从源头就没有** `WEBSITE.md`、上一级也没有忽略清单 ⇒ 新旧两个引擎本来就读同一份内容，`mk-parity-corpus.sh` 那套"造副本"在这条路上不需要了。③ 采 golden **之前**先让两边在夹具上做逐字节对账（`file-parity` 159 行 / `blocks-parity` 5 段 / `highlight-parity` 6 个代码块，**全绿**）⇒ golden 采的是"**两个引擎都同意的那份产物**"，不是"某一侧说了算"。④ 新判据 `tools/engine-fixtures.sh`（站岗 + 四向诱饵 + `--capture`） | 2026-10-07。**为什么非得有这一条**：那三条迁移期判据比的是"新引擎 vs 现场跑的旧实现"，参照物 `lib/*.mjs` 一退役，它们**同时失去参照物与一端** —— 而引擎仍然需要语料级回归覆盖（改了 `engine/content` 或 `engine/highlight`，总得有人盯着产物变没变）。换成"冻结语料 + 冻结期望"之后，**D29 那次的腐法在这里结构上不成立**（那次腐是因为基线绑在**会变**的内容仓上）。**读数**：`gen-file` **174 行** / `dump-blocks` **43 行** / `batch` **13 行**，三份都与入库 golden 逐字节一致；`--selftest` 四向诱饵全被点名（三份 golden 各改一个字节 ⇒ 红；空语料 ⇒ 引擎拒跑 ⇒ 红）。⚠️ **三条实测坑**：① `batch` 每一行的**头一列是本机绝对路径** ⇒ golden 必须归一化，而且**只能**去掉到语料根为止 —— 我第一版用贪心 `sed` 把 `alpha-skill/SKILL.md` 削成了 `SKILL.md`，两份不同文件就再也分不开了；② **枚举漏 `.mbtx` 这个形状的漏犯了两次**（R9 一次、账本一次）—— 新文件类型进仓时，"谁负责枚举"要跟着看一眼；③ **夹具太薄时 golden 抓不到退步**：第一版代码块只有一行，`moonbit`/`toml` 的 `dark=0`（一个 capture 都没命中）⇒ 加厚成"有关键字/字符串/注释/数字"的块之后才有读数（`javascript`/`toml` 仍是 0，但**两边一致**，是 query 的性质不是这次迁移的偏差 —— 写进 `tools/fixtures/README.md` 的"诚实的边角"了）。**还没做**：三条迁移期判据的替换（与 `lib/` 退役同一批做）、`package.json` 的 `check`/`verify`/`audit` 切到新入口、`lib/` 与 `bin/` 的退役 |

| D42 | **④ 第二步：`audit` 闸门搬进新引擎 + 四条 `npm run` 入口全部换成新实现**。① 新文件 `cmd/skillpress/cli/audit.mbt`（`node tools/run-js.mjs audit [<内容根>]`），口径逐条照抄旧实现：真值表四类（关键字 / 字符串 / 注释 / 数字）→ 召回率、未上色比例、每门语言的 dark/white、**空集合必须红**、闸门 `recall ≥ 0.9` / `dark ≤ 0.4`。② `package.json`：`check` → 新 CLI、`verify` → `bash tools/verify.sh`（壳子：先编 native 再跑）、`audit` → 新 CLI、`check:selftest` → `moon test engine/gates`（旧 CLI 的 `--selftest` 按 D31 没搬，14 条诱饵早就在 22 条 wbtest 里）。③ 账本**三行自销账**（audit 那三条 `ow` → `ok`），PLAN 的 `DG-audit` 改成**已还** | 2026-10-07。**读数**：在**冻结夹具语料**上让新旧两边的 `audit` 各跑一遍 —— **逐项相同**：`keyword 10/10`、`string 22/22`、`comment 6/6`、`number 6/6`、合计 `44/44 100.0%`、`未上色 37/578（6.4%）`、五门语言五对数字全对；新 `audit` 在**真语料**上 `104/109（95.4%）` / 未上色 `30.5%`，而**每门语言的 dark/white 与 `batch` 的读数完全一致**（两条判据互为佐证）。四条 `npm run` 逐条跑了：`check` 6 个 skill 全过、`check:selftest` 22 条、`audit` 在闸门内、`verify` 22 条全绿。⚠️ **两处有意不同，都记在明处**：① **扫描范围**用引擎那份语料列举（跳过 `node_modules`/`_build`/`.mooncakes`/点目录），旧实现是**无差别遍历整个内容根** —— 它把 `.mooncakes/**/README.md` 的代码块也算进了分母（实测真语料上旧的数到 **114** 个 moonbit 块、新的 **8** 个，而那是**厂商依赖的文档**，不是我们的内容）；② 按语言的打印顺序固定成 `moonbit/bash/json/javascript/toml`（与 `batch` 同一套，为了能 `diff`），旧的是 JS 对象的**插入序**；③ 头部那句"纯正则数出来的"改成"纯扫描数出来的"—— 新实现里**没有正则**，照抄那句话就是一句假话。⚠️ **顺手被自己的工具逮到一次**：我在 `tools/engine-fixtures.sh` 的双引号里写了反引号，`bash tools/shell-traps.sh` 当场点名两处，而且 `--capture` **真的被执行了**（屏幕上跳出 `--capture: command not found`）—— 那个工具存在的理由，它刚刚自己演示了一遍 | 

| D43 | **④ 收口：`lib/` 与 `bin/` 整体退役，参照物换成入库 golden**。① 先脱钩最后两条还吃着旧实现的判据：`blocks-fixtures.sh`（夹具一/二的块文本 + 夹具三的诊断 + 夹具四的措辞，全部改成与 `tools/fixtures/expected/blocks-fixtures.txt` / `blocks-fixture3.err` 逐字节比）、`site-source.sh` 的 ⑦（原来是"旧门 vs 新 CLI 在副本上逐字节一致"—— 旧门没了，这一条**退役**，读数记在 D31 与 `mbt-traps`/`gates_wbtest` 那 22 条里）。② 删 `lib/`（7 个 `.mjs`，约 3400 行）+ `bin/`；删五条迁移期判据（`file-parity` / `blocks-parity` / `highlight-parity` / `site-parity` / `site-corpus-parity`）与它们专用的旧侧工具（`tools/site-dump-old.mjs`、`tools/spike/{old-doc-blocks,node-side-batch,node-side-hl}.mjs`）。③ 引用全部改掉：`acceptance.sh` 的 A3 ① 换成 `engine-fixtures.sh`、`fresh-clone-check.sh` 的三条并成一条、`tools/fixtures/README.md` / `README.md` / `SPEC.md` / 两份 skill 与它们的 references 里"实现住哪儿"的指针全部指到新家。④ `.moonignore` 的 `/lib/` `/bin/` 两条**留着但标明已退役**（防御性：万一有人加回来，仍然不该进包） | 2026-10-07。**约定（以后读仓库的人先看这句）**：仓库里凡是提 `lib/xxx.mjs` / `bin/skillpress.mjs` 的地方，**都是历史坐标**（对账与迁移记录里的出处），不是活文件；要动现役实现请去 `engine/**` / `cmd/**`。**读数**：`engine-fixtures`（四份 golden，174 / 43 / 13 / 14 行逐字节一致 + 五向诱饵）、`blocks-fixtures`（三档全过 + 诱饵）、`line-budget` 124 文件、`diagnostics-ledger` 42 对 + 9 欠、`site-source` 全过、`attach-check` 全过、`native-parity` 三条逐字节、`package-check` 230 文件、`shell-traps` / `mbt-traps` / `queries-check` 全过。⚠️ **退役时被自己的工具拦了两次，都记在这儿**：① `shell-traps` 逮到我在 `engine-fixtures.sh` 与 `blocks-fixtures.sh` 的双引号里写了反引号（`--capture` **真的被执行了**）；② 我一开始想把 `site-source` 的 ⑦ 改成"副本上全绿"，**跑出来是红的** —— 副本里 `skillpress/SKILL.md` 会退回成一份普通 skill，它满不满足 G2 取决于**内容仓当前长什么样**；拿一个随内容变的东西当断言，就是又造一条会腐的基线（D29 那类错）⇒ 改成**退役并说明证据在哪**，而不是硬凑一条绿的 | 

| D44 | **对标表 #10「图片」做完了 —— 一条内容里的 `![alt](src)` 从内容到像素的全链路**。三处一起动（缺一条都不成）：① **引擎**：整行一条的 `![alt](src)` 收成 `Block::Image(alt, src)`（行内的仍不收，见下）；新函数 `asset_src(raw, label, base)` 把"相对那份 md 的路径"折成"站点能直接加载的 URL"（站外 / `data:` 原样；仓内路径折成规范路径再挂 `--asset-base`，默认 `img/`）；② **`press`**：照**生成物里现成的清单**把图拷进实例 `img/` 并**逐字节**比对（`--check` 也会因"实例里缺 / 多 / 不一样"而红，"内容根里找不到这张图"当场点名），`template/instance/build-web.mjs` 再把 `img/` 拷进 `dist/`；③ **站点**：`shell/blocks.mbt` 把 `Block::Image` 排成 `@html.img`（`max_width: 100%`，**不写死宽高**），搜索索引**明确不收** `alt`（那是描述不是正文）。跨仓那半在 moobile：标签表放开 `img`、宿主把 `src` 改写成 `source{{uri}}`、**web 上渲染成真正的 `<img>`**（RNW 的 `Image` 根没有高度 ⇒ 不写尺寸的图排出来是 **720×0**，页面上什么都看不见而"元素在/naturalWidth 对"两条照样绿 —— 详见 moobile `docs/FINDINGS.md` 的图片补记）| 2026-10-07。**读数**：`node _scratch/image-check.mjs`（**现搭一份夹具站点**：拿冻结夹具语料当内容根，走和真实站点完全同一条路）**10 条全绿** —— 真 `<img>`、`src = img/assets/fixture.png`、**解码 160×90**（= 夹具图真实尺寸）、`alt` 在、**占版面 720×405**（16:9 正确）、按 URL 取回 **HTTP 200 且字节数与语料逐字节相同**；**证伪** `--drop-asset`（删掉 `dist/img/`）⇒ **红 3 条**（解码 0×0 / 404 / 字节数不符），而且实测 ② ⑤ 仍绿 ⇒ "看起来对"不等于"取到了"。夹具图是**生成**的（`tools/fixtures/make-fixture-png.py`，160×90、斜带 + 边框，肉眼能看出拉伸/错位），不手工丢二进制。**顺带逮到 9 笔账，全部记账并修掉**：① **`llms_lines()` 把首页原文路径写死**成 `skills/skillpress/WEBSITE.md` —— 首页**回退到 `SKILL.md`** 的内容根（R2 支持、夹具语料就是这样）会印出一条指向不存在文件的清单，`press` 照它拷原文 ⇒ **当场停下、站点印不出来**（判据覆盖不到的那半边一直是坏的）；② 生成物**文件头注释**里同一处写死（"内容源：`skills/skillpress/SKILL.md`（首页）"）⇒ 参数化（归一化规则①会抹掉开头的 `//` 块，所以它错了很久没人发现）；③ `site-source.sh` **写死了 `dev.js` 的产物路径**（工作区成员的产物多一层 `<作者>/<模块>/` 前缀）⇒ ④⑤ 两段的"门的读数"其实是 `node` 找不到文件的退出码 ⇒ **两条判据一起假红**（用 `git worktree` 在 HEAD 上复跑证实：同样的红在改动之前就在）⇒ 改成"两处都找、取最新的"；④ 同一个脚本的 ①**grep 整份生成物**找"SKILL.md 的首页内容"，而夹具里 `skillpress/` 本身也是一份 skill（它的 `title` 恰好就是那句话）⇒ 永远红；**把范围收到 `home()` 那一段**（不是放宽：它把"首页真的来自 WEBSITE"钉得更死）；⑤ launcher 的新鲜度守卫把 `*_wbtest.mbt` 也算成"源码" ⇒ 改一条测试的期望值就把所有 `node tools/run-js.mjs …` 堵住（而 `moon build` 说得对："no work to do"）⇒ 测试文件排除；⑥ `blocks-fixtures` **没有 `--capture`**，而它的 golden 自链接那一轮（`Txt`/`Code` → `Link`）起就**没重采过**（红了很久没人知道）⇒ 补上 `--capture` 并重采；⑦ 同一个脚本的**夹具三**指望"图片会被点名"（5 条）⇒ 图片**已经支持**了，改成 3 条 + **反向那一条**（支持了就不许再点名 —— 假警报的训练效果是"大家都学会忽略这一栏"）；⑧ `line-budget` **3 个文件超 400 行**（`blocks.mbt` 416 是这一刀加的、`search.mbt` 485 与 `state.mbt` 429 是既有的）⇒ 按"一个文件一件事"拆成 `shell/code_block.mbt` / `shell/search_view.mbt` / `shell/update.mbt`（142 个文件全绿）；⑨ `moon test` **3 条期望值**还停在 G8 那句措辞的旧版（`bin/skillpress.mjs` → `tools/run-js.mjs`）⇒ 跟上，**146/146**。⚠️ **留在明处的缺口**：① 原生 RN 的 `img` **仍需调用方给尺寸**（RN 语义；web 那条路自适应）；② **行内图片没有去处** —— 不独占一行的 `![alt](src)` 今天退化成一条指向原路径的链接（既不渲染图也不点名），`tools/blocks-fixtures.sh` 夹具二就是这一格的负向控制；要不要"报问题"或"真支持行内图"是下一刀的账 |

| D45 | **站点判据换血：那批断言从「旧 IA」改判「今天这套 IA」（22 → **23 条全绿**）**。① **判据改成只量具名节点**：给顶栏加了 `#topbar` / `#topnav`、给侧栏加了 `#sidebar`（`#prose` / `#toc-rail` / `#copy-<i>` 本来就有）—— 旧写法按**整页文字**猜（"哪个元素的内容以 `SKILL 文档` 开头"、"有没有『文档 / SKILL』这条"、"哪个元素正好写着这个 slug"），于是 IA 一改判据就**瞎**：实测 6 条永远红（`verify.sh` 报 6/13），而它们想守的东西（导航有没有跟内容对上）其实没被守住。② **逐条换血**：顶栏 = 首页/书架/搜索三条结构性条目 + **只有带目标的节**进导航（且序号已剥，§2.3）、`Doc` 加 `title`（新 IA 渲染的是 title，slug 只在 URL 与 kicker 里 ⇒ 旧判据按 slug 找列表项"缺 3 个"）、入口从退休的「文档 / SKILL」换成**书架**与首页那张「从哪开始」卡片、展开/收起**两态都验**（新 IA 会把"正在读的那一份"自动展开，旧断言点一下反而**收起来**了）、代码块认**结构**（`#copy-<i>` 的祖先）不认颜色（旧写法认的是当年暖色主题的 `rgb(240,233,218)` 字面量 ⇒ 主题一换一个盒子都认不出）、子页那一行认**三种形态**（新 IA 里就是它的标题；旧形态 `§ 名字`/`⌗ 名字` 也留着）、纯链接节着陆判据用**目标页的标题**（旧写法拿"目标文件里第一段够长的正文"当探针，那段文字未必原样渲染 ⇒ 看着像"点了没反应"，而 hash 早就跳对了） | 2026-10-07。**读数**：`bash tools/verify.sh --skills ../moobile/skills --app skills/skillpress/scripts/.skillpress` ⇒ **全部通过（23 条）**（22 → 23 是多出来的那条"收起"）；同一天里 `_scratch/{toc-click,link-check,code-toolbar-check,search-check}.mjs` 四支仪器**全绿**（换血没碰站点行为）。**这一轮踩到的坑（都写进注释了）**：① **判据的产物路径不许写死**（这一条一天里犯了三次）：`site-source.sh` 写死 `dev.js`、`verify.sh`/`native-parity.sh` 写死 native exe —— 而工作区成员的产物**多一层 `<作者>/<模块>/` 前缀**，写死那条**还在盘上**（旧时间戳）⇒ 脚本挑到**上一次编的二进制**，症状是"判据红得莫名其妙"（实测 native 把链接拍平成 `Txt`，看着像两端行为不一致）。三处都改成"两处都找、取 mtime 最新"。② **launcher 把 `*_wbtest.mbt` 也算成"源码"** ⇒ 改一条测试的期望值就把所有 `node tools/run-js.mjs …` 堵住（而 `moon build` 说得对："no work to do"）⇒ 测试文件排除。③ `blocks-fixtures` **没有 `--capture`**、golden 自链接那一轮起就没重采过 ⇒ 补上并重采；它的**夹具三**指望"整行图片会被点名"（5 条）⇒ 图片**已经支持**，改成 3 条 + **反向那一条**（支持了就不许再点名 —— 假警报的训练效果是"大家都学会忽略这一栏"）。④ `moon test` **3 条期望值**还停在 G8 那句措辞的旧版（`bin/skillpress.mjs` → `tools/run-js.mjs`）⇒ 跟上，146/146。⑤ **`attach` 产物不幂等**：首页那份文件被**两条路径**读（`pick_home` 用调用方给的标签、指纹那处按"内容根 + 标签"拼绝对路径），于是 `attach` 的虚拟读只命中一条 ⇒ 第一次跑指纹算的是空串、第二次变了。修法是**收成一处**（指纹用 `pick.text`，即这次真的读进来的那份文本）。⑥ **`line-budget` 三个文件超 400 行**（`blocks.mbt` 416 是这一刀加的、`search.mbt` 485 / `state.mbt` 429 是既有的）⇒ 按"一个文件一件事"拆出 `shell/code_block.mbt` / `shell/search_view.mbt` / `shell/update.mbt`（142 个文件全绿）。⑦ **`docs_geo` 的具名节点第一次没落地**：那次 Python 批改在后面的断言上抛了异常、进程退出前没 flush ⇒ **那次写盘丢了**（症状是 `#sidebar` 在页面上根本不存在，而我以为它在了）。教训：批改脚本要么 `with open(...)`、要么每步 `assert` 完立刻落盘 —— 别把"打了日志"当成"写进去了" |

## 2. 阶段

### P1 内容：拆完 references + 描述收成一句 —— ✅ **已落地**（2026-10-06）
- **做**：剩 5 份（迁移 / 组件 / React 库 / 写法 / 改库）按同一套样板拆 —— **门禁留主文档、细则进
  `references/`**（长表 / 逐条清单 / 证据链）；主文档压到 ~60–120 行；`description` 收成**一句话**
  （"这技能干什么"），细则味道的东西挪进正文或 `whenToUse`。
- **样板**：`moobile-pitfalls`（110 行 → 主文档 68 行 + `references/` 5 份：events / styles /
  tags-and-layout / platform / channels）。
- **证明**：`check`（G2 体量、G3 路径、G8 复核后落锁）｜`press` + 站点判据（子页可展开、可点开）。
- **纪律**：拆 = **搬运**，一条信息都不许丢；也不许顺手加新事实（SPEC §5：先改家，再改投影）。
- **尺度**：一个主题一份 ref；碎到 5 行一份就过头了 —— 宁可两个主题合一份。

**实际结果**（5 份主文档 74–98 行 / 各 3–5 份 ref；站点子页 5 → 29）：

| skill | 拆前 | 拆后主文档 | refs |
|---|---|---|---|
| `moobile-app-development` | 172 行 | 98 行 | structure / styles / events-and-subs / pages-and-lists / host-and-capabilities |
| `moobile-custom-component` | 136 行 | 93 行 | registration / events-and-children / identity-and-selfcheck |
| `moobile-library-development` | 156 行 | 74 行 | capability-levels / gates-coupling / vendor-host-and-generated / release-and-rules / writing-and-tooling |
| `moobile-react-library` | 184 行 | 87 行 | channel / libgen / register-library / integration |
| `moobile-migrate-from-rabbita` | 187 行 | 95 行 | entry-and-artifacts / migration-discipline / report-and-audit / lessons-and-unverified / gates（原有） |

**教训（执行期踩到的，值得留给下一份计划）**：

- **G3 不查兄弟 skill 的目录**：跨 skill 引用写 `references/platform.md` 会红，必须写全路径
  （`skills/moobile-pitfalls/references/platform.md`）。
- **`press` 生成物必须重跑**：改了内容不重跑，`press --check` 会红（这正是它的用处）。
- **G8 会按 skill 红**；落锁用 `--update-lock <名字>` **逐个锁**，别整文件重写（会连别人正在改的一起锁掉）。
- **G6 会抓"节号写了但不存在"**：我写 `LAYERS.md` **§三端产物**，实际那张图在 **§4** —— 引节号前先看标题。

**逐条对账抓到的东西（D9 那道的实际产出，值得记下来）**：

| 类别 | 实际抓到的 |
|---|---|
| **真丢信息** | 1 处：拆 `moobile-migrate-from-rabbita` 时漏了 `regen --styles` 的**两个出处指针**（`regen-diff.js` 文件头 + `lib/regen.js` 的 `--styles`） |
| **我编的解释** | 1 处：把"库的门 + **三端**"擅自解释成"离线全集 + web e2e"；本意是 **web / android / 桌面**（`docs/design/LAYERS.md` §4）。**搬运工不许自己做解释** |
| **检索面被削** | 1 处：`moobile-react-library` 的 `description` 收成一句话时**收掉了关键词**（`--check` / 四个面 / 三个声明名）；`description` 是加载路由面，短不等于可以丢词 |
| **漂移点（我自己造的）** | 21 处：ref 开头写"主文档只留了 X 这一条"—— 主文档一改这句就变假，且好几处数错了数。已统一成不依赖主文档具体内容的固定说法 |
| **门自己抓到的** | G3 一处（跨 skill 相对路径）、G6 一处（不存在的节号）、G8 五处（体量，复核后落锁） |

**第二路对账（另一组 skill）额外抓到的**——这几条都属"搬运工自己加的东西"，最值得记：

- **引错了代码分支**：我在 `styles.md` 里给 `Attrs::styles` 补了个出处括号 `render.mbt 的 props.attrs_map()` —— 
  那是**字符串属性**表（`render.mbt:617`）；类型化样式走的是 `props.styles_map()` → `styles_to_js`（`render.mbt:648-677`）。
  结论没说错、出处指错了，而**错的出处比没有出处更坏**（它让人去读错的地方）。已整句撤掉。
- **掉了限定词**：原版"能写、能编译、**在 RN 上**没有任何效果"被我写成"没有任何效果"——
  `class=` 在**浏览器**里是有效的，去掉"在 RN 上"会让门禁表读成"哪儿都没效果"。已补回。
- **无出处的新断言**：我在主文档写"注册顺序错了在 web 上**未必**同时炸"，那句来自姊妹 skill 的某一行、
  不在它自己挂的细则里（细则只写了真机）。已改回原版口径。
- **丢了一条出处**：`custom-component` 的"先分清这活归谁（划分依据见 skillpress 的 `SKILLS.md`）"括号被我删了。已补回。
- **顺着"常识"补的解释**：`page()` 那条注释也一样——不是原版的话，撤掉。
- **归类歧义**：把"视口 / 尺寸"合成一句，而 `platform.md` 里"尺寸 / 滚动量恒为 0"是**另一回事**。已改成只讲订阅的共性坑。

> 结论：**门能证明"结构没坏"，证明不了"信息没丢、意思没变"**。D9 那道对账是必要的，不是走过场 ——
> 两路合起来抓到：2 条真丢失、1 处我编的解释、1 处指错的出处、1 处掉的限定词、2 处无出处断言、21 处漂移自述。


### P2 站点导航（顶栏）—— ✅ 主体已落地（吸顶的修法已查明，见下）
- **做**：分栏 tab 改成现代分段控件（下划线指示、吸顶、按下态）；**「文档」并入同一排的最右一栏**，
  不再单独做成一个实心按钮（D2）；**纯链接节**标记进数据，点那一栏直接渲染目标文件（D3）。
- **要改**：`lib/gen-content.mjs`（多算一个"这一节是不是纯链接节 / 链接指向哪"的标记）、
  实例的 `app.mbt`（顶栏渲染与 `Msg`）。
- **证明**：现有几何判据（分栏在同一行）+ 人眼看截图；点击行为用**一次性探针**验（D8）。

**实际做法与结果**：

| 项 | 怎么落的 | 怎么验的 |
|---|---|---|
| 分段控件 | `nav_tab` 常态无底色，选中 = **下划线指示条**（子 View + `position(Absolute)` + `bottom(0)`）；顶栏合成**一行** | 现有几何判据（分栏同一行，y 全等）+ `verify` 21/21 |
| 「文档」并排 | `seg_bar` 把它放同一排最右，只差一条竖细线（不再实心按钮） | 同上；`hasDocsTab` 那条仍在 |
| 纯链接节（D3） | 生成期把 `## [名字](目标)` 的目标解析成**页面键**写进 `Section.link`，认不出**报错**；应用侧 `top_msg()` 经 `@content.find_page()` 换成 `Go(kind,i,k)` | **新加一条判据**：从目标文件现取一句真话，点那一栏后断言它出现 |

**按下态没做，而且是刻意的**：`press()` 的键会被拆成 `pressStyle`，而**库侧没有消费点**
（`moobile-pitfalls` 记着这条）⇒ 写了也不会有视觉效果 —— 所以这一轮**不写按下的视觉**，
只留可点性与 `on_click`，等 `pressStyle` 有了消费方再说。

#### 吸顶：**已落地**（宿主模板一行 CSS + 一条真判据）

样式层里**没有 `sticky`**（`style/style.mbt` 文件头明说 `position:sticky`、`::before`
"根本没有构造器"；`Position` 枚举只有 `Relative` / `Absolute`）⇒ 吸顶只能靠**结构**：
顶栏在**滚动容器外面**、滚的是正文那一个。

**根因**（不是"RN 做不到"，是**宿主 HTML 的一个块盒上下文问题**）：

- `index.html` 给 `#root` 设了 `height:100%`，但它是 **`display:block`**；
- 而应用的根是 `flex: 1 1 0%` 的**弹性项** —— 弹性项在块盒里**没有可分配的 flex 空间**，
  于是直接长到**内容高**；
- ⇒ 正文那个 `scroll` 容器被撑满（实测：内容 3000px 时容器 **3435**、`可滚 0`）
  ⇒ 实际滚的是**整个 document** ⇒ **顶栏跟着滚走**。

**修法（已落地）**：宿主那份 `index.html` 里加一条

```css
#root { display: flex; flex-direction: column; height: 100%; min-height: 0; }
```

| 量什么 | 修前 | 修后 |
|---|---|---|
| 滚动容器高 | 3435（= 内容高） | **490**（有界） |
| 整页可滚 | 2945 | **0** |
| 滚 window 300px 后顶栏 y | 跟着走 | **0 → 0（不动）** |

⚠️ 这是**宿主侧**的修法（`#root` 是宿主自己的 HTML，不是库的样式层）—— 依赖它的正是那个
"零依赖静态 web 宿主"，所以跟那个宿主绑定是恰当的；真机上 `ScrollView` 本来就有界，不需要它。

**踩过的弯路（值得记）**：① 前几次实验拿**短页面**量，量到的"可滚 0"是"本来就不需要滚"，
不是缺陷——要量滚动行为，页面必须**真的比视口长**；② 探针里认"顶栏那一条"别按文字匹配
（`文档 / SKILL` 在按钮里嵌套层数会变），**按几何**认（最靠上的那条矮横栏）最稳。

#### 顶栏在窄窗口下**横向溢出** —— ✅ 已修（还有一条尾巴）

第 9 条分栏（「使用手册」）加进去之后，顶栏那一排在 **1378px 宽的视口**里量到 **1838px 宽**
⇒ 最左边的「首页」被推到 **x=1883（屏幕外）** ⇒ `document.elementFromPoint` 返回 `null`
⇒ **点它等于点空气**（判据里那两条红就是它）。

对照实验证明**与吸顶那行 CSS 无关**：`#root` 是 `flex` 还是 `block`，顶栏都是 1838px 宽。

根因是**这一排不做换行、也没有横向滚动**。**选了"横向滚动"**，落地时踩到两处：

1. **`horizontal` 怎么递进去**：`scroll` 伪标签只映射组件类型、不带 prop，而 `is_prop_key`
   **只认 `numberOfLines`**（库侧白名单）。解法是 `@html.Attrs::build().prop_bool("horizontal", true)`
   —— 它走 `props_map` 那张**类型化**表（React 收到布尔 `true`；若用 `prop_str` 会变成字符串）。
   **零库改动**。
2. **弹性空隙抢宽度**：那一排是 `[品牌, 空隙, 分段控件]` 三个弹性项，空隙写成 `flex: 1` 时
   会和分段控件**平分**剩余宽度（实测 1478 的排里各得 580）⇒ 分段控件只拿到 580、
   而它要 961 ⇒ 只能看见一条分栏。改成**固定间距**（`width: 14px`）之后，
   分段控件拿到 1046、9 条分栏全在视口内、可点击。

**尾巴（还没修）**：「首页」那一条的 **click 不生效** —— 消息换成 `Top(3)` 也不响
（证伪过），而其它 9 条都正常。它是唯一用 `let items = [ nav_tab(...) ]` 初始化、
而不是 `items.push(...)` 加进去的那一条；`println` 显示消息**根本没到** `update`。

> 这一条正是 P2 那句"宽屏优先：窄屏还没做折叠菜单"的**真实代价** —— 之前只是"挤"，
> 加了一栏之后变成"**够不着**"。

**顺带查出来的一条**（不是 P2 引入的，是 P2 量的）：应用自己的滚动容器**在这一版根本上没有滚动能力**
—— 长文档靠的是**整个 document 在滚**。真机上 `ScrollView` 是有界的，所以这条大概只影响 web 宿主，
但值得单记一笔（见上）。


### P3 目录（TOC）
- **做**：`press` 在**生成期**为每个 md 算 TOC（层级 / 文本 / 锚点 id）塞进 `Home`/`Doc`/`Kid`；
  宽屏挂右栏；窄屏把当前页 TOC 收进侧栏对应条目下（可展开）；当前节高亮。
- **spike（先做，再定实现）**：
  1. **怎么滚到锚点** —— 三条候选：① 浏览器原生锚点（`Attrs::id` + 真 `<a href="#id">`）；
     ② `@cmd.custom_cmd` + 宿主 JS 调 `scrollIntoView`；③ 不滚，TOC 点击 = **切段**（首页已是切段模式）。
     拿到证据再定。
  2. `Attrs::id` 在 RNW 里是否真落到 DOM 的 `id`；以及 web 上能不能表达真 `:hover`（样式层现在只有 `.press()`）。
- **响应式**：**没有 `@media`**（`style.mbt` 明说要放 Model）⇒ 视口宽度进 Model：
  `@sub.current_viewport()`（**同步读一次**）+ `@sub.on_resize`（订阅）**两条都要用** ——
  源码里写着"两端都不会在挂载时补发一次"，只用订阅就会永远拿不到初始宽度（zhouyi-reader 栽过）。
- **证明**：现有判据 + 一次性探针；**不加新判据**（D8）。

### P4 样式现代化（与 P3 同批：都动布局）
- **做**：设计 token（间距 / 字号 / 圆角 / 层次）集中一处；首页 hero（标题 + 一句定位 + 主按钮）
  + 「这里有什么」卡片网格（读 `skills()` 生成）；正文排版（行宽 ~72ch、标题层级、段间距）；
  链接样式（现在渲染成"文字 + 代码样式路径"，读起来卡）；表格与代码块改观；`.press()` 按下态。
- **证明**：现有 20 条判据 + 截图给人看。

### P5 侧栏（等 P1 完再定）
- **做**：不分组（D5）；描述收短之后重新看"每项一行"是否够；活跃项色条；缩进引导线。
- **前置**：P1（`description` 收成一句）+ sidebar 的数据形状（是否要分组由 P1 后的观感决定）。

### P6 结构：抽 `shell` 包 → 便携 → 集成

**P6 的目标形状（2026-10-06 侦察后就地记下，免得下次再摸一遍）**

实例侧现在是：`moon.pkg` 里 `import { "skillpress-site/content" @content, … }` + `options(link: {js: {exports: ["app"]}})`；
`app.mbt` **1062 行**，全是界面与状态机。生成物 `content/content.generated.mbt` 里**同时声明类型与值**
（`Span` / `Block` / `Kid` / `Doc` / `NavItem` / `Section` / `Home` + `home()` / `skills()` / `find_page()`）。

目标：**类型与界面搬进包**（`shell/`），实例只剩几行。按 R9 拆（每文件 ≤400 行）：

| 新文件 | 搬什么（按 `app.mbt` 现在的行段） |
|---|---|
| `shell/types.mbt` | 公开契约：上面那 7 个类型（从生成物的声明**原样搬**，注释写清各自的角色） |
| `shell/theme.mbt` | 13 个颜色常量 + `body_style()` 等样式函数（119–187） |
| `shell/inline.mbt` | `plain` / `span_view` / `inline_text` / `tok_color`（163–234） |
| `shell/blocks.mbt` | `code_block` / `table_view` / `heading` / `bullet_view` / `block_view`（235–382） |
| `shell/state.mbt` | `Sel` / `Model` / `Msg` / `initial` / `update`（27–118） |
| `shell/docs.mbt` | `Page` / `page_of` + 侧栏树（383–…） |
| `shell/home.mbt` | 顶栏（分段控件 + 下拉）+ 首栏/分栏渲染 |
| `shell/site.mbt` | `pub fn site()`：把上面拼成一个 moobile 应用（实例里 `pub fn app` 就调它） |

实例侧随之变成：`app.mbt` 只剩几行（A2 的判据取 **≤20 行**）；`moon.mod` 里**直接依赖** `XiLaiTL/skillpress`。
⚠️ **生成物的形状会变**（类型不再声明在里面、值要带包前缀）——所以那一步的判据**不再是"逐字节"**，
而是：`moon check` 干净 + 实例 `npm run build` + `verify` **22/22** + `app.mbt` ≤20 行。
"逐字节"那条判据管的是**映射逻辑**（P8.1 已经拿到），不是最终的发射格式。

**P6 做完了（2026-10-06）—— 实际读数与三个"没想到"**

做到了：`shell/` 10 个文件（`types` / `state` / `theme` / `inline` / `blocks` / `docs` / `topbar` / `home` / `site`）、
实例 `app.mbt` **1062 → 17 行**、实例 `moon.mod` 直接依赖 `XiLaiTL/skillpress@0.1.0`、实例 `moon.work`
（成员 `["." , "../../../../../skillpress"]`，**相对**路径 —— 与 `verify.mjs` / `package.json` 的跨仓约定同源）。
读数：`moon check`（实例两个包）0 错 0 警 ｜ 实例 `build` 出 `dist/bundle.js` ｜ 真浏览器 `verify` **22/22** ｜
`tools/acceptance.sh` 的 **A2 三条全绿**（17 ≤ 20 行 / 依赖在 / 没有界面副本）。

⚠️ **对账口径没有"放弃逐字节"**：两个引擎跑在**同一份副本**上（`tools/mk-parity-corpus.sh`），
两边先过 `tools/normalize-gen.mjs`（三条规则：去头注释 / 去类型声明块 / 去 `@shell.` 前缀）再逐字节比。
"两边读法相同"这条前提由造副本的脚本自己断言，`file-parity --selftest` 里还有一条
"**前提被破 ⇒ 拒绝比**"的诱饵。见 D25 / D26 / **D29**（基线退役那一笔：R2 之后旧实现不认识
`WEBSITE.md`，继续冻基线只会得到"恒真的判据"或"无解的死循环"）。

三个"没想到"（都是实测，不是推理）：

1. **`using` 救不了构造器**：`using @shell {type Span, type Block}` 只把**类型名**引进作用域，
   `Txt(...)` / `Hr` 仍然 unbound ⇒ 生成物里的值必须写 `@shell.Txt(...)`。
   而 `@shell.NavItem { … }` 这种"限定结构体字面量"**不是合法语法** —— 好在生成物里的结构体字面量
   本来就是**匿名**的（`{ title: … }`，靠字段类型推），所以不受影响。
2. **`pub` 是只读的**：类型搬进包之后，`pub enum` / `pub struct` 对**别的包**只读 ——
   消费者写 `@shell.Txt("x")` 会得到 `Cannot create values of the read-only type`，
   写 `@shell.NavItem { … }` 会得到 `Value NavItem not found in package shell`。
   跨包填值必须 `pub(all)`（探针：`_scratch` 包，用完即删）。
3. **搬界面的等价性得自己造仪器**：`app.mbt` 被机械切进 `shell/` 之后"两边都编得过"**不构成证据**
   （少画一个块、顺序换一条都不会报错）。所以加了 `tools/dom-dump.mjs`：真 Chrome 抓渲染后的 DOM，
   并且**先自证**（同一份 bundle 连抓两次逐字节相同），再比"搬之前 / 搬之后"——
   实测**21142 字符逐字节相同**（期间 bundle 的 sha256 换了三次，DOM 一次没动）。
   ⚠️ 它踩过一个坑：同进程里的静态服务 + `spawnSync` 会**死锁**（同步子进程堵住事件循环 ⇒ 服务答不上请求），
   必须异步 `spawn`。


> ⚠️ `pack` / `attach` 现在是**核心需求**（D16：产品要做成通用的），不是「以后再说」。
1. **抽包**：把实例的 `app.mbt`（界面 + 状态机）搬进程序成一个 MoonBit 包，**数据类型的家一起搬**
   （`Home`/`Doc`/`Block`… 变成程序的公开契约，生成器只填值）；实例 `app.mbt` 缩到几行
   `@skillpress.site(...)`。顺带定"实例进不进 `moon.work`"。
2. **`pack`**：一组 skill → 便携目录（程序副本 + 生成的首页 skill）。
3. ✅ **`attach`**（挂进一个已有的项目：写 `skills/` 骨架 + 实例 + npm scripts）—— **已落地**，见下面的 P9。
4. **moobile 的 `--with <包或路径>` 钩子**：通用扩展点，skillpress 做第一个插件。
   ⚠️ 那条 CLI 面在 moobile 是**冻结**的（`bin/cli.js` 明说改前先看 `docs/design/SCAFFOLD.md` §3.8），
   所以要先写那边设计文档、再补它的门。
- **证明**：`moon check` 全绿 + `verify` 20/20（换实现不改行为）｜ **pack 出来的目录要在临时目录里
  真的能 `build` + `verify`**（"便携"的判据不是"文件拷过去了"）。

### P9 脚手架 `attach` —— ✅ 已落地（判据 ①–⑨ + 诱饵）

**一句话**：给一份 `skills/` 直接生成一个站点 —— 扫内容根 → 选哪几份不上书架（**每条带理由**）
→ 首页来自目标仓的 `README.md`（复制 + 改写）→ 写整套 `skills/skillpress/{SKILL.md, WEBSITE.md, scripts/.skillpress/**}`
与仓根的 `skillpress.ignore.md`。

```bash
node tools/run-js.mjs attach [--repo <仓根>] [--skills <内容根>] [--home <README>]
                            [--ignore <名字>=<理由>]… [--host-dep <依赖值>]
                            [--interactive] [--yes] [--force] [--dry-run]
```

**三个设计点**（口径写进 D30）：

1. **先算后写**：全部产物（含内容包）在内存里算完，一个问题都不剩才开始落盘 —— 出问题退 2 且
   **一个字节都不写**。写的是**别人的仓库**："半成品实例"最坏（看着装好了，下次再跑被"不覆盖"挡住 ⇒ 永远缺那一半）。
2. **人写的文件不许被覆盖**：`Authored`（首页源 / 门口那份 / 忽略清单 / 实例工程文件）**已存在就跳过并点名**，
   `--force` 才覆盖；`Derived`（内容包）每次都写。
3. **沿用盘上已有的忽略清单**：没给 `--ignore` 时读 `<仓根>/skillpress.ignore.md` 并**照它算书架**。
   不读它的话"再跑一次"会把该藏的又放回书架 —— 内容**悄悄变**，而 `press --check` 当场红（实测踩到）。

**模板真源 = `template/instance/**`**（带占位符），生成出来的那份实例是它的产物 ——
"两份手写的同类文件必然漂移"这条别处已经量过一次，所以这里**不摆第二份**。
⚠️ 模板目录名**不能以点开头**：实测 `template/.skillpress/` 会被 `moon package` **整个跳过**
（同一份内容叫 `template/instance/` 就一条不落）⇒ 入场券钉在 `package-check.sh` 的 REQUIRED 里。

**判据**：`bash tools/attach-check.sh`（①–⑨：产物齐全且能真的印成站 / 幂等 / 不覆盖手写 /
坏输入退 2 不落盘 / README 改写有降级有打印 / 无 README 回退 / 交互式管道可测 / 默认全部进文档区 /
沿用已有清单），外加 `--selftest` 两向诱饵。

**路上修掉的四个真 bug**（都不是打字错，是设计漏）：
① 产物不幂等（书架按"跑之前"的语料算，而 attach 自己会写出一份新 skill）；
② `md_kids` 列不到目录时直接 ENOENT 崩（引导层漏了"列不到 = 空表"这条口径，已补在
`tools/run-js.mjs` 与 `launcher/skillpress.mjs` **两处**并保持逐字节一致）——
⚠️ **"两处"这条要求已作废**（2026-10-07，见 D35）：两份合成了一份，`tools/run-js.mjs`
现在只是一行转发 ⇒ 再没有"两处要同步"这件事。当初写"并保持逐字节一致"，正是因为没有
别的机制替我们扛这份同步 —— 而它**没扛住**（下面 D35 那笔账：`check` 快路径只更新了一边）；
③ 首页被跳过时内容包仍按 README 改写稿生成 ⇒ 站上的内容与盘上的首页脱节；
④ 不读盘上已有的忽略清单（见上面第 3 条）。

### P10 原生 CLI（`moon install`）—— 🚧 进行中（工具链那关已过）

**为什么这是硬需求**（不是"能不能"的偏好）：发布形态是**一个月亮包、CLI 用 `moon install` 装**（D15），
而 `moon install` **默认选 native** —— 实测（2026-10-06）：

```
$ moon install ./cmd/skillpress
Error: Selected backend 'native' is incompatible with the dependency graph.
       'cmd/skillpress' requires 'engine/highlight' which supports [js].
```

⇒ **今天这个包装不上**。要走通，CLI 必须能编 native（使用者那边零 Node）。

**① 工具链那关（✅ 已修并验证）**：本机 `~/.moon` 是**半升级**状态 —— `bin/` 是 9-20，而
`lib/runtime/` 与 `include/` 停在 8-27。症状是 native **链接**失败（`LNK2019: moonbit_flush_cycles`），
而 8-27 那份 `runtime.c` 里**连这个符号都没有**（`grep` 全文 0 命中）⇒ 编译器生成的代码配不上那份运行时。
修法：从官方归档（`cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip`，86 MB，`Last-Modified` 正是 2026-09-20 = 本机这版）
把 `lib/runtime`、`lib/*.o`、`include/` 补齐（先备份到 `/tmp/moon-runtime-backup.tgz`）。
验证：`moon run hello --target native` 打印出结果；js 那条路回归 `moon build cmd/skillpress --target js` + `moon test` 29/29 照过。
⚠️ **别把 `moon upgrade` 当修法**：这次的不匹配正是升级留下的（`lib/` 目录被碰过、里面的文件没换）。

**② native tree-sitter 的复核结果（2026-10-06 实测，全部在临时工程里做，没动仓库）**

*上游那个包不能用*：`tonyfettes/tree_sitter@0.4.6` 的 `src/tree-sitter.c` 第一行就 `#include "tree-sitter#lib#src#lib.c"`，
而 tree-sitter 的 C 库上游是 **git submodule**（`git submodule update --init`）—— 发布 tarball 只带 `src/`，
连那个本该生成单体 C 的 `scripts/prepare.py` 都没进包（发布版 `moon.mod.json` 里没有 `scripts`）。
绕不过去：`moon add` 只认 registry 包名（不吃 git 源），而本机 **GitHub 不通**（代理没开）。
⚠️ 顺带一笔：它钉的 `tonyfettes/c@0.7.4` 在当前 core 上编不过（`@strconv.parse_uint64` 已不在），提到 **0.7.8** 才过。

*料从哪儿来（都不用 GitHub）*：**PyPI 的 sdist `tree-sitter==0.26.0`** 带完整 C 库
（`tree_sitter/core/lib/{src,include}`，MIT；`pip download --no-binary :all:` 就能拿）——
⚠️ 这里原来记的是 npm `tree-sitter@0.25.1`，**后来换了**：C 侧与 js 侧必须同版本，而 0.25.1 会把
旧实现打崩（见 ⑪），所以最终钉在 0.26.0（`vendor/tree-sitter/PROVENANCE.md` 记着出处与 sha256）；
五门语法按 `grammars/PROVENANCE.md` 记的**同版** npm 包取 `parser.c` + `scanner.c`。
已验：我们 `grammars/*.wasm` 与那些包自带的预编译 `.wasm` **逐字节相同** ⇒ 语法出处是对得上的，不存在版本漂移。

*实测：同一个 C 探针 vs 我们的 js 垫片，喂同一份 `.scm`*

| 条件 | 结果 |
|---|---|
| toml（0 谓词） | ✓ 逐字节一致（28 条 capture） |
| **纯 ASCII 素材 + 剥掉谓词** | ✓ **五门全逐字节一致**：bash 1605、javascript 762、moonbit 1991、json 61、toml 28 |

⇒ 结论：**native 实现与 js 实现是同一个行为**，只要补上两处口径 —— 而这两处都已经钉死：

| # | 要补什么 | 证据 |
|---|---|---|
| ① | **谓词**：`web-tree-sitter` 的 `captures()` **自己实现了谓词**（源码里就是 `#eq?`/`#match?`/`#any-of?` 那几段），而 tree-sitter 的 C API 把谓词留给**调用方** ⇒ 不补就会多出 capture | 带谓词时：bash 1605 vs **1173**、javascript 762 vs **544**、moonbit 1991 vs **756** |
| ② | **偏移单位**：C 给的是 **UTF-8 字节**偏移、js 给的是 **UTF-16 码元**，而 native MoonBit 字符串按**码点**索引（实测 `"中k".length() == 2`）⇒ native 侧要把字节偏移折成码点 | 同一份含中文的 json：C `string 84 216` vs js `string 84 158`；把这几个字符换成 ASCII 后 ⇒ 逐字节一致 |

*我们 query 实际用到的算子（全量清点，垫片只需覆盖这些）*：
`#match?` ×7、`#any-of?` ×6、`#eq?` ×2、`#is-not?` ×2（`json` / `toml` 一份都不用）。

*下一轮起可用的判据*：同一份语料上 **native 与 js 的 capture 三列文本逐字节一致**（临时工程里已经跑得起来）。

**③ 原型已跑通（2026-10-06 实测，仍在临时工程 `/tmp/tsnative` 里）**

MoonBit 侧的 native 垫片写出来了：**我们的 C 桩**（把 vendored 的 tree-sitter C 库拉进来）+ `extern "c"` 调用，
形状是"MoonBit 把 UTF-8 字节交给 C，C 跑 parse+query 返回三列 ASCII 文本"。与 js 垫片比：

| 语言 | capture 条数 | 结果 |
|---|---|---|
| json | 61 | ✓ 逐字节一致 |
| moonbit | 1991 | ✓ 逐字节一致 |
| bash | 1605 | ✓ 逐字节一致 |
| javascript | 762 | ✓ 逐字节一致 |
| toml | 28 | ✓ 逐字节一致 |

（条件：纯 ASCII 素材 + 剥掉谓词的 query；唯一差异是 Windows 上 `println` 的 CRLF，`tr -d '
'` 后完全一致。）

**五条工程坑（都是实测，写在这儿省下一轮的时间）**：
1. **每门语法要用它自己的 ABI 头**：五个包的 `tree_sitter/parser.h`、`alloc.h`、`array.h` **互不相同**
   （实测 sha256 分三组）—— 混用会报 `TSLanguage` 字段不存在。要按语法分目录摆。
2. **`native-stub` 里的文件基名必须唯一**：五个 `parser.c` 同名会让 **`moon` 直接 panic**
   （`execution action inputs must be declared once`）—— 改名成 `json-parser.c` 这类即可。
3. **stub 是"就地编译"的**（不拷进 `_build`）⇒ 引号包含按**各文件自己所在目录**解析 ✓（不用 `-I`）。
4. `extern "c"` 的指针参数要加 **`#borrow(...)`**（不加直接报 `unannotated_ffi`）。
5. **MoonBit native 字符串在 C ABI 上是 UTF-16**（`moonbit_string_t = uint16_t*`），而且**按 UTF-16 码元索引**
   （实测 `"a😀b".length() == 4`）—— 与 js 侧**同口径** ⇒ 垫片只需要把 tree-sitter 的 **UTF-8 字节**偏移折成 UTF-16 码元。

**体积账（影响"vendor 哪些"的决定）**：语法的 `parser.c` 是**生成的巨物** —— bash 9.9 MB、moonbit 3.0 MB、
javascript 2.9 MB（`.wasm` 则小得多）。两条路：
① **vendor C**（版本与我们的 `.wasm` 严格一致，但仓里多出约 16 MB 生成的 C 文本）；
② 依赖 registry 上现成的语法包 `tonyfettes/tree_sitter_*@0.1.26`（它们自带 `parser.c` + `native-stub` 配置，**轻**）
—— 但那些包的语法版本与我们 `.wasm` 是否同口径**尚未验**，要先量（下一轮第一件事）。
另外 `moonbitlang/x` 的 `@fs.read_file_to_string` 在 native 上可用（对 ③ native 宿主有用）。

**④ vendor 范围的决定（2026-10-06 实测）**：语法 C 不一定都要自己扛 —— 我把 registry 上的语法包
（`tonyfettes/tree_sitter_*@0.1.26`，各自带 `parser.c` + `native-stub` 配置）接进探针，与我们的 `.wasm` 对 capture：

| 语言 | registry 语法包 vs 我们的 `.wasm`（同一份 `.scm`） |
|---|---|
| json | ✓ 逐字节一致（61 条） |
| bash | ✓ 逐字节一致（1605 条） |
| javascript | ✓ 逐字节一致（762 条） |
| toml | ✓ 逐字节一致（28 条） |
| **moonbit** | ✗ **0 条**（它自带的是**另一门语法**：我们的 query 在它上面一个节点名都命中不了） |

⇒ 三个选项（体积是实测的）：**ⓐ 4 门用 registry 包 + moonbit 自己 vendor ≈ 3.9 MB**（tree-sitter C 库 850 KB + moonbit 语法 3.0 MB）；
**ⓑ 五门全 vendor ≈ 17 MB**（自足，但仓里多 16 MB 生成的 C）；**ⓒ 五门都用 registry —— 不可行**（moonbit 那门语法不同）。
⚠️ 一个容易误判的点：registry 包里自带的 `.wasm` 与我们的**字节不同**（sha256 全不一样），但其中 4 门的 **C 语法表是一致的**
（capture 逐字节相同就是证据）—— "wasm 字节不同" ≠ "语法不同"，别再拿 sha 去判语法。
（我们 `.wasm` 的出处仍由 `grammars/PROVENANCE.md` 钉着：与对应 **npm** 包自带的 `.wasm` 逐字节相同。）

**还差两件（都在垫片里）**：谓词（`#eq?`/`#match?`/`#any-of?`/`#is-not?`，照 `web-tree-sitter` 的口径实现）+
字节→UTF-16 码元折算。

**⑤ 谓词的范围（全量清点，垫片只需覆盖这些 —— 2026-10-06）**

我们五份 query 用到 `#match?`×7、`#any-of?`×6、`#eq?`×2、`#is-not?`×2，而**指令一条都没有**
（`#set!` / `#offset!` / `#strip!` / `#select-adjacent!` 全为 **0**）⇒ **不需要属性表**，
`#is-not? local` 指的是"从未被断言的属性"，按 web-tree-sitter 的口径恒为真（上线时要拿真语料验一遍）。

`#match?` 在 web-tree-sitter 里就是 `new RegExp(pattern)`（**不带 flags** ⇒ `^`/`$` 是整串锚）。我们实际用到的模式只有这几条：

`^-` ｜ `^[A-Z]` ｜ `^[A-Z_][A-Z\d_]+$` ｜ `^(arguments|module|console|window|document)$` ｜
`^[A-Z][A-Z_]+$` ｜ `^\.[A-Z][A-Z_]+$` ｜ `^#deprecated\(.*\)`

⇒ 要写的小正则子集就是：`^ $`、字面、转义（`\.` `\(` `\)`）、字符类 `[...]`（含区间与 `\d`）、
分组择一 `(a|b|c)`、量词 `* +`。`#eq?` / `#any-of?` 是字面比较，照 web-tree-sitter 的 `every()` 语义写即可。

**⑥ native 垫片**全链路**跑通**（2026-10-06，临时工程）：谓词实现 + 偏移折算都进去之后，
拿**真 query + 含中文的真实素材**五门全量对账（native 垫片 vs js 垫片）：

| 语言 | capture 条数 | 结果 |
|---|---|---|
| json | 61 | ✓ 逐字节一致 |
| moonbit | 1725 | ✓ 逐字节一致 |
| bash | 1173 | ✓ 逐字节一致 |
| javascript | 544 | ✓ 逐字节一致 |
| toml | 28 | ✓ 逐字节一致 |

**三条硬知识（都是这一轮踩出来的，进仓前必须先知道）**：

1. **迭代口径要用 captures、不能用 match**：web-tree-sitter 走的是 tree-sitter 的 **captures** 迭代。
   我先写成 `ts_query_cursor_next_match` + 逐 capture 出 —— **条数完全一样、顺序不一致**
   （moonbit/javascript/toml 各有几处 capture 挪了位置）。改回 `next_capture`（并在 **match 层面**过滤谓词，
   同一个 `match.id` 只算一次）之后逐字节一致。
2. **`#eq?` 与 `#match?` / `#any-of?` 在"capture 不在 match 里"时**结论相反**（照 web-tree-sitter 抄）：
   `#eq?` 走 `nodes.every(...)`，空集 = **真**；而 `#match?` / `#any-of?` 显式 `if (nodes.length === 0) return !isPositive` ⇒ **假**。
   这一条差异会直接改变命中集合，不能想当然。
3. **`#is?` / `#is-not?` / `#set!` 对"capture 列表"是空操作**：web-tree-sitter 只把它们**记成属性**挂在结果上，
   不参与过滤；我们五份 query 里 `#set!` 为 0 ⇒ 垫片把它们当空操作即可（`#is-not? local` 因此不筛任何东西）。

**⑦ 落地方案定案：全 vendor（2026-10-06）**

两条实测把方案钉死了：

1. **moon 没有条件 import**（报错原文：「Conditional imports are not yet supported by the build system.」）⇒
   同一个包里不能"js 用一套依赖、native 用另一套"。而 js 那条路今天撑着全部判据与 `press`，
   P10 的对账判据又要求 native 与 js **都在** ⇒ 想用 registry 上那四个 `+native` 语法包当依赖，
   **js 就编不过**。所以"四门走 registry、一门自己 vendor"那条路**不成立**。
2. **体积不是问题**：整棵 vendor 树未压缩 17 MB，`tar.gz` 压完 **0.91 MB**（生成码表极度可压；
   对照：已有的 `vendor/web-tree-sitter` + `grammars` 压完 0.41 MB）⇒ 进包的代价是**约 0.9 MB 下载量**。

⇒ 于是**一个包同时支持 js 与 native**（正是 ④ 要的形状），全部 C 自己带：

* 已落地（本轮）：`vendor/tree-sitter/`（C 库 850 KB + `PROVENANCE.md`）、
  `vendor/tree-sitter-grammars/`（五门语法的 `parser.c`/`scanner.c` + **各自的** ABI 头 + `PROVENANCE.md`）。
  出处与我们 `.wasm` 的 npm 版本**严格相同**（那是"两边同一门语法"可复算的前提）。
  发布契约里也钉住了（`tools/package-check.sh` 的 REQUIRED，含"少了它 native 编不出来、而 js 照样绿"这条理由）。
* 下一轮：把垫片接进 `engine/highlight`（`ts_shim.mbt` 保持 js、新增 `ts_shim.native.mbt` + C 桩，
  `moon.pkg` 用 `options(targets: …)` 按 target 选文件；`supported_targets` 放开到 `+js +native`）。

**⑧ 垫片搬进仓了（2026-10-06）—— ② 的代码落地**

`engine/highlight` 现在是**双 target 的一个包**：

| 文件 | 角色 |
|---|---|
| `hl.mbt` / `wrap.mbt` | 纯逻辑（调色板 / 刷色 / 包装候选）—— 两个 target 共用 |
| `captures.mbt` | 三列文本 → `Capture`（与 target 无关的那半） |
| `queries.generated.mbt` | **内嵌**五份 query（native 没有引导层读盘）；由 **`skillpress gen-queries`**（`cmd/skillpress/cli/gen_queries.mbt`）从 `grammars/*.scm` 生成，判据 `tools/queries-check.sh` |
| `ts_shim.mbt`（js） / `ts_shim.native.mbt`（native） | 两份垫片，各提供 `ready` / `languages` / `captures_text`；`moon.pkg` 用 `options(targets: …)` 选文件 |
| `ts.c` + `gram-{bash,javascript,json,moonbit,toml}.c` | native 的 C 桩（谓词 + 查表折算接口）+ 把 vendor 里的语法与 C 库编进来 |

`moon.pkg`：`supported_targets = "+js +native"`（**④ 的样板**，其余包照这个来）。

**实测**（同一份真素材 + 真 query，native 垫片 vs js 垫片）：json 61 ｜ moonbit 1725 ｜ bash 1173 ｜
javascript 544 ｜ toml 28 —— **五门全逐字节一致** ✓

**两条新的工程事实（都实测）**：
1. **`stub-cc-flags` 的相对路径会随"从哪儿构建"漂**（从别的模块里构建时 cwd 不同 ⇒ `-I` 失效）。
   改用**相邻头**：把 `lib/include/tree_sitter/api.h` 复制到 `lib/src/tree_sitter/api.h`，
   让引号包含按"相邻"解析（副本与正本逐字节相同，已记进 `vendor/tree-sitter/PROVENANCE.md`）。
2. `@string.parse_int` 是**抛**的（不是 `Result`）⇒ 垫片里用 `try/catch`（写 `match Ok/Err` 编不过）。

**js 回归（拆 `ts_shim.mbt` 之后必须验）**：`press --check` 两份语料 ✓ ｜ `file-parity` 逐字节 ✓ ｜
`highlight-parity` 与旧实现逐字节 ✓ ｜ `moon test` 29/29 ✓。

**⑨ ③ native 宿主落地（2026-10-06）**

| 件 | 落点 |
|---|---|
| 门/脚手架用的宿主 | **新包** `engine/gates/native/`（`host.mbt` + `host.c` + `mbstr.h`）—— 与 `engine/gates/js` 对称 |
| 内容管线的 IO | `engine/content/io.native.mbt` + `note.c`（`io.mbt` 那份 js 的**一字未动**） |
| ④ 的第二块 | `engine/content` 的 `supported_targets` 从 `+js` 放开成 `+js +native` |

*能力从哪来*：`moonbitlang/x` 的 `@fs`（读文件 / 列目录 / 建目录 / 写文件）与 `@path`（`Path::resolve`）；
**三条它没有的**（`cwd` / `is_tty` / `read_line`）走 60 行 C（`host.c`，纯 C 的 UTF-8↔UTF-16 转换，
不依赖平台 API）。诊断输出（stderr）也是 C（`note.c`）—— MoonBit 的 `println` 只往 stdout 写，
而 `gen-file` 的 stdout 就是产物本身。

*实测*：native 的 `md_kids` / `script_kids` 与 js 那条（引导层 `mdKids`/`scriptKids` 的口径）在
**三个真实 skill 目录**上**逐字节一致** ✓（这是"两个 target 的站点内容不会分叉"的前提）。

*两条写在明处的账*：
1. native 没有 `process.exitCode` ⇒ `set_exit_code` 只把码记在 `Ref` 里、由**可执行件**收摊时用
   （`pub fn exit_code()` 暴露出来）；**不在中途 exit**（那会把还在跑的事截断）。
2. **已知口径差**：js 的 `md_kids` 用 `localeCompare`（分语言环境），native 用 UTF-16 码元序 ——
   同一层里**既有大写开头又有小写开头**的名字会排得不同（例：`B.md` vs `a.md`）。
   我们两份语料都没有这种名字（判据盯着），但别人的语料可能有；真出现差异时要记账，不能让两个 target 悄悄给出两种站点。

*新依赖*：`moonbitlang/x@0.5.5` 进了 `moon.mod`（模块级依赖 ⇒ 随包发）。

*还剩*：`cmd/skillpress` 的 target 分叉 —— 它要同时用 `engine/gates/js`（js）与 `engine/gates/native`（native），
而 moon 没有条件 import ⇒ 得拆成**共享逻辑包 + 两个薄可执行件**（js 一个、native 一个），然后才谈 ⑤。

**⑩ CLI 拆包 + native 可执行件（2026-10-06）**

*形状*（因为没有条件 import，只能在**可执行件**那一层分叉）：

| 包 | 是什么 |
|---|---|
| `cmd/skillpress/cli/` | **所有子命令的实现**（`cli.mbt` / `check.mbt` / `attach.mbt` / `dump_blocks.mbt` / `args.mbt`），与 target 无关；宿主与"程序根提示"由 `run(host, hint)` **注入** |
| `cmd/skillpress/`（js） | 薄：`@cli.run(@gjs.js_host(), program_root())` —— 产物路径**没变**（`_build/js/debug/build/cmd/skillpress/skillpress.js`，引导层与启动器都按它找） |
| `cmd/skillpress-native/`（native） | 薄：切二进制 stdio → `@cli.run(@gnative.native_host(), hint)` → `@sys.exit(@content.exit_code())`。`hint` 来自 `SKILLPRESS_PROGRAM`（**不猜**：`moon install` 把可执行件装到 `~/.moon/bin/`，那里没有程序数据） |

*顺带把"引导层喂的数据"全撤了*：`read_text` / `md_files` / `dump_root` / `skill_dirs` 以前是引导层挂在
`globalThis` 上的（native 没有引导层）⇒ 现在都从**注入的宿主**算（`SKILLPRESS_CORPUS` 走 `@sys`）。
js 那条路的行为**没变**（`press --check` ×2 + 门 + 29 条 wbtest 全绿实测）。

*实测读数*：
* native 可执行件编出来了（4.6 MB），`gen-file ../moobile/skills` 能跑；
* ⚠️ **CRLF**：不切二进制模式时 Windows 把每个换行写成 CRLF ⇒ 产物**整份**与 js 不同。加 `sp_set_binary_stdio()`
  （`_setmode(_O_BINARY)`）之后，差异从 1842 行掉到 **6 行**；
* ⚠️ **剩下 6 行**（921 行产物里）：isolate 到**一条多出来的 capture**（`type`，出现在一个"包进 match 分支"的
  moonbit 片段上）⇒ 两个实现的**语法树不同**。变量有两个：**运行时**（native vendored 的 C 是 **0.25.1**，
  js 侧 `web-tree-sitter` 是 **0.27.0**）与**语法表**（npm 包里那份预编译 `.wasm` vs `parser.c`）。
  隔离实验还差一步（`web-tree-sitter@0.25.1` 那份探针没跑起来）。
* 🔎 **影响决策的新事实**：npm 的 `web-tree-sitter@0.25.1` **带 C 库**（`lib/*.c`），而 **0.27.0 只带 wasm**；
  `tree-sitter`（Node 绑定）在 npm 上只到 **0.25.1** ⇒ **C 运行时要对齐 0.27 必须走 GitHub**（本机代理没开）。
  两条出路：**(a)** 打开代理，取 0.27 的 C 源 vendor 进来（两边同版，最省事）；**(b)** 把 **js 侧也钉到 0.25.1**
  （两边的 runtime 就同版了；代价是站点颜色在少数块上会变一点点，而且 `package.json` 里那个 dev 依赖要跟着动 ——
  旧实现那 3404 行**代码**仍然冻结，不碰）。

*另*：`G3` 当场逮到"拆包之后文档里引用的旧路径"（`skills/skillpress-dev/SKILL.md` 里的 `cmd/skillpress/attach.mbt`）
—— 改完全部引用、并按规矩复核体量后重新落锁 ✓。

**⑪ 那 6 行查清了：**运行时版本**，两边对齐到 0.26.0（2026-10-07）**

⑩ 留下的 6 行差异（921 行产物里一处多出来的 `type` capture）**不是语法表的问题，是运行时版本**。
隔离实验把两个变量分开了（同一份素材、同一份 `.scm`）：

| 组合 | 读数 |
|---|---|
| js `web-tree-sitter@0.25.1` + 我们那份 `.wasm` ｜ native 0.25.1 + 我们那份 `parser.c` | **一致**（54 条 capture） |
| js `web-tree-sitter@0.27.0` + 同一份 `.wasm` | 53 条 ⇒ **少一条** |

⇒ 差的是 **wasm 运行时**（0.27.0）与 **C 库**（0.26.0）之间的行为，与"npm 预编译 `.wasm` vs `parser.c`"
无关。于是走 ⑩ 里那条 **(b)** 的升级版：**两边都钉到 0.26.0**——

* js 侧 `vendor/web-tree-sitter/` 覆到 **0.26.0**（`package.json` 里那个 `^0.26.0` 的 dev 依赖同步）；
* native 侧 `vendor/tree-sitter/` 覆到 **PyPI sdist 0.26.0**（npm 到不了 0.26 的 C：那条线停在 0.25.x，
  0.26+/0.27.0 只发 wasm；crates.io 403、GitHub 不通 ⇒ sdist 是唯一够得到的出处）；
* **两份 `LICENSE` 也一起换**（实测 0.26.0 与 0.27.0 的 MIT 版权行不同 —— 只换源文件不换许可证，
  就是"表里写一版、盘上是另一版"）；
* 两份 `PROVENANCE.md` 的表与版本理由重写（含"**换版本必须两边一起换**"这条前提）。

*为什么不是 0.25.1*：旧实现（`lib/*.mjs`，对账参照物、不能改）在 `web-tree-sitter@0.25.1` 下当场报
`Error: Dynamic require of "fs/promises" is not supported`，0.26.0 不报 ⇒ 0.26.0 是唯一同时满足
"旧实现跑得动"与"两个 target 的 C/wasm 同版本"的版本。代价已认：少数块的颜色与 0.27.0 差一点点。

*对齐后的读数*：native 与 js 的 `gen-file` 产物**逐字节一致（921 行）** ✓；`highlight-parity`（旧 vs 新）
32 个代码块 + 各语言汇总**逐字节一致** ✓。

*⚠️ 顺手修掉的一条假红*：`highlight-parity` 曾因**标签里的路径写法**变红 —— 新实现那侧的内容根是
`resolve` 过的绝对正斜杠形式（`dump_root()`：native 没有引导层喂它，两个 target 统一在这一层规范化），
而旧实现那侧的驱动脚本打的是 `SKILLPRESS_CORPUS` 原样字符串。34 行读数逐字全等，diff 却是 68 行。
修的是**驱动脚本**（`tools/spike/node-side-batch.mjs` 也按 `prepareRoot()` 的口径规范化），
不动冻结的 `lib/`，也不动引擎 —— **红的是标签、不是上色**，这种红会把真正的退步埋掉。

**⑫ 判据落地 + `moon install` 端到端验过（2026-10-07）**

*判据*：`tools/native-parity.sh` —— 同一份语料上 **native 与 js 的产物逐字节一致**，三份读数：
`gen-file` 921 行 ｜ `dump-blocks` 224 行 ｜ `batch` 41 行（全绿）。六条诱饵（1 绿 + 5 红）：
改一个字符 / CRLF（native 落地时真踩过的坑）/ 两侧都空 / **两份 runtime 版本号不同** /
**vendor 里的文件与 `PROVENANCE` 记的 sha256 不符**。前两条诱饵是**前提守卫**：
这条判据的合法性压在"js 的 wasm 与 native 的 C 库同版本"上，所以脚本自己先把版本号互相对、
再拿表里的 sha256 核一遍盘上的文件。
⚠️ 顺带修掉一处**判据自己留下的脏东西**：诱饵原先写进真产物目录（`_build/parity/`），
"把 wasm 改坏 ⇒ 期望红"那一条会把真的 `js-gen.txt` 留成**空的**（`> 文件` 在失败时先清空），
下一个读它的人就拿空文件当基准 —— 实测就踩着了一次。现在诱饵一律写 `$ST/out`。

*`moon install` 端到端*（这是 P10 的**硬需求**，之前只记着"没验过"）：

| 步骤 | 实测 |
|---|---|
| `moon install <绝对路径>/cmd/skillpress-native --bin <目录>` | ✓ 装上（**release** 构建，2.98 MB）｜⚠️ 第二参数（repo 内路径）**只认 git 源**，本地源会报 `Path in repo can only be used with git URLs` ⇒ 本地要**直接指到包目录** |
| 装出来的二进制跑 `gen-file <语料>`（在仓外、cwd 是 `/tmp`） | ✓ 921 行，与 js **逐字节一致** |
| 装出来的二进制跑 `check --program <程序根> --skills <内容根>` | ✓ 门跑通（rc 与 js 同口径） |
| 不给 `--program` | ⚠️ 原先会打「5 项不合格」而**真因是"程序根落回 cwd"**（第一条是"G4 命令引用的脚本不存在：tools/press.mjs"，会把人带偏）⇒ 已加一条点名：**「程序根没给（native 不猜）：现在按 cwd 算 —— …」** |

*诚实说明同步*：`README`（目录表 + 判据 ⑮ + 诚实清单第 2 条）、`skills/skillpress-user/SKILL.md`
（"今天要不要 Node"那一段）、`skills/skillpress-dev/SKILL.md`（改 native 那一侧要跑哪条判据）、
本文件 P8 的状态表（原先写着"还没动手"，与事实不符）。两份 `SKILL.md` 的体量变化都**复核后重新落锁**。

*顺手修的两条假红*（都不是这次改动引入的，是"源码/脚本搬了家而判据没跟着搬"）：
① `file-parity --selftest` 的前提诱饵**结构上不可能触发**（`mk-parity-corpus.sh` 自己会摘掉
`WEBSITE.md`）⇒ 改成**证明前提的作用**：往副本里放一份 `WEBSITE.md`，两个引擎**真的分叉 59 行**；
② `diagnostics-ledger` 的扫描范围少了 `cmd/*/*/*.mbt` ⇒ CLI 拆包（⑩）之后那三条"落锁"诊断
被报成"无声蒸发"，其实它们**搬了地方、一个字没改**。

**⑬ 还没做**（下一轮）：站点判据（P8.3：`lib/verify-site.mjs` 的 22 条断言搬进 MoonBit、并去掉
"写死 moobile 语料"）；`attach` 在 native 上的端到端（`--program` 那条已能用，但没像 `check` 一样逐条验）；
`moon install` 到默认 `~/.moon/bin/` 的那一步（本次刻意装到 `_build/install-bin/`，没动用户的工具链目录）。

**② 那四件的现状（⑧⑨⑩ 已把 1–4 做完，留在这儿当对照）**：

| # | 动哪儿 | 现状（2026-10-07） |
|---|---|---|
| 1 | `engine/highlight` | ✅ js 垫片 `ts_shim.mbt` + native 垫片 `ts_shim.native.mbt` + C 桩（**走的不是 registry 包**：全 vendor，见 ⑦） |
| 2 | `engine/content` 的 IO | ✅ `io.mbt`（js）与 `io.native.mbt` + `note.c`（native），由 `moon.pkg` 的 `options(targets: …)` 选文件 |
| 3 | 宿主 | ✅ `engine/gates/native/{host.mbt,host.c,mbstr.h}` 与 `engine/gates/js` 对称（缺的三样 —— `cwd`/`is_tty`/`read_line` —— 走 C） |
| 4 | `supported_targets` | ✅ 放了 `content` / `highlight` / `gates/native` / `cmd/skillpress-native`；**`shell` 与 js 可执行件保持 `+js`**（`cmd/skillpress` 不 import `shell` —— 已核依赖） |

**③ 判据**：同一份语料上 **native 产物与 js 产物逐字节一致**（沿用 `file-parity` 那套对账法），
外加"`moon install` 出来的那支命令真的能跑 `check` / `gen-file` / `attach`"。

⚠️ **网站那一侧的 JS 依赖去不掉**（`moobile-host` + react/react-dom/react-native-web + esbuild 是**浏览器宿主**的生态）——
但那是**产物**的事，与 CLI 用什么语言写、要不要 Node 无关。

### P7 收尾
判据补齐（等 D8 解除）｜文档对齐（`SPEC.md` / 内容侧 `references/layout.md` / 两份 README）｜
发布前清单（包形态、副本新鲜度那条门）。

### P8 引擎迁到 MoonBit（D15）—— 🚧 **P8.0–P8.2 已落地**，P8.3 还没动手

⚠️ 这行原先是"**还没动手，先落方案**"（2026-10-06 写下时确实没动手）。今天的实际状态：

| 步 | 状态 |
|---|---|
| P8.0 探针 | ✅ 落地（探针留在 `tools/spike/`，不进发布包） |
| P8.1 管线 | ✅ 落地：`engine/content/` + `cmd/skillpress` 的 `gen-file` / `dump-blocks`，判据 `file-parity` / `blocks-parity` / `blocks-fixtures` / `highlight-parity` |
| P8.2 门 | ✅ 落地：`engine/gates/` + CLI 的 `check`（13 个诱饵照搬） |
| P8.3 站点判据 | ❌ **还在冻结的 `lib/verify-site.mjs`**（真 Chrome + CDP；22 条判据没搬）—— 而且它那条链**写死了 moobile 那份语料**，换语料会一片红 |
| P8.4 收口 | 🚧 部分：CLI 已能 native（P10）；"一个月亮装下引擎 + shell + skills"与 `moon install` 端到端还没验 |

**为什么迁**：这套东西本来就是 MoonBit 生态（库与站点界面都是 MoonBit），而引擎是 **3404 行 `.mjs`**
（`gen-content` 834 ｜ `verify-site` 776 ｜ `check` 635 ｜ `docfacts` 567 ｜ `highlight` 332 ｜
`roots`+`kids` 180 ｜ `bin` 80），只因为**继承了既有工具链的语言**才长成这样。
迁完的收益不只是"整齐"：**一个月亮包装下引擎 + shell + skills**，CLI 用 `moon install` 装，
不必再维护 npm 那条线（也就不必再有两个 registry、两条发布命令）。

**怎么迁**（照本仓库自己的迁移纪律：**新实现与旧实现逐条对账 + 证伪**，先例是 moobile 的 `tools/mbtools`）：

| 步 | 做什么 | 怎么算"成了"（判据） |
|---|---|---|
| **P8.0 探针** | 一个独立嵌套模块：`mizchi/markdown` 解析一份 `SKILL.md`；`tree_sitter_*` 对同一段代码块上色 | ① 块结构与我们 `gen-content` 对得上；② 色号片段拼回去**逐字节等于原文**（照搬现有硬断言）；③ **同一块的未上色比例不比 Node 侧差**（audit 那道闸门）；④ 定下 native 还是 js |
| **P8.1 管线** | `lib/gen-content.mjs` + `lib/kids.mjs` → MoonBit | `--check` 语义照搬（生成物与内容源**逐字节一致**）；现有 7 份 skill 全绿 |
| **P8.2 门** | `lib/check.mjs`（含 13 个诱饵）+ `lib/docfacts.mjs` → MoonBit | 诱饵**全被点名**、正例不误杀；`facts` 的读数与 Node 侧一致 |
| **P8.3 站点判据** | `lib/verify-site.mjs`：真 Chrome + CDP + 起静态服务 | 那条链在 `moonbitlang/async` 上跑通；**22 条判据语义不变** |
| **P8.4 收口**（每个文件 ≤400 行 —— 预估 9 个文件 / ~1870 行，见 D21） | 与 P6 的 `shell` 包合流：一个月亮装下引擎 + shell + skills | `moon install` 装出来的 CLI 在内容仓跑通 `check` / `press` / `verify` |

**P8 一并落地的（这几条都是引擎侧的通用化，按「内容等引擎」的顺序一起动）**：

| 落什么 | 出处 |
|---|---|
| **忽略清单** `skillpress.ignore.md`（解析 + 门 + 站点三处；跳过必须"响"） | D17 / `SPEC.md` §0.1 |
| **首页拆出来**：读 `<内容根>/skillpress/WEBSITE.md`，`--home` 可覆盖，没有就回退 `SKILL.md` 并打印 | D19 |
| **首页也过门**（G2/G3/G7 + 进 G8 指纹）且**不算子页** | D20 |
| **门分层**：G5 / G6 / `facts` 搬去内容仓自己（核心只留通用门） | D18 |
| **缺 moobile 也不许死**：缺什么**明说跳过**（现在是 `process.exit(2)`） | R6 |
| **每个源文件 ≤ 400 行**（含注释），并配一个 401 行的诱饵 | R9 / D21 |

⚠️ **内容侧的拆分（`WEBSITE.md` + `SKILL.md` 瘦身 + 第一个 ignore）与这批同批做** —— 用户定（2026-10-06）：
引擎支持之前不动内容，免得"文档/内容先跑在实现前面"。

**P8.0 探针已跑（2026-10-06，代码与结论在 `tools/spike/`）**：

| 问 | 答 |
|---|---|
| `mizchi/markdown` 够不够映射我们的 `Block`/`Span` | **够**（块类型齐全 + **自带 frontmatter 解析**；与正则真值逐项一致），跑在 **js** |
| tree-sitter 上色链 | **两条路各缺一块**：js 被包声明的 `supported-targets: +native` 挡住；native 被**上游缺 C 源**挡住（`tree_sitter@0.4.6` 的 `tree-sitter.c` include 了包里没有的 `tree-sitter/lib/src/lib.c`） |
| 走哪条 | **js 是主路**（语法用我们自己 vendor 的 wasm）；native 记为备选 —— 而"零 npm"这条目标 **2026-10-06 已用另一条路达成**（把运行时也 vendor 进来，见 D34）⇒ native 不再是它的前提 |
| 额外两条硬结论 | ① **native 必须先设 MSVC 环境**（不设时报的是 `LNK1120`，像"没装工具链"，其实是 `INCLUDE`/`LIB` 没设；本机用 `native-build.bat` 包 vcvars64）② **js 与 native 是两张构建图**（一个入口 import 了只支持 native 的包，js 整张图就编不出来）⇒ 探针拆成 `cmd/js` 与 `cmd/native` |

⚠️ 探针**没**回答的（别当成已覆盖）：**召回率对账**（它的 query 是精简 4 条 pattern，不是完整
`highlights.scm`；上色质量是这条路上最要紧的风险，必须在 P8.1 用同一块 + 同一份 scm 量）；
**字节偏移 ↔ 字符下标**（tree-sitter 给 UTF-8 字节偏移，MoonBit 的 `String` 在 js 后端是 UTF-16）。

**P8.1 起步（2026-10-06，js 主路）**：

- 正式模块落位：程序仓根上的 `moon.mod`（`XiLaiTL/skillpress` v0.1.0，`preferred_target = js`）
  + `.moonignore`（`/tools/`、`/_build/`、`skills.lock.json` 不进包）。
- **上色链在 js 上打通**（`engine/highlight/`）：`hl.mbt` = 色号表 / 区间收集 / 片段拼装 / 未上色计数（**纯逻辑**）；
  `ts_shim.mbt` = 一层**薄垫片**，只把 tree-sitter 的 capture 压成"名字	起点	终点"三列文本，其余全在 MoonBit。
  异步留在**引导层** `tools/run-js.mjs`（Node 先 `await` 装好 `web-tree-sitter` 与我们 vendor 的 5 份 wasm，
  挂 `globalThis`）—— 因为 `moon run --target js` 产出的是 **CJS**，顶层 await 不成立。
- **读数对账（同一块 + 同一份 scm）**：bash 块与旧实现**逐项一致**（未上色 19/23 ｜ 色号 6 → 0 ｜ 拼回原文 true）；
  moonbit 块差 **1/93**（31 vs 30）—— 差在旧实现的"**包装候选**"还没搬（**已知缺口**，下一步补）。
- **A1 的机制已经活了**：`moon package --list` 打出 `XiLaiTL-skillpress-0.1.0.zip`（42 文件 / 437 KB，含 `engine/`）。
  ⚠️ 但"**别的工程装上**"这条**必须真发布才能证** —— `moon add` **只认注册表模块名**，没有本地路径形式
  （本地联调只能靠 `moon.work` 工作区）；发布要凭据（等用户点头）。
- ⚠️ 包里**暂时还带着 Node 版引擎**（`lib/*.mjs`、`bin/`、`package.json`）：过渡期如此，
  等 MoonBit 侧与它对齐（P8.1–P8.3）之后再把它请出包。

**P8.1 上色链对账通过（2026-10-06）**：

- `engine/highlight/` 三件：`hl.mbt`（调色板 + **按优先级刷字符** + 合并同色片段）、
  `wrap.mbt`（语言表 + **包装候选**：裸着解析 / 函数体 / let / 调用参数 / 数组元素 / struct 字段 / match 分支）、
  `ts_shim.mbt`（薄垫片，只做同步调用）。
- **判据**：`SKILLPRESS_CORPUS=<内容根> bash tools/highlight-parity.sh`
  —— 新实现与旧实现（直接调 `lib/highlight.mjs`）在**全语料**上的读数**逐字节一致**
  （32 个代码块 + 4 个语言汇总；只有第 1 行的"各自名字"不同）。
  实测：moonbit 8 块 93/1061 ｜ bash 18 块 1162/2207 ｜ json 1 块 33/260 ｜ javascript 5 块 57/905。
- 两条**语义细节**是这次对账逼出来的（自创就会差一点，而差一点最容易被当成"差不多"）：
  ① 重叠时**先按优先级、再按起点**（`PALETTE` 的顺序就是优先级），不是"按区间丢重叠"；
  ② 挑包装用**严格小于**（相等取先出现的那个），`dark == 0` 提前收工。
- 所以 `audit` 那道闸门（召回率 / 漏色比例）的读数**两边必然一致** —— 逐块 runs 已经逐字节相同。
- 顺带修掉两个"自己骗自己"的坑：语料清单别把 `split().filter()` 的**视图迭代器**当数组（实测读出来 0 份，
  看起来像"没语料"）；汇总行按**固定顺序**打印，好让 `diff` 成为判据。

**P8.1 后半：文档块管线（2026-10-06，进行中）**

- **判据先行**：`bash tools/blocks-parity.sh`（`SKILLPRESS_CORPUS=<内容仓>/skills`）——
  新实现（`engine/content` + CLI 的 `dump-blocks`）吐出的 `blocks: [ … ]`
  与**旧实现已经产出的** `content.generated.mbt` 里的同名区段**逐字节一致**。
  基准侧的切段器是 `tools/spike/old-doc-blocks.mjs`（按括号深度配对、跳过字符串里的括号；
  实测切出 7 段 / 226 行）。
- 为什么这条比"数一数块数"硬：那份生成物是**旧实现的产物 = 真相**；能原样吐出来才说明每条渲染细节
  （`esc` 的转义、缩进、**链接拆成 `Txt(名字) + Code(目标)`**、表格单元格的空格、列表的 `indent`/`num`…）都搬对了。
- 移植对象是 `lib/gen-content.mjs` 的 `parseFrontmatter` / `summarize`(46) / `inline` / `parseBlocks` /
  `emitBlock` / `esc` / `spanList` / `runList`；代码块的 runs 用已经对账通过的 `engine/highlight`。

**A1 的本地形态已验（2026-10-06）**：另一个工程能依赖这个模块 —— 实测做法（不需要先发布）：

- 消费者 `moon.mod` 里**声明依赖**：`import { "XiLaiTL/skillpress@0.1.0", }`；
- 用 `moon.work` 把两个模块连成工作区（`members = [".", "<skillpress 的绝对路径>"]`）——
  ⚠️ 成员路径要**绝对路径**（相对路径实测报 "系统找不到指定的文件"）；
- 消费者的包 `import { "XiLaiTL/skillpress/engine/highlight" @hl, }` + `supported_targets = "+js"`（跟着依赖声明）。
- 结果：`moon check --target js` **干净通过**（零警告）。
- ⚠️ 但"**moon add 装上**"这条判据**仍然只能靠发布**：`moon add` 只认注册表模块名，没有本地路径形式。

**P8.1 收官（2026-10-06）：整份生成物由 MoonBit 引擎产出，逐字节一致**

- `engine/content/` 十个文件 / 1809 行（每份 ≤400，R9 已核）：`md`（frontmatter + `inline`）｜
  `blocks`（块解析）｜`text`（文本工具，为守 R9 从 md 拆出）｜`home`（首页 + 分栏 + 下拉 + 纯链接节）｜
  `file`（整份拼装 + 类型声明 + 取数函数）｜`kids`（子页）｜`generate`（总装）｜`emit`（转义/字面量）｜
  `io`（读文件）｜`doc`（一份 md → 段）。
- **判据**：`SKILLPRESS_CORPUS=<内容根> bash tools/file-parity.sh`
  → **整份 1143 行与旧实现产出的 `content.generated.mbt` 逐字节一致**（含旧实现那些诊断输出）。
- 配套：`blocks-parity` ｜ `highlight-parity` ｜ `blocks-fixtures` ｜ `line-budget`（含证伪）全绿；
  `moon build` 零警告；`check` 7/7 与 `check --skills skills` 2/2 不受影响。
- **意义**：**"press 生成"已经真由 MoonBit 引擎完成** —— 旧引擎的产物能被原样复现，
  所以旧引擎自己的 `press --check` 对这份输出同样成立（两份文件逐字节相同）。

**下一步的岔口**（两条都要，顺序待定）：
1. **P8.2 门**：`check`（G1–G4 / G7 / G8 + 13 个诱饵 + 落锁）搬进 MoonBit（`facts` 按 D18 搬去内容仓自己）。
2. **P6 抽 `shell` 包**：界面搬进包（目标形状见下），实例 `app.mbt` 缩到 ≤20 行 —— **A2 就靠它**。

**每一步都要守的一条**：**R6 通用性**（D16）—— 迁完不许变成「只有 moobile 能跑」。
新建的门/管线一律先问一句：**一个只有 `skills/` 的陌生仓库，它跑得起来吗？**

**过渡期唯一那条纪律**：两套实现会**同时存在**一段时间，所以
**任何一条判据的期望值都不许"跟着新实现改"** —— 先让新实现对齐旧实现的输出，再谈优化。
（这正是 D9 那次"逐条对账"的教训：门只能证明"结构没坏"，证明不了"信息没丢"。）

## 3. 风险与未知（要探的）

| 项 | 为什么是风险 | 兜底 |
|---|---|---|
| 滚到锚点 | RN 的滚动容器是伪标签 `scroll`，`@sub.on_scroll` 只读不写 | TOC 点击改成"切段"（首页形态） |
| 真 `:hover` | 样式层只有 `.press()`（源 CSS 的 `:hover` 降级到它） | 只用按下态，不做悬停特效 |
| `Attrs::id` 落不落 DOM | RNW 的 props 有严格白名单，白名单外的键**连警告都没有** | 用 `@html.node("a", …)` 或宿主侧 JS 补 |
| 拆 ref 的尺度 | "门禁 vs 细则"靠人判断，容易拆碎或拆不动 | 一个主题一份；宁可合，不许丢信息 |
| 实例进不进 `moon.work` | 进了 `moon check` 会连它一起编（多一层覆盖），也让它依赖工作区布局 | 先独立构建（现状），P6 里定 |
| 发布形态 | npm 包名 / moonbit scope 都没定 | P6 再定，先不影响仓库内路径 |
| **上色召回在 MoonBit 侧掉下来** | 现在的召回是**调出来的**（裸解析 12% → 包装候选 93%）：换实现很容易"跑起来了但质量掉了" | P8.0 的判据③：与 Node 侧**同一个块**比未上色比例；不许只报"能上色" |
| **native 还是 js** | native 要 C 工具链（本机有 MinGW `gcc` 15.1.0，**没有 `clang`**）；js 走的正是**同一个 `web-tree-sitter`** | P8.0 两条都试，按"能不能零 npm + 判据不掉"定 —— ✅ **2026-10-06 结案：走 js，并且"零 npm"用 vendor 运行时达成（D34）** |
| **真 Chrome 那条链** | 776 行 CDP 判据是这套东西里最脆的一环（真鼠标事件、动态端口、Chrome 的 stderr 必须留着） | `moonbitlang/async` 自带 process / http / websocket / tls；P8.3 先做最小探针（起 Chrome → 连 CDP → 发一次真鼠标事件） |
| **过渡期两套实现漂移** | "改了 Node 侧忘了 MoonBit 侧" = 两份会漂的真相，而门只会查其中一套 | 过渡期**只让一套是"真相"**（判据以它为准），另一套要么只读、要么立刻删 |
| **忽略清单变成静默的后门** | D17 允许「不上桌就不过门」—— 而「让门变绿」正是这套东西最不想要的形状 | `SPEC.md` §0.1 的四条：**必须带理由**、**每次打印被跳过的 N 份**、**首页不许被忽略**、清单进 git 可复核 |

## 4. 明确不做（这轮）

> ⚠️ 这一节记的是**那一轮**的边界（2026-10-06 之前）。发布形态后来被 D15 改了：
> **不单独发 npm 引擎包**，路线见 P8；站点那条见 P6。

深浅色主题 ｜ 站内搜索（要用同一份标题索引，排在 TOC 之后）｜ PWA / 离线 ｜ 真机（Android / iOS）
上的站点 ｜ 真机判据（`verify_android.py` 那套与站点无关）｜ 发布到 registry。

## 5. 调研记录：MoonBit 侧要用的包（2026-10-06 查实）

**先记一条方法论教训**：别只查本机 `~/.moon/registry/cache` —— 那里只有**下载过**的东西。
我一度据此写下"MoonBit 没有 tree-sitter 绑定"，**是错的**；权威查法是 `moon search <关键词>`
与 `moon view <用户名>`（都能直接查注册表）。

| 要的东西 | 包（实测存在） | 关键细节 |
|---|---|---|
| tree-sitter 绑定 | `tonyfettes/tree_sitter@0.4.6`、`tonyfettes/tree_sitter_language@0.1.3` | **js** target 上是 `await import("web-tree-sitter")`（跟今天我们用的**同一个 npm 包**）；**native** 上链 `tree-sitter.c`（`supported-targets: "+native"`） |
| 我们那 5 种语法 | `tree_sitter_moonbit` ｜ `tree_sitter_bash` ｜ `tree_sitter_json` ｜ `tree_sitter_javascript` ｜ `tree_sitter_toml`（都 `@0.1.26`） | **一个不缺**（该用户下另有 30 个左右语法：c / python / rust / markdown…） |
| markdown 解析 | `mizchi/markdown@0.8.3` | CommonMark 0.31.2 + GFM 表格；描述写明支持 JS / Wasm / MoonBit |
| 起进程 / HTTP / WebSocket（CDP 那条链） | `moonbitlang/async`（`process` `http` `websocket` `tls` `fs` `socket`） | **moobile 本来就在依赖它**（`moon.mod` 的 `moonbitlang/async@0.21.0`）⇒ 这条链的原料是现成的 |
| CLI 怎么发给别人 | `moon install <user/module/pkg>` | **全局装二进制包**（npm 之外的第二条分发路） |
| 本机工具链 | `cc` / `gcc` **15.1.0**（MinGW-w64）在 PATH；**没有 `clang`** | 决定 native 那条路走不走得通 |

## 6. 验收：这个项目的**完成判据**（用户定，2026-10-06）

> 目标一句话：**完成 skillpress 直到打出并发布 moonbit 包**。
> 下面三条**每条都要能被命令证明** —— 证明不了的不算完成（这是本仓库的老规矩：
> "先测再断言：哪条命令的输出能证明这句话？"）。

| # | 判据 | 怎么证明 |
|---|---|---|
| **A1** | **包存在、装得上** | 程序仓 `moon package` 打出 `XiLaiTL-skillpress-<ver>.zip`（`moon package --list` 复核内容）；别的工程 `moon add` 装得上并 `moon check` 编过。发布之后再加一条：**从 registry 装下来**编译过（照 moobile 的 `tools/check_published.sh` 那套：发布包 ≠ 工作区） |
| **A2** | **站点直接依赖那个包，而不是抄界面** | 内容仓的站点实例 `moon.mod` 里写的是 `XiLaiTL/skillpress@<ver>`；实例的 `app.mbt` **只剩几行**（`@skillpress.site(...)`，验收取 ≤ 20 行）；**界面的第二份副本不存在**（引擎与 `shell` 都在包里） |
| **A3** | **自家的 skills 真能出站** | `press` → `build` → `serve` 打开就是那 7 份 skill 的站点；`verify` **判据全过**；`check` 对内容**全绿**；`moon package` 出的包里带上 `skills/`（随包分发那份） |

### 反过来：**这些情况不算完成**（防自欺）

- 本机跑得通，但**包装不上** / 装上了编不过（"本机绿 ≠ 装出来绿"）。
- 站点**还是抄的**：实例里留着一份 `app.mbt` 界面代码（那就等于包没起作用）。
- 只有**我们自己这套仓库**能跑（R6 通用性：一个只有 `skills/` 的陌生仓库也得能起站）。
- 包**缺件**：`grammars/` 的 wasm、规范账本、`skills/` 之类悄悄没打进去（`files` 白名单不报错 ⇒ 必须真打包真安装量）。
- 判据被"跟着新实现改"来凑绿（过渡期铁律：先让新实现对旧实现的输出，再谈优化）。

### 顺序（已经定过的，别再来回改）

引擎的通用化与迁移（P8）→ 与 P6 的 `shell` 抽包合流 → 打出包 → **内容侧拆分与它同批做**
（D19：引擎支持之前不动内容）。每个源文件 ≤ 400 行（R9 / D21）贯穿全程。

## 6b. 本轮（2026-10-07）站点侧交了什么 + 三处工具/实例的账

**功能**（对标表 #5 / #12 / #14 与 moobile 侧的甲级能力，逐条都有会自己红的判据）：

| 件 | 读数（命令 + 日期） |
|---|---|
| **代码块工具条**（#5：语言标签 + 复制） | `_scratch/code-toolbar-check.mjs`（真鼠标，剪贴板换成记录器）：3 个块都有**非空**语言标签（bash / moonbit / bash）、点一下**剪贴板被调用 1 次**且载荷与那一块正文**长度相同、开头逐字符相同**、按钮变「已复制」而**别的块不受影响**、0 条 JS 错误 |
| **本地搜索**（#12） | `_scratch/search-check.mjs`：17 条全过（含"点小节命中 ⇒ 目标节**顶到上沿差 0px**"） |
| **目录可点 + 跟读高亮**（⑤） | `_scratch/toc-click.mjs`：点最后一行 ⇒ sec-7 差 0px、点第一行 ⇒ sec-0；装载后**恰好一条**高亮在第 0 条、滚到第 4 节 ⇒ 高亮换到第 4 条 |
| **正文链接**（#9） | `_scratch/link-check.mjs`：正文里那条链接是**下划线 + 品牌色**、点一下 ⇒ **地址栏变**（`#/s/moobile-pitfalls/` → `#/s/moobile-app-development/`）、**页面没重新加载**（点前盖的戳还在）、落地页大标题**正是那条链接的标签**；0 条 JS 错误 |
| **prod 产物档**（#14） | `npm run build` ⇒ **829 KB**（dev 档 2939 KB，3.5 倍）；`dist/artifact.json` 的 `mode: "prod"`；三档回归 `ui-probe` 全过 |
| 站点三档回归 | `node tools/ui-probe.mjs` ⇒ **全部通过（3 个视口）** |

**三处工具/实例的账（都是本轮实测撞出来的）**：

1. ⚠️ **`npm run press` 在 Windows 上从来跑不通**：模板里是 POSIX 的
   `"${SKILLPRESS_ENGINE:-{{ENGINE_REL}}}"`，而 npm 在 Windows 上用 `cmd.exe` 跑 script
   ⇒ 原样传给 node，报 `Cannot find module '…\skillpress}	ools\press.mjs'`。
   修法：新增 `engine.mjs` 壳子（在 **Node** 里找程序根；`SKILLPRESS_ENGINE` 仍优先，找不到**直接报错不猜**）。
2. ⚠️ **`press` 的默认 `--app` 指向"别人那份实例"**：它是按"程序根旁边的内容仓"算的 ——
   在实例里直接跑，改/查的是 `../moobile/skills/skillpress/scripts/.skillpress`。
   ⇒ 两个 npm script 现在都显式带 `--app .`（npm 的 cwd 就是实例目录）。
3. ⚠️ **内容仓那份实例落后三处**（`build-web.mjs` 旧版 / `content.generated.mbt` 早于 `Doc.title` 契约 /
   `app.mbt` 少 `footer`），已一次还清并给了读数（见 moobile `FINDINGS.md` 本轮补记）。
   ⚠️ 顺带记一条**没有门盯住它**的原因：站点实例在内容仓，而两边各自的门都以为对方会跑它。

---

## 7. 发布清单（`moon publish` **之前**要过的）

> 这一节是"目标最后一步"的清单。⚠️ **发布是不可逆的对外动作** —— 走到这里要先停下来跟用户确认。

| # | 要过的 | 怎么证 |
|---|---|---|
| 1 | **`moon.mod` 的元数据齐全** | 实测：`readme` 与 `repository` **原先没设**，`moon package` 每次警告两行（2026-10-06 已补）。发布前再跑一次 `moon package --list`，警告应为 0 |
| 2 | **包内容复核** | `bash tools/package-check.sh`（**判据，不是"人读一遍"**）：该含的缺一个也红、不该含的多一个也红，带三向诱饵；两张清单与理由写在 `.moonignore` 的文件头（D24） |
| 3 | **许可与署名** | `LICENSE`（Apache-2.0）+ `THIRD-PARTY-NOTICE.md`（随包分发的语法资产是 MIT / Apache-2.0 —— 这条是**发出去才有的义务**） |
| 4 | **判据全绿** | 十三条，一条都不能少：`acceptance.sh`（A1/A2/A3）｜`file-parity`（含 `--selftest` 五条）｜`blocks-parity`｜`highlight-parity`｜`blocks-fixtures`（含夹具四）｜`native-parity`（**两个 target 的产物逐字节一致** + 六条诱饵）｜`site-source`（R2 首页源 + R4 忽略清单 + D20 指纹）｜`line-budget`（R9）｜`diagnostics-ledger`（诊断口径账本）｜`mbt-traps`（MoonBit 坑位）｜`shell-traps`（双引号里的反引号 = **会真的执行**）｜`package-check`（第 2 条）｜`consumer-check`（从 zip 出发的消费者视角）—— 再加 `fresh-clone-check.sh`：**干净克隆 + 现编下也是这些读数**；发布之后再加 `published-check.sh`（第 7 条：从 registry 装下来、在别的工程里编过） |
| 5 | **凭据** | `moon login`（**需要用户**）—— 到这一步先问 |
| 6 | 发布 | `moon publish` ✅ **2026-10-07 已发 `XiLaiTL/skillpress@0.1.0`**（`Server status: 200 OK`）。**读数**：`tools/published-check.sh` 全绿（从 registry 装下来 → 编过 → 包内容复核 → 门能跑）；`tools/acceptance.sh` **17 过 / 0 未到**（A1 那条"别的工程声明依赖后能编过"是**从 registry 装的这一版**）；`tools/consumer-check.sh` 消费者视角全过。⚠️ **同日还换血了它的两条旧断言**：`consumer-check` ⑧ 原来拿"整行图片"当"认不出的构造"（图片已支持 ⇒ 必然红）⇒ 改用行首原始 HTML，并补两条正向读数（整行图片收成 `Image`、站外图片原样） |
| 7′ | **✅ 已做（2026-10-07）：moobile 锚点抬到 `0.6.0`，`moon.work` 删了** | `shell/` 用的是 moobile 的**节点寻址**（`scroll_to_node` / `node_rect` / `node_scroll_top` / `on_node_scroll`）、`Style::transform`、`copy_text` / `open_url`、`img` 映射 —— 这些都在 **`XiLaiTL/moobile@0.6.0`** 里（**已发布**；核对方式是"从 registry 装下来的那份包里逐个 grep 到这些名字"，不是看本机源码）。⇒ 这一批把三处锚点全抬上来：`skillpress/moon.mod`、`template/instance/moon.mod`、内容仓那份实例的 `moon.mod`；宿主依赖 `^0.5.0 → ^0.6.0`（⚠️ **0.x 的 `^` 只到下一个 minor**，不抬就装不到 0.6.0：`engine/scaffold/names.mbt` 的 `host_dep_default` + 自举实例的 `package.json`；模板里是 `{{HOST_DEP}}` 占位符，由生成器填）。**删掉 `skillpress/moon.work`**（它存在的唯一目的就是吃本地 moobile），两个实例的 `moon.work` 去掉 moobile 那一条（留"程序根"那一条 —— 那是吃**本地 skillpress 源码**用的，等本包发出去再删）。**读数**：删完之后**不带工作区** `moon check --target js` **0 error**（60 个包，registry 的 moobile 0.6.0 满足全部 import）—— 这正是"用户拿到的那份能不能编"的第一道读数 |
| 7 | **发布后：外部视角** | 另一个工程 `moon add XiLaiTL/skillpress@<ver>` → `moon check` 编过（**这才是 A1 的注册表那条判据** —— 本地工作区那套不算数）；再跑一次 `tools/acceptance.sh` |

⚠️ `moon package --list` 的读数**只在模块没人在改时可信**（实测：有子代理在改时它会报"20 个错误"，
看着像包坏了，其实是半成品）。

## 8. 诊断欠账（账本：`tools/diagnostics-ledger.sh`）

> 2026-10-06 一场**只读静态审计**把旧实现（冻结的 `lib/*.mjs`）里 **76 条用户可见诊断**逐条对到新实现，
> 逮到一类判据照不到的东西：**产物逐字节对得上，诊断却在悄悄蒸发**（句子没了、退出码反了、该走 stderr 的走了 stdout）。
> 那份审计**做成了会站岗的判据**：每条诊断要么在新源码里**钉住句子**（`ok` / `dev`），要么在这里记成一笔**欠账**（`ow`）。
>
> ⚠️ 欠账行的断言语义是「**现在确实还缺**」—— 谁把它补上了，那一行就**红**，逼着把账本同步成 `ok` 并钉住新句子
> （**自销账**：账本不会烂在那儿）。反向也锁着：`ok` 行里那句一旦被无声删掉/改写，立刻红。

| 编号 | 欠什么 | 危害 | 归谁 |
|---|---|---|---|
| **DG-20** | 引擎不报「（N/M 个代码块没配语法或为空，按原文渲染）」 | 🔴 **今天就在触发**（真实语料上旧引擎打 `3/38`）却被**静默咽掉** —— 本表唯一"当场实测为静默"的一条 | P8.1 收尾 |
| **DG-丢前缀** | 首页两条问题丢了 `${where}：` 定位前缀；下拉菜单那条连尾注 `（当菜单的话它就不会渲染在正文里了）` 一起丢 | 出问题时**指不到是哪份文件**；尾注是"为什么必须改"的唯一解释 | P8.1 收尾 |
| **DG-CLI** | 未知子命令**新实现 `rc=0`**（旧 `rc=2` 且点名）；用法缺 `--repo/--skills/--app`。⚠️ **2026-10-06 部分变动**：`attach` 已在新 CLI 落地（用法里那两行补上了）⇒ 旧门面那句「还没做」**只对 `pack` 还成立**；而旧门面那句**刻意不动** —— 它是冻结的对照物，动它就破坏下面账本的句子钉子（对外那条路是新 CLI） | `cmd && next` 会把拼错的子命令**当成功** —— "退出码不对的门比没有门更糟" | P8.2 |
| **DG-check** | `--check` 全套 6 条（产物不存在 / 一致 / 不一致 / 第一处差异在第 N 行 …） | 判据侧有 `file-parity` 同语义替代，但**直接调引擎的人拿不到** | P8.2 |
| **DG-高亮指路** | 语法缺失时丢了「见程序根 `grammars/PROVENANCE.md` 的取法」，还多出 `ERR:` 前缀 | 撞上缺语法的人找不到取法 | P8.2 |
| **DG-audit** | ~~高亮的 audit 闸门整条未移植~~ **已还**（2026-10-07）：搬进 `cmd/skillpress/cli/audit.mbt`，口径逐条照抄（空集合必须红 / 召回率 ≥ 90% / 未上色 ≤ 40%）。⚠️ **两处有意不同**：① 扫描范围用**引擎那份语料列举**（跳过 `node_modules`/`_build`/`.mooncakes`/点目录），而旧实现是**无差别遍历整个内容根** —— 它把 `.mooncakes/**/README.md` 里的块也算进了分母（实测：真语料上旧的数到 114 个 moonbit 块，新的 8 个，那是**厂商依赖的文档**不是我们的内容）；② 按语言的打印顺序固定成 `moonbit/bash/json/javascript/toml`（与 `batch` 同一套），旧的是 JS 对象的插入序 | P8.2 → 2026-10-07 还清 |
| **DG-门整条** | ~~`check.mjs` 的 G1–G4 / G7 / G8 未移植~~ | ✅ **已落地**（2026-10-06，P8.2）：`engine/gates/` 19 文件 / 2817 行，真语料报告与旧实现**逐字节一致（76 行 / diff 0）**、28 文件夹具树 14 个诱饵全点红、G8 锁序列化回环逐字节、22 条 wbtest。**G5 / G6 按 D18 不搬**（它们读的是 moobile 的源码与 docs），所以夹具树里 `bad-api` / `bad-section` 两个诱饵在新实现里是绿的 —— 这是**刻意**的偏差，不是漏 | 已落地 |
| **DG-facts** | `docfacts.mjs` 8 条 | 按 D18 搬去内容仓，不在核心里 | 内容仓 |
| **DG-verify** | `verify-site.mjs` 7 条 + 22 条判据 label | 站点判据未移植 | P8.3 |
| **DG-首页标签** | 首页问题的标签口径：旧是 `relative(REPO, …)`（**随机器变**，实测能退化成带反斜杠的绝对路径），新是内容根口径（`skillpress/SKILL.md` 或 `skillpress/WEBSITE.md`）。⚠️ **2026-10-06 部分销账**：那条被删掉的**可行动信息**（「便携目录由 pack 生成它；项目里也可以自己写一份」）已在 R2 那一批**补回**，并且"找不到首页"现在把**两个候选源**都点出来（`WEBSITE.md` 与 `SKILL.md` 都没有）；剩下的只是"标签随机器变"这一条被迫偏差 | 标签固定是**被迫且应接受**的（跨机器稳定）。判据：`tools/site-source.sh` 盯三路首页源各自的标签 | 部分已修 |
| **DG-提示走 stderr** | 纯链接节提示「（…还带着 N 块正文…）」文本逐字节一致，但**流向 stdout → stderr** | 方向是被迫的（`gen-file` 的 stdout 必须是产物），但**用户可见行为变了**，得登记 | 已登记，`file-parity` 会把 stderr 逐条打出来给人看 |

**另外两笔不是欠账、是账本外的漏洞（`tools/diagnostics-ledger.sh` 管不到，另记在这里）—— 两笔都已修：**

1. ~~🔴 **`acceptance.sh` 的 A3 跑的是旧 CLI** ⇒ 迁移一完成 A3 对新引擎什么都证明不了（假绿）~~ ⇒ ✅ **已修**（P6）：A3 现在两头都钉 ——
   ① 旧引擎**现场重印**基线（证明基线不是手抄的、也没被新引擎覆盖过）；② `file-parity` 把新引擎产物与基线**归一化后逐字节**比。
2. ~~🟠 **`file-parity.sh` 的 `EXPECTED.sha256` 缺失时被静默跳过** ⇒ 删掉那个文件就等于关锁~~ ⇒ ✅ **已修**（2026-10-06）：
   改成"钉子文件不存在直接判红"，并实测过（移走文件 ⇒ 红并点名；放回 ⇒ 绿）。**不许有静默后门。**
