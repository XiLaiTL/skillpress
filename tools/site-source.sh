#!/usr/bin/env bash
# site-source.sh —— **首页源（R2 / D19 / D20）与忽略清单（R4）**的判据。
#
#   bash tools/site-source.sh              # 站岗
#   bash tools/site-source.sh --selftest   # 诱饵：证"坏清单必须红"不是摆设（逐条自己验一遍）
#
# ── 为什么要有它 ──────────────────────────────────────────────────────────────
# R2 把**首页**从"那份 skill"里拆了出来（`skillpress/WEBSITE.md`），R4 给了"把 skill 藏起来"的机制。
# 这两件事的共同点是：**坏掉的时候不报错**——
#   · 首页源选错了 ⇒ 站点顶栏/首屏悄悄变成另一份内容（看着还挺正常）；
#   · 忽略清单写错名字 / 漏写理由 ⇒ 那份 skill 照常上桌，而你以为它被忽略了（或反过来）。
# 所以这里把三路首页源与四种坏清单形状**逐个钉死**，并且都断言"退 2 且 stdout 是空的"
# （`gen-file > 产物` 是常见用法，有问题还照吐 = 把一份坏产物落盘）。
set -u
cd "$(dirname "$0")/.."
source tools/_ensure-built.sh

W=./_build/site-source
rm -rf "$W"
mkdir -p "$W"

CLI="node tools/run-js.mjs"
fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }

# ── 造一个内容根：`skillpress/`（首页候选）+ 两份 skill ─────────────────────────
# ⚠️ 忽略清单住**内容仓根**（与内容根同级，不进内容根里）—— 所以 fixture 也要有"上一级"。
mk_corpus() { # $1 = 语料目录名
  C="$W/$1"
  mkdir -p "$C/root/skillpress" "$C/root/alpha" "$C/root/beta"
  cat > "$C/root/skillpress/WEBSITE.md" <<'MD'
# 站名来自 WEBSITE

WEBSITE 的首屏引言。

## 网站栏

WEBSITE 的正文。
MD
  cat > "$C/root/skillpress/SKILL.md" <<'MD'
---
name: skillpress
description: 工具自己的那份
whenToUse: 改这个工具时
---

# 站名来自 SKILL

SKILL 的首屏。

## skill 栏

SKILL 的正文。
MD
  for s in alpha beta; do
    cat > "$C/root/$s/SKILL.md" <<MD
---
name: $s
description: 夹具里的 $s
whenToUse: 测试
---

# $s

## 一栏

正文。
MD
  done
  printf '%s' "$C"
}

run() { # $1 = 语料目录；其余 = CLI 参数；输出：out/err/rc
  C=$1; shift
  SKILLPRESS_CORPUS="$C/root" $CLI gen-file "$C/root" "$@" > "$C/out.txt" 2> "$C/err.txt"
  echo "$?" > "$C/rc.txt"
}

# ── ① 首页三路：WEBSITE.md 优先 / 没有就回退 SKILL.md / `--home` 覆盖 ─────────────
echo "① 首页源（R2 / D19 / D20）"
C=$(mk_corpus website); run "$C"
[ "$(cat "$C/rc.txt")" = 0 ] || bad "① WEBSITE.md 那一路退码非 0（$(tail -2 "$C/err.txt" | tr '\n' ' ')）"
grep -q 'title: "站名来自 WEBSITE"' "$C/out.txt" && ok "① WEBSITE.md 赢（H1 来自它）" || bad "① 首页没取 WEBSITE.md"
grep -q '站名来自 SKILL' "$C/out.txt" && bad "① 生成物里混进了 SKILL.md 的首页内容" || ok "① SKILL.md 的首页内容没混进来"
grep -qF '· 首页源：`skillpress/WEBSITE.md`' "$C/err.txt" && ok "① 打印了用了哪个源" || bad "① 没打印首页源（R2 要求打印）"
# D20 的第二个洞：同一个文件**既当首页、又当书架里的一页** ⇒ 两套渲染规矩打架。
# 所以 `WEBSITE.md` **不算子页**（索引与 kids 都排除它）。
# ⚠️ 断言要收窄：生成物头部的注释里**本来就该**出现 `WEBSITE.md` 的名字（那句在说"首页来自它"），
#    首页正文里也有站名。要查的是"**子页条目**里没有它" ⇒ 只看 kids 那两行的形状（`kind:` + `name:`）。
if grep -A 1 'kind: "ref"' "$C/out.txt" | grep -q 'name: "WEBSITE"'; then
  bad "① 首页源 WEBSITE.md 被当成子页收进生成物了（D20：它不算子页）"
