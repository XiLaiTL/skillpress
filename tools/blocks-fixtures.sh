#!/usr/bin/env bash
# blocks-fixtures.sh —— **夹具对账**：拿一组"刁钻但合法"的 markdown 当内容源，
# 用**旧生成器**现场产出基准，再拿新实现（`engine/content`）与它逐字节对账。
#
#   bash tools/blocks-fixtures.sh
#
# 为什么在"7 份真实 skill 已经全绿"之外还要这一道：那 7 份**覆盖不到**一些边界，
# 而边界一旦写错是**静默的**（生成物看着正常，只是某处少一个字符）。这道判据现场就逮到过两个：
#   ① `/^https?:/i` 写成了 `has_prefix("http:")` ⇒ `https://…` 被当站内链接、拆成两个片段；
#   ② 链接 label 去反引号**不是全局**（MoonBit 的 `String::replace` 只换第一处）⇒ label 里留一个 `。
#
# ⚠️ 它**不碰** `../moobile/**`：夹具与旧生成器的产物都建在 `_build/fixtures/`（gitignore 的）里。
set -u
cd "$(dirname "$0")/.."

# 前置：确保 CLI 的 js 产物新鲜（干净克隆里 _build 不存在 —— 实测过）
source tools/_ensure-built.sh

W=./_build/fixtures
rm -rf "$W"
mkdir -p "$W/root/alpha/references" "$W/root/beta" "$W/root/skillpress" "$W/app"

# ── 夹具一：行内与列表的刁钻处 ──────────────────────────────────────────────
cat > "$W/root/skillpress/SKILL.md" <<'MD'
---
name: skillpress
description: 首页
whenToUse: 测试
---

# 站名

首页引言。

## 一栏

正文。
MD

cat > "$W/root/alpha/SKILL.md" <<'MD'
---
name: alpha
description: 夹具一：行内与列表的刁钻处
whenToUse: 测试
---

# 夹具一

段落里有 `code`、**bold**、[label](references/x.md)、[same](same)、[ext](https://a.b)、
[`Code`](references/x.md) 与 [`a` 和 `b`](references/x.md)（多反引号标签——测 replace 是否全局）。

连续空白   会被压成一个空格，反斜杠 \ 与引号 " 要转义，tab 在下面：
带	tab 的一行。

#### 四级标题

##### 五级标题会退化成段落

## [纯链接节](references/x.md)

## 列表

- 顶格一项
  - 缩进两项（indent=1）
* 星号项
1. 有序第一
2. 有序第二
3) 括号序号（num 也写 `. `）
10. 两位数

表格：

| 线 | 错了会怎样 | 细则 |
|---|---|---|
| 空单元格 |  | `x` |
|  两侧有空格  | **粗** | [链接](same) |

> 引用第一行
> 引用第二行

---

```bash
echo "hi"
```

```
没有语言标记的块
```

```
```
MD

# ── 夹具二：中文、奇怪空白、以及"会被跳过"的构造 ─────────────────────────────
cat > "$W/root/beta/SKILL.md" <<'MD'
---
name: beta
description: 夹具二：中文与奇怪空白
whenToUse: 测试
---

# 夹具二

中文段落：这里有一个不断行空格（NBSP）和 emoji 🚀，以及全角标点：，。！

图片会被跳过：![图](x.png)

原始 HTML 也会被跳过：<div>hi</div>

一个没有语言标记的块，与一个空块：

```
无标记
```

```
```
MD

# ── 旧生成器现场产出基准（写进临时 app）──────────────────────────────────────
node lib/gen-content.mjs --skills "$W/root" --app "$W/app" > "$W/gen.log" 2>&1 || {
  echo "✗ 旧生成器跑失败（$W/gen.log）："; tail -5 "$W/gen.log"; exit 1;
}
node tools/spike/old-doc-blocks.mjs "$W/app/content/content.generated.mbt" > "$W/base.txt" || {
  echo "✗ 基准切不出来"; exit 1;
}
node tools/run-js.mjs dump-blocks "$W/root" > "$W/new.txt" 2>&1 || {
  echo "✗ 新实现跑失败："; tail -5 "$W/new.txt"; exit 1;
}

