// skillpress 引擎迁 MoonBit 的 **P8.0 探针**（临时模块，不进正式布局）。
//
// 探针只回答三件事：
//   ① `mizchi/markdown` 解析我们的 `SKILL.md` 出来的块结构，跟现有 Node 版 `gen-content` 对不对得上；
//   ② `tonyfettes/tree_sitter_*` 对**同一段代码块**上色，片段拼回去是否**逐字节等于原文**，
//      以及**未上色比例**比 Node 侧（`web-tree-sitter`）差不差；
//   ③ 到底走 **native** 还是 **js**（native 要 C 工具链；js 那条路其实就是同一个 `web-tree-sitter`）。
//
// 结论写在 `README.md`，正式实现从 P8.1 起另起模块（到时候根上的 `moon.mod` 必须用
// `.moonignore` 排掉 `/tools/`，否则探针会被打进正式包）。

name = "XiLaiTL/skillpress-spike"

version = "0.1.0"

license = "Apache-2.0"

description = "P8.0 探针：markdown 解析 + tree-sitter 上色能不能撑起 skillpress 的引擎（临时）"

preferred_target = "native"

import {
  "mizchi/markdown@0.8.3",
  "tonyfettes/tree_sitter@0.4.6",
  "tonyfettes/tree_sitter_bash@0.1.26",
  "tonyfettes/c@0.7.8",
}
