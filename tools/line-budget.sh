#!/usr/bin/env bash
# line-budget.sh —— **R9 的判据**：新引擎每个源文件 ≤ 400 行（含注释）。
#
#   bash tools/line-budget.sh            # 查一遍
#   bash tools/line-budget.sh --selftest # 证伪：造一个 401 行的诱饵，判据**必须**点名
#
# 为什么要有它（R9 / PLAN 的 D21）：**代码这边原先一条体量门都没有** ——
# 于是 Node 版长成 3412 行、四个文件超 400（`gen-content` 636 ｜ `verify-site` 565 ｜
# `check` 444 ｜ `docfacts` 401）。规矩是"超了拆成**一个文件一件事**"，**不许删注释凑数**。
#
# 数的是**行数**（含注释与空行）——与 skill 那边同一个数字（`SPEC.md` §3 的 400 行预算）。
#
# ── 覆盖范围：**默认全覆盖 + 明确豁免**（2026-10-06 改；原先是一张"要查的目录"清单）────────
#
# ⚠️ **旧写法的实测代价**：原先写的是 `find engine cmd` —— 而 P6 抽出来的界面包 `shell/`
# 在**仓库根**上，于是它有生以来**一次都没被这条判据量过**，判据却一直打印
# 「✓ R9 通过：42 个文件全部 ≤ 400 行」——**42 里没有一份是 shell**。
# 教训不是"再补一个目录"（那张清单下次还会烂），而是：**枚举默认全查，豁免必须显式写出来**。
# 豁免清单（每条都要有理由，别默默加）：
#   · `node_modules/` `.mooncakes/` `_build/` —— 依赖与产物
#   · `lib/`            —— 冻结的旧 Node 版（D15：不回改，所以不管辖）
#   · `tools/spike/`    —— P8.0 的一次性探针（不进包、也不进账）
#   · `tools/baseline/` —— **生成物的基线**（244 KB 的 `content.generated.mbt` 是"内容"，不是源码）
set -u
cd "$(dirname "$0")/.."

LIMIT=400

list_files() {
  # MoonBit 源码（含 moon.pkg）——**全仓**枚举后逐条豁免
  find . \( -name "*.mbt" -o -name "moon.pkg" \) \
    -not -path "*/node_modules/*" -not -path "*/.mooncakes/*" -not -path "*/_build/*" \
    -not -path "./lib/*" -not -path "./tools/spike/*" -not -path "./tools/baseline/*" \
    2>/dev/null
  # 入口与判据脚本（`tools/` 只查顶层：子目录里的是探针与基线，已在上面豁免）
  find tools -maxdepth 1 \( -name "*.mjs" -o -name "*.sh" \) 2>/dev/null
}

count_lines() { # 行数（以换行结尾的文件：wc -l 即可）
  wc -l < "$1" | tr -d ' '
}

check_dir() { # $1 = 目录；打印超限的文件
  local bad=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local n
    n=$(count_lines "$f")
    if [ "$n" -gt "$LIMIT" ]; then
      echo "✗ $f —— $n 行（超 $LIMIT：拆成「一个文件一件事」，别删注释凑数）"
      bad=$((bad + 1))
    fi
  done < <(list_files | sort)
  return "$bad"
}

if [ "${1:-}" = "--selftest" ]; then
  # ⚠️ 证伪：判据**自己**也要被证明会红。造一个 401 行的诱饵放进管辖范围，它必须被点名。
  DECOY="engine/_selftest_decoy.mbt"
  mkdir -p engine
  : > "$DECOY"
  for _ in $(seq 1 $((LIMIT + 1))); do echo "// 诱饵（$LIMIT+1 行）" >> "$DECOY"; done
  out=$(check_dir)
  rm -f "$DECOY"
  if echo "$out" | grep -q "_selftest_decoy"; then
    echo "✓ 证伪通过：401 行的诱饵被点名"
    echo "$out" | sed 's/^/    /'
    exit 0
  else
    echo "✗ 证伪失败：401 行的诱饵**没被点名** —— 这条判据本身有问题"
    echo "$out" | sed 's/^/    /'
    exit 1
  fi
fi

out=$(check_dir)
code=$?
n=$(list_files | grep -c . )

# ── 空集合守卫 ────────────────────────────────────────────────────────────────
# `find` 的写法一变坏（少个引号、豁免写过宽）就会**静默返回空**：那时上面的循环一条都不报错，
# 判据会兴高采烈地打「✓ 0 个文件全部 ≤ 400 行」。**判据在空集合上通过，比没有判据更糟。**
if [ "$n" -lt 20 ]; then
  echo "✗ R9 只枚举到 $n 个文件（实测应有 50+）—— find 写坏了 / 豁免写过头了？（这条判据不允许在空集合上通过）"
  exit 1
fi

# 覆盖可见化：把"量到了哪些目录、各几个文件"打出来 —— 免得下次又是"某个包从来没被量过"而没人看出来
cov=$(list_files | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | awk '{printf "%s:%s  ", $2, $1}')
if [ "$code" -eq 0 ]; then
  echo "✓ R9 通过：$n 个文件全部 ≤ $LIMIT 行"
  echo "  覆盖：$cov"
else
  echo "$out"
  echo "✗ $code 个文件超 $LIMIT 行"
  echo "  覆盖：$cov"
  exit 1
fi
