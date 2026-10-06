#!/usr/bin/env bash
# file-parity.sh —— **整份文件对账**（P6 换过一次口径，下面写清为什么）。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/file-parity.sh
#   SKILLPRESS_INSTANCE=<站点实例目录>   覆盖实例位置（默认取内容根下的那份）
#   SKILLPRESS_PARITY_BASE=<文件>        覆盖基线（只给 --selftest 用）
#   SKILLPRESS_PARITY_NEW=<文件>         不跑引擎、直接拿这个文件当"新产物"（只给 --selftest 用）
#
# ── 口径（P6 起）───────────────────────────────────────────────────────────────
#
# 真相仍然在**旧实现**（`lib/gen-content.mjs`）。它的产物冻在 `tools/baseline/`：
#
#   基线 = 旧引擎从**当前内容源**印出来的那份（刷新方式见 tools/baseline/README.md）
#
# P6 把 7 个类型从生成物搬进了包 `shell`，生成物因此换了**形状**（值带 `@shell.` 前缀、签名
# 带包前缀、文件头不再声明类型）。形状差**不是**判据里该检查的东西 —— 内容的映射才是。
# 所以这里用 `tools/normalize-gen.mjs` 把两边都归一化（三条规则：去头注释 / 去类型声明块 / 去包前缀），
# 然后**逐字节**比。归一化只抹形状、不抹内容（值、顺序、缩进、转义、runs、正文空行都还在判据里），
# `node tools/normalize-gen.mjs --selftest` 就是钉这条边界的（"值改一个字符"必须红）。
#
# ⚠️ 三条形状判据（0a/0b/0c）不是装饰：没有它们，"基线被新引擎覆盖"或"基线被手改"这两件事
#    会让上面那条 diff **恒真** —— 判据就废了。sha 钉住基线，形状判据钉住它是旧形状。
set -u
cd "$(dirname "$0")/.."

# 前置：确保 CLI 的 js 产物新鲜（干净克隆里 _build 不存在 —— 实测过）
source tools/_ensure-built.sh
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"

BASE="${SKILLPRESS_PARITY_BASE:-tools/baseline/content/content.generated.mbt}"
EXPECTED_SHA_FILE="tools/baseline/EXPECTED.sha256"
INSTANCE="${SKILLPRESS_INSTANCE:-$SKILLPRESS_CORPUS/skillpress/scripts/.skillpress}"
OUT=./_build/parity
mkdir -p "$OUT"
: > "$OUT/file-new.err"   # 上一轮的诊断不要漏到这一轮

bad=0
fail() { echo "✗ $1"; bad=1; }

# ── 0a 基线必须是**旧形状**（含类型声明、不含包前缀）─────────────────────────────
if [ ! -f "$BASE" ]; then
  echo "✗ 找不到基线：$BASE（见 tools/baseline/README.md）"
  exit 2
fi
grep -q '^pub enum Span {' "$BASE" || fail "基线里没有 \`pub enum Span {\` —— 它已经不是旧形状了（被新引擎覆盖？）"
if grep -q '@shell\.' "$BASE"; then
  fail "基线里出现了 \`@shell.\` —— 旧形状不可能有它（基线被新引擎/手改动过？）"
fi

# ── 0b 基线的 sha256 必须与钉住的值一致（防**静默**刷新）───────────────────────
# ⚠️ 钉子文件**必须存在**：原先这里是 `if [ -f "$EXPECTED_SHA_FILE" ]; then …` ⇒ 谁把它删掉，
#    这道锁就**被悄悄关掉**，而判据照样绿（"不许有静默后门"）。缺文件直接判红。
if [ ! -f "$EXPECTED_SHA_FILE" ]; then
  fail "找不到钉子文件：$EXPECTED_SHA_FILE —— 它是防基线被静默刷新的那道锁，缺了就是关锁，判红"
else
  actual=$(sha256sum "$BASE" | awk '{print $1}')
  expected=$(awk '{print $1}' "$EXPECTED_SHA_FILE")
  if [ "$actual" != "$expected" ]; then
    fail "基线的 sha256 变了（expected=$expected actual=$actual）—— 换基线是**刻意**动作：跑 tools/baseline/README.md 里的刷新步骤，并一起更新 EXPECTED.sha256"
  fi
fi

# ── 新产物：现跑引擎（--selftest 时可以换成注入的文件）────────────────────────
if [ -n "${SKILLPRESS_PARITY_NEW:-}" ]; then
  cp "$SKILLPRESS_PARITY_NEW" "$OUT/file-new.txt"
  NEWNOTE="（注入：$SKILLPRESS_PARITY_NEW）"
else
  node tools/run-js.mjs gen-file "$SKILLPRESS_CORPUS" > "$OUT/file-new.txt" 2> "$OUT/file-new.err" || {
    echo "✗ 新实现那一侧跑失败（退出码非零）—— stderr 末尾："
    tail -8 "$OUT/file-new.err" | sed 's/^/    /'
    exit 1
  }
  NEWNOTE=""
fi

# ── 0c 新产物必须是**新形状**（含包前缀、没有类型声明）────────────────────────
grep -q '@shell\.' "$OUT/file-new.txt" || fail "新产物里没有 \`@shell.\` —— 引擎没吐新形状（类型没搬进包？）"
if grep -q '^pub enum Span {' "$OUT/file-new.txt"; then
  fail "新产物里还有 \`pub enum Span {\` —— 类型声明的搬家没生效"
fi

