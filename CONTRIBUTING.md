# CONTRIBUTING —— 改 skillpress 本身

想**用**它做站点的话，读 [`README.md`](README.md) 与
[`skills/skillpress-user/SKILL.md`](skills/skillpress-user/SKILL.md)。
这份是给**改程序**的人看的：引擎、界面、门、判据、发版。
程序侧的规程另有一份随包发的 skill：[`skills/skillpress-dev/SKILL.md`](skills/skillpress-dev/SKILL.md)
（四个根、门、站点管线、改什么跑什么）—— 细节以那三份 `references/` 为准，这份不抄第二遍。

## 0. 先认识这份仓库的黑话

| 词 | 意思 |
|---|---|
| **门** | 一道**能变红**的校验：内容门 `check`（G1–G8）、两道形状不同的门见 [`skills/skillpress-dev/references/gates.md`](skills/skillpress-dev/references/gates.md) |
| **判据** | 一条会打印 ✓/✗ 的断言。"产物是文字，编译器不报"的那些事实，全靠它 |
| **红** | 失败。判据红了要修**被量的东西**，不是放宽判据 |
| **点名** | 报错时指出是哪一条、哪个文件、哪一处差异（不许静默吞掉） |
| **退 2** | 用退出码 2 表示"用法错 / 内容解不开"，且**一个字节的产物都不吐** |
| **收录 / 上桌** | 进书架。没收录的写在 `skillpress.ignore.md` 里，**每条都要理由** |
| **诱饵** | 造一个"必须红"的输入，证明判据不是永远绿（`--selftest`） |
| **实例** | 一个"用 skillpress"的站点工程（生成物），不是本程序 |

## 1. 六条设计原则

**① 前提是"文档会变成 skill"，所以真源只能是 skill 本身。**
不做 CMS、不做"再写一套给人看的页面"。站点是那批 skill 的**一种排法**，不是第二份内容：
删掉站点不丢任何东西，改内容也永远只改一处。谁要是把站点当成真源，这份前提就已经破了。

**② 人机共读 = 两个出口同源，而不是各读一份。**
站点 / `llms.txt` / `md/**`（每页原文）出自**同一次解析**；书架树与右栏目录也在构建期从同一批内容算出来。
于是"agent 读到的"和"人看到的"结构上不可能对不上 —— 不是靠纪律对齐，而是**没有第二处可漂**。

**③ 内容源必须是标准 markdown，一个字节都不改。**
一旦为了站点发明语法（`:::tip`、站点专用的 frontmatter），就等于承认"给人看的那份要特殊"——
那就又回到两份源了。所以宁可不支持某个效果（行内图片、`*斜体*` 到今天都没做），
也不往内容里加站点才懂的东西。同一份 md 在 GitHub 上、在编辑器里、在 agent 手里都还是它自己。

**④ 人机共读的东西不能悄悄漂 —— 所以判据要能自己变红。**
每条"应该成立的事"都写成一条能变红的判据，而且让判据**自己也被验过**（造一个必须红的诱饵）。
仓库里判据比功能代码还多，是刻意的。

**⑤ 不画点了没反应的东西，不静默吞东西。**
书架每一行、首页每一格都真的能到某处；算不出目标就**不画那一格**（画一个灰箭头等于骗读者）。
认不出的内容构造**点名报错**；拼错的子命令**点名 + 退 2**。

**⑥ 界面住在包里，站点工程只接线。**
生成的 `app.mbt` 只有 19 行（把内容包交给 `@shell.site`）。于是升级 skillpress = **所有站点一起升级**。

## 2. 五条设计取舍

1. **只做投影，不做 CMS** —— 内容源是唯一真源，站点是产物，删了能重印。
2. **构建期能算的就不放到运行期** —— 高亮、目录锚点、页序都在 `press` / `build` 里算完
   （唯一例外是搜索索引：渲染期现算，构建期索引还没做）。
3. **一个事实一个副本** —— 三件产物同源；同一件事要是有两份实现，迟早分叉。
4. **判据是进程边界，不是仓库内外** —— 纯文本变换写成 `.mbtx`，碰进程的（起服务、开 Chrome）留 `.mjs`。
5. **不静默** —— 认不出的构造点名、产物不一致指出第一处差异、找不到程序根直接报错不猜。

## 3. 三个根（改东西之前先认清）

| 根 | 是什么 | 在哪儿 |
|---|---|---|
| **程序** | 引擎 + 站点界面 + 语法资产（能发布的那份） | 本仓库根；用户那边是 `.mooncakes/XiLaiTL/skillpress` |
| **内容** | 那批 skill（`SKILL.md` + `references/`） | `--skills` 指定；生成出来的实例里**已经写死**在 `npm run press` 里 |
| **实例** | 一个「用程序」的 MoonBit 工程，`content/` 是生成物 | `<内容根>/skillpress/scripts/.skillpress/` |