else
  ok "① 首页源不算子页（D20）"
fi

# 回退：把 WEBSITE.md 抽走（也顺带覆盖"文件在但是空的"这条边界）
C2=$(mk_corpus fallback); : > "$C2/root/skillpress/WEBSITE.md"; run "$C2"
[ "$(cat "$C2/rc.txt")" = 0 ] || bad "① 回退那一路退码非 0"
grep -q 'title: "站名来自 SKILL"' "$C2/out.txt" && ok "① 没有 WEBSITE.md（或它是空的）⇒ 回退 SKILL.md" || bad "① 回退没生效"
grep -qF '按 R2 回退' "$C2/err.txt" && ok "① 回退**打印**了（不打印就成了没人查得出来的谜）" || bad "① 回退没打印"

# `--home` 覆盖
C3=$(mk_corpus homename); cat > "$C3/custom.md" <<'MD'
# 站名来自 --home

首屏。

## 一栏

正文。
MD
run "$C3" --home "$C3/custom.md"
[ "$(cat "$C3/rc.txt")" = 0 ] || bad "① --home 那一路退码非 0"
grep -q 'title: "站名来自 --home"' "$C3/out.txt" && ok "① --home 覆盖生效" || bad "① --home 没生效"
grep -qF '（--home 指定）' "$C3/err.txt" && ok "① --home 也打印了" || bad "① --home 没打印"

# ── ② 忽略清单：不上书架（R4）＋ **打印"跳过了几份 + 理由"** ──────────────────────
echo "② 忽略清单（R4）"
C4=$(mk_corpus ignore)
printf '# 忽略清单\n\n- beta —— 先不上桌，等内容补齐\n' > "$C4/skillpress.ignore.md"
run "$C4"
[ "$(cat "$C4/rc.txt")" = 0 ] || bad "② 好清单那一路退码非 0（$(tail -3 "$C4/err.txt" | tr '\n' ' ')）"
grep -q 'slug: "alpha"' "$C4/out.txt" && ok "② 没被忽略的还在" || bad "② alpha 不见了"
grep -q 'slug: "beta"' "$C4/out.txt" && bad "② 被忽略的 beta 居然还在生成物里" || ok "② 被忽略的不上桌"
grep -qF '（忽略清单跳过了 1 份' "$C4/err.txt" && ok "② 打印了「跳过了几份」" || bad "② 没打印跳过份数（总数也是读数）"
grep -qF '⊘ beta —— 先不上桌，等内容补齐' "$C4/err.txt" && ok "② 跳过的形状带**理由**、且与通过不同形" || bad "② 没逐条打理由"

# ── ③ 坏清单四种形状：**都必须退 2、点名、且 stdout 空**（不许静默）───────────────
echo "③ 坏清单（不静默容忍）"
bad_case() { # $1 = 名字；$2 = 清单内容；$3 = 期望点名的关键词
  C5=$(mk_corpus "bad-$1")
  printf '%s' "$2" > "$C5/skillpress.ignore.md"
  run "$C5"
  rc5=$(cat "$C5/rc.txt")
  [ "$rc5" = 2 ] || { bad "③ $1：退码是 $rc5（应当是 2）"; return; }
  [ ! -s "$C5/out.txt" ] || { bad "③ $1：有问题还往 stdout 吐了产物"; return; }
  grep -qF "$3" "$C5/err.txt" && ok "③ $1 被点名（且退 2、不吐产物）" || bad "③ $1 没点到「$3」"
}
bad_case noreason '- beta
' '没写理由'
bad_case typo '- btea —— 手滑打错
' '静默失效'
bad_case stray '这一行是散落的段落
' '认不出'
bad_case homepage '- WEBSITE.md —— 想把首页藏起来
' '静默失效'

