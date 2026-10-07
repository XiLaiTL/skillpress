#!/usr/bin/env bash
# blocks-fixtures.sh —— **夹具对账**：拿一组「刁钻但合法」的 markdown 当内容源，
# 再拿新实现（`engine/content`）的读数与**入库的 golden**逐字节对账。
#
# ⚠️ 2026-10-07（PLAN 的 D43）：参照物从「现场跑冻结的旧生成器」换成了入库 golden
#    —— 旧生成器随 `lib/` 一起退役了。期望值在 `tools/fixtures/expected/`覆盖的是
#    「both 个引擎都同意」的那份产物（换之前这条判据已经在它上报过一次绿）。
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
EXPECT=tools/fixtures/expected
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

# ── 新引擎现跑 → 与**入库 golden** 逐字节比 ────────────────────────────
# ⚠️ 2026-10-07（PLAN D43）：参照物从「现场跑冻结的旧生成器」换成了**入库的 golden**（旧生成器随 `lib/` 一起退役）。
#    golden 里那份期望是**两个引擎都同意**的那份产物（换之前这条判据已经在它上报过一次绿）。
node tools/run-js.mjs dump-blocks "$W/root" > "$W/new.raw.txt" 2>&1 || {
  echo "✗ 新实现跑失败："; tail -5 "$W/new.raw.txt"; exit 1;
}
# 形状守卫（不是装饰）：没有它，「引擎哪天改成吐旧形状」会让下面那条 diff 变成**恒真**。
if ! grep -q '@shell\.' "$W/new.raw.txt"; then
  echo "✗ 夹具一：新实现里没有 @shell. 前缀 —— 类型没搬进包（新形状没生效？）"; exit 1
fi
# 归一化（P6 的口径，三条规则）：只抹**形状差**（文件头注释 / 类型声明块 / `@shell.` 前缀）。
# ⚠️ golden 里存的就是**归一化之后**的那份（与这里同一条管道）—— 两边都过同一个归一化器，否则比的就不是同一件事。
bash tools/normalize-gen.sh "$W/new.raw.txt" > "$W/new.txt"

if diff -u "$EXPECT/blocks-fixtures.txt" "$W/new.txt" > "$W/diff.txt"; then
  # 诱饵：把产物改**一个字符**，这条 diff 必须红 —— 证明归一化没把判据吃空
  sed '0,/Txt("/s//Txt("诱/' "$W/new.txt" > "$W/new-decoy.txt"
  if diff -q "$EXPECT/blocks-fixtures.txt" "$W/new-decoy.txt" > /dev/null; then
    echo "✗ 夹具一（诱饵）：值改一个字符居然还判「一致」—— 归一化把这条判据吃空了"; exit 1
  fi
  docs=$(grep -c '^### ' "$W/new.txt")
  echo "✓ 夹具对账通过：$docs 段（含结尾标记）与入库 golden 逐字节一致（归一化后；诱饵已证会红）"
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

node tools/run-js.mjs gen-file "$W3" > "$W/new3.out" 2> "$W/new3.err"
new_rc=$?

fail=0
[ "$new_rc" = 2 ] || { echo "✗ 夹具三：退出码是 $new_rc（应当是 2）"; fail=1; }
[ ! -s "$W/new3.out" ] || { echo "✗ 夹具三：有问题却还往 stdout 吐了产物 —— 刻意不做的事"; fail=1; }
for kind in '不支持的构造（图片）' '不支持的构造（原始 HTML）' '表格缺分隔行' '代码块没闭合'; do
  grep -q "$kind" "$W/new3.err" || { echo "✗ 夹具三：没点名「$kind」（夹具没触发，或规矩漏了）"; fail=1; }
done
n_new=$(grep -c '✗' "$W/new3.err" || true)
[ "$n_new" = 5 ] || { echo "✗ 夹具三：点名条数 $n_new（应当是 5）"; fail=1; }
# ⚠️ stderr 里**现在还有信息行**（`· ` 开头）—— 例如 R2 要求的「首页源…」。这个夹具比的是**问题清单**
#    （点名逐字节一致），所以先把信息行滤掉再 diff —— 也别让「多打了一句实话」把这条判据弄红。
grep -v '^· ' "$W/new3.err" > "$W/new3.cmp"
if diff -u "$EXPECT/blocks-fixture3.err" "$W/new3.cmp" > "$W/diff3.txt"; then
  :
