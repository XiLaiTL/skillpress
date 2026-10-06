#!/usr/bin/env bash
# mbt-traps.sh —— **MoonBit 侧会安静咬人的坑**（第一条：`Array::sort()` 不是字典序）。
#
#   bash tools/mbt-traps.sh              # 站岗
#   bash tools/mbt-traps.sh --selftest   # 诱饵：塞一句真 `.sort()` ⇒ 必须点名；注释里的不算
#
# ── 坑①：`Array::sort()` 排字符串**不是字典序** ────────────────────────────────
# 实测（2026-10-06，P8.2 通用门对账逮到）：`["styles.md","structure.md","events-and-subs.md","FAQ.md"]`
# 被 `Array::sort()` 排成 `["FAQ.md","styles.md","structure.md","events-and-subs.md"]`（看着像按长度）。
# 后果不是崩溃、也不是报错 —— 是**真语料里 `references/` 的顺序整片错位**，只有逐字节对账才看得见。
# 而「与旧实现逐字节一致」里的那个顺序，恰恰是 JS `.sort()` 的 **UTF-16 码元序**。
# ⇒ 规矩：**要排字符串就自己写比较器**（`engine/gates/` 里有现成的 `utf16_compare` + 稳定排序）。
#
# 为什么做成判据而不是写进文档：这条**不会自己红**（编译器不管、不写测试就不炸），
# 只会在某天"顺序又不对了"时以最难查的形式冒出来。
set -u
cd "$(dirname "$0")/.."

FAIL=0

# 扫哪些源码（新引擎 + 界面包 + CLI）；`tools/spike/` 是探针，不在管辖内
FILES=$(find engine cmd shell -name "*.mbt" 2>/dev/null)
n=$(printf '%s\n' "$FILES" | grep -c .)

# 空集合守卫：`find` 写坏就一条都不扫，判据会兴高采烈地打「✓ 没有踩坑」。
if [ "$n" -lt 20 ]; then
  echo "✗ 只扫到 $n 个 .mbt 文件（实测应有 40+）—— find 写坏了？（这条判据不允许在空集合上通过）"
  exit 1
fi

# 判据：**非注释行**上的 `.sort()`。
#   注释里当然可以提 `.sort()`（解释为什么不许用它）—— 只看真正的代码行，
#   否则"写清理由的注释"会把门弄红，人就只好去删注释，正好把规矩的解释也删了。
hit_all=$(grep -rn '\.sort()' $FILES 2>/dev/null | grep -vE ':[[:space:]]*(//|///)' || true)

# ── 例外（两条，都必须写明理由）──────────────────────────────────────────────
# ① `engine/gates/report_wbtest.mbt` 里那句 `b.sort()` 是**故意**的：那条测试断言
#    「`.sort()` 的结果与字典序不一致」，是这条规矩为真的**现场证据**。
# ② `engine/highlight/ts_shim.mbt` 里那句 `.sort()` 位于 `#|` 的 **JS 源码**里（由 Node 引导层执行）
#    —— 那是 JS 的字典序，正是我们要的那个顺序。
EXCEPT="report_wbtest.mbt
ts_shim.mbt"
hit=$(printf '%s\n' "$hit_all" | grep . | grep -v -F -f <(printf '%s\n' "$EXCEPT") || true)

# 例外自证：例外里点到的地方**必须仍然含 `.sort()`** —— 否则那条例外就是一笔烂账（代码早改了、豁免还挂着）
while IFS= read -r ex; do
  [ -z "$ex" ] && continue
  if ! printf '%s\n' "$hit_all" | grep -q -F "$ex"; then
    # ⚠️ 反引号在**双引号字符串**里会被 bash 当命令替换（一路吃到文件尾，消息里那块直接变空）——
    #    要打反引号必须 `\`` 转义。这个坑实测踩过两次，所以这里照 blocks-fixtures.sh 的写法。
    echo "✗ 例外清单里的「$ex」现在已经不含 \`.sort()\` 了 —— 把这条例外撤掉（豁免不许烂在判据里）"
    FAIL=$((FAIL + 1))
  fi
done <<< "$EXCEPT"

if [ "${1:-}" = "--selftest" ]; then
  W=$(mktemp -d)
  mkdir -p "$W/engine/probe"
  # 诱饵(a)：真代码里一句 .sort() ⇒ 必须被点名
  printf 'pub fn 诱饵(xs : Array[String]) -> Unit {\n  xs.sort() |> ignore\n}\n' > "$W/engine/probe/decoy.mbt"
  # 诱饵(b)：**注释里**提 .sort() ⇒ 不许被点名（否则"解释这条规矩"的注释会让门红）
  printf '// 别用 .sort() —— 它不是字典序\npub fn 干净() -> Unit { }\n' > "$W/engine/probe/clean.mbt"
  # ⚠️ 这里刻意**不嵌套命令替换**（`$(… $(find …) …)`）：那层嵌套会让 bash 报
  #    "unexpected end of file"，虽然结果看着对，但绿里带噪音。交给内层 bash 去展开。
  out_a=$(cd "$W" && bash -c 'grep -rn "\.sort()" $(find engine cmd shell -name "*.mbt" 2>/dev/null) 2>/dev/null | grep -vE ":[[:space:]]*(//|///)" || true')
  ok_a=0; printf '%s' "$out_a" | grep -q 'decoy.mbt' && ok_a=1
  ok_b=1; printf '%s' "$out_a" | grep -q 'clean.mbt' && ok_b=0
  rm -rf "$W"
  if [ "$ok_a" = 1 ] && [ "$ok_b" = 1 ] && [ "$FAIL" = 0 ]; then
    echo "✓ 诱饵生效：代码里的 .sort() 被点名、注释里的不被点名（两向都活着）"
    exit 0
  fi
  echo "✗ 诱饵没生效（点名真代码=$ok_a 放过注释=$ok_b）—— 这条判据不可信"; exit 1
fi

if [ -n "$hit" ]; then
  echo "✗ 这些地方用了 \`.sort()\` —— 在 MoonBit 里它**不是字典序**（实测：看着像先比长度）："
  printf '%s\n' "$hit" | sed 's/^/      /'
  echo "    改法：自己写比较器（参考 engine/gates 里的 utf16_compare + 稳定排序）——"
  echo "    「与旧实现逐字节一致」里的顺序就是 JS .sort() 的 UTF-16 码元序。"
  FAIL=$((FAIL + 1))
fi

if [ "$FAIL" = 0 ]; then
  echo "✓ MoonBit 坑位检查通过：扫了 $n 个 .mbt 文件，没有落在规矩外的 \`.sort()\`（例外 2 处，都有理由且在位）"
else
  exit 1
fi
