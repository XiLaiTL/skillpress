#!/usr/bin/env bash
# attach-check.sh —— **脚手架 `attach` 的判据**。
#
#   bash tools/attach-check.sh              # 站岗
#   bash tools/attach-check.sh --selftest   # 诱饵：把"必须绿"的那几条反过来验一遍
#
# ── 为什么要有它 ──────────────────────────────────────────────────────────────
# `attach` 写的是**别人的仓库**，而且它坏掉的样子大多是"**看着像装好了**"：
#   · 产物不幂等（第二次跑出来的书架与第一次不一样）—— 页面照常渲染，只是内容悄悄变了；
#   · 该跳过的文件被覆盖（把人家手写的首页冲掉）；
#   · 缺理由的忽略清单照写（那份 skill 照常上桌，而你以为它被藏起来了）；
#   · 算到一半失败还落下一半文件 —— 下次再跑被"不覆盖"挡住，于是永远缺那一半。
# 所以断言一律**逐字节比**（sha256 / cmp），不靠"看着对"。
#
# ⚠️ 写这个脚本时踩到的两个 shell 坑（都写在这儿，免得下一个人再踩）：
#   ① **双引号里的反引号会真的被执行**（消息里想打反引号必须写成 \`）；
#   ② `printf '...\n...' | 命令` 那种"一行里带转义换行"的写法别用，改 `printf '%s\n' a b c`。
set -u
cd "$(dirname "$0")/.."

CLI="node tools/run-js.mjs"
fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }

