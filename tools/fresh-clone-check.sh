#!/usr/bin/env bash
# fresh-clone-check.sh —— **干净克隆自查**：把 HEAD 克隆到临时目录（**只有 tracked 文件**），
# 装依赖，跑四条对账 + R9 + 诊断账本 + MoonBit 坑位 + 包内容。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/fresh-clone-check.sh
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/fresh-clone-check.sh --selftest   # 诱饵
#
# 为什么要有它（本仓库的两笔老账）：
#   1) **本机绿 ≠ 干净克隆也绿**。本机有 `_build/`、`node_modules/`、各种缓存，克隆里什么都没有。
#      第一次跑就逮到：四条对账判据在克隆里全失败（它们要吃编出来的 js，而 `_build/` 不进版本库）
#      —— 本机一直绿，只因为我本机早就编过。与 moobile 的"CI 每次运行都是一个新鲜克隆"同源。
#   2) **本机 `_build/` 是脏的 ⇒ 判据读的是"上一版源码"**。第二次跑逮到更狠的一条：提交态 HEAD 的
#      引擎里**根本没有**「图片 / 原始 HTML / 表格缺分隔行 / 围栏没闭合」这四条检测规矩，于是它把认不出
#      的构造**咽了下去**、照吐一份坏产物、退出码还是 0 —— 正是旧实现刻意不做的"静默丢"。
#      本机之所以看不出来：本机编的是**工作区**（未提交的 WIP，那四条规矩在 WIP 里）。
#      ⇒ 判据只在"干净克隆 + 干净重编"下才算读数；**改完必须重编再读**，别拿旧产物当读数。
set -u
SELFTEST=0
case "${1:-}" in
  "") ;;
  --selftest) SELFTEST=1 ;;
  *) echo "用法：bash tools/fresh-clone-check.sh [--selftest]"; exit 2 ;;
esac

SRC=$(cd "$(dirname "$0")/.." && pwd -W)
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"
export SKILLPRESS_CORPUS

W=$(mktemp -d)
C="$W/clone"
trap 'cd /; rm -rf "$W"' EXIT
echo "干净克隆自查 —— 源：$SRC"
git clone -q "$SRC" "$C" || { echo "✗ 克隆失败"; exit 1; }
cd "$C"
echo "  克隆 HEAD = $(git rev-parse --short HEAD) ｜ tracked 文件 $(git ls-files | wc -l | tr -d ' ') 个"
echo "  npm install（js 那条图要 web-tree-sitter）"
npm install --no-audit --no-fund > "$W/npm.log" 2>&1 || { echo "✗ npm install 失败"; tail -3 "$W/npm.log"; exit 1; }

# 跑四条对账 + R9，把结果记进 fail/red
fail=0
red=""
run() {
  name=$1
  shift
  printf "  %-18s " "$name"
  if out=$("$@" 2>&1); then
    echo "$out" | grep -E "^✓" | tail -1 | sed 's/^/  /'
  else
    echo "✗ 失败"
    echo "$out" | tail -3 | sed 's/^/      /'
    fail=$((fail + 1))
    red="$red $name"
  fi
}
run engine-fixtures bash tools/engine-fixtures.sh
run blocks-fixtures bash tools/blocks-fixtures.sh
run line-budget bash tools/line-budget.sh
run diagnostics-ledger bash tools/diagnostics-ledger.sh
run mbt-traps bash tools/mbt-traps.sh
run site-source bash tools/site-source.sh
run shell-traps bash tools/shell-traps.sh
# 包内容也在干净克隆里复核：这里**没有未跟踪文件**，所以清单反映的就是版本库的真实内容
run package-check bash tools/package-check.sh
echo

# ── 诱饵（--selftest）：把一条检测规矩的**措辞**改掉 ⇒ blocks-fixtures 必须点出这一条 ──────
# 为什么改措辞而不是删掉那行：删了可能编不过（空块），而改措辞同样改变行为、却一定编得过。
# 断言写得很具体（必须点名「代码块没闭合」）：判据要是因为别的原因红了，诱饵不算生效 ——
# 那样我就是在拿一条不相干的红当"我的判据能抓东西"的证据。
if [ "$SELFTEST" = 1 ]; then
  echo "诱饵：把 blocks.mbt 里「代码块没闭合」这条点名的措辞改掉，blocks-fixtures 必须点名这一条"
  sed -i 's/代码块没闭合/代码块没封口/' engine/content/blocks.mbt
  grep -q '代码块没封口' engine/content/blocks.mbt || {
    echo "✗ 诱饵没打上：HEAD 的 engine/content/blocks.mbt 里**根本没有**「代码块没闭合」这条规矩 ——"
    echo "  这本身就是红的证据（该点名的构造被静默咽掉），诱饵无从下手。先修规矩，再跑诱饵。"
    exit 1
  }
  if out=$(bash tools/blocks-fixtures.sh 2>&1); then
    echo "✗ 诱饵没生效：规矩的措辞都改了，blocks-fixtures 还是绿的 ⇒ 这条判据不可信"
    exit 1
  fi
  if echo "$out" | grep -q '没点名「代码块没闭合」'; then
    echo "✓ 诱饵生效：改掉措辞后 blocks-fixtures 精确点名了「代码块没闭合」—— 这条判据真的在盯着它"
    exit 0
  fi
  echo "✗ 诱饵红了，但**不是**因为这条规矩（没点名「代码块没闭合」）—— 判据红了也说明不了它盯着这条："
  echo "$out" | tail -6 | sed 's/^/      /'
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "✓ 干净克隆自查通过：上面那几条（对账 / 夹具 / R9 / 诊断账本 / MoonBit 坑位 / 包内容）在**只有 tracked 文件**、**现编**的克隆里全绿"
else
  echo "✗ 干净克隆自查：$fail 项失败（$red ）—— 本机绿不算数，先修这里"
  exit 1
fi
