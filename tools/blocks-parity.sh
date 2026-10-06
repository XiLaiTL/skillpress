#!/usr/bin/env bash
# blocks-parity.sh —— **文档块对账（v2：改在"两边读法相同的副本"上跑）**。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/blocks-parity.sh
#   SKILLPRESS_BLOCKS_NEW=<文件>   注入"新侧块文本"（只给 --selftest 用）
#
# ── 为什么换口径 ──────────────────────────────────────────────────────────────
# v1 拿**实例里那份生成物**当真相，并让新实现跑**真语料**。R2 之后内容仓会有 `skillpress/WEBSITE.md`
# （而且那天"实例里那份"会变成**新引擎自己**印的 ⇒ 这条判据就成了"新 vs 新"的**假绿**）。
# 所以 v2 与 `file-parity` 同源：两个引擎都跑在 `tools/mk-parity-corpus.sh` 造出的副本上，
# 旧侧从**副本**里现印，再各自切出块文本逐字节比。前提（副本里没有 WEBSITE.md、上一级没有清单）
# 由那个脚本自己断言。
#
# 为什么这条还值钱：块文本是**另一条抽取路径**（`dump-blocks` / `old-doc-blocks.mjs`），
# 与整份文件的 diff 互为交叉验证 —— "块数对上了"只说明粗结构对；能原样吐出来才说明每一条
# 渲染细节（转义、缩进、链接拆两段、表格单元格、列表 indent/num…）都搬对了。
set -u
cd "$(dirname "$0")/.."
source tools/_ensure-built.sh
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"

COPY=$(SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" bash tools/mk-parity-corpus.sh) || {
  echo "✗ 造不出「两个引擎读法相同」的副本 —— 对账前提不成立"
  [ -n "$COPY" ] && printf '%s\n' "$COPY" | sed 's/^/    /'
  exit 2
}

OUT=./_build/parity
mkdir -p "$OUT"

# ── 旧侧：旧引擎在副本上现印，再切出块文本 ─────────────────────────────────────
APP="$OUT/blocks-old-app"
rm -rf "$APP"
mkdir -p "$APP"
SKILLPRESS_SKILLS="$COPY" node lib/gen-content.mjs --skills "$COPY" --app "$APP" > "$OUT/blocks-old.log" 2>&1 || {
  echo "✗ 旧实现跑副本失败："; tail -5 "$OUT/blocks-old.log" | sed 's/^/    /'; exit 1
}
node tools/spike/old-doc-blocks.mjs "$APP/content/content.generated.mbt" > "$OUT/blocks-old.txt" || {
  echo "✗ 旧侧切不出块文本"; exit 1
}

# ── 新侧：新引擎在同一份副本上跑 `dump-blocks`（--selftest 可注入）──────────────
if [ -n "${SKILLPRESS_BLOCKS_NEW:-}" ]; then
  cp "$SKILLPRESS_BLOCKS_NEW" "$OUT/blocks-new.txt"
else
  node tools/run-js.mjs dump-blocks "$COPY" > "$OUT/blocks-new.txt" 2> "$OUT/blocks-new.err" || {
    echo "✗ 新实现那一侧跑失败："; tail -5 "$OUT/blocks-new.err" | sed 's/^/    /'; exit 1
  }
fi

# ── 两边各自**归一化**再比 ─────────────────────────────────────────────────────
# 必须做：旧侧是从**旧形状**产物里切出来的（裸构造器 `P([Txt(…)]）`），而新引擎的 `dump-blocks`
# 吐的是**新形状**（`@shell.P([@shell.Txt(…)]）`）。形状差是设计（D25/D26），不是内容差。
# `normalize-gen.mjs` 的规则③正好只抹这个前缀；规则①②对"块文本片段"是空转。
node tools/normalize-gen.mjs "$OUT/blocks-old.txt" > "$OUT/blocks-old.norm"
node tools/normalize-gen.mjs "$OUT/blocks-new.txt" > "$OUT/blocks-new.norm"

if diff -u "$OUT/blocks-old.norm" "$OUT/blocks-new.norm" > "$OUT/blocks-diff.txt"; then
  docs=$(grep -c '^### ' "$OUT/blocks-new.txt")
  # 空集合守卫：一份都没切出来时两侧"逐字节一致"是**假绿**
  if [ "$docs" -lt 2 ]; then
    echo "✗ 只切出 $docs 段（含结尾标记应当 ≥2）—— 副本路径不对？（这条判据不允许在空集合上通过）"
    exit 1
  fi
  echo "✓ 文档块对账通过：副本上 $docs 段（含结尾标记）与旧实现产物**逐字节一致**"
else
  len=$(wc -l < "$OUT/blocks-diff.txt")
  echo "✗ 文档块对账**不一致**（差异 $len 行，完整 diff 在 $OUT/blocks-diff.txt）："
  head -30 "$OUT/blocks-diff.txt" | sed 's/^/    /'
  exit 1
fi

# ── 诱饵：块文本改一个字符 ⇒ 必须红（证明这条判据真在比，不是走过场）────────────
if [ "${1:-}" = "--selftest" ]; then
  ST="$OUT/blocks-selftest"
  rm -rf "$ST"; mkdir -p "$ST"
  sed '0,/Txt("/s//Txt("改/' "$OUT/blocks-new.txt" > "$ST/mutated.txt"
  if cmp -s "$OUT/blocks-new.txt" "$ST/mutated.txt"; then
    echo "✗ 诱饵自己造歪了（一个字符都没改到）"; exit 1
  fi
  if SKILLPRESS_BLOCKS_NEW="$ST/mutated.txt" bash "$0" > "$ST/log" 2>&1; then
    echo "✗ 诱饵没生效：块文本改了一个字符，判据还是绿的 ⇒ 这条判据不可信"
    sed 's/^/      /' "$ST/log" | head -8
    exit 1
  fi
  echo "✓ 诱饵生效：块文本改一个字符后确实红了"
fi