# ── 夹具：内容根（两份 skill）+ README（刻意放三种链接：能对上账的 / 死链 / 外链）──────
mk_repo() { # $1 = 目录；$2 = 1 表示不放 README
  local C="$1"
  rm -rf "$C"
  mkdir -p "$C/skills/alpha" "$C/skills/beta"
  for s in alpha beta; do
    cat > "$C/skills/$s/SKILL.md" <<MD
---
name: $s
description: 夹具里的 $s
whenToUse: 测试
---

# $s

## 一节

正文。
MD
  done
  [ "${2:-}" = "1" ] && return 0
  cat > "$C/README.md" <<'MD'
# 夹具仓

判据用的仓库。

## [先读 alpha](skills/alpha/SKILL.md)

> 纯链接节：目标是书架上的一页。

## [外链不该当栏](https://example.com/x)

外链指不到站点上的页。

## 去哪看

- [alpha](skills/alpha/SKILL.md)
- [站点](https://example.com)
MD
}

APP=skills/skillpress/scripts/.skillpress
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

# ── ① 全新夹具：产物齐全 + 那份语料真的能印成站 ──────────────────────────────────
echo "① 全新夹具：attach 一次"
mk_repo "$W/a"
if $CLI attach --repo "$W/a" --skills "$W/a/skills" > "$W/a.log" 2>&1; then
  ok "退码 0"
else
  bad "退码非 0（$(tail -3 "$W/a.log" | tr '\n' ' ')）"
fi
missing=""
for f in skills/skillpress/WEBSITE.md skills/skillpress/SKILL.md \
  "$APP/moon.mod" "$APP/moon.pkg" "$APP/moon.work" "$APP/app.mbt" "$APP/package.json" \
  "$APP/index.html" "$APP/index.js" "$APP/App.js" "$APP/build-web.mjs" "$APP/serve-web.mjs" \
  "$APP/verify.mjs" "$APP/registry.generated.js" "$APP/.gitignore" \
  "$APP/content/moon.pkg" "$APP/content/content.generated.mbt"; do
  [ -f "$W/a/$f" ] || missing="$missing $f"
done
[ -z "$missing" ] && ok "17 个产物一个不少" || bad "缺产物：$missing"
# 生成物里**一个占位符都不许剩**：替换漏了不会报错，只会静静编不过
if grep -rq '{{' "$W/a/$APP" 2>/dev/null; then
  bad "生成物里还有没替换的占位符：$(grep -rho '{{[^}]*}}' "$W/a/$APP" | head -3 | tr '\n' ' ')"
else
  ok "生成物里没有残留占位符"
fi
# "能真的印成站"才是脚手架存在的意义 —— 拿引擎在那份语料上现跑一遍
if $CLI gen-file "$W/a/skills" > "$W/e.mbt" 2> "$W/e.err"; then
  if grep -q 'slug: "alpha"' "$W/e.mbt" && grep -q 'slug: "beta"' "$W/e.mbt"; then
    ok "生成出来的语料能被引擎印成站（alpha/beta 都在）"
  else
    bad "生成物里没有 alpha/beta"
  fi
else
  bad "引擎在那份语料上退码非 0（$(tail -2 "$W/e.err" | tr '\n' ' ')）"
fi

# ── ② 幂等：连跑两遍，内容包逐字节不变；再验"人写的文件不被覆盖" ──────────────────
echo "② 幂等（第二遍不许改变任何东西）"
before=$(sha256sum "$W/a/$APP/content/content.generated.mbt" | cut -d' ' -f1)
$CLI attach --repo "$W/a" --skills "$W/a/skills" > "$W/a2.log" 2>&1
rc=$?
after=$(sha256sum "$W/a/$APP/content/content.generated.mbt" | cut -d' ' -f1)
[ "$rc" = 0 ] && ok "第二遍退码 0" || bad "第二遍退码 $rc（$(tail -2 "$W/a2.log" | tr '\n' ' ')）"
[ "$before" = "$after" ] && ok "内容包逐字节不变（书架不随跑的次数漂）" || bad "内容包变了 —— 产物不幂等"
# 手改首页：这条断言必须**能看见**改动（不然"没被覆盖"可能只是"本来就没写"）。
# ⚠️ 探针用**受支持的构造**：原始 HTML 会被引擎点名（那是它该干的事），拿它当"手写痕迹"会红在别处。
home_before=$(sha256sum "$W/a/skills/skillpress/WEBSITE.md" | cut -d' ' -f1)
printf '\n手写的一句话。\n' >> "$W/a/skills/skillpress/WEBSITE.md"
home_edited=$(sha256sum "$W/a/skills/skillpress/WEBSITE.md" | cut -d' ' -f1)
$CLI attach --repo "$W/a" --skills "$W/a/skills" > "$W/a3.log" 2>&1
grep -q '手写的一句话' "$W/a/skills/skillpress/WEBSITE.md" &&
  ok "手写过的首页**没被覆盖**（人写的东西不许被产物冲掉）" || bad "首页被覆盖了 —— 手写的内容没了"
grep -q '⊘ 已经有，没动它' "$W/a3.log" && ok "跳过了哪几个**点名**了（不静默）" || bad "没点名跳过的文件"
[ "$home_before" != "$home_edited" ] &&
  ok "（自证：那条「没被覆盖」确实在比一个会变的 sha）" || bad "sha 没变，断言可能没在比对"
# 首页被跳过时，内容包必须按**盘上那一份**生成，否则站上的内容与首页脱节（press --check 会红）
$CLI gen-file "$W/a/skills" > "$W/fresh.mbt" 2>/dev/null
cmp -s "$W/a/$APP/content/content.generated.mbt" "$W/fresh.mbt" &&
  ok "内容包与引擎现跑的一致（人改过首页之后也对得上）" ||
  bad "内容包与引擎现跑的不一致 —— 站点内容与首页脱节了"

# ── ③ 坏输入：必须退 2、点名、且**一个字节都不写** ────────────────────────────────
echo "③ 坏输入（退 2 + 不落盘）"
bad_case() { # $1 = 名字；最后一个是期望点名的关键词；中间是 attach 的参数
  local name="$1"; shift
  local kw="${!#}"
  mk_repo "$W/b-$name"
  $CLI attach --repo "$W/b-$name" --skills "$W/b-$name/skills" "$@" > "$W/b-$name.log" 2>&1
  local rc=$?
  if [ "$rc" != 2 ]; then bad "③ $name：退码是 $rc（应当是 2）"; return; fi
  if [ -d "$W/b-$name/skills/skillpress" ]; then bad "③ $name：有问题还是落盘了半成品"; return; fi
  grep -qF "$kw" "$W/b-$name.log" && ok "③ $name 被点名（退 2、一个字节都没写）" || bad "③ $name 没点到「$kw」"
}
bad_case noreason --ignore 'beta' '没写理由'
bad_case typo --ignore 'btea=手滑打错' '没有这份 skill'
bad_case nohome --home "$W/不存在.md" '读不到'

# ── ④ dry-run：退 0 且磁盘上一个字节都没动 ──────────────────────────────────────
echo "④ dry-run"
mk_repo "$W/d"
$CLI attach --repo "$W/d" --skills "$W/d/skills" --dry-run > "$W/d.log" 2>&1
[ ! -d "$W/d/skills/skillpress" ] && ok "dry-run 没写任何东西" || bad "dry-run 居然写了"
grep -q 'dry-run' "$W/d.log" && ok "dry-run 说了自己要写什么" || bad "dry-run 什么都没说"

# ── ⑤ README → 首页：能对上账的改写成站点口径、对不上的降级**并打印** ──────────────
echo "⑤ README → 首页的改写"
grep -q '^## \[先读 alpha\](alpha/SKILL.md)$' "$W/a/skills/skillpress/WEBSITE.md" &&
  ok "标题里的链接改成了站点口径（skills/alpha/SKILL.md 变成 alpha/SKILL.md）" ||
  bad "标题链接没改写对"
grep -q '^## 外链不该当栏$' "$W/a/skills/skillpress/WEBSITE.md" &&
  ok "指不到站点上的链接**降级成纯文本标题**" || bad "外链那条没降级"
grep -q '^## 书架$' "$W/a/skills/skillpress/WEBSITE.md" &&
  ok "补了一栏「书架」（下拉菜单）" || bad "没有补书架栏"
grep -q '降级成纯文本标题' "$W/a.log" && ok "降级**打印**了（悄悄改人家的文档是最坏的一种帮忙）" || bad "降级没打印"

# ── ⑥ 没有 README ⇒ 回退生成模板首页 ─────────────────────────────────────────────
echo "⑥ 没有 README 的回退"
mk_repo "$W/f" 1
$CLI attach --repo "$W/f" --skills "$W/f/skills" > "$W/f.log" 2>&1 &&
  ok "退码 0" || bad "没有 README 时退码非 0"
grep -q '^# f$' "$W/f/skills/skillpress/WEBSITE.md" &&
  ok "回退的模板首页有站名（用仓目录名兜底）" || bad "回退首页没有站名"
grep -q '模板首页' "$W/f.log" && ok "回退**打印**了（不静默）" || bad "回退没打印"

# ── ⑦ 交互式：管道喂答案也要能走（只认终端的话，这条逻辑永远测不到）──────────────
echo "⑦ 交互式（管道喂答案）"
mk_repo "$W/g"
# 问话顺序 = 名字序（alpha / beta / skillpress）：空行 = alpha 上架、n = beta 不上架、第三行是理由
printf '%s\n' '' 'n' '夹具里还没写完' |
  $CLI attach --repo "$W/g" --skills "$W/g/skills" --interactive > "$W/g.log" 2>&1
rc=$?
[ "$rc" = 0 ] && ok "交互式退码 0" || bad "交互式退码 $rc（$(tail -2 "$W/g.log" | tr '\n' ' ')）"
grep -q '^- beta —— 夹具里还没写完$' "$W/g/skillpress.ignore.md" 2>/dev/null &&
  ok "答 n 的那份写进了忽略清单，理由也在" ||
  bad "忽略清单没写成（$(tail -2 "$W/g/skillpress.ignore.md" 2>/dev/null | tr '\n' ' ')）"
grep -q 'slug: "beta"' "$W/g/$APP/content/content.generated.mbt" &&
  bad "被忽略的 beta 还是上了书架" || ok "被忽略的没上书架"

# ── ⑧ 默认：不问、也不指定 ⇒ 全部进文档区（并且打印出来）─────────────────────────
echo "⑧ 默认全部进文档区"
mk_repo "$W/h"
$CLI attach --repo "$W/h" --skills "$W/h/skills" > "$W/h.log" 2>&1
[ ! -f "$W/h/skillpress.ignore.md" ] && ok "一份都没忽略 ⇒ 不写清单文件（空清单不如没有清单清楚）" || bad "写了空的忽略清单"
grep -q '默认全部进文档区' "$W/h.log" && ok "默认行为**打印**了" || bad "默认行为没打印"
# attach 自己写出的门口那份**也是一份 skill** ⇒ 它必须出现在书架里（否则产物不幂等）
grep -q 'slug: "skillpress"' "$W/h/$APP/content/content.generated.mbt" &&
  ok "门口那份也在书架里（书架按「写完之后」的语料算）" || bad "门口那份没进书架 —— 幂等那条会被它咬到"
# 首页源**不算子页**（D20）—— attach 传的首页标签必须是内容根口径，否则第二次跑会多出一页
grep -q 'name: "WEBSITE"' "$W/h/$APP/content/content.generated.mbt" &&
  bad "首页源被当成子页收进去了（D20）" || ok "首页源没被当成子页（D20）"

# ── ⑨ 盘上已有清单 ⇒ **必须沿用**（不读它就会把该藏的又放回书架，内容悄悄变）────────
echo "⑨ 沿用盘上已有的忽略清单"
mk_repo "$W/i"
$CLI attach --repo "$W/i" --skills "$W/i/skills" --ignore 'beta=先藏着' > /dev/null 2>&1
$CLI attach --repo "$W/i" --skills "$W/i/skills" > "$W/i.log" 2>&1
grep -q '沿用盘上那份' "$W/i.log" && ok "第二次跑读了盘上那份清单（并打印了）" || bad "没有沿用盘上那份清单"
grep -q 'slug: "beta"' "$W/i/$APP/content/content.generated.mbt" &&
  bad "被忽略的 beta 又回到书架了 —— 内容会在两次跑之间悄悄变" || ok "沿用之后书架没变（beta 仍被藏着）"
cmp -s <($CLI gen-file "$W/i/skills" 2>/dev/null) "$W/i/$APP/content/content.generated.mbt" &&
  ok "内容包与引擎现跑一致（attach 与 press 同一套口径）" || bad "内容包与引擎现跑不一致"

# ── ⑩（可选，`--build`）生成出来的实例**真的能编** ───────────────────────────────
# 为什么单列一档而不是默认跑：它要拷依赖（`node_modules` + `.mooncakes`，几十 MB）再 `moon build`
# —— 慢，而且依赖只在"本仓已经装过"时才拷得动。但它证明的是别的东西换不来的那句话：
# **产出的不是一堆文件，是一个能跑起来的站点**（"文件拷过去了"不是"能跑"）。
if [ "${1:-}" = "--build" ] || [ "${SKILLPRESS_ATTACH_BUILD:-}" = "1" ]; then
  echo "⑩（--build）生成出来的实例真的能编"
  SELF="skills/skillpress/scripts/.skillpress"
  if [ ! -d "$SELF/node_modules" ] || [ ! -d "$SELF/.mooncakes" ]; then
    echo "  ⚠️ 跳过：本仓自举那份实例还没装依赖（$SELF/node_modules 或 .mooncakes 不在）"
  else
    cp -r "$SELF/node_modules" "$W/a/$APP/node_modules"
    cp -r "$SELF/.mooncakes" "$W/a/$APP/.mooncakes"
    if (cd "$W/a/$APP" && npm run build > "$W/build.log" 2>&1); then
      [ -s "$W/a/$APP/dist/bundle.js" ] &&
        ok "生成出来的实例编过了（dist/bundle.js $(du -k "$W/a/$APP/dist/bundle.js" | cut -f1) KB）" ||
        bad "编过了但 dist/bundle.js 是空的"
    else
      bad "生成出来的实例编不过（$(tail -3 "$W/build.log" | tr '
' ' ')）"
    fi
  fi
fi

# ── 诱饵（--selftest）：把"必须绿"的几条反过来验一遍 ─────────────────────────────
if [ "${1:-}" = "--selftest" ]; then
  mk_repo "$W/s"
  if $CLI attach --repo "$W/s" --skills "$W/s/skills" --ignore 'beta=理由' > "$W/s.log" 2>&1 &&
    grep -q '^- beta —— 理由$' "$W/s/skillpress.ignore.md" &&
    ! grep -q 'slug: "beta"' "$W/s/$APP/content/content.generated.mbt"; then
    mk_repo "$W/s2"
    if $CLI attach --repo "$W/s2" --skills "$W/s2/skills" --ignore 'beta=' > /dev/null 2>&1; then
      echo "✗ 诱饵没生效：缺理由的清单居然过了 ⇒ 判据不可信"; exit 1
    fi
    echo "✓ 诱饵生效：好清单绿、缺理由的当场红 —— 两向都活着"
    exit 0
  fi
  echo "✗ 诱饵没生效：好清单那一侧不绿 ⇒ 判据不可信"; exit 1
fi

echo
if [ "$fail" = 0 ]; then
  echo "✓ 脚手架判据全过：产物齐全 + 幂等 + 不覆盖手写 + 坏输入不落盘 + 首页改写有降级有打印"
else
  echo "✗ 脚手架判据有红 —— 修完再看一遍"
  exit 1
fi
