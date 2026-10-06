#!/usr/bin/env bash
# file-parity.sh —— **整份文件对账**（v3：R2 起改成"在两边读法相同的副本上跑"）。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/file-parity.sh
#   SKILLPRESS_INSTANCE=<站点实例目录>   覆盖实例位置（默认取内容根下的那份）
#   SKILLPRESS_PARITY_OLD=<文件>         注入"旧侧产物"（只给 --selftest 用）
#   SKILLPRESS_PARITY_NEW=<文件>         注入"新侧产物"（只给 --selftest 用）
#
# ── 为什么换口径（v2 的基线为什么退役）────────────────────────────────────────
# v2 拿"旧引擎从**当前内容源**印出来的那份"当冻结基线，比的是"新引擎在**真语料**上的产物"。
# 但 R2 之后内容仓会有 `skillpress/WEBSITE.md`（新首页源），R4 之后还有忽略清单 ——
# **冻结的旧实现不认识这两样** ⇒ 它在真语料上必然与新引擎分叉。那不是 bug，是设计。
#
# 于是改成：两个引擎都跑在**同一份副本**上（`tools/mk-parity-corpus.sh` 把真语料的 skill 原样拷来、
# 去掉 WEBSITE.md、且副本上一级不放清单）⇒ 读的内容相同 ⇒ 仍然**整份文件逐字节**比，
# 而内容的**广度一点没丢**（真语料的链接 / 表格 / 代码块 / 子页顺序都还在）。
# ⚠️ "两边读法相同"是这条判据的**前提**，不是假设：它由 `mk-parity-corpus.sh` 自己断言
#    （副本里不许有 WEBSITE.md、上一级不许有清单），`--selftest` 还会专门证一遍"破了前提必须红"。
#
# 形状差（`@shell.` 前缀 / 类型声明搬家）仍然由 `tools/normalize-gen.mjs` 抹掉 —— 只抹形状、不抹内容。
set -u
cd "$(dirname "$0")/.."

source tools/_ensure-built.sh
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"

INSTANCE="${SKILLPRESS_INSTANCE:-$SKILLPRESS_CORPUS/skillpress/scripts/.skillpress}"
OUT=./_build/parity
mkdir -p "$OUT"
: > "$OUT/file-new.err"

bad=0
fail() { echo "✗ $1"; bad=1; }

# ── 0 前提：造副本（两个引擎读法相同）。它自己会断言"没有 WEBSITE.md / 没有清单 / 不是空集合"──
COPY=$(SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" bash tools/mk-parity-corpus.sh) || {
  echo "✗ 造不出「两个引擎读法相同」的副本 —— 对账的**前提**就不成立，别比了（见上面的原因）"
  # ⚠️ 子脚本的报错在**它的 stdout**（被我捕获了）⇒ 这里必须打出来，不然"为什么红"就丢了
  [ -n "$COPY" ] && printf '%s\n' "$COPY" | sed 's/^/    /'
  exit 2
}

# ── 1 旧侧：现跑冻结的旧实现（--selftest 可注入）───────────────────────────────
OLD="$OUT/file-old.txt"
if [ -n "${SKILLPRESS_PARITY_OLD:-}" ]; then
  cp "$SKILLPRESS_PARITY_OLD" "$OLD"
else
  APP="$OUT/old-app"
  rm -rf "$APP"
  mkdir -p "$APP"
  SKILLPRESS_SKILLS="$COPY" node lib/gen-content.mjs --skills "$COPY" --app "$APP" > "$OUT/old.log" 2>&1 || {
    echo "✗ 旧实现那一侧跑失败（退出码非零）—— 末尾："
    tail -6 "$OUT/old.log" | sed 's/^/    /'
    exit 1
  }
  cp "$APP/content/content.generated.mbt" "$OLD"
fi

# ── 2 新侧：现跑新引擎（--selftest 可注入）─────────────────────────────────────
NEW="$OUT/file-new.txt"
if [ -n "${SKILLPRESS_PARITY_NEW:-}" ]; then
  cp "$SKILLPRESS_PARITY_NEW" "$NEW"
else
  node tools/run-js.mjs gen-file "$COPY" > "$NEW" 2> "$OUT/file-new.err" || {
    echo "✗ 新实现那一侧跑失败（退出码非零）—— stderr 末尾："
    tail -8 "$OUT/file-new.err" | sed 's/^/    /'
    exit 1
  }
fi

# ── 3 形状判据（不是装饰：没有它们，"两边形状被换过"会让下面那条 diff 恒真）──────
grep -q '^pub enum Span {' "$OLD" || fail "旧侧产物里没有 \`pub enum Span {\` —— 它已经不是旧形状了（跑错引擎了？）"
grep -q '@shell\.' "$OLD" && fail "旧侧产物里出现了 \`@shell.\` —— 旧形状不可能有它（新引擎写进了旧侧？）"
grep -q '@shell\.' "$NEW" || fail "新侧产物里没有 \`@shell.\` —— 引擎没吐新形状（类型没搬进包？）"
grep -q '^pub enum Span {' "$NEW" && fail "新侧产物里还有 \`pub enum Span {\` —— 类型声明的搬家没生效"

