#!/usr/bin/env bash
# mk-parity-corpus.sh —— 造一份**两个引擎读法完全相同**的语料副本（对账用）。打印副本的内容根。
#
#   SKILLPRESS_CORPUS=<真内容根> bash tools/mk-parity-corpus.sh
#
# ── 为什么需要它（“干净副本”）─────────────────────────────
# R2 起，内容仓有 `skillpress/WEBSITE.md`（首页源）与 `skillpress.ignore.md`（忽略清单），而 `tools/site-source.sh` 的 C10
# 场景要的是**一份没有这两样的副本**（回到 R2/R4 之前的形状）。
# ⚠️ 2026-10-07（D43）：它原来还服务于“旧实现 vs 新引擎”那几条对账，而那些已随 `lib/` 退役；#    现在它只剩 C10 这一个用途。

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

# ── 去掉"新功能会改变读法"的那两样（**必须在拷完之后删**）──────────────────────
# ⚠️ 第一版把 `rm` 写在拷贝循环**之前** —— R2 之前没有 WEBSITE.md，所以那个顺序 bug 看不出来；
#    R2 落地当天它立刻冒出来（副本里还有 WEBSITE.md ⇒ 前提守卫判红）。这就是"顺序也是判据"。
rm -f "$OUT/skills/skillpress/WEBSITE.md"
rm -f "$OUT/skillpress.ignore.md"

# ── 副本的**前提**必须自己验一遍（不然"两边读法相同"这句话就是空的）────────────────
# ⚠️ 下面那两条守卫是**兜底**：摘除动作在上面两行 `rm -f` 里，正常情况它们**永远不触发**
#    （实测 2026-10-07：有人写了一条"往语料里放 WEBSITE.md ⇒ 应当被拒绝"的诱饵，
#    结果它红着说"没被拦住" —— 因为这里**自己会摘掉**，诱饵测的是一条结构上不可能发生的路径）。
#    它们真正防的是"那两行 `rm -f` 哪天被改坏/删掉"。
#    而"这条前提**要紧**"这件事，由 `tools/file-parity.sh --selftest` 的 ⑤ 现证一遍：
#    前提一旦被破（副本里留着 WEBSITE.md），两个引擎的产物**真的会分叉**。
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
