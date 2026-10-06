#!/usr/bin/env bash
# _ensure-built.sh —— 判据脚本的**前置**：确保 CLI 的 js 产物是新鲜的（需要才编）。
#
# 为什么要有它（干净克隆里实测到的）：四条对账判据都要 `node tools/run-js.mjs …` 吃**编出来的 js**，
# 而 `_build/` 不在版本库里 ⇒ **干净克隆里它们全失败**（本机绿不算数，克隆能跑才算）。
# 之前每条脚本都得先被人手动 `moon build`，这个前置把那条隐式步骤变成显式的。
#
# 判"新鲜"的口径：产物不存在，或**有比它更新的 .mbt 源** ⇒ 重编一次。
# 编不过就让调用方去失败（错误信息由 `moon build` 自己给，别在这里吞掉原因）。
set -u

CLI=./_build/js/debug/build/cmd/skillpress/skillpress.js
need=0
if [ ! -f "$CLI" ]; then
  need=1
else
  newer=$(find engine cmd -name "*.mbt" -newer "$CLI" 2>/dev/null | head -1)
  [ -n "$newer" ] && need=1
fi

if [ "$need" = 1 ]; then
  echo "（前置：CLI 产物缺失或过期 ⇒ 先 moon build cmd/skillpress --target js）"
  if ! timeout 900 moon build cmd/skillpress --target js 2>&1 | tail -3; then
    echo "✗ 前置失败：编不出来" >&2
    exit 2
  fi
fi
