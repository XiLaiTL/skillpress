#!/usr/bin/env bash
# published-check.sh —— **发布后**的判据（发布清单 §7 第 7 条）：**从 registry** 装下来，在**另一个工程**里编过。
#
#   bash tools/published-check.sh              # 默认取 moon.mod 里那一版
#   bash tools/published-check.sh 0.1.0        # 指定版本
#
# ── 为什么必须单独有这一条（这次不再自己发明，照 moobile 的 `tools/check_published.sh` 来）──────
# `tools/consumer-check.sh` 验的是"**打出来的 zip** 能跑"（发布前就能跑）；这一条验的是
# **registry 上那一版**能被人装下来、编过、并且里面的东西对得上。两者不能互相替代：
#   · 发布包 = `.moonignore` 过滤后的产物，**跟工作区不是同一份东西**（历史教训遍地）；
#   · 本机工作区里 `moon.work` 指着源码 ⇒"能跑"一个字节都不算数。
#
# ⚠️ 两条实测过的环境坑（都在这里处理掉，不让它们伪装成"包没发出去"）：
#   ① 本机 git 全局配了代理 `127.0.0.1:7890`；代理没开时 `moon add` 拉索引会失败，报的却是
#      `no version satisfies requirement …` —— 看着像"没发布"，其实是**索引没刷新**。
#      所以第一次失败时会用 `GIT_CONFIG_*` 把代理关掉重试一次。
#   ② 依赖**已经**写在 `moon.mod` 里时，`moon add` 只说 "already exists, will not update it"
#      并且**不下载** —— 下载发生在 `moon check`。所以这里走真实用户流程：
#      **空 `moon.mod` → `moon add` → `moon check`**（这时才落盘）。
set -u
cd "$(dirname "$0")/.."
PROG=$(pwd -W)

VER="${1:-$(grep -oE '^version *= *"[^"]+"' moon.mod | head -1 | sed 's/.*"\(.*\)"/\1/')}"
[ -n "$VER" ] || { echo "✗ 从 moon.mod 里读不出版本，也没给参数"; exit 2; }
echo "验的是 registry 上的 XiLaiTL/skillpress@$VER"

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
cd "$W"

# ── 一个**空**的消费者工程（新工程没有依赖 ⇒ 后面 moon add 才会真的下载）──────────────
cat > moon.mod <<'EOF'
name = "XiLaiTL/published-probe"

version = "0.0.1"

preferred_target = "js"
EOF

echo "① moon add（从 registry 装）"
add() {
  if [ "${NO_PROXY_RETRY:-0}" = 1 ]; then
    env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.proxy GIT_CONFIG_VALUE_0= \
      GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_1=https.proxy GIT_CONFIG_VALUE_1= \
      moon add "XiLaiTL/skillpress@$VER" > "$W/add.log" 2>&1
  else
    moon add "XiLaiTL/skillpress@$VER" > "$W/add.log" 2>&1
  fi
}
if ! add; then
  echo "  · 第一次没成 —— 关掉 git 代理重试一次（本机的老坑：代理没开时索引拉不下来，"
  echo "    而报错长得像「这个版本不存在」，见 moobile 那边的同款补记）"
  NO_PROXY_RETRY=1 add || true
fi
if ! grep -q 'skillpress' moon.mod; then
  echo "✗ 装不上。两种可能，都要看下面这段输出："
  echo "    ① **还没发布这一版**（那就先跑 \`moon publish\`）—— ⚠️ 这句里的反引号必须转义："
  echo "       不转义的话 bash 会把它当**命令替换**，于是这条判据自己**真的会去跑一次 moon publish**"
  echo "       （2026-10-06 实测踩到：它失败了，只因那个临时探针工程的 moon.mod 缺 license 字段）；"
  echo "    ② 本机 git 代理/网络问题（报错里若是 \`no version satisfies requirement\`，多半是这个）。"
  sed 's/^/      /' "$W/add.log" | tail -8
  exit 1
fi
echo "  ✓ moon.mod 里已经写上依赖：$(grep skillpress moon.mod | tr -d ' ')"

echo "② 写一个**真的用它**的探针，再 moon check（这一步才真下载到 .mooncakes/）"
mkdir -p probe
cat > probe/moon.pkg <<'EOF'
import {
  "XiLaiTL/skillpress/engine/highlight" @hl,
}
EOF
cat > probe/probe.mbt <<'EOF'
///|
/// 消费者探针：只调一个纯函数，证明"依赖解析 + 编译"成立。
pub fn color_of_keyword() -> Int {
  let (idx, _) = @hl.palette_of("keyword")
  idx
}
EOF
cat > moon.pkg <<'EOF'
import {
  "XiLaiTL/published-probe/probe",
}
EOF
if moon check --target js > "$W/check.log" 2>&1; then
  echo "  ✓ 编过了（从 registry 装的这一版）"
else
  echo "✗ 编不过"; tail -8 "$W/check.log" | sed 's/^/      /'; exit 1
fi

# ── ③ 装下来的那份里，**该有的东西在不在**（发布包 ≠ 工作区 ⇒ 这一条才是发布视角的复核）──
PKG=".mooncakes/XiLaiTL/skillpress"
echo "③ 发布包内容复核（跟工作区那份分开看）"
miss=0
for need in moon.mod engine/gates/moon.pkg engine/content/moon.pkg shell/moon.pkg \
  cmd/skillpress/main.mbt launcher/skillpress.mjs grammars/moonbit.wasm claims.txt \
  skills/skillpress-user/SKILL.md LICENSE THIRD-PARTY-NOTICE.md; do
  [ -e "$PKG/$need" ] || { echo "  ✗ 缺 $need"; miss=1; }
done
for bad in tools lib bin package.json skills.lock.json done-claims.txt; do
  [ -e "$PKG/$bad" ] && { echo "  ✗ 混进了不该发的：$bad"; miss=1; }
done
[ "$miss" = 0 ] && echo "  ✓ 该有的都在、不该发的一个都没有" || echo "  ✗ 见上面"

# ── ④ **从装下来的那份**跑一次门（R6/D33 那条路：包里带启动器、check 不需要 npm 依赖）────
echo "④ 从装下来的那份跑门（check 不依赖 tree-sitter）"
if [ -f "$PKG/launcher/skillpress.mjs" ]; then
  moon -C "$PKG" build cmd/skillpress --target js > "$W/build.log" 2>&1 || { echo "  ✗ 包里的 CLI 编不过"; tail -5 "$W/build.log" | sed 's/^/      /'; }
  node "$PKG/launcher/skillpress.mjs" check --repo "$W" --skills "$PKG/skills" > "$W/gate.log" 2>&1
  rc=$?
  if [ "$rc" = 0 ] || [ "$rc" = 1 ]; then
    echo "  ✓ 门跑起来了（rc=$rc，末行：$(tail -1 "$W/gate.log")）"
  else
    echo "  ✗ 门跑不起来（rc=$rc）"; tail -5 "$W/gate.log" | sed 's/^/      /'
  fi
else
  echo "  ✗ 包里没有 launcher/skillpress.mjs —— 拿到包的人没有入口（见 D33）"
fi

echo
echo "✓ 发布视角验完：registry 上这一版装得下来、编得过、内容对得上"
echo "  （⚠️ 想验「内容仓那 7 份 skill 真印成站点」的话，那是 acceptance.sh 的 A3，不是在 registry 这一侧）"
