#!/usr/bin/env bash
# verify.sh —— **壳子**：站点判据的真实现是 `skillpress-native verify`（`engine/site/`，P8.3）。
#
#   bash tools/verify.sh [--skills <内容根>] [--app <站点实例>] [--shot <png>] [--keep]
#
# ⚠️ 为什么要一层壳：那条路**只有 native 那份 CLI 有**（站点判据要 async 的 http server /
#    websocket / process，而它们在 `moonbitlang/async` 的 js 目标上没有实现）⇒ 要先编一次。
#    把"编一次"固定在这一处，比让每个调用点各记一遍强 —— 与 `native-parity.sh` 的前置同一个形状。
set -u
cd "$(dirname "$0")/.."
EXE=""
for c in _build/native/debug/build/cmd/skillpress-native/skillpress-native.exe \
         _build/native/debug/build/cmd/skillpress-native/skillpress-native; do
  [ -f "$c" ] && EXE="$c"
done
if [ -z "$EXE" ] || [ -n "$(find engine cmd -name '*.mbt' -newer "$EXE" 2>/dev/null | head -1)" ]; then
  echo "（前置：native CLI 缺失或过期 ⇒ 先 moon build cmd/skillpress-native --target native）"
  if ! timeout 1800 moon build cmd/skillpress-native --target native 2>&1 | tail -3; then
    echo "✗ 前置失败：native CLI 编不出来（站点判据要一次 C 工具链）" >&2
    exit 2
  fi
  for c in _build/native/debug/build/cmd/skillpress-native/skillpress-native.exe \
           _build/native/debug/build/cmd/skillpress-native/skillpress-native; do
    [ -f "$c" ] && EXE="$c"
  done
fi
[ -n "$EXE" ] || { echo "✗ 找不到 native CLI" >&2; exit 2; }
exec "$EXE" verify "$@"