# `--ignore` 指的清单不存在 ⇒ 不许当成"没有清单"
C6=$(mk_corpus nofile); run "$C6" --ignore "$C6/does-not-exist.md"
[ "$(cat "$C6/rc.txt")" = 2 ] && [ ! -s "$C6/out.txt" ] &&
  ok "③ --ignore 指了不存在的清单：退 2、不吐产物" || bad "③ --ignore 指了不存在的清单却照常出产物"

# ── ④ 门那一侧：R4 说"**门也跳过**"（站点跳过是上面 ②，两边得一致）──────────────────
# ⚠️ 新门的可执行入口今天是 `engine/gates/dev`（PLAN 的 P8.2 还没把它接进 CLI），所以这里跑它。
#    接进 CLI 之后这一段应当改成跑 CLI —— 但**断言不许松**。
echo "④ 门也跳过（R4）"
timeout 600 moon build --target js > /dev/null 2>&1 || bad "④ 模块编不过，跑不了门"
DEV=_build/js/debug/build/engine/gates/dev/dev.js
C8=$(mk_corpus gates-ignore)
printf -- '- beta —— 先不上桌\n' > "$C8/skillpress.ignore.md"
node "$DEV" --repo "$C8" --skills "$C8/root" --program . > "$C8/gate.txt" 2>&1
g8=$?
[ "$g8" = 0 ] || bad "④ 门在有忽略清单时退码 $g8（应当 0）"
grep -q '✓ alpha' "$C8/gate.txt" && ok "④ 没被忽略的那份照常查" || bad "④ alpha 没被查"
grep -q '⊘ beta —— 先不上桌' "$C8/gate.txt" && ok "④ 门也跳过，并且**打了理由**" || bad "④ 门没跳过 beta（或没打理由）"
grep -q '✓ beta' "$C8/gate.txt" && bad "④ 门居然还查了被忽略的 beta" || ok "④ 被忽略的没进门的报告"

# 全被忽略 ⇒ **判红**（门在空集合上通过等于没查）
# ⚠️ 夹具里其实有**三份** skill（`skillpress` 那份也在）：要造"一份不剩"就得三份都忽略 ——
#    只忽略两份的话 `skillpress` 还在，门照常绿（我第一版断言就是这么写错的，实测逮到）。
printf -- '- alpha —— 甲\n- beta —— 乙\n- skillpress —— 丙\n' > "$C8/skillpress.ignore.md"
node "$DEV" --repo "$C8" --skills "$C8/root" --program . > "$C8/gate2.txt" 2>&1
g9=$?
[ "$g9" = 1 ] && grep -q '一份 skill 都不剩' "$C8/gate2.txt" &&
  ok "④ 全被忽略 ⇒ 判红（不许在空集合上通过）" || bad "④ 全被忽略时退码是 $g9（应当是 1 并点名）"

# ── ⑤ 首页源**也过门**（R2 / D20：它不是 skill，但它是站点的脸）──────────────────
# D20 的第一半：`skillFiles()` 收不到首页源 ⇒ 它原先既不过门也不进指纹（能无限膨胀而没人复核）。
echo "⑤ 首页源也过门（D20）"
C9=$(mk_corpus gate-home)
node "$DEV" --repo "$C9" --skills "$C9/root" --program . > "$C9/good.txt" 2>&1
grep -q '✓ skillpress/WEBSITE.md（首页源）' "$C9/good.txt" &&
  ok "⑤ 好首页源被门认下（报告里有它那一行）" || bad "⑤ 门没有把首页源算进去"
