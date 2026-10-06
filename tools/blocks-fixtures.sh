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
