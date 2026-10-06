#!/usr/bin/env bash
# highlight-parity.sh —— **上色对账**：新实现（MoonBit 引擎）与旧实现（Node 版 lib/highlight.mjs）
# 在**全语料**上的读数必须逐字节一致（只允许第 1 行不同 —— 那行是各自的名字）。
#
#   SKILLPRESS_CORPUS=<内容根> bash tools/highlight-parity.sh
#
# 为什么这条判据值钱：上色的质量是整条迁移路上**最可能悄悄退步**的地方
# （旧实现那套"包装候选"是调出来的：裸解析召回 12% → 挑对包装 93%），
# 而"跑起来了"和"跟原来一样好"是两件事。逐块 + 逐语言的读数对齐，才说明没退步。
set -u
cd "$(dirname "$0")/.."

# 前置：确保 CLI 的 js 产物新鲜（干净克隆里 _build 不存在 —— 实测过）
source tools/_ensure-built.sh
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定语料（例：../moobile/skills）}"
export SKILLPRESS_CORPUS

OUT=./_build/parity
mkdir -p "$OUT"

node tools/spike/node-side-batch.mjs > "$OUT/old.txt" 2>&1 || { echo "✗ 旧实现那一侧跑失败了"; tail -5 "$OUT/old.txt"; exit 1; }
node tools/run-js.mjs batch           > "$OUT/new.txt" 2>&1 || { echo "✗ 新实现那一侧跑失败了"; tail -5 "$OUT/new.txt"; exit 1; }

# 第 1 行是各自的名字，不算读数
if diff <(tail -n +2 "$OUT/old.txt") <(tail -n +2 "$OUT/new.txt") > "$OUT/diff.txt"; then
  # 代码块行是 `…|dark=…`；汇总行多一个 `块|` 标记 ⇒ 数的时候排掉汇总行
  blocks=$(grep '|dark=' "$OUT/new.txt" | grep -vc '块|')
  # ── **空集合不许通过** ─────────────────────────────────────────────────────
  # 旧实现的原话：`✗ 一个代码块都没数到 —— 内容源的路径不对？（这条判据不允许在空集合上通过）`。
  # 为什么非要这一条：**语料路径写错/语料被挪走时，两侧读数会同样为空，diff 当然一致** ——
  # 判据会兴高采烈地打"✓ 0 个代码块 + 各语言汇总"并退 0。实测（2026-10-06）：给一个
  # 没有任何围栏的语料，它照样打 ✓ 并退 0。**判据在空集合上通过，比没有判据更糟。**
  if [ "$blocks" -eq 0 ]; then
    echo "✗ 一个代码块都没数到 —— 语料路径不对？（这条判据**不允许在空集合上通过**）"
    echo "    语料根：$SKILLPRESS_CORPUS"
    echo "    两侧读数都是空的、所以 diff 一致 —— 这不是「没退步」，这是**什么都没测**"
    exit 1
  fi
  echo "✓ 上色对账通过：$blocks 个代码块 + 各语言汇总，与旧实现**逐字节一致**"
  grep '块|dark=' "$OUT/new.txt" | sed 's/^/    /'
else
  echo "✗ 上色对账不一致（差异在 $OUT/diff.txt）—— 这就是"悄悄退步"的样子："
  head -20 "$OUT/diff.txt" | sed 's/^/    /'
  exit 1
fi
