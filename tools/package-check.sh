#!/usr/bin/env bash
# package-check.sh —— **发布清单第 2 条**（包内容复核）的判据：`moon package --list` 的清单
# 必须**含该含的、不含不该含的**。
#
#   bash tools/package-check.sh
#   bash tools/package-check.sh --selftest    # 诱饵：自造清单，三向都要能被看见（绿 / 多了 / 少了）
#
# ── 为什么要有它 ──────────────────────────────────────────────────────────────
# 原先这一条是"发布前人去读一遍 `moon package --list`"。而人不会每次发布都读、也读不了 grep 那么细。
# 实测（2026-10-06）：清单里赫然有 `lib\*.mjs`（冻结的旧引擎）、`bin\skillpress.mjs`（旧 CLI）、
# `package.json` / `package-lock.json` —— 全是**开发期**的东西，发出去就是让用户拿到两个引擎、其中一个旧版。
# 该含 / 不该含两张清单与理由写在 `.moonignore` 的文件头（决定 D24）。
#
# ⚠️ 读数边界：`moon package --list` 要**编译本模块** ⇒ 只有**模块没人在改时**读数才可信。
#    ⚠️ 所以**诱饵不走 moon**（`--selftest` 拿自造清单喂检查器）：把"判据自己会不会红"绑在
#    "本模块此刻编不编得过"上，就等于**别人一改代码，诱饵先失效**。
set -u
cd "$(dirname "$0")/.."

# ── 该含的（文件；`<目录>/:<最少文件数>` 表示目录至少要有几个文件）────────────────
REQUIRED="
moon.mod
LICENSE
README.md
SPEC.md
SKILLS.md
DRIFT.md
PLAN.md
THIRD-PARTY-NOTICE.md
claims.txt
done-claims.txt
engine/content/moon.pkg
engine/highlight/moon.pkg
engine/gates/moon.pkg
shell/moon.pkg
cmd/skillpress/main.mbt
cmd/skillpress/moon.pkg
grammars/moonbit.wasm
grammars/PROVENANCE.md
skills/skillpress-dev/SKILL.md
skills/skillpress-user/SKILL.md
engine/gates/:8
shell/:8
skills/:6
"
# ── 不该含的（正则；命中即红）──────────────────────────────────────────────────
FORBIDDEN="
^lib/
^bin/
^tools/
^_build/
^node_modules/
^\.mooncakes/
^package\.json$
^package-lock\.json$
^skills\.lock\.json$
^_scratch/
"

# 检查一份清单：打印问题，return 不合格数
check_list() { # $1 = 清单文件
  local f=$1 bad=0
  local files n
  files=$(grep -E '^[A-Za-z0-9_./\\-]+$' "$f")   # moon 的日志行都带空格/冒号/框线，一过正则就滤掉了
  files=${files//\\//}
  n=$(printf '%s\n' "$files" | grep -c .)

  # 空集合守卫：解析一变坏就只读到 0 个文件 —— 那时"该含的都缺"会报一堆假红，
  # 万一将来改成"缺了才报"，空集合就**静默通过**了。先钉住下限。
  if [ "$n" -lt 40 ]; then
    echo "✗ 只从清单里解析出 $n 个文件（实测应有 60+）—— 解析坏了，或包真空了（这条判据不允许在空集合上通过）"
    return 1
  fi

  local req dir min got hit
  while IFS= read -r req; do
    [ -z "$req" ] && continue
    case "$req" in
      */:*) dir="${req%%:*}"; min="${req##*:}"
            got=$(printf '%s\n' "$files" | grep -c "^$dir") ;;
      */)   dir="$req"; min=1
            got=$(printf '%s\n' "$files" | grep -c "^$dir") ;;
      *)    if ! printf '%s\n' "$files" | grep -qxF "$req"; then
              echo "✗ 包里**缺**：$req —— 它是发布契约的一部分（见 .moonignore 的文件头）"
              bad=$((bad + 1))
            fi
            continue ;;
    esac
    if [ "$got" -lt "$min" ]; then
      echo "✗ 包里 **$dir 只有 $got 个文件**（至少要 $min）—— 这个包被掏空了？"
      bad=$((bad + 1))
    fi
  done <<< "$REQUIRED"

  local pat
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    hit=$(printf '%s\n' "$files" | grep -E "$pat" | head -4)
    if [ -n "$hit" ]; then
      echo "✗ 包里**混进了不该发布的**（匹配 $pat）："
      printf '%s\n' "$hit" | sed 's/^/      /'
      bad=$((bad + 1))
    fi
  done <<< "$FORBIDDEN"
  return "$bad"
}

