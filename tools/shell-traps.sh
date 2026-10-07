#!/usr/bin/env bash
# shell-traps.sh —— **壳子**：真实现是 `tools/shell-traps.mbtx`（2026-10-07，② 的第二件）。
#
#   bash tools/shell-traps.sh              # 站岗
#   bash tools/shell-traps.sh --selftest   # 四向诱饵
#
# ⚠️ 为什么要一层壳：`.mbtx` 有两条"调用点不该各自记住"的约定 ——
#    **必须带 `--target js`**（不带会走 wasm 后端，本机不一定备了那套 std 产物），
#    以及它读的是**相对路径** `tools/`（**要在仓根跑**）。
#    钉在一处比散在每个调用点强 —— moobile 那边的 `tools/mb.sh` 就是同一个理由。
set -u
cd "$(dirname "$0")/.."
# ⚠️ `--disable-warning=MODULE_TYPELESS_PACKAGE_JSON`：moon 的 js 产物是 **CJS 风格的 `.js`**，
#    而 `package.json` 里**不能**写 `"type": "module"` —— 写了 Node 会按 ESM 解析那份产物，
#    而它里面是 `require(...)` ⇒ 当场 `ReferenceError: require is not defined in ES module scope`（实测踩过）.
#    所以那条警告只能从这一侧关掉（Node 22+ 的 `--disable-warning=<code>`），别去动 package.json。
export NODE_OPTIONS="${NODE_OPTIONS:-} --disable-warning=MODULE_TYPELESS_PACKAGE_JSON"
exec moon run --target js tools/shell-traps.mbtx "$@"