# ── 4 归一化后**逐字节**比（旧 vs 新，同一份副本）──────────────────────────────
node tools/normalize-gen.mjs "$OLD" > "$OUT/file-old.norm"
node tools/normalize-gen.mjs "$NEW" > "$OUT/file-new.norm"
if diff -u "$OUT/file-old.norm" "$OUT/file-new.norm" > "$OUT/file-diff.txt"; then
  lines=$(wc -l < "$OUT/file-new.norm" | tr -d ' ')
  [ "$bad" = 0 ] && echo "✓ 整份文件对账通过：同一份副本上，旧实现与新引擎归一化后 $lines 行**逐字节一致**"
else
  fail "整份文件对账**不一致**（差异在 $OUT/file-diff.txt）："
  head -30 "$OUT/file-diff.txt" | sed 's/^/    /'
fi

# ── 5 实例里那份 == 新引擎在**真语料**上现跑（逐字节，不归一化）──────────────────
# 专治"改了内容源/引擎却忘了重跑"（旧的 `press --check` 在这个阶段对应的口径）。
if [ -z "${SKILLPRESS_PARITY_NEW:-}" ] && [ -z "${SKILLPRESS_PARITY_OLD:-}" ] &&
  [ -f "$INSTANCE/content/content.generated.mbt" ]; then
  SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" node tools/run-js.mjs gen-file "$SKILLPRESS_CORPUS" \
      > "$OUT/file-real.txt" 2> /dev/null || fail "新引擎在真语料上跑失败"
  if diff -q "$INSTANCE/content/content.generated.mbt" "$OUT/file-real.txt" > /dev/null 2>&1; then
    echo "✓ 实例里的生成物与新引擎现跑**逐字节一致**（$(wc -l < "$OUT/file-real.txt" | tr -d ' ') 行）"
  else
    fail "实例里的生成物与新引擎现跑**不一致** —— 改了内容源或引擎之后忘了重跑"
    diff -u "$INSTANCE/content/content.generated.mbt" "$OUT/file-real.txt" > "$OUT/file-instance-diff.txt" 2>&1
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
if [ -n "${SKILLPRESS_PARITY_OLD:-}${SKILLPRESS_PARITY_NEW:-}" ]; then
  exit 0   # 注入模式只给自证用
fi

# ── --selftest：证明这条判据**会红**（不然它可能是一条永远绿的判据）────────────
if [ "${1:-}" = "--selftest" ]; then
  echo
  echo "── 自证（file-parity v3）────────────────────────────────────────────"
  ST="$OUT/selftest"
  rm -rf "$ST"
  mkdir -p "$ST"
  self() { # self <名字> <期望 green|red> <旧侧> <新侧>
    local name="$1" want="$2" o="$3" n="$4" got
    SKILLPRESS_PARITY_OLD="$o" SKILLPRESS_PARITY_NEW="$n" SKILLPRESS_INSTANCE=/nonexistent \
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
  cp "$NEW" "$ST/new-ok.txt"
  cp "$OLD" "$ST/old-ok.mbt"
  # ① 正常一对：绿
  self "合规的一对（旧实现产物 + 新引擎产物）" green "$ST/old-ok.mbt" "$ST/new-ok.txt"
  # ② 新侧的值改一个字符：红
  sed '0,/Txt("/s//Txt("改/' "$ST/new-ok.txt" > "$ST/new-bad.txt"
  self "新侧的值改了一个字符" red "$ST/old-ok.mbt" "$ST/new-bad.txt"
  # ③ 旧侧的值改一个字符：红（两个方向都要抓得住）
  sed '0,/Txt("/s//Txt("改/' "$ST/old-ok.mbt" > "$ST/old-bad.mbt"
  self "旧侧的值改了一个字符" red "$ST/old-bad.mbt" "$ST/new-ok.txt"
  # ④ 新侧少了包前缀（形状判据该抓）：红
  sed 's/@shell\.//g' "$ST/new-ok.txt" > "$ST/new-noprefix.txt"
  self "新侧少了包前缀（形状判据）" red "$ST/old-ok.mbt" "$ST/new-noprefix.txt"
  # ⑤ **前提诱饵**：语料里放了 `WEBSITE.md` ⇒ 两个引擎的读法就不同了 ⇒ 必须**拒绝比**
  #    （这条最要紧：v3 的整个合法性都压在「两边读同一份内容」上）
  #    ⚠️ 造这份坏语料时用**副本**打底（真语料里有 node_modules，`cp -r` 会把几百兆拖进来）
  BADC="$ST/bad-corpus"
  rm -rf "$BADC"
  mkdir -p "$BADC"
  cp -r ./_build/parity-corpus/skills/. "$BADC/"
  printf '# 站名\n\n引言。\n\n## 一栏\n\n正文。\n' > "$BADC/skillpress/WEBSITE.md"
  out=$(SKILLPRESS_CORPUS="$BADC" bash "$0" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q '还有 WEBSITE.md'; then
    echo "✓ 前提被破（语料里有 WEBSITE.md）⇒ 拒绝对账并点名（期望 red，实得 red）"
  else
    echo "✗ 前提被破时没被拦住（rc=$rc）—— 那 v3 就可能拿两份不同内容当「一致」比"
    printf '%s' "$out" | head -6 | sed 's/^/      /'
    bad=1
  fi

  if [ "$bad" = 0 ]; then
    echo "✓ file-parity 自证通过（5 条：1 绿 + 4 红，每条红的理由都在上面）"
  else
    echo "✗ file-parity 自证失败"
  fi
fi

exit $bad