# ── 诱饵：三向都要被看见 —— 合规清单必须**绿**、多一个不该发的必须红、少一个该发的必须红 ──
if [ "${1:-}" = "--selftest" ]; then
  W=$(mktemp -d)
  # 合成一份"合规清单"：REQUIRED 里的文件 + 凑够目录下限 + 补足 40 行
  {
    printf '%s\n' "$REQUIRED" | grep -v '/:' | grep -v '/$'
    for i in 1 2 3 4 5 6 7 8 9 10; do echo "engine/gates/g$i.mbt"; done
    for i in 1 2 3 4 5 6 7 8 9 10; do echo "shell/s$i.mbt"; done
    for i in 1 2 3 4 5 6 7 8; do echo "skills/skillpress-dev/references/r$i.md"; done
    for i in 1 2 3 4 5 6 7 8; do echo "engine/content/c$i.mbt"; done
  } > "$W/base.txt"
  cp "$W/base.txt" "$W/extra.txt";  echo "lib/gen-content.mjs" >> "$W/extra.txt"
  grep -v '^shell/moon.pkg$' "$W/base.txt" > "$W/missing.txt"

  out_base=$(SKILLPRESS_PKG_LIST="$W/base.txt" bash "$0" 2>&1); r_base=$?
  out_extra=$(SKILLPRESS_PKG_LIST="$W/extra.txt" bash "$0" 2>&1); r_extra=$?
  out_missing=$(SKILLPRESS_PKG_LIST="$W/missing.txt" bash "$0" 2>&1); r_missing=$?
  rm -rf "$W"

  ok=1
  [ "$r_base" = 0 ] || { ok=0; echo "✗ 诱饵(绿)：合规清单居然不通过 —— 判据是「永远红」的？"; printf '%s\n' "$out_base" | head -4 | sed 's/^/      /'; }
  { [ "$r_extra" != 0 ] && printf '%s' "$out_extra" | grep -q '混进了不该发布的'; } || { ok=0; echo "✗ 诱饵(多了)：塞进 lib/ 没被点名"; }
  { [ "$r_missing" != 0 ] && printf '%s' "$out_missing" | grep -q '包里\*\*缺\*\*：shell/moon.pkg'; } || { ok=0; echo "✗ 诱饵(少了)：抽掉 shell/moon.pkg 没被点名"; }
  if [ "$ok" = 1 ]; then
    echo "✓ 诱饵生效：合规清单绿、多一个不该发的被点名、少一个该发的被点名（三向都活着）"
    exit 0
  fi
  echo "✗ 诱饵没生效 —— 这条判据不可信"; exit 1
fi

# ── 主路径：现跑 `moon package --list`（`SKILLPRESS_PKG_LIST` 可注入清单，给诱饵与调试用）──
LIST=./_build/package-list.txt
mkdir -p ./_build
if [ -n "${SKILLPRESS_PKG_LIST:-}" ]; then
  cp "$SKILLPRESS_PKG_LIST" "$LIST"; SRC="注入：$SKILLPRESS_PKG_LIST"
else
  if ! moon package --list > "$LIST" 2>&1; then
    echo "✗ moon package --list 跑失败（有人正在改这个模块？）—— 末尾："
    tail -5 "$LIST" | sed 's/^/    /'
    exit 1
  fi
  SRC="现跑 moon package --list"
fi
n=$(grep -E '^[A-Za-z0-9_./\\-]+$' "$LIST" | grep -c .)
echo "包内容复核（$SRC）：$n 个文件"
out=$(check_list "$LIST"); code=$?
if [ "$code" = 0 ]; then
  echo "✓ 包内容复核通过：该含的都在、不该含的一个都没有"
else
  printf '%s\n' "$out"
  echo "✗ 包内容复核：$code 处不合格 —— 清单与理由见 .moonignore 的文件头"
  exit 1
fi
