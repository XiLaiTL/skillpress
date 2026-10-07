#!/usr/bin/env bash
# queries-check.sh —— **内嵌 query 与 `grammars/*.scm` 逐字节同源**这条判据。
#
#   bash tools/queries-check.sh              # 站岗
#   bash tools/queries-check.sh --selftest   # 诱饵：改一个字节 ⇒ 必须红；改回来 ⇒ 必须绿
#
# ── 为什么要有它 ──────────────────────────────────────────────────────────────
# native 垫片没有引导层去读盘，所以**五份 highlights query 是编进二进制的**
# （`engine/highlight/queries.generated.mbt`，由 **`skillpress gen-queries`** 生成）。
# 而 js 垫片仍然走引导层**读盘**（`grammars/*.scm`）。
# 于是有一份"同一个事实的两个副本"—— 它们一变味，症状是：
#
#   · **同一份内容，native 与 js 上成两种颜色**（而两边各自的判据都可能还是绿的）；
#   · 或者更阴的：改了 `.scm` 以为生效了，其实只有 js 那边生效（native 还用着旧的）。
#
# 所以这条判据钉的是"两份逐字节相同"，而不是"看起来像"。
set -u
cd "$(dirname "$0")/.."

GEN=engine/highlight/queries.generated.mbt
fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }

# 空集合守卫：产物没生成 / 是空的，"同源"就会变成**假绿**（两边都空也算一样）。
if [ ! -s "$GEN" ]; then
  echo "✗ $GEN 不存在或是空的 —— 先跑 \`node tools/run-js.mjs gen-queries\`"
  echo "  （这条判据不允许在空集合上通过：两份都空也算"同源"，那是假绿）"
  exit 1
fi

# 内嵌的那几门语言要在产物里真的出现（产物被掏空但还剩个头注释时也算假绿）
for L in bash javascript json moonbit toml; do
  grep -q "\"$L\" =>" "$GEN" || bad "产物里没有这门语言的 query：$L"
done
[ "$fail" = 0 ] && ok "产物非空，五门语言都在"

if out=$(node tools/run-js.mjs gen-queries --check 2>&1); then
  ok "$out"
else
  bad "内嵌 query 与 grammars/*.scm 不同源："
  printf '%s\n' "$out" | sed 's/^/      /'
fi

# ── 诱饵：改一个字节必须红、改回来必须绿（"永远绿"的判据比没有判据更糟）────────────
if [ "${1:-}" = "--selftest" ]; then
  cp "$GEN" "$GEN.bak"
  printf '\n// 诱饵探针\n' >> "$GEN"
  if node tools/run-js.mjs gen-queries --check > /dev/null 2>&1; then
    cp "$GEN.bak" "$GEN"; rm -f "$GEN.bak"
    echo "✗ 诱饵没生效：产物被改了一个字节，判据还是绿的 ⇒ 这条判据不可信"
    exit 1
  fi
  cp "$GEN.bak" "$GEN"; rm -f "$GEN.bak"
  if node tools/run-js.mjs gen-queries --check > /dev/null 2>&1; then
    echo "✓ 诱饵生效：改一个字节当场红、改回来立刻绿 —— 两向都活着"
    exit 0
  fi
  echo "✗ 诱饵后半段没生效：改回来之后仍然红（判据成了"永远红"）"
  exit 1
fi

echo
if [ "$fail" = 0 ]; then
  echo "✓ 内嵌 query 判据全过：native 那份与 grammars/*.scm 逐字节同源"
else
  echo "✗ 内嵌 query 判据有红 —— 跑 \`node tools/run-js.mjs gen-queries\` 重新生成（别手改产物）"
  exit 1
fi
