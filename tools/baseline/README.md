# `tools/baseline/` —— 旧形状生成物的**冻结基线**（P6 起）

这里只有一样东西：

```
tools/baseline/content/content.generated.mbt   ← 旧引擎（lib/gen-content.mjs）印出来的那份
tools/baseline/EXPECTED.sha256                 ← 上者的 sha256（钉住它，防"静默换基线"）
tools/baseline/dom-before-p6.html              ← P6 **搬界面之前**那份站点渲染出来的 DOM（一次性证据，见文末）
```

## 它是什么、为什么在这里

P6 把 `Span` / `Block` / `Kid` / `Doc` / `NavItem` / `Section` / `Home` 这 7 个类型
从**生成物**搬进了包 `shell` —— 生成物换了形状（值带 `@shell.` 前缀、签名带包前缀、文件头不再声明类型）。
**映射本身没变**，但"逐字节比对旧产物"这条判据从此比不出东西了。

于是把**旧形状**的那份产物挪到这里当作**真相**（它由**旧引擎**印出来，是 3412 行 Node 实现干出来的东西）：

* `tools/file-parity.sh` 拿**新引擎**的产物与它比 —— 经过 `tools/normalize-gen.mjs` 归一化
  （只抹形状差：去头注释 / 去类型声明块 / 去 `@shell.` 前缀），然后**逐字节**比。
* 那份基线自己也被三道判据钉着：**是旧形状**（含类型声明、无 `@shell.`）、**sha256 与
  `EXPECTED.sha256` 一致**、以及（在 `acceptance.sh` 的 A3 里）**能被旧引擎现场重印出来**。
  没有这三道，"基线被新引擎覆盖/被手改"会让 diff 变成恒真，判据就废了。

## 刷新（**只能在内容源真的改了之后做，而且只能用旧引擎**）

```bash
# ① 用**旧引擎**按当前内容源重印基线（程序根跑；内容仓与程序是兄弟）
SKILLPRESS_APP_DIR="$(pwd -W)/tools/baseline" node bin/skillpress.mjs press

# ② 立刻复核：旧引擎说"与磁盘一致"（= 刚才那次重印就是它的产物，不是手抄的）
SKILLPRESS_APP_DIR="$(pwd -W)/tools/baseline" node bin/skillpress.mjs press --check

# ③ 更新钉住的 sha256
sha256sum tools/baseline/content/content.generated.mbt > tools/baseline/EXPECTED.sha256

# ④ 对账必须仍然绿（形状差被归一化吃掉）
SKILLPRESS_CORPUS=../moobile/skills bash tools/file-parity.sh
```

⚠️ **不许用新引擎（`cmd/skillpress gen-file`）刷这个文件**：那样基线与被测对象就成了同一份东西，
`file-parity` 变成恒真 —— 判据里那条"基线里没有 `@shell.`"就是专门拦这个的。

## 什么时候该刷

内容源（`skills/**`、首页那份 `SKILL.md`…）**有意**改动之后。`press --check` 会先红给你看，
红本身就是提醒："你改了内容，基线得跟着刷，而且要刷得明明白白"。

## 2026-10-06（P6）冻结时的读数

| 项 | 值 |
|---|---|
| 行数 | 1143 |
| sha256 | `4fd41b3c2968411ad7e3ca8d7925a10ddc92670cfd03cbdbea6cf18ef0e27cc8` |
| 与实例里那份（当时还是旧形状）对比 | 逐字节相同 |
| 旧引擎现场重印对比 | 逐字节相同（`press` 之后 `diff` 无输出） |

## ★ `dom-before-p6.html`：搬界面之前的渲染（**一次性证据，不是判据**）

P6 把实例的 `app.mbt`（1062 行界面）机械切进了包 `shell/`。切完之后**两边都编得过**这件事
**不构成证据** —— 少画一个块、下拉菜单少一条、块的顺序换一下，编译器一声不响。
所以搬之前用真 Chrome 抓了一份渲染后的 DOM（`tools/dom-dump.mjs`，`--repeat 2` 先自证仪器稳定）：

| 项 | 值 |
|---|---|
| 抓取时 bundle.js 的 sha256 | `c4ddc8d7d58d38d5752efcad5cad13b598d90bee5120afcc0f701c69ac83f7b5` |
| 这份 DOM 的 sha256 | `8e851d3fc0acc613cea28f3a56a4527ef45006e0b770731ab7683783a8cf9035` |
| 大小 | 22061 字节（21142 个 JS 字符） |

搬完之后（期间 bundle 的 sha256 换了三次：`07450605…` → `89ebb71a…` → 之后的清理版）：
**DOM 逐字节相同**，且真浏览器判据 `verify` **22/22**。

复核方式（内容源**有意**改动之后这条会合法地不匹配 —— 那时重抓一份覆盖它即可）：

```bash
node tools/dom-dump.mjs --app <实例目录> --out /tmp/now.html --repeat 2
diff tools/baseline/dom-before-p6.html /tmp/now.html    # 现在的站点应该仍与它逐字节相同
```

