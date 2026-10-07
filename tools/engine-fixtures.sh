#!/usr/bin/env bash
# engine-fixtures.sh —— **引擎在冻结夹具语料上的读数 == 入库的 golden**（逐字节，四份）。
#
#   bash tools/engine-fixtures.sh              # 站岗
#   bash tools/engine-fixtures.sh --selftest   # 诱饵：把 golden 改一个字节 ⇒ 必须红；坏语料 ⇒ 必须红
#   bash tools/engine-fixtures.sh --capture    # 重新采 golden（**改的是"期望值"，所以要么是升级、要么是修判据**）
#
# ── 它替的是谁 ────────────────────────────────────────────────────────────────
# 迁移期那三条对账判据（`file-parity` / `blocks-parity` / `highlight-parity`）比的是
# "**新引擎 vs 冻结的旧实现**，现场各跑一遍"。它们的参照物 `lib/*.mjs` 一旦退役，那三条就
# 同时失去参照物与一端 —— 而**引擎仍然需要语料级的回归覆盖**（改了 `engine/content` 或
# `engine/highlight`，总得有人盯着产物变没变）。
#
# 于是把参照物换成**入库的 golden**：
#   · 语料是**冻结**的（`tools/fixtures/corpus/skills/` 住在本仓里，不随内容仓变化）；
#   · golden 是从**旧实现与新实现都同意的那份产物**上采的（采之前两边在这份夹具上做过逐字节对账：
#     `file-parity` 159 行 / `blocks-parity` 5 段 / `highlight-parity` 6 个代码块，全绿）；
#   · 输入冻结 + 期望冻结 ⇒ **不会像 D29 那次那样"基线自己腐掉"**（那次腐是因为基线绑在会变的内容仓上）。
#
# ⚠️ 与那三条的**分工**：这一条盯"引擎的读数变了没有"；那三条盯"与旧实现是否同口径"（迁移期）。
#    两边都留着直到 `lib/` 退役；那时这一条就是引擎的语料级回归网。
set -u
cd "$(dirname "$0")/.."

CORPUS=tools/fixtures/corpus/skills
EXPECT=tools/fixtures/expected
OUT=./_build/engine-fixtures
mkdir -p "$OUT"
bad=0
fail() { echo "✗ $1"; bad=1; }

CAPTURE=0
SELFTEST=0
for a in "$@"; do
  case "$a" in
    --capture) CAPTURE=1 ;;
    --selftest) SELFTEST=1 ;;
  esac
done

# ── 语料在不在（它**随仓走**，所以"不在"一定是路径写坏或有人搬了它）──────────────
[ -d "$CORPUS" ] || { echo "✗ 夹具语料不在：$CORPUS" >&2; exit 2; }

# ── 三条读数怎么跑（与迁移期那三条判据**同一套命令**，只是旧侧换成 golden）──────
run_gen() { node tools/run-js.mjs gen-file "$CORPUS" 2> "$OUT/gen.err"; }
run_blocks() { node tools/run-js.mjs dump-blocks "$CORPUS" 2> "$OUT/blocks.err"; }
# `batch` 的每一行头一列是**本机绝对路径** ⇒ 采 golden 与现跑都用同一套归一化（去掉仓内前缀），
# 否则 golden 一换机器就红。⚠️ 只去掉到 `tools/fixtures/corpus/skills/` 为止 —— 贪掉整段会把
# `alpha-skill/SKILL.md` 削成 `SKILL.md`，两份不同的文件就再也分不开了（实测踩过）。
run_batch() {
  SKILLPRESS_CORPUS="$CORPUS" node tools/run-js.mjs batch 2> "$OUT/batch.err" |
    sed 's|.*/tools/fixtures/corpus/skills/||'
}
# `audit`（上色的回归闸门）的**读数部分**也入 golden：它把"召回率 / 未上色比例 / 每门语言的
# dark-white"钉住 —— 高亮塌方在这份夹具上会当场红（阈值那三条另有其用：它是**判决**）。
run_audit() { SKILLPRESS_CORPUS="$CORPUS" node tools/run-js.mjs audit 2> "$OUT/audit.err"; }

