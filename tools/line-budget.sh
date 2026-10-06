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
# 覆盖范围：新引擎与它的入口/工具（`engine/**` `cmd/**` `tools/*.mjs` `tools/*.sh`）。
# 旧 Node 版（`lib/*.mjs`）**不回改**（它冻结了，见 D15/P8），所以不在管辖内。
set -u
cd "$(dirname "$0")/.."

LIMIT=400

list_files() {
  find engine cmd -name "*.mbt" -o -name "moon.pkg" 2>/dev/null
  find tools -maxdepth 1 -name "*.mjs" -o -maxdepth 1 -name "*.sh" 2>/dev/null
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
if [ "$code" -eq 0 ]; then
  n=$(list_files | grep -c . )
  echo "✓ R9 通过：$n 个文件全部 ≤ $LIMIT 行"
else
  echo "$out"
  echo "✗ $code 个文件超 $LIMIT 行"
  exit 1
fi
