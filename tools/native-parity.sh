#!/usr/bin/env bash
# native-parity.sh —— **两个 target 的产物对账**：同一份语料上，native CLI 与 js CLI 的产物**逐字节一致**。
#
#   SKILLPRESS_CORPUS=<内容根> bash tools/native-parity.sh [--selftest]
#   SKILLPRESS_CORPUS=../moobile/skills bash tools/native-parity.sh
#
# ── 为什么这条判据值钱 ────────────────────────────────────────────────────────
# P10 的目标是"CLI 能 `moon install`（native，使用者零 Node）"。可 native 一旦与 js 分成两套实现，
# **最容易悄悄发生的退步就是"两边产物不一样"** —— 站点内容、上色、块结构任一处分叉，都是
# "同一份 skill 在两个 target 上生成两种网站"，而且两边都各自"跑得通"。
# 所以判据只有一条，但很硬：**三份读数逐字节比**（不归一化、不忽略空白）：
#   ① `gen-file` 整份产物（含上色后的色号）② `dump-blocks` 页面骨架 ③ `batch` 全语料上色读数
#
# ── 这条判据的**前提**（`--selftest` 会证一遍）────────────────────────────────
# js 侧的 `vendor/web-tree-sitter`（wasm）与 native 侧的 `vendor/tree-sitter`（C 库）**必须同版本**。
# 实测（2026-10-07）：0.27.0 的 wasm 配 0.26.0 的 C 库，921 行产物里**恰好差 6 行**（多一个 `type` 捕获）。
# 所以脚本开头会拿两份 `PROVENANCE.md` 里记的版本号**互相对**、并拿记的 sha256 **核对盘上文件** ——
# "说是一版、盘上是另一版"这种最容易骗过人的情况在这里当场红。理由详见
# `vendor/web-tree-sitter/PROVENANCE.md` 的"版本"那一节。
set -u
cd "$(dirname "$0")/.."

source tools/_ensure-built.sh
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定语料（例：../moobile/skills）}"

# ── 前置：native 可执行件（与 `_ensure-built.sh` 同口径：缺了或过期就重编）────────
NATIVE=""
for c in _build/native/debug/build/cmd/skillpress-native/skillpress-native.exe \
         _build/native/debug/build/cmd/skillpress-native/skillpress-native; do
  [ -f "$c" ] && NATIVE="$c"
done
if [ -z "$NATIVE" ] || [ -n "$(find engine cmd -name '*.mbt' -newer "$NATIVE" 2>/dev/null | head -1)" ]; then
  echo "（前置：native CLI 缺失或过期 ⇒ 先 moon build cmd/skillpress-native --target native）"
  if ! timeout 1800 moon build cmd/skillpress-native --target native 2>&1 | tail -3; then
    echo "✗ 前置失败：native CLI 编不出来" >&2
    exit 2
  fi
  for c in _build/native/debug/build/cmd/skillpress-native/skillpress-native.exe \
           _build/native/debug/build/cmd/skillpress-native/skillpress-native; do
    [ -f "$c" ] && NATIVE="$c"
  done
fi
[ -n "$NATIVE" ] || { echo "✗ 找不到 native 可执行件（编出来了吗？）" >&2; exit 2; }

[ -d "$SKILLPRESS_CORPUS" ] || { echo "✗ 语料不存在：$SKILLPRESS_CORPUS" >&2; exit 2; }

# ⚠️ 产物目录可覆盖：`--selftest` 那些诱饵会往这里**写坏文件**，实测踩到过 ——
#    诱饵跑完（尤其是"把 wasm 改坏 ⇒ 期望红"那两条），真的产物会被留成**空的**
#    （`gen-file > 文件` 在那一侧失败时先把文件清空了），下一个读它的人就会拿空文件当基准。
#    所以诱饵一律写到临时目录里去。
OUT="${SKILLPRESS_PARITY_OUT:-./_build/parity}"
mkdir -p "$OUT"
bad=0
fail() { echo "✗ $1"; bad=1; }

