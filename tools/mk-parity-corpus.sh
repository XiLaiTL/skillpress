#!/usr/bin/env bash
# mk-parity-corpus.sh —— 造一份**两个引擎读法完全相同**的语料副本（对账用）。打印副本的内容根。
#
#   SKILLPRESS_CORPUS=<真内容根> bash tools/mk-parity-corpus.sh
#
# ── 为什么需要它（R2 之后的对账前提）──────────────────────────────────────────
# R2 起，内容仓会有 `skillpress/WEBSITE.md`（新首页源）与 `skillpress.ignore.md`（忽略清单）。
# 而**冻结的旧实现不认识这两样**：它照旧拿 `skillpress/SKILL.md` 当首页、也不跳过任何 skill。
# 于是在真语料上"旧 vs 新"**必然**分叉 —— 那不是 bug，是设计（新引擎实现了 R2/R4）。
#
# 干瞪眼没用，也不能把判据删掉（那等于放弃"逐字节"这条最强的防线）。做法是：
# **把真语料的 skill 原样拷进副本，但把"新功能会改变读法"的两个东西拿掉**——
#   ① 去掉 `skillpress/WEBSITE.md` ⇒ 两边都读 `SKILL.md` 当首页；
#   ② 副本的**上一级**不放 `skillpress.ignore.md`（清单住内容仓根）⇒ 两边都不跳过任何一份。
# 两个引擎读的是同一份内容 ⇒ 仍然可以**整份文件逐字节**比，而且内容的**广度一点没丢**
# （真语料里的链接、表格、代码块、子页顺序都还在）。
#
# ⚠️ 只拷引擎**真的会读**的东西（`.md` + `scripts/` 下的非 md）：`skills/skillpress/scripts/.skillpress/`
#    里有 `node_modules/`、`_build/`、`.mooncakes/`，整个 `cp -r` 会把几百兆拖进来，而且毫无意义。
set -u
cd "$(dirname "$0")/.."
: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<真内容根> 指定语料（例：../moobile/skills）}"
[ -d "$SKILLPRESS_CORPUS" ] || { echo "✗ 语料根不存在：$SKILLPRESS_CORPUS"; exit 1; }

# 目录名必须是 `skills`：旧实现的标签把 `skills/` 前缀**写死**在产物与点名里（见 PLAN 的 DG-首页标签）。
OUT=./_build/parity-corpus
rm -rf "$OUT"
mkdir -p "$OUT/skills"

skip='-not -path */node_modules/* -not -path */_build/* -not -path */.mooncakes/* -not -path */.git/*'
n_skills=0
for d in "$SKILLPRESS_CORPUS"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  dest="$OUT/skills/$name"
  # ① 所有 `.md`（主文档 + references/** + FAQ.md）
  # ⚠️ `cp` 必须在**外层**跑，所以拼绝对路径 `$d/$rel` —— `cd` 只在 `find` 的子壳里生效
  #    （第一版就是在这儿栽的：`cd` 写进 `< <(…)` 里，`cp` 还在仓库根，结果一份都没拷到）。
  found=0
  while IFS= read -r -d '' f; do
    rel="${f#"$d"}"
    mkdir -p "$dest/$(dirname "$rel")"
    cp "$d/$rel" "$dest/$rel"
    found=1
  done < <(cd "$d" && find . -name '*.md' $skip -print0 2>/dev/null)
  # ② `scripts/` 下**直接放着**的非 md（同 `lib/kids.mjs` 的口径：不递归、跳过点目录 ——
  #    站点实例就住在 `scripts/.skillpress/` 里，整个拖进来毫无意义还会拖几百兆）
  if [ -d "$d/scripts" ]; then
    mkdir -p "$dest/scripts"
    for f in "$d"/scripts/*; do
      [ -f "$f" ] || continue
      base=$(basename "$f")
      case "$base" in .*|*.md) continue ;; esac
      cp "$f" "$dest/scripts/$base"
    done
  fi
  if [ "$found" = 1 ]; then
    n_skills=$((n_skills + 1))
  else
    rm -rf "$dest"
  fi
done

# ── 副本的**前提**必须自己验一遍（不然"两边读法相同"这句话就是空的）────────────────
fail=0
if [ -e "$OUT/skills/skillpress/WEBSITE.md" ]; then
  echo "✗ 副本里还有 WEBSITE.md —— 旧实现不认识它，两边读法就不同了（这条前提破了）"; fail=1
fi
if [ -e "$OUT/skillpress.ignore.md" ]; then
  echo "✗ 副本上一级有 ignore 清单 —— 旧实现不跳过任何一份，两边读法就不同了"; fail=1
fi
# 空集合守卫：语料路径写错时这里会造出一份空副本，而两个引擎在同一份空内容上"逐字节一致"是**假绿**
if [ "$n_skills" -lt 1 ]; then
  echo "✗ 副本里一份 skill 都没有（语料路径不对？）—— 判据不允许在空集合上通过"; fail=1
fi
for s in $(cd "$OUT/skills" && ls -d */ 2>/dev/null | tr -d '/'); do
  [ -f "$OUT/skills/$s/SKILL.md" ] || { echo "✗ 副本里的 $s 没有 SKILL.md（拷漏了？）"; fail=1; }
done
n_md=$(find "$OUT/skills" -name '*.md' | wc -l | tr -d ' ')
[ "$n_md" -ge 5 ] || { echo "✗ 副本里只有 $n_md 个 .md —— 拷漏了？"; fail=1; }
[ "$fail" = 0 ] || exit 1

echo "（副本：$n_skills 份 skill / $n_md 个 .md —— 已去掉 WEBSITE.md，且上一级没有忽略清单）" >&2
echo "$OUT/skills"
