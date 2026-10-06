---
name: skillpress-dev
description: 改 skillpress 程序本身（引擎 / 三道门 / 上色 / 站点判据 / 规范与账本）：四个根在哪、改了什么跑哪条门、怎么加一条判据和它的诱饵、落锁的规矩、以及那些会安静咬人的坑。
whenToUse: 你要动 `lib/*.mjs`（内容管线 / 高亮 / check / docfacts / verify-site）、要加或改一道门的判据、动语法资产与 SPEC/SKILLS/DRIFT，或者遇到"门绿着，但它查的不是我以为的那份东西"这类症状。
---

# skillpress 开发者 —— 改这套程序

**一句话**：这台程序只守一条 —— **一个说谎的 skill 比没有 skill 更糟**。
门、规范、账本、判据全都是为这一条服务的；判断任何改动，先问"它让谎更难撒，还是更容易"。

## 一、先认清四个根（不认清就会改错文件）

| 根 | 在哪 | 谁说了算 |
|---|---|---|
| **程序** | 本仓库根（`interest/skillpress`） | `lib/roots.mjs` —— **唯一算法** |
| **仓库**（内容仓） | **旁边的** `../moobile/`；找不到才退回"程序往上 3 层" | 同上：`--repo` / `SKILLPRESS_REPO` |
| **内容** | `<内容仓>/skills` | 同上：`--skills` / `SKILLPRESS_SKILLS` |
| **实例** | `<内容>/skillpress/scripts/.skillpress` | 同上：`--app` / `SKILLPRESS_APP_DIR` |

⚠️ **不猜是刻意的**：猜错的表现是"站点没更新"—— 页面照常渲染，只是旧内容，最难查的一类症状。
别再手写"往上几层"：那四条路径原先在 5 个文件里各写一遍，家规改一次要改五处。

## 二、改了什么 → 跑什么（都在**程序根**跑）

```bash
node bin/skillpress.mjs check             # 门：skill 自己（G1–G8）
node bin/skillpress.mjs check --selftest  # 证伪：诱饵必须全被点名
node bin/skillpress.mjs press --check     # 生成物与源一致吗
node bin/skillpress.mjs facts             # 事实来源对账（docs 有没有撒谎）
node bin/skillpress.mjs audit             # 上色的闸门（召回率 / 漏色比例）
node bin/skillpress.mjs verify            # 站点判据：真 Chrome 无头 + CDP 真鼠标
```

> 在**内容仓根**跑同一份程序就多一层：`node ../skillpress/bin/skillpress.mjs …`。

| 动了什么 | 必须跟着跑 |
|---|---|
| `lib/check.mjs` 的判据 | `check --selftest` —— **新判据必须配诱饵**，否则等于没加 |
| `lib/gen-content.mjs` / `lib/highlight.mjs` | `press` → `press --check`；上色的改动还要 `audit` |
| `lib/verify-site.mjs`（站点判据） | `verify`；加断言照它文件头那张表写（每条抓哪个失败模式） |
| `lib/docfacts.mjs` | `facts` |
| `grammars/**` | `audit` + 更新 `grammars/PROVENANCE.md` 的 sha256 |
| 内容源（在**内容仓**） | `check` → 复核体量 → `check --update-lock <名字>` → `press` |
| `SPEC.md` / `SKILLS.md` / `DRIFT.md` | 查有没有被引用的路径与 `§` 号（G3 / G6）—— **改引用，别改判据** |

## 三、三条不许破的规矩

1. **不许为了让谁变绿而放宽断言**。放宽 = 把 bug 藏起来；非放宽不可，注释里要写清为什么。
2. **落锁不是让门变绿的手段**。`--update-lock` 的含义是"我**看过**这次体量变化"；
   而且只锁一个（`--update-lock <名字>`）—— 整文件重写会把别人正在改的那份指纹一起锁掉。
3. **空集合不算通过**。一个块都没数到时 `NaN < 阈值` 是 false ⇒ 会假绿；
   出口一律 `process.exitCode`，别调 `process.exit()`。

判据逐条（G1–G8）、怎么加一条新规则、诱饵的形状 —— 见 `references/gates.md`。

## 四、坑（都是踩出来的）