# ── 0 前提一：**两个 runtime 同版本**（记的版本号互相对 + 盘上文件的 sha256 对账）────
ver_of() { grep -o "$2" "$1" | head -1 | grep -o '[0-9][0-9.]*' | head -1; }
sha_of() { sha256sum "$1" 2>/dev/null | cut -c1-16; }

v_wasm=$(ver_of vendor/web-tree-sitter/PROVENANCE.md 'web-tree-sitter@[0-9.]*')
v_c=$(ver_of vendor/tree-sitter/PROVENANCE.md 'tree-sitter==[0-9.]*')
if [ -z "$v_wasm" ] || [ -z "$v_c" ]; then
  fail "两份 PROVENANCE.md 里读不到版本号（格式变了？）—— 这条判据的**前提**读不出来就不能算通过"
elif [ "$v_wasm" != "$v_c" ]; then
  fail "两个 runtime **不同版本**：js wasm = $v_wasm，native C 库 = $v_c
    这就是实测过的那个坑：版本不齐会在产物里差几行（921 行差 6 行），而两边看上去都还绿
    换版本必须**两边一起换**（见 vendor/web-tree-sitter/PROVENANCE.md 的「版本」）"
fi
# 记的 sha256 与盘上文件对不对得上（"表里写一版、盘上是另一版"）
# 表里那一列是"文件名 + 前 16 位 sha256"，路径按各自 PROVENANCE 所在的目录解析
check_table() { # check_table <PROVENANCE 文件> <它所在的目录>
  local prov="$1" base="$2" f s got
  while IFS=$'\t' read -r f s; do
    [ -n "$f" ] && [ -n "$s" ] || continue
    [ -f "$base/$f" ] || { fail "$base/$f 不在盘上，而 $prov 的表里列着它"; continue; }
    got=$(sha_of "$base/$f")
    [ "$got" = "$s" ] || fail "$base/$f 的 sha256 是 $got，而表里记的是 $s（换了文件没更新表，或反过来）"
  done < <(awk -F'|' '{ f=$2; s=$5;
                       # 只取"路径那一段"：表格里文件名后面常跟着中文注解（如 `lib.c`（单体入口…））
                       if (match(f, /[A-Za-z0-9._\/-]+/)) f=substr(f, RSTART, RLENGTH);
                       gsub(/[ `]/,"",s);
                       if (length(s)==16 && s ~ /^[0-9a-f]+$/) print f "\t" s }' "$prov")
}
check_table vendor/web-tree-sitter/PROVENANCE.md vendor/web-tree-sitter
check_table vendor/tree-sitter/PROVENANCE.md     vendor/tree-sitter

# ── 0 前提二：语料**不是空集合**（空集合上两边同样为空、diff 当然一致 —— 那是假绿）────
n_skills=0
for d in "$SKILLPRESS_CORPUS"/*/; do
  [ -f "$d/SKILL.md" ] && n_skills=$((n_skills + 1))
done
if [ "$n_skills" -lt 1 ]; then
  echo "✗ 语料里一份 skill 都没有（$SKILLPRESS_CORPUS）—— 判据**不允许在空集合上通过**"
  exit 1
fi

# ── 跑两侧：native 与 js，同一份语料、同一份参数 ────────────────────────────────
run_pair() { # run_pair <名字> <给 CLI 的参数…>；结果落在 $OUT/native-<名字>.txt 与 $OUT/js-<名字>.txt
  local name="$1"; shift
  if [ "$name" = gen ] && [ -n "${SKILLPRESS_PARITY_NATIVE_GEN:-}" ]; then
    cp "$SKILLPRESS_PARITY_NATIVE_GEN" "$OUT/native-$name.txt"
  else
    "$NATIVE" "$@" > "$OUT/native-$name.txt" 2> "$OUT/native-$name.err" || {
      echo "✗ native 那一侧跑失败：$name $*"; tail -5 "$OUT/native-$name.err" | sed 's/^/    /'; return 1
    }
  fi
  if [ "$name" = gen ] && [ -n "${SKILLPRESS_PARITY_JS_GEN:-}" ]; then
    cp "$SKILLPRESS_PARITY_JS_GEN" "$OUT/js-$name.txt"
  else
    node tools/run-js.mjs "$@" > "$OUT/js-$name.txt" 2> "$OUT/js-$name.err" || {
      echo "✗ js 那一侧跑失败：$name $*"; tail -5 "$OUT/js-$name.err" | sed 's/^/    /'; return 1
    }
  fi
  return 0
}

# 三份读数（顺序就是"离产物有多近"的顺序）
SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" run_pair gen   gen-file   "$SKILLPRESS_CORPUS" || bad=1
run_pair blocks dump-blocks "$SKILLPRESS_CORPUS" || bad=1
SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" run_pair batch batch || bad=1

# ── 形状守卫（不是装饰：没有它们，"两侧都退化成空文件"会让下面那条 diff 恒真）──────
if [ -f "$OUT/js-gen.txt" ]; then
  txt=$(grep -c '@shell\.Txt(' "$OUT/js-gen.txt" || true)
  code=$(grep -c '@shell\.Code(' "$OUT/js-gen.txt" || true)
  [ "$txt" -ge 50 ] || fail "js 产物里只有 $txt 个 \`@shell.Txt(\` —— 产物退化了（语料不对？引擎没吐内容？）"
  [ "$code" -ge 20 ] || fail "js 产物里只有 $code 个 \`@shell.Code(\` —— 代码块没进产物（上色那条链断了？）"
fi
blocks=$(grep '|dark=' "$OUT/js-batch.txt" 2>/dev/null | wc -l | tr -d ' ')
[ "$blocks" -ge 1 ] || fail "batch 一个代码块都没数到 —— 上色链条断了或语料里没有围栏块"
# ⚠️ CRLF：Windows 文本模式会把每个换行写成 CRLF ⇒ 产物**整份**与 js 不同（实测 1842 行）。
#    native 用 `sp_set_binary_stdio()` 修掉了；这里钉住"别再退回去"。
for f in "$OUT/native-gen.txt" "$OUT/native-blocks.txt" "$OUT/js-gen.txt"; do
  [ -f "$f" ] || continue
  grep -q $'\r' "$f" && fail "$f 里有 CR（\\r）—— 二进制 stdio 那条修法没生效（Windows 文本模式又回来了）"
done

# ── 逐字节比 ────────────────────────────────────────────────────────────────
cmp_pair() { # cmp_pair <名字> <人话>
  local name="$1" what="$2"
  [ -f "$OUT/native-$name.txt" ] && [ -f "$OUT/js-$name.txt" ] || return 0
  if diff "$OUT/native-$name.txt" "$OUT/js-$name.txt" > "$OUT/native-$name.diff"; then
    echo "✓ $what：$(wc -l < "$OUT/js-$name.txt" | tr -d ' ') 行**逐字节一致**（native vs js）"
  else
    fail "$what **不一致**（差异在 $OUT/native-$name.diff，$(grep -c '^[<>]' "$OUT/native-$name.diff") 行）："
    head -12 "$OUT/native-$name.diff" | sed 's/^/    /'
  fi
}
cmp_pair gen    "gen-file 整份产物"
cmp_pair blocks "dump-blocks 页面骨架"
cmp_pair batch  "batch 全语料上色读数"

if [ "$bad" != 0 ]; then
  exit 1
fi
[ -z "${SKILLPRESS_PARITY_NATIVE_GEN:-}${SKILLPRESS_PARITY_JS_GEN:-}" ] || exit 0

# ── --selftest：证明这条判据**会红**（不然它可能是一条永远绿的判据）────────────────
if [ "${1:-}" = "--selftest" ]; then
  echo
  echo "── 自证（native-parity）──────────────────────────────────────────────"
  ST="$OUT/native-selftest"
  rm -rf "$ST"; mkdir -p "$ST"
  self() { # self <名字> <期望 green|red> [注入的 native 产物] [注入的 js 产物]
    local name="$1" want="$2" got
    # ⚠️ 诱饵一律写到 `$ST/out`（`SKILLPRESS_PARITY_OUT`）—— 别污染真产物目录，理由见上面 OUT 那段
    SKILLPRESS_PARITY_OUT="$ST/out" \
      SKILLPRESS_PARITY_NATIVE_GEN="$3" SKILLPRESS_PARITY_JS_GEN="$4" bash "$0" > "$ST/log" 2>&1
    local rc=$?
    got=$([ $rc -eq 0 ] && echo green || echo red)
    if [ "$got" = "$want" ]; then echo "✓ $name（期望 $want，实得 $got）"
    else echo "✗ $name（期望 $want，实得 $got）—— 判据这条有问题"; sed 's/^/      /' "$ST/log" | head -10; bad=1; fi
  }
  cp "$OUT/js-gen.txt" "$ST/js-ok.txt"
  cp "$OUT/native-gen.txt" "$ST/native-ok.txt"
  self "正常一对（同一份语料两侧现跑）" green "$ST/native-ok.txt" "$ST/js-ok.txt"
  # ① native 侧改一个字符 ⇒ 红（"差一点点"也要抓住）
  sed '0,/Txt("/s//Txt("改/' "$ST/native-ok.txt" > "$ST/native-onechar.txt"
  self "native 侧改了一个字符" red "$ST/native-onechar.txt" "$ST/js-ok.txt"
  # ② native 侧换成 CRLF ⇒ 红（这正是 native 落地时真踩过的坑）
  sed 's/$/\r/' "$ST/native-ok.txt" > "$ST/native-crlf.txt"
  self "native 侧是 CRLF（Windows 文本模式）" red "$ST/native-crlf.txt" "$ST/js-ok.txt"
  # ③ 两侧都空 ⇒ 红（空集合不许通过 —— 语料写错时就是这个形状）
  : > "$ST/empty.txt"
  self "两侧都是空文件（空集合）" red "$ST/empty.txt" "$ST/empty.txt"
  # ④ 前提诱饵：把"两个 runtime 同版本"这条前提破掉 ⇒ 必须红
  #    做法：临时把 web-tree-sitter 那份 PROVENANCE 的版本号改一个字（改完立刻还原）
  P=vendor/web-tree-sitter/PROVENANCE.md
  cp "$P" "$ST/provenance.bak"
  sed -i '0,/web-tree-sitter@0\.26\.0/s//web-tree-sitter@0.27.0/' "$P"
  out=$(SKILLPRESS_PARITY_OUT="$ST/out" SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" SKILLPRESS_PARITY_NATIVE_GEN="$ST/native-ok.txt" SKILLPRESS_PARITY_JS_GEN="$ST/js-ok.txt" bash "$0" 2>&1); rc=$?
  cp "$ST/provenance.bak" "$P"
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q '不同版本'; then
    echo "✓ 前提被破（两份 runtime 版本号不同）⇒ 拒绝并点名（期望 red，实得 red）"
  else
    echo "✗ 前提被破时没被拦住（rc=$rc）—— 那这条判据可能拿「版本不齐」的产物当「一致」比"
    printf '%s' "$out" | head -6 | sed 's/^/      /'
    bad=1
  fi
  # ⑤ 前提诱饵：sha256 与盘上文件对不上 ⇒ 必须红（"表里写一版、盘上是另一版"）
  cp vendor/web-tree-sitter/web-tree-sitter.wasm "$ST/wasm.bak"
  printf 'x' >> vendor/web-tree-sitter/web-tree-sitter.wasm
  out=$(SKILLPRESS_PARITY_OUT="$ST/out" SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" SKILLPRESS_PARITY_NATIVE_GEN="$ST/native-ok.txt" SKILLPRESS_PARITY_JS_GEN="$ST/js-ok.txt" bash "$0" 2>&1); rc=$?
  cp "$ST/wasm.bak" vendor/web-tree-sitter/web-tree-sitter.wasm
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'sha256'; then
    echo "✓ 前提被破（vendor 里的 wasm 与 PROVENANCE 记的 sha256 不符）⇒ 拒绝（期望 red，实得 red）"
  else
    echo "✗ sha256 对不上时没被拦住（rc=$rc）——那 PROVENANCE 那张表就只是装饰"
    bad=1
  fi

  if [ "$bad" = 0 ]; then
    echo "✓ native-parity 自证通过（6 条：1 绿 + 5 红，每条红的理由都在上面）"
  else
    echo "✗ native-parity 自证失败"
  fi
fi

exit $bad