if diff -u "$W/base.txt" "$W/new.txt" > "$W/diff.txt"; then
  docs=$(grep -c '^### ' "$W/new.txt")
  echo "✓ 夹具对账通过：$docs 段（含结尾标记）与**旧生成器现场产出**的基准逐字节一致"
else
  echo "✗ 夹具对账不一致（完整 diff 在 $W/diff.txt）："
  head -30 "$W/diff.txt" | sed 's/^/    /'
  exit 1
fi

# ── 夹具三：**认不出的构造** ⇒ 两边都点名、都退 2、都**不写产物** ─────────────
#
# 为什么单独一段：夹具二里那句"会被跳过"其实**没生效** —— 图片与 `<div>` 都写在行中间，
# 旧实现那两条判据（`/^!\[/`、`/^</`）打在**行首**，于是它们只是普通段落文字。
# 真正的"跳过"（行首图片 / 行首原始 HTML / 表格缺分隔行 / 围栏没闭合）一条都没被覆盖过。
#
# 这一段对的是**诊断**而不是生成物，因为旧实现在有问题时**根本不写产物**（那个 `writeFileSync`
# 在 `else` 分支里）。所以这四条一起判：两边的退出码、旧实现没落盘、新实现 stdout 为空、
# 以及 stderr **逐字节一致**（行号、措辞、顺序都算）。
W3="$W/root3"
mkdir -p "$W3/bad/references" "$W3/skillpress" "$W/app3"
cat > "$W3/skillpress/SKILL.md" <<'MD'
---
name: skillpress
description: 首页（这一段刻意保持干净：两边对"首页问题"的标签写法不同，别混进对账）
whenToUse: 测试
---

# 站名

首页引言。

## 一栏

正文。
MD
cat > "$W3/bad/SKILL.md" <<'MD'
---
name: bad
description: 夹具三：认不出的构造要点名
whenToUse: 测试
---

# 夹具三

![行首图片](x.png)

<div>行首原始 HTML</div>

| a | b |
| c | d |

