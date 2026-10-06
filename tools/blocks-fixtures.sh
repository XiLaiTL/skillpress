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
if [ "$fail" != 0 ]; then
  exit 1
fi
echo "✓ 夹具三对账通过：4 类认不出的构造 $n_new 条点名，行号/措辞/顺序与旧实现**逐字节一致**，且两边都没吐产物"
