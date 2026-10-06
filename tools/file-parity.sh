#!/usr/bin/env bash
# file-parity.sh —— **整份文件对账**：新实现（MoonBit 引擎）吐出的 `content.generated.mbt`
# 必须与**旧实现已经产出的**那一份**逐字节一致**。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/file-parity.sh
#   SKILLPRESS_INSTANCE=<站点实例目录> 可以覆盖实例位置（默认取内容根下的那份）
#
# 这是本阶段**最硬的一条判据**：那份生成物是旧实现的产物 = 真相。
# 逐字节相同意味着**每一条渲染细节**都对上了 —— 类型声明的空行、`esc` 的转义、链接拆两段、
# 表格单元格、列表的 indent/num、子页的取名与顺序、首页的纯链接节与下拉菜单、
# 以及每个代码块的**高亮片段**（runs）。
set -u
cd "$(dirname "$0")/.."
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"

INSTANCE="${SKILLPRESS_INSTANCE:-$SKILLPRESS_CORPUS/skillpress/scripts/.skillpress}"
OLD="$INSTANCE/content/content.generated.mbt"
if [ ! -f "$OLD" ]; then
  echo "✗ 找不到旧实现的产物：$OLD"
  exit 2
fi

OUT=./_build/parity
mkdir -p "$OUT"

node tools/run-js.mjs gen-file "$SKILLPRESS_CORPUS" > "$OUT/file-new.txt" 2> "$OUT/file-new.err" || {
  echo "✗ 新实现那一侧跑失败（退出码非零）—— stderr 末尾："
  tail -8 "$OUT/file-new.err" | sed 's/^/    /'
  exit 1
}

if diff -u "$OLD" "$OUT/file-new.txt" > "$OUT/file-diff.txt"; then
  lines=$(wc -l < "$OUT/file-new.txt" | tr -d ' ')
  echo "✓ 整份文件对账通过：$lines 行与旧实现产物**逐字节一致**"
  if [ -s "$OUT/file-new.err" ]; then
    echo "  （stderr 有诊断，逐条如下 —— 旧实现也打印这些）"
    sed 's/^/    /' "$OUT/file-new.err"
  fi
else
  echo "✗ 整份文件对账**不一致**（差异在 $OUT/file-diff.txt）："
  head -30 "$OUT/file-diff.txt" | sed 's/^/    /'
  exit 1
fi