四项（含"仓库"这一根）的定位算法、两种布局、以及"为什么不猜"：
[`skills/skillpress-dev/references/roots.md`](skills/skillpress-dev/references/roots.md)。
⚠️ 这四个根**只有一处实现**（`cmd/skillpress/cli/args.mbt` + `engine/site/entry.mbt`）—— 别在别处再算一遍。

## 4. 改什么 → 跑什么

| 动了什么 | 必须跟着跑 |
|---|---|
| `engine/gates/` | `moon test engine/gates`（新判据**必须配诱饵**，否则等于没加） |
| `engine/content/` `engine/highlight/` | `bash tools/engine-fixtures.sh`（与入库 golden 逐字节对账；有意的变化 `--capture` 重采）+ `node tools/run-js.mjs audit` |
| `engine/site/**`（站点判据本体） | `bash tools/verify.sh`（23 条，真 Chrome）；加断言照 `engine/site/checks.mbt` 那张表写 |
| `engine/scaffold/**` `template/instance/**` `cmd/skillpress/cli/attach.mbt` | `bash tools/attach-check.sh`；模板动了要重生成自举实例：`node tools/run-js.mjs attach --repo . --skills skills --force` |
| `shell/**`（界面） | `bash tools/theme-check.sh` + `bash tools/verify.sh` + 重拍 `assets/*.png`（见 §7） |
| native 那一侧（`vendor/**`、`*.native.mbt`、`cmd/skillpress-native/**`） | `bash tools/native-parity.sh`（native 与 js 的产物**逐字节一致**） |
| `SPEC.md` `SKILLS.md` 里的引用 | `check` 的 G3 / G6（**改引用，别改判据**） |
| 内容源（在内容仓那边） | `check` → 复核体量 → `check --update-lock <名字>` → `press` |

## 5. 发版判据（一条都不能少跑）

```bash
SKILLPRESS_CORPUS=<内容仓>/skills bash tools/acceptance.sh          # A1/A2/A3 落到一条命令
SKILLPRESS_CORPUS=<内容仓>/skills bash tools/acceptance.sh --build  # 顺带重建实例（慢）
bash tools/fresh-clone-check.sh                                     # 干净克隆 + 现编，也是这些读数
```

⚠️ `moon package` / `moon check` 那几条读数**只在"本模块没人在改"时可信**（有人在改时它会报一堆
"别人的半成品"错误，看着像包坏了）。

| 判据 | 钉住什么 |
|---|---|
| `acceptance.sh` | 目标的验收（A1 装得下 / A2 实例合规 / A3 真站点），带 `--selftest` 证伪 |
| `verify.sh` | 站点判据的**壳**，真实现是 `skillpress-native verify`（23 条，真 Chrome + CDP） |
| `engine-fixtures.sh` | 引擎在冻结语料上的读数 == 入库 golden（逐字节） |
| `blocks-fixtures.sh` | 一组"刁钻但合法"的 markdown 与入库 golden 对账 |
| `site-source.sh` | 首页源的回退链（R2）与忽略清单（R4） |
| `attach-check.sh` | 脚手架：产物齐全 + 幂等 + 不覆盖手写 + 坏输入不落盘 |
| `native-parity.sh` | native CLI 与 js CLI 在同一语料上产物逐字节一致 |
| `package-check.sh` | `moon package --list`：该含的都在、不该含的一个都没有（三向诱饵） |
| `consumer-check.sh` | 从 zip 出发、**一个 npm 依赖都不装**，用包里的启动器跑 `check` / `gen-file` |
| `published-check.sh` | 发布后：从 registry 装下来，在**另一个工程**里编过 |
| `fresh-clone-check.sh` | 只有 tracked 文件的干净克隆里，上面这些读数不变 |
| `line-budget.sh` | 每个源文件 ≤ 400 行（含注释） |
| `shell-traps.sh` | 双引号里的反引号会**真的执行** —— 这类坑位 |
| `mbt-traps.sh` | MoonBit 侧会安静咬人的坑（第一条：`Array::sort()` 不是字典序） |
| `queries-check.sh` | 内嵌 query 与 `grammars/*.scm` 逐字节同源 |
| `diagnostics-ledger.sh` | 旧实现里每条"给人看的诊断"要么有对应物、要么记成欠账，**不许无声蒸发** |
| `theme-check.sh` | 主题那四条判据（明/暗/跟随系统 × 三档） |
| `agent-exports.sh` | Agent 出口：`llms.txt` + 每页原文 `md/**` |
| `check-links.py` | 文档链接点得动；且**不许出现跳出本仓的相对链接**（README 同时是 mooncakes 上的门面） |