| 现象 | 真因 | 处置 |
|---|---|---|
| 门绿着，但它查的不是那份东西 | 除 `roots.mjs` 外的"往上几层"都是漂移点（曾实测 `check` 报「moobile 根：`D:\`」、遍历整个盘） | 只用 `roots.mjs` |
| 内容里讲程序的指针"查过了" | 其实是**静默不查**：第二个根曾与第一个重复，且 `bin`/`lib`/`grammars` 不在 G3 白名单 | 现已修：第二个根 = 程序根 + 三个目录进白名单 + 诱饵 `bad-program-path` |
| 某条判据"永远绿" | 口径太松（整页子串 / 合成 `click()` / 写死端口） | 与同一次运行里的另一处口径对齐；**总数也是读数**（少验了长得像验过了） |
| 某个语言上色突然少一大片 | tree-sitter 的 `Parser` **有状态**：最后装载的语言污染之后所有解析 | 每种语言一个 `Parser` |
| `press` 跑完站点还是旧的 | 生成物没重跑，或者 `dist/` 是缓存 | `press --check`；实在怪就删 `dist/` 重编 |
| frontmatter 静默失效 | 文件是 CRLF（`(.*)$` 匹配不到行尾 `\r`） | 一律 LF（`.gitattributes` 钉着，G2 也拦） |
| 改完程序，内容侧报"某路径不存在" | G3 的候选根只有三个（内容仓根 / 程序根 / 那个 skill 自己的目录） | 指针写清是相对哪个根 |

## 五、程序自己的 skill 住哪儿（这份就在这儿）

程序自己的 skill 住在 **本仓库的 `skills/`** —— 给**用这个仓库的人**看的那份（用它的人 + 改它的人）。

⚠️ **两个 `skills/`，别混**：内容仓（`../moobile/`）里那个也在同一个位置、同一个名字，
但它是**内容**（会被印成站点、给别人看的那份）。分得清它们的只有**仓库**，不是目录名 ——
所以指向内容的地方一律写全 `<内容仓>/skills/…`，别只写 `skills/…`。

⚠️ 与老约定的一处差别：内容根原先是 **`.agents` 下的 `skills`**（**harness 的项目扫描根**，rank 200），
搬到 `skills/` 之后 harness **不再自动加载**它们（`skills/` 不在 DSH 的扫描根里）。
要恢复"agent 一进仓库就带 7 份 skill"，得配 DSH 的 `customSkillDirs`（本机全局设置）——
**别两边各放一份**：两份内容就是两份会漂的真相。

⚠️ 这不是风格问题：`skills/` 的形状和内容根**一模一样**（`skills/<名字>/SKILL.md`），
所以将来把程序自己的 skill 印成站点（自举）时，它天然就是那个内容根。

跑门时**显式指这个根**（默认那个根是内容仓的）：

```bash
node bin/skillpress.mjs check --skills skills
```

落锁同样认这个根，而且 `--update-lock` **出现在哪儿都认**（曾经它必须正好是第一个参数，
于是 `check --skills <根> --update-lock` 会**静默变成一次普通检查** —— 你以为落了锁，
其实什么都没发生）：

```bash
node bin/skillpress.mjs check --skills skills --update-lock
```

`skills.lock.json` 仍然**只有一份**（跟着程序走 = 它是机制的契约），但每条指纹都记着
**它属于哪个内容根** ⇒ 查 A 根不会把 B 根的条目报成"已删除的 skill"。

⚠️ **还没自举**（诚实清单）：`press` 只往内容仓那个实例写，所以 `skills/` 里的这两份
暂时**上不了站点**（自举 = 程序自己也有实例，是下一步）。

## 六、诚实清单（现状，别写成"已支持"）

- **还没发布**：靠源码路径调用（`node bin/skillpress.mjs …`）；发 npm / moonbit 包在 `PLAN.md` 里。
- `pack` / `attach` **还没做**：命令存在，但会明说"还没做"并非零退出（不做"看着像跑了"的假动作）。
- 界面**还没抽成 `shell` 包**：整套界面住在内容侧的实例 `app.mbt` 里，实例与程序之间隔着一份界面代码。

## 七、指针

| 要什么 | 去哪 |
|---|---|
| 判据逐条（G1–G8）、加一条规则的形状、诱饵怎么写 | `references/gates.md` |
| 内容管线内部（数据形状、解析边界、两种模式、上色、站点判据） | `references/pipeline.md` |
| 四个根的算法、两种布局、程序为什么在仓库外 | `references/roots.md` |
| 投影规范（收录判据 / 结构 / 预算 / 站点边界） | `SPEC.md`（§2 / §3 / §6 / §8） |
| 集合划分、产出顺序 | `SKILLS.md` |
| 漂移账本的方法、政策与已知边界 | `DRIFT.md` |
| 禁语表 / 已落地台账 / 体量指纹 | `claims.txt` ｜ `done-claims.txt` ｜ `skills.lock.json` |
| 计划与未做（会变，别当契约） | `PLAN.md` |
| 用**这套工具**做站点那一侧 | 另一份 skill：`skillpress-user` |
| 内容仓的现状与已踩的坑（**唯一来源**，别抄数字） | `../moobile/docs/STATUS.md` ｜ `../moobile/docs/FINDINGS.md` |
