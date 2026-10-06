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
| D20 | **首页文件也过门，且不许被忽略豁免**：`WEBSITE.md` 过 G2（体量 + LF）/ G3（路径）/ G7（禁语），并进 G8 指纹；**它不算子页**（kids 必须排除它） | 用户定（2026-10-06）。两个洞都是实测出来的：① `skillFiles()` 只收 `SKILL.md` + `references/**` + `FAQ.md` ⇒ **首页今天既不过门也不进指纹**（能无限膨胀而没人复核）；② `mdFiles()` 收除 `SKILL.md` 外的所有 `.md` ⇒ 不加排除的话，同一个文件**既当首页又当书架里的一页**，两套渲染规矩打架 |
| D21 | **新引擎每个源文件 ≤ 400 行（含注释）**，与 skill 那边同一个预算；超了拆成「一个文件一件事」，**不许删注释凑数**；**由门 + 诱饵保证** | 用户定（2026-10-06，原话「转成 moonbit 后最多一个文件 400 行」）。为什么值得单列：**代码这边原先一条体量门都没有** —— 实测 3412 总行 / **2413 代码行**（注释 23%、空行 7%，不是注水），其中 4 个文件超 400（`gen-content` 636 ｜ `verify-site` 565 ｜ `check` 444 ｜ `docfacts` 401）。真因：几件事塞进同一个文件 + 手写了两样本该是包的东西（markdown 解析器、CDP 客户端）+ moobile 专属的东西混在核心里（D18 要搬走）。⚠️ Node 版**不回改**（冻结），规矩只对**新实现**生效 |
| D22 | **诊断措辞允许一种偏差：「旧句子在新设计下成了假话」，但必须记账、并把新句子冻在判据里**。第一条实例是**空内容根**：旧实现 push `skills/ 下没有 SKILL.md`（**还会多报一条**「找不到首页」），新实现打「内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）」。**行为**（退 2、不吐产物）两边必须一致；**措辞**这处偏差由 `tools/blocks-fixtures.sh` **夹具四**冻住：整句逐字节断言 + 一条诱饵（**有内容的内容根不许出现这句**）+ 断言本条决定在 PLAN 里记着 | 实测（2026-10-06，干净克隆自查 + 静态审计）。理由：旧句把根名**写死**成 `skills/`，而内容根现在可配置（`--skills <目录>` / `SKILLPRESS_CORPUS`）—— 照抄旧句在新设计下就是**假话**；新句还交代了"目录是谁列举的"，更指得动路。⚠️ 这段还牵出下面那笔老账 |
| D23 | **判据的读数只在「干净克隆 + 现编」下算数**：新增 `tools/fresh-clone-check.sh`（把 HEAD 克隆到临时目录、**只带 tracked 文件**、现装依赖现编，再跑四条对账 + R9；带 `--selftest` 诱饵）。**本机绿不算数** | 实测两笔老账（2026-10-06）：① 四条对账判据要"编出来的 js"，而 `_build/` 不进版本库 ⇒ **干净克隆里全红**、本机一直绿（只因本机早编过）；② 更狠的一条：**已提交的引擎里根本没有**「图片 / 原始 HTML / 表格缺分隔行 / 围栏没闭合」这四条点名规矩 —— `parse_blocks(body)` 的签名里**没有 problems 参数**，移植时按我自己写的注释（"`dump-blocks` 的判据是逐字节一致 ⇒ 这条命令不用 problems"）把报错清单从 API 上摘了，而 `gen-file` 正需要它。**参数一摘，规矩就没了出口**：坏夹具上 `gen-file` 退出码 0、stdout 吐 4407 字节坏产物、stderr 全空 —— 正是旧实现刻意不做的「静默丢」。⚠️ 连带承认：`blocks-fixtures` **从出生那一刻（25046f6）起就是红的**，我上一轮报的"四条判据全绿"里那一条是**假绿** |

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


> ⚠️ `pack` / `attach` 现在是**核心需求**（D16：产品要做成通用的），不是「以后再说」。
1. **抽包**：把实例的 `app.mbt`（界面 + 状态机）搬进程序成一个 MoonBit 包，**数据类型的家一起搬**
   （`Home`/`Doc`/`Block`… 变成程序的公开契约，生成器只填值）；实例 `app.mbt` 缩到几行
   `@skillpress.site(...)`。顺带定"实例进不进 `moon.work`"。
2. **`pack`**：一组 skill → 便携目录（程序副本 + 生成的首页 skill）。
3. **`attach`**：挂进一个已有的 moobile 项目（写 `skills/` 骨架 + 实例 + npm scripts）。
4. **moobile 的 `--with <包或路径>` 钩子**：通用扩展点，skillpress 做第一个插件。
   ⚠️ 那条 CLI 面在 moobile 是**冻结**的（`bin/cli.js` 明说改前先看 `docs/design/SCAFFOLD.md` §3.8），
   所以要先写那边设计文档、再补它的门。
- **证明**：`moon check` 全绿 + `verify` 20/20（换实现不改行为）｜ **pack 出来的目录要在临时目录里
  真的能 `build` + `verify`**（"便携"的判据不是"文件拷过去了"）。

### P7 收尾
判据补齐（等 D8 解除）｜文档对齐（`SPEC.md` / 内容侧 `references/layout.md` / 两份 README）｜
发布前清单（包形态、副本新鲜度那条门）。