# 坏首页源：里面摆一条不存在的仓库内路径 ⇒ G3 必须点名它（而且**指名到 WEBSITE.md**）
printf '# 站名\n\n引言。\n\n## 一栏\n\n见 `docs/没有这份文档.md`。\n' > "$C9/root/skillpress/WEBSITE.md"
node "$DEV" --repo "$C9" --skills "$C9/root" --program . > "$C9/bad.txt" 2>&1
g10=$?
[ "$g10" = 1 ] && grep -q '✗ skillpress/WEBSITE.md（首页源）' "$C9/bad.txt" &&
  grep -q 'G3 路径不存在：docs/没有这份文档.md' "$C9/bad.txt" &&
  ok "⑤ 坏首页源（死路径）被点名，且指名到首页源那一行" ||
  bad "⑤ 坏首页源没被抓住（rc=$g10）—— 首页就又成了没人复核的那块"

# ── ⑥ 首页源**也进 G8 指纹**（D20 的另一半）──────────────────────────────────────
# D20 的第二个洞：首页源原先**既不过门、也不进指纹** ⇒ 它可以无限膨胀而没人复核。
# ⑤ 管的是"过门"，这里管"进指纹"：落锁要写出它那一条、改一个字节要**当场红**。
echo "⑥ 首页源进 G8 指纹（D20）"
P6=$(mktemp -d)
node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$SKILLPRESS_CORPUS" \
  --program "$P6" --update-lock > "$W/lockh.txt" 2>&1
grep -q '"skillpress/WEBSITE.md"' "$P6/skills.lock.json" &&
  ok "⑥ 落锁把首页源写进了锁（key = skillpress/WEBSITE.md）" || bad "⑥ 首页源没进锁"
out=$(node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$SKILLPRESS_CORPUS" \
  --program "$P6" 2>&1)
printf '%s' "$out" | grep -q '首页源还没进 G8 指纹' &&
  bad "⑥ 门还在说「首页源还没进指纹」—— 那句话已经过期（自销账没同步）" ||
  ok "⑥ 门上那句「还没进指纹」的声明已撤（它真进指纹了）"
# 改**真首页源**一个字节（改完立刻撤回；这条判据必须证明它会红）
cp "$SKILLPRESS_CORPUS/skillpress/WEBSITE.md" "$W/home.bak"
printf '\n<!-- 判据探针 -->\n' >> "$SKILLPRESS_CORPUS/skillpress/WEBSITE.md"
printf '%s' "$(node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$SKILLPRESS_CORPUS" --program "$P6" 2>&1)" |
  grep -q 'G8 首页源指纹变了：skillpress/WEBSITE.md' &&
  ok "⑥ 首页源改一个字节 ⇒ 「首页源指纹变了」当场红（指纹不是摆设）" || bad "⑥ 首页源变了没被抓住"
cp "$W/home.bak" "$SKILLPRESS_CORPUS/skillpress/WEBSITE.md"   # 撤回探针
rm -rf "$P6"

# ── ⑦ 门与**旧门**在同一份副本上逐字节一致 ──────────────────────────────────────
# 为什么必须挪到副本上：R4 之后旧实现不认识忽略清单 ⇒ 在真语料上两边**必然**差出"被跳过的那一份"
# （那不是 bug，是设计）。副本上没有清单、没有 WEBSITE.md ⇒ 读的内容相同 ⇒ 可以整份报告逐字节比。
# ⚠️ 跑法要用**真仓库根**（旧门的 G5/G6 要靠那边的 `.mbt` 索引）+ **显式空清单**（不然默认路径会把
#    真清单漏进来）。G5/G6 按 D18 不搬 —— 用真索引时它们在旧门那一侧**通过**，所以两边输出仍然相等。
echo "⑦ 门在副本上与旧门逐字节一致"
C10=$(SKILLPRESS_CORPUS="$SKILLPRESS_CORPUS" bash tools/mk-parity-corpus.sh 2>/dev/null) ||
  bad "⑦ 造不出副本（前提不成立）"