else
  echo "✗ 夹具三：诊断与入库 golden **不一致**（完整 diff 在 $W/diff3.txt）："
  head -30 "$W/diff3.txt" | sed 's/^/    /'
  fail=1
fi
if [ "$fail" = 0 ]; then
  echo "✓ 夹具三对账通过：4 类认不出的构造 $n_new 条点名，行号/措辞/顺序与入库 golden**逐字节一致**，且没吐产物"
else
  # 不早退：让夹具四照样出声 —— 红的地方要一次看全
  echo "✗ 夹具三**未通过**（仍然继续跑夹具四）"
fi

# ── 夹具四：**空内容根**（一份 SKILL.md 都没有）⇒ 退 2、不吐产物、措辞逐字节冻住 ─────────
#
# 为什么单列一段：这是本项目**唯一一条记账过的口径偏差**（PLAN 决定表 **D22**）。
#   旧实现：`skills/ 下没有 SKILL.md`，**还会多报一条**「找不到首页」（它接着往下读首页了）；
#   新实现：「内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）」。
# 偏差的理由（D22 里写着）：旧句把根名**写死**成 `skills/`，而内容根现在可配置
#   （`--skills <目录>` / `SKILLPRESS_CORPUS`）—— 照抄旧句在新设计下就成了**假话**。
# 这一段盯两件事：① 「行为」（**退 2 + 不吐产物**）不许漂；② 措辞**逐字节冻住**，改动即红。
#    （旧实现那一侧的断言已随 `lib/` 退役；「旧句」本身仍留在 D22 的记账里作为出处。）
# 诱饵：再跑一次**有内容**的内容根，断言那句话**不出现** —— 证明它不是"永远都打"。
W4="$W/empty-corpus"
mkdir -p "$W4/empty" "$W4/app4"
node tools/run-js.mjs gen-file "$W4/empty" > "$W4/new4.out" 2> "$W4/new4.err"
new4_rc=$?
node tools/run-js.mjs gen-file "$W/root" > "$W4/new4b.out" 2> "$W4/new4b.err"

f4=0
[ "$new4_rc" = 2 ] || { echo "✗ 夹具四：新实现退出码是 $new4_rc（应当是 2）"; f4=1; }
[ ! -s "$W4/new4.out" ] ||
  { echo "✗ 夹具四：新实现有问题却还往 stdout 吐了产物 —— 正是旧实现刻意不做的事"; f4=1; }
frozen4='✗ 内容根下没有带 SKILL.md 的目录（引导层按 `gen-file <内容根>` 列举，检查那个参数）'
grep -qxF "$frozen4" "$W4/new4.err" || {
  echo "✗ 夹具四：新实现的措辞与 D22 冻住的那句**不一致** —— 要么改了话（那就同步改 D22 + 本判据），要么这条规矩整个丢了："
  echo "      期望：$frozen4"
  sed 's/^/      实际：/' "$W4/new4.err" | head -5
  f4=1
}
if grep -q '没有带 SKILL.md 的目录' "$W4/new4b.err"; then
  echo "✗ 夹具四（诱饵）：内容根里**有** SKILL.md，居然也打了这句 ⇒ 这句话不是『只在空内容根时』才打的"
  f4=1
fi
grep -q 'D22' PLAN.md || {
  echo "✗ 夹具四：这条口径偏差没记账 —— PLAN 决定表里补 D22（豁免必须写在文档里）"; f4=1;
}

if [ "$f4" = 0 ]; then
  echo "✓ 夹具四对账通过：空内容根退 2、不吐产物；措辞与 D22 记账的那句**逐字节一致**，且有内容的内容根不会打这句"
else
  echo "✗ 夹具四**未通过**"
fi
# 夹具四自己的失败并进总账（f4 与 fail 分开是刻意的：夹具三留下的 fail 不该让夹具四**看起来也红了**）
[ "$f4" = 0 ] || fail=1

if [ "$fail" != 0 ]; then
  echo
  echo "✗ 夹具对账：上面有红 —— 修完再看一遍，别拿部分绿当绿"
  exit 1
fi