capture() {
  mkdir -p "$EXPECT"
  run_gen > "$EXPECT/gen-file.mbt" || { echo "✗ gen-file 跑失败，不采"; exit 1; }
  run_blocks > "$EXPECT/dump-blocks.txt" || { echo "✗ dump-blocks 跑失败，不采"; exit 1; }
  run_batch > "$EXPECT/batch.txt" || { echo "✗ batch 跑失败，不采"; exit 1; }
  run_audit > "$EXPECT/audit.txt" || { echo "✗ audit 跑失败，不采"; exit 1; }
  echo "✓ 重新采了 golden（四份）："
  wc -l "$EXPECT"/* | sed 's/^/    /'
  echo "  ⚠️ 「--capture」改的是**期望值** —— 提交前请确认这次变化是「升级」，不是「把红改绿」"
  exit 0
}
[ "$CAPTURE" = 1 ] && capture

# ── 空集合守卫：golden 不在/被截断时，"比"会变成**假绿** ────────────────────────
for g in gen-file.mbt dump-blocks.txt batch.txt audit.txt; do
  if [ ! -s "$EXPECT/$g" ]; then
    echo "✗ golden 不在或是空的：$EXPECT/$g" >&2
    echo "  （先 bash tools/engine-fixtures.sh --capture —— 但**先想清楚**为什么它没了）" >&2
    exit 2
  fi
  n=$(wc -l < "$EXPECT/$g" | tr -d ' \r')
  if [ "$n" -lt 5 ]; then
    fail "golden $g 只有 $n 行 —— 被截断了吧？（这条判据不允许在空集合上比）"
  fi
done

# ── 现跑三条 ────────────────────────────────────────────────────────────────
run_gen > "$OUT/fresh-gen" || { fail "gen-file 跑失败："; tail -4 "$OUT/gen.err" | sed 's/^/    /'; }
run_blocks > "$OUT/fresh-blocks" || { fail "dump-blocks 跑失败："; tail -4 "$OUT/blocks.err" | sed 's/^/    /'; }
run_batch > "$OUT/fresh-batch" || { fail "batch 跑失败："; tail -4 "$OUT/batch.err" | sed 's/^/    /'; }
run_audit > "$OUT/fresh-audit" || { fail "audit 跑失败："; tail -4 "$OUT/audit.err" | sed 's/^/    /'; }

check_one() { # <名字> <golden 文件> <现跑文件>
  if [ ! -s "$3" ]; then
    fail "$1 现跑出来是空的 —— 引擎没吐东西（别把它当成"一致"）"
    return
  fi
  if diff -u "$2" "$3" > "$OUT/$1.diff"; then
    echo "✓ $1：$(wc -l < "$3" | tr -d ' \r') 行与 golden **逐字节一致**"
  else
    fail "$1 与 golden **不一致**（差异在 $OUT/$1.diff）："
    head -20 "$OUT/$1.diff" | sed 's/^/    /'
  fi
}

check_one "gen-file" "$EXPECT/gen-file.mbt" "$OUT/fresh-gen"
check_one "dump-blocks" "$EXPECT/dump-blocks.txt" "$OUT/fresh-blocks"
check_one "batch" "$EXPECT/batch.txt" "$OUT/fresh-batch"
check_one "audit" "$EXPECT/audit.txt" "$OUT/fresh-audit"

# ── 证伪 ────────────────────────────────────────────────────────────────────
if [ "$SELFTEST" = 1 ]; then
  echo "── 证伪（诱饵必须被点名）──"
  for pair in "gen-file.mbt:fresh-gen" "dump-blocks.txt:fresh-blocks" "batch.txt:fresh-batch" "audit.txt:fresh-audit"; do
    g="${pair%%:*}"
    f="${pair##*:}"
    cp "$EXPECT/$g" "$OUT/bad-$g"
    printf '\n诱饵探针\n' >> "$OUT/bad-$g"
    if diff -q "$OUT/bad-$g" "$OUT/$f" > /dev/null; then
      fail "诱饵「$g」：golden 改了一个字节，diff 竟然还是绿的"
    else
      echo "  ✓ 诱饵「$g」：golden 改一个字节 ⇒ 红"
    fi
  done
  # 坏语料 ⇒ 引擎跑不起来 ⇒ 必须红（"跑不起来"不许当成"一致"）
  mkdir -p "$OUT/empty-corpus"
  if node tools/run-js.mjs gen-file "$OUT/empty-corpus" > /dev/null 2>&1; then
    fail "诱饵：空语料竟然跑成功了（引擎应当在空集合上拒跑）"
  else
    echo "  ✓ 诱饵：空语料 ⇒ 引擎拒跑（退非零）"
  fi
fi

echo
if [ "$bad" = 0 ]; then
  echo "✓ 引擎夹具判据全过：四份读数与入库 golden 逐字节一致"
  exit 0
fi
echo "✗ 引擎夹具判据有红 —— 要么引擎退了步，要么这次变化是**有意的**（那就重新采 golden 并在提交信息里说清）"
exit 1