if [ -n "${C10:-}" ]; then
  : > "$W/empty-ignore.md"
  node lib/check.mjs --repo "$SKILLPRESS_CORPUS/.." --skills "$C10" > "$W/gate-old.txt" 2>&1
  ro=$?
  # ⚠️ 跑的是**新 CLI**（`run-js.mjs check`），不是开发入口 —— 出厂那条路才是要钉的东西
  node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$C10" --ignore "$W/empty-ignore.md" \
    > "$W/gate-new.txt" 2>&1
  rn=$?
  if [ "$ro" = "$rn" ] && diff -q "$W/gate-old.txt" "$W/gate-new.txt" > /dev/null; then
    ok "⑦ 旧门与新 CLI 在副本上**逐字节一致**（rc 都是 $ro，$(grep -c . "$W/gate-new.txt") 行）"
  else
    bad "⑦ 门对账不一致（旧 rc=$ro 新 rc=$rn）"
    diff "$W/gate-old.txt" "$W/gate-new.txt" | head -8 | sed 's/^/      /'
  fi
fi

# ── ⑧ 落锁（写侧）走一遍完整循环（**在临时程序根里做，真锁一个字都不碰**）──────────
# 为什么单列：写侧是"让门变绿"的唯一入口，它坏掉的样子最危险 —— 要么悄悄不写、要么把别人的指纹
# 一起锁掉。所以：落锁 ⇒ 不再报「新增」；改一个字节 ⇒ **必须**报「指纹变了」。
echo "⑧ 落锁写侧（临时程序根）"
P7=$(mktemp -d)
node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$C10" --program "$P7" \
  --update-lock > "$W/lock1.txt" 2>&1
grep -q '已落锁：7 个 skill' "$W/lock1.txt" &&
  ok "⑧ 落锁：打印与旧实现同形（$(head -1 "$W/lock1.txt")）" || bad "⑧ 落锁没打那句（$(head -2 "$W/lock1.txt" | tr '\n' ' ')）"
[ -f "$P7/skills.lock.json" ] && ok "⑧ 锁写到了指定的程序根（不是别处）" || bad "⑧ 锁没写出来"
out=$(node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$C10" --program "$P7" 2>&1)
printf '%s' "$out" | grep -q 'G8 新增 skill' &&
  bad "⑧ 刚落完锁还报「新增」⇒ 写侧与读侧对不上" || ok "⑧ 落锁后不再报「新增」（读写同一套口径）"
printf '\n<!-- 判据探针 -->\n' >> "$C10/moobile-pitfalls/SKILL.md"
printf '%s' "$(node tools/run-js.mjs check --repo "$SKILLPRESS_CORPUS/.." --skills "$C10" --program "$P7" 2>&1)" |
  grep -q 'G8 指纹变了：moobile-pitfalls' &&
  ok "⑧ 改一个字节 ⇒ 「指纹变了」当场红（门的意义就在这一条）" || bad "⑧ 指纹变了没被抓住"
rm -rf "$P7"


# ── 诱饵（--selftest）：把上面那些"必须红"的用例反过来验一遍 ─────────────────────
# 光有"坏清单必须红"不够 —— 还得证明**好清单必须绿**，否则这条判据可能只是"永远红"的摆设。
if [ "${1:-}" = "--selftest" ]; then
  # ① 好清单必须**绿**（不然上面那些红可能只是"这条判据永远红"）
  C7=$(mk_corpus selftest-ok)
  printf -- '- beta —— 理由\n' > "$C7/skillpress.ignore.md"
  run "$C7"
  if [ "$(cat "$C7/rc.txt")" = 0 ] && ! grep -q 'slug: "beta"' "$C7/out.txt"; then
    echo "✓ 诱饵生效：好清单绿（且确实藏住了 beta），坏清单一律红 —— 两向都活着"
    exit 0
  fi
  echo "✗ 诱饵没生效：好清单那一侧不绿 ⇒ 判据不可信"; exit 1
fi

echo
if [ "$fail" = 0 ]; then
  echo "✓ 首页源（R2）与忽略清单（R4）判据全过：三路首页源各自归位、四种坏清单全部当场点名"
else
  echo "✗ 首页源 / 忽略清单判据有红 —— 修完再看一遍"
  exit 1
fi