```bash
echo 这个围栏没闭合
MD
cat > "$W3/bad/references/sub.md" <<'MD'
---
title: 子页
---

# 子页

![子页里的图片](y.png)

正文。
MD

SKILLPRESS_SKILLS="$W3" node lib/gen-content.mjs --skills "$W3" --app "$W/app3" > "$W/old3.out" 2> "$W/old3.err"
old_rc=$?
node tools/run-js.mjs gen-file "$W3" > "$W/new3.out" 2> "$W/new3.err"
new_rc=$?

fail=0
[ "$old_rc" = 2 ] || { echo "✗ 夹具三：旧实现退出码是 $old_rc（应当是 2）"; fail=1; }
[ "$new_rc" = 2 ] || { echo "✗ 夹具三：新实现退出码是 $new_rc（应当是 2）"; fail=1; }
[ ! -e "$W/app3/content/content.generated.mbt" ] || { echo "✗ 夹具三：旧实现竟然写了产物（基准本身就不该存在）"; fail=1; }
[ ! -s "$W/new3.out" ] || { echo "✗ 夹具三：新实现有问题却还往 stdout 吐了产物 —— 正是旧实现刻意不做的事"; fail=1; }
for kind in '不支持的构造（图片）' '不支持的构造（原始 HTML）' '表格缺分隔行' '代码块没闭合'; do
  grep -q "$kind" "$W/new3.err" || { echo "✗ 夹具三：新实现没点名「$kind」（夹具没触发，或规矩漏了）"; fail=1; }
done
n_old=$(grep -c '✗' "$W/old3.err" || true)
n_new=$(grep -c '✗' "$W/new3.err" || true)
[ "$n_old" = 5 ] && [ "$n_new" = 5 ] || { echo "✗ 夹具三：点名条数 旧=$n_old 新=$n_new（都应当是 5）"; fail=1; }
if diff -u "$W/old3.err" "$W/new3.err" > "$W/diff3.txt"; then
  :
else
  echo "✗ 夹具三：诊断**不一致**（完整 diff 在 $W/diff3.txt）："
  head -30 "$W/diff3.txt" | sed 's/^/    /'
  fail=1
fi
if [ "$fail" = 0 ]; then
  echo "✓ 夹具三对账通过：4 类认不出的构造 $n_new 条点名，行号/措辞/顺序与旧实现**逐字节一致**，且两边都没吐产物"
else
  # 不早退：让夹具四照样出声 —— 红的地方要一次看全，别让前一段把后一段的读数挡住
  echo "✗ 夹具三**未通过**（仍然继续跑夹具四）"
fi

# ── 夹具四：**空内容根**（一份 SKILL.md 都没有）⇒ 行为一致、措辞**故意**不一致 ─────
#
# 为什么单列一段：这是本项目**唯一一条记账过的口径偏差**（PLAN 决定表 **D22**）。
#   旧实现：`skills/ 下没有 SKILL.md`，**还会多报一条**「找不到首页」（它接着往下读首页了）；
#   新实现：「内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）」。
# 偏差的理由（D22 里写着）：旧句把根名**写死**成 `skills/`，而内容根现在可配置
#   （`--skills <目录>` / `SKILLPRESS_CORPUS`）—— 照抄旧句在新设计下就成了**假话**。
# 这一段盯两件事：① 「行为」（**退 2 + 不吐产物**）两边不许漂；② 新措辞**逐字节冻住**，改动即红。
# 诱饵：再跑一次**有内容**的内容根，断言那句话**不出现** —— 证明它不是"永远都打"。
W4="$W/empty-corpus"
mkdir -p "$W4/empty" "$W4/app4"
SKILLPRESS_SKILLS="$W4/empty" node lib/gen-content.mjs --skills "$W4/empty" --app "$W4/app4" > "$W4/old4.out" 2> "$W4/old4.err"
old4_rc=$?
node tools/run-js.mjs gen-file "$W4/empty" > "$W4/new4.out" 2> "$W4/new4.err"
new4_rc=$?
node tools/run-js.mjs gen-file "$W/root" > "$W4/new4b.out" 2> "$W4/new4b.err"

[ "$old4_rc" = 2 ] || { echo "✗ 夹具四：旧实现退出码是 $old4_rc（应当是 2）"; fail=1; }
grep -q 'skills/ 下没有 SKILL.md' "$W4/old4.err" ||
  { echo "✗ 夹具四：旧实现没点名「skills/ 下没有 SKILL.md」—— 这条偏差的『旧句』就是它，基准变了"; fail=1; }
[ ! -e "$W4/app4/content/content.generated.mbt" ] ||
  { echo "✗ 夹具四：旧实现竟然写了产物（基准本身就不该存在）"; fail=1; }
[ "$new4_rc" = 2 ] || { echo "✗ 夹具四：新实现退出码是 $new4_rc（应当是 2）"; fail=1; }
[ ! -s "$W4/new4.out" ] ||
  { echo "✗ 夹具四：新实现有问题却还往 stdout 吐了产物 —— 正是旧实现刻意不做的事"; fail=1; }
frozen4='✗ 内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）'
grep -qxF "$frozen4" "$W4/new4.err" || {
  echo "✗ 夹具四：新实现的措辞与 D22 冻住的那句**不一致** —— 要么改了话（那就同步改 D22 + 本判据），要么这条规矩整个丢了："
  echo "      期望：$frozen4"
  sed 's/^/      实际：/' "$W4/new4.err" | head -5
  fail=1
}
if grep -q '没有带 SKILL.md 的目录' "$W4/new4b.err"; then
  echo "✗ 夹具四（诱饵）：内容根里**有** SKILL.md，居然也打了这句 ⇒ 这句话不是『只在空内容根时』才打的"
  fail=1
fi
grep -q 'D22' PLAN.md || {
  echo "✗ 夹具四：这条口径偏差没记账 —— PLAN 决定表里补 D22（豁免必须写在文档里）"; fail=1;
}

if [ "$fail" = 0 ]; then
  echo "✓ 夹具四对账通过：空内容根两边都退 2、都不吐产物；新措辞与 D22 记账的那句**逐字节一致**，且有内容的内容根不会打这句"
else
  echo "✗ 夹具四**未通过**"
fi

if [ "$fail" != 0 ]; then
  echo
  echo "✗ 夹具对账：上面有红 —— 修完再看一遍，别拿部分绿当绿"
  exit 1
fi
