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
# ⚠️ **产物路径不许写死**（2026-10-07 实测踩到）：moon 的产物路径取决于**模块在构建根里的身份** ——
#    独立模块 `_build/native/debug/build/<pkg>/…`，**工作区成员**多一层 `<作者>/<模块>/` 前缀。
#    程序根加了 `moon.work` 之后走后面那条，而这里写死的是前面那条 —— 它**还在盘上**（旧时间戳），
#    于是会**优先挑到旧二进制**：症状是"判据红得莫名其妙"（跑的是上一次编的东西），不是报错。
#    ⇒ 两处都找、取 mtime 最新的那份。（同一课在 `site-source.sh` 的 `dev.js` 与
#    `launcher/skillpress.mjs` 的 js 产物上各演过一次。）
pick_native() {
  ls -t _build/native/debug/build/cmd/skillpress-native/skillpress-native.exe \
        _build/native/debug/build/cmd/skillpress-native/skillpress-native \
        _build/native/debug/build/*/*/cmd/skillpress-native/skillpress-native.exe \
        _build/native/debug/build/*/*/cmd/skillpress-native/skillpress-native 2>/dev/null | head -1
}
EXE="$(pick_native)"
if [ -z "$EXE" ] || [ -n "$(find engine cmd -name '*.mbt' -newer "$EXE" 2>/dev/null | head -1)" ]; then
  echo "（前置：native CLI 缺失或过期 ⇒ 先 moon build cmd/skillpress-native --target native）"
  if ! timeout 1800 moon build cmd/skillpress-native --target native 2>&1 | tail -3; then
    echo "✗ 前置失败：native CLI 编不出来（站点判据要一次 C 工具链）" >&2
    exit 2
  fi
  EXE="$(pick_native)"
fi
[ -n "$EXE" ] || { echo "✗ 找不到 native CLI" >&2; exit 2; }
exec "$EXE" verify "$@"
