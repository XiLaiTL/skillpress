#!/usr/bin/env bash
# normalize-gen.sh —— **壳子**：真实现是 `tools/normalize-gen.mbtx`（2026-10-07，② 的第三件）。
#
#   bash tools/normalize-gen.sh <生成物文件>   # 归一化后打到 stdout
#   bash tools/normalize-gen.sh --selftest     # 自证：边界还在（六条）
#
# ⚠️ 为什么要一层壳：`.mbtx` 有两条"调用点不该各自记住"的约定 ——
#    **必须带 `--target js`**（它用了 `extern "js"` 往 stderr 写用法；而 `moon run` 不带
#    `--target` 会走 wasm 后端），以及 `NODE_OPTIONS` 里那条关掉 Node 噪声警告的开关。
set -u
cd "$(dirname "$0")/.."
# ⚠️ moon 的 js 产物是 **CJS 风格的 `.js`**，而 `package.json` 里**不能**写 `"type": "module"`
#    （写了 Node 会按 ESM 解析那份产物，而它里面是 `require(...)` ⇒ 当场 ReferenceError，实测踩过）。
export NODE_OPTIONS="${NODE_OPTIONS:-} --disable-warning=MODULE_TYPELESS_PACKAGE_JSON"
exec moon run --target js tools/normalize-gen.mbtx "$@"
