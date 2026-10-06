#!/usr/bin/env bash
# blocks-parity.sh —— **文档块对账**：新实现（`engine/content`）吐出的 `blocks: [ … ]`
# 必须与**旧实现已经产出的** `content.generated.mbt` **逐字节一致**。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/blocks-parity.sh
#   SKILLPRESS_INSTANCE=<站点实例目录> 可以覆盖实例位置（默认取内容根下的那份）
#
# 为什么这是最硬的判据：那份生成物是**旧实现的产物** —— 它就是真相。
# "块数对上了"只说明粗结构对；能原样吐出来才说明**每一条渲染细节**（转义、缩进、链接拆两段、
# 表格单元格的空格、列表的 indent/num…）都搬对了。
set -u
cd "$(dirname "$0")/.."
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"

INSTANCE="${SKILLPRESS_INSTANCE:-$SKILLPRESS_CORPUS/skillpress/scripts/.skillpress}"
GENERATED="$INSTANCE/content/content.generated.mbt"
if [ ! -f "$GENERATED" ]; then
  echo "✗ 找不到旧实现的产物：$GENERATED"
  exit 2
fi

OUT=./_build/parity
mkdir -p "$OUT"

node tools/spike/old-doc-blocks.mjs "$GENERATED" > "$OUT/blocks-old.txt" || { echo "✗ 基准那一侧切不出来"; exit 1; }
node tools/run-js.mjs dump-blocks "$SKILLPRESS_CORPUS" > "$OUT/blocks-new.txt" || { echo "✗ 新实现那一侧跑失败"; tail -5 "$OUT/blocks-new.txt"; exit 1; }

if diff -u "$OUT/blocks-old.txt" "$OUT/blocks-new.txt" > "$OUT/blocks-diff.txt"; then
  docs=$(grep -c '^### ' "$OUT/blocks-new.txt")
  echo "✓ 文档块对账通过：$docs 段（含结尾标记）与旧实现产物**逐字节一致**"
else
  len=$(wc -l < "$OUT/blocks-diff.txt")
  echo "✗ 文档块对账**不一致**（差异 $len 行，完整 diff 在 $OUT/blocks-diff.txt）："
  head -30 "$OUT/blocks-diff.txt" | sed 's/^/    /'
  exit 1
fi