发布流程与凭据那几步在 [`PLAN.md`](PLAN.md) §7「发布清单」。

## 6. CLI 全表与退出码契约

**同一个 CLI，两个入口**（逻辑一份在 `cmd/skillpress/cli/`，只是宿主不同）：

| 入口 | 怎么调 | 要什么 | 多什么 |
|---|---|---|---|
| **js**（日常） | `node <包>/launcher/skillpress.mjs <命令> …`；本仓开发期是 `node tools/run-js.mjs <命令>` | Node ≥ 20 + 编一次的 js 产物 | —— |
| **native**（判据 / 零 Node） | `moon install ./cmd/skillpress-native --bin <目录>` ⇒ 跑 `skillpress-native <命令>` | 一次 C 工具链 | **`verify`**（站点判据 23 条）与 `dump-corpus` |

| 子命令 | 干什么 | 关键参数 |
|---|---|---|
| `check` | 内容门 **G1–G8**（引用路径、frontmatter、体量、禁语、锁……） | `--repo` `--skills` `--program` `--update-lock [名字]` `--ignore` |
| `gen-file <内容根>` | 内容包 → **stdout** | `--llms`（改吐 `llms.txt`）`--home` `--ignore` `--license` `--asset-base` |
| `attach` | 生成/更新**站点工程**（渲染模板 + 改写首页 + 拼忽略清单） | `--repo` `--skills` `--ignore <名>=<理由>` `--force` `--program` `--host-dep` `--dry-run` `--interactive` |
| `dump-blocks <内容根>` | 调试：把解析出来的块逐个打出来 | —— |
| `hl <文件> <语言>` | 单文件高亮（看色号） | —— |
| `batch` | 全语料上色读数（按语言汇总） | `SKILLPRESS_CORPUS=<内容根>` |
| `audit [<内容根>]` | 上色**回归闸门**：召回率 ≥ 90%、未上色 ≤ 40% | —— |
| `gen-queries [--check]` | 把 `grammars/*.scm` 嵌进 MoonBit（native 那份要用） | `--check` |
| `verify` **（native）** | **站点判据**：自起服务 + 真 Chrome 无头 + 23 条断言 | `--skills` `--app` `--shot <png>` |
| `dump-corpus` **（native）** | 语料侧转储（对账 / 调试用） | `--skills` `--home` |
| `pack` | ❌ **还没做**（便携目录打包）：会说清 + 退 2 | —— |

**退出码是有约定的**（这条比"有没有这个命令"更重要 —— 拼错的命令返回 0 会被 `cmd1 && cmd2` 当成功）：

| 码 | 什么意思 |
|---|---|
| `0` | 通过；裸调用不带命令时也走这条（打用法给你看） |
| `1` | 门 / 判据**有红**（并列出是哪几条） |
| `2` | **用法错或内容有解不开的东西**：认不出的子命令（点名）、`pack` 还没做、内容根不存在、tree-sitter 没装好 —— 这些一律**不吐产物** |

## 7. 本地开发闭环

```bash
node tools/run-js.mjs check --repo . --skills ./skills   # 门：内容本身
node tools/run-js.mjs gen-file ./skills                  # 内容包 → stdout（可以直接看）
node tools/run-js.mjs attach --repo . --skills ./skills  # 生成/更新站点工程
bash tools/verify.sh                                     # 站点判据（要一次 native 编译）
```

**重拍 README 里那两张图**（`assets/site-doc.png` / `assets/site-home.png`）：图是事实，
界面一改它就过期了 —— 它拍的是自举实例，所以命令是：

```bash
cd skills/skillpress/scripts/.skillpress && npm run press && npm run build && node serve-web.mjs 8123 &
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --hide-scrollbars \
  --window-size=1440,1000 --virtual-time-budget=12000 \
  --screenshot=assets/site-doc.png "http://127.0.0.1:8123/#/s/skillpress-user/"
```

## 8. 许可与第三方

Apache-2.0，见 [`LICENSE`](LICENSE)。随包分发与编译期依赖的第三方清单在
[`THIRD-PARTY-NOTICE.md`](THIRD-PARTY-NOTICE.md)；语法资产的出处与 sha256 在
[`grammars/PROVENANCE.md`](grammars/PROVENANCE.md) 与两份 `vendor/*/PROVENANCE.md`。
**两个 tree-sitter 运行时（js 的 wasm 与 native 的 C）必须同版本** —— `native-parity.sh` 会自己核。