### P8 引擎迁到 MoonBit（D15）—— **还没动手，先落方案**

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
| 走哪条 | **js 是主路**（就那一个 `web-tree-sitter` 依赖，与现状一致；语法用我们自己 vendor 的 wasm）；native 记为备选 = "零 npm"那条，等上游修 |
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
| **native 还是 js** | native 要 C 工具链（本机有 MinGW `gcc` 15.1.0，**没有 `clang`**）；js 走的正是**同一个 `web-tree-sitter`**（等于没摆脱 npm） | P8.0 两条都试，按"能不能零 npm + 判据不掉"定 |
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
| tree-sitter 绑定 | `tonyfettes/tree_sitter@0.4.6`、`tonyfettes/tree_sitter_language@0.1.3`（官方另有 `moonbitlang/moonbit-tree-sitter`） | **js** target 上是 `await import("web-tree-sitter")`（跟今天我们用的**同一个 npm 包**）；**native** 上链 `tree-sitter.c`（`supported-targets: "+native"`） |
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

## 7. 发布清单（`moon publish` **之前**要过的）

> 这一节是"目标最后一步"的清单。⚠️ **发布是不可逆的对外动作** —— 走到这里要先停下来跟用户确认。

| # | 要过的 | 怎么证 |
|---|---|---|
| 1 | **`moon.mod` 的元数据齐全** | 实测：`readme` 与 `repository` **原先没设**，`moon package` 每次警告两行（2026-10-06 已补）。发布前再跑一次 `moon package --list`，警告应为 0 |
| 2 | **包内容复核** | `moon package --list`：要含 `engine/**`（含 `shell/`）、`skills/**`、规范与账本、`THIRD-PARTY-NOTICE.md`；**不该含** `tools/`、`_build/`、`.mooncakes/`、`skills.lock.json`（`.moonignore` 钉着） |
| 3 | **许可与署名** | `LICENSE`（Apache-2.0）+ `THIRD-PARTY-NOTICE.md`（随包分发的语法资产是 MIT / Apache-2.0 —— 这条是**发出去才有的义务**） |
| 4 | **判据全绿** | `tools/acceptance.sh`（A1/A2/A3）+ 四条对账判据 + `line-budget.sh` |
| 5 | **凭据** | `moon login`（**需要用户**）—— 到这一步先问 |
| 6 | 发布 | `moon publish` |
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
| **DG-CLI** | 未知子命令**新实现 `rc=0`**（旧 `rc=2` 且点名）；用法缺 `--repo/--skills/--app`、缺 pack/attach 的"还没做" | `cmd && next` 会把拼错的子命令**当成功** —— "退出码不对的门比没有门更糟" | P8.2 |
| **DG-check** | `--check` 全套 6 条（产物不存在 / 一致 / 不一致 / 第一处差异在第 N 行 …） | 判据侧有 `file-parity` 同语义替代，但**直接调引擎的人拿不到** | P8.2 |
| **DG-高亮指路** | 语法缺失时丢了「见程序根 `grammars/PROVENANCE.md` 的取法」，还多出 `ERR:` 前缀 | 撞上缺语法的人找不到取法 | P8.2 |
| **DG-audit** | 高亮的 audit 闸门整条未移植（**空集合必须红** / 召回率 ≥ 90% / 未上色 ≤ 40%） | `highlight-parity` 更强，但**旧 npm 侧一撤这道保护同时消失**；空集合上还能"两侧都空"地**假绿** | P8.2 |
| **DG-门整条** | `check.mjs` 的 27 条（G1–G4 / G7 / G8）未移植 | 门整体不存在：今天由旧 CLI 提供，**迁移完成那刻保险一起失效** | P8.2（`engine/gates/` 在做） |
| **DG-facts** | `docfacts.mjs` 8 条 | 按 D18 搬去内容仓，不在核心里 | 内容仓 |
| **DG-verify** | `verify-site.mjs` 7 条 + 22 条判据 label | 站点判据未移植 | P8.3 |
| **DG-首页标签** | 首页问题的标签口径：旧是 `relative(REPO, …)`（**随机器变**，实测能退化成带反斜杠的绝对路径），新固定 `skillpress/SKILL.md`；"找不到首页"那条还**删掉了**「便携目录由 pack 生成它；项目里也可以自己写一份」 | 标签固定是**被迫且应接受**的（跨机器稳定）；但被删掉的那句是**可行动信息**，属于新实现漏的 | P8.1 收尾 |
| **DG-提示走 stderr** | 纯链接节提示「（…还带着 N 块正文…）」文本逐字节一致，但**流向 stdout → stderr** | 方向是被迫的（`gen-file` 的 stdout 必须是产物），但**用户可见行为变了**，得登记 | 已登记，待补断言 |

**另外两笔不是欠账、是账本外的漏洞（`tools/diagnostics-ledger.sh` 管不到，另记在这里）：**

1. 🔴 **`acceptance.sh` 的 A3 跑的是旧 CLI**（`bin/skillpress.mjs press --check`）⇒ 迁移一完成，A3 对新引擎**什么都证明不了**（假绿）。
   修法：A3 直接吃 `node tools/run-js.mjs gen-file <内容根>` 与 `tools/baseline/` 的对账（即把 `file-parity` 拉进验收）。
2. 🟠 **`file-parity.sh` 的 `EXPECTED.sha256` 缺失时会被静默跳过**（那段是 `if [ -f "$EXPECTED_SHA_FILE" ]`）⇒
   删掉那个文件就等于关掉"防基线被静默刷新"这道锁。修法：文件缺失直接判红（**不许有静默后门**）。