# ── 1 归一化后**逐字节**比 ────────────────────────────────────────────────────
node tools/normalize-gen.mjs "$BASE" > "$OUT/file-base.norm"
node tools/normalize-gen.mjs "$OUT/file-new.txt" > "$OUT/file-new.norm"
if diff -u "$OUT/file-base.norm" "$OUT/file-new.norm" > "$OUT/file-diff.txt"; then
  lines=$(wc -l < "$OUT/file-new.norm" | tr -d ' ')
  if [ "$bad" = 0 ]; then
    echo "✓ 整份文件对账通过：归一化后 $lines 行与旧实现产物（tools/baseline/）**逐字节一致** $NEWNOTE"
  fi
else
  fail "整份文件对账**不一致**（差异在 $OUT/file-diff.txt）："
  head -30 "$OUT/file-diff.txt" | sed 's/^/    /'
fi

# ── 2 实例里的那份 == 新引擎现跑（逐字节，不归一化）──────────────────────────
# 这是旧的 `press --check` 在这个阶段对应的口径：**实例里的生成物必须是新引擎的产物**。
# 比基线那条更严（同一个形状，所以一个字节都不许差），专治"改了内容源忘了重跑 gen-file"。
if [ -z "${SKILLPRESS_PARITY_NEW:-}" ] && [ -f "$INSTANCE/content/content.generated.mbt" ]; then
  if diff -q "$INSTANCE/content/content.generated.mbt" "$OUT/file-new.txt" > /dev/null; then
    echo "✓ 实例里的生成物与新引擎现跑**逐字节一致**（$(wc -l < "$OUT/file-new.txt" | tr -d ' ') 行）"
  else
    fail "实例里的生成物与新引擎现跑**不一致** —— 改了内容源或引擎之后忘了重跑（差异：$OUT/file-instance-diff.txt）"
    diff -u "$INSTANCE/content/content.generated.mbt" "$OUT/file-new.txt" > "$OUT/file-instance-diff.txt"
    head -12 "$OUT/file-instance-diff.txt" | sed 's/^/    /'
  fi
fi

# ── stderr 里的诊断照旧透传（旧实现也打印这些）───────────────────────────────
if [ -s "$OUT/file-new.err" ]; then
  echo "  （stderr 有诊断，逐条如下 —— 旧实现也打印这些）"
  sed 's/^/    /' "$OUT/file-new.err"
fi

if [ "$bad" != 0 ]; then
  exit 1
fi

# ── --selftest：证明这条判据**会红**（不然它可能是一条永远绿的判据）────────────
if [ "${1:-}" = "--selftest" ]; then
  echo
  echo "── 自证（file-parity）──────────────────────────────────────────────"
  ST="$OUT/selftest"
  rm -rf "$ST"
  mkdir -p "$ST"
  self() { # self <名字> <期望> <base文件> <new文件>
    local name="$1" want="$2" b="$3" n="$4" got
    SKILLPRESS_PARITY_BASE="$b" SKILLPRESS_PARITY_NEW="$n" SKILLPRESS_INSTANCE=/nonexistent \
      bash "$0" > "$ST/log" 2>&1
    local rc=$?
    case "$want" in
      green) got=$([ $rc -eq 0 ] && echo green || echo red) ;;
      red)   got=$([ $rc -ne 0 ] && echo red || echo green) ;;
    esac
    if [ "$got" = "$want" ]; then
      echo "✓ $name（期望 $want，实得 $got）"
    else
      echo "✗ $name（期望 $want，实得 $got）—— 判据这条有问题"
      sed 's/^/      /' "$ST/log" | head -12
      bad=1
    fi
  }

  cp "$OUT/file-new.txt" "$ST/new-ok.txt"
  cp "$BASE" "$ST/base-ok.mbt"
  # ① 正常：必须绿
  self "合规的一对（旧形状基线 + 新形状产物）" green "$ST/base-ok.mbt" "$ST/new-ok.txt"
  # ② 值改一个字符：必须红
  sed '0,/Txt("/s//Txt("改/' "$ST/new-ok.txt" > "$ST/new-bad-value.txt"
  self "值改了一个字符" red "$ST/base-ok.mbt" "$ST/new-bad-value.txt"
  # ③ 基线被换成新形状（模拟"有人用新引擎覆盖了基线"）：必须红
  self "基线被新引擎覆盖（形状判据 0a）" red "$ST/new-ok.txt" "$ST/new-ok.txt"
  # ④ 把前缀去掉（形状差）—— ⚠️ 这条**期望红**，而且红的理由要看清：
  #    归一化只抹"合法的形状差"（旧形状 ↔ 新形状），而 0c 还要求新产物**确实是新形状**。
  #    所以"新产物没有前缀"不该被放过去（那正是"类型没搬进包"的症状）。
  sed 's/@shell\.//g' "$ST/new-ok.txt" > "$ST/new-noprefix.txt"
  self "新产物少了包前缀（形状判据 0c 该抓它）" red "$ST/base-ok.mbt" "$ST/new-noprefix.txt"
  # ⑤ 只改**基线里类型声明块**的一个字符 —— 这一处**归一化看不见**（规则②会整块砍掉），
  #    所以只有 0b（sha256 钉子）能抓。没有 0b，这条会**绿**：那就等于"基线可以被悄悄改"。
  sed 's/^pub enum Span {$/pub enum Span { \/\/ 被手改了（归一化看不见）/' "$ST/base-ok.mbt" > "$ST/base-tampered.mbt"
  if cmp -s "$ST/base-ok.mbt" "$ST/base-tampered.mbt"; then
    echo "✗ 用例⑤自己造歪了（sed 一个字符都没改到）—— 自证无效"
    bad=1
  else
    self "基线被手改（只在归一化看不见的地方）" red "$ST/base-tampered.mbt" "$ST/new-ok.txt"
  fi

  if [ "$bad" = 0 ]; then
    echo "✓ file-parity 自证通过（5 条：1 绿 + 4 红，每条红的理由都在上面）"
  else
    echo "✗ file-parity 自证失败"
  fi
fi

exit $bad
