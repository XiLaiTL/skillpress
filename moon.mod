// skillpress 引擎（MoonBit 实现，P8 起逐步接手 Node 版）。
//
// 布局（正式形状，P8.4 才收口）：
//   engine/**  —— 引擎：内容管线、通用门、上色
//   shell/**   —— 站点界面（P6 从内容侧实例抽进来）
//   cmd/**     —— CLI 入口
//   skills/**  —— 程序自己的 skill（随包发）
//
// ⚠️ `tools/**`（含 P8.0 探针与 dev 脚本）**不进包** —— 见 `.moonignore`。

name = "XiLaiTL/skillpress"

version = "0.1.0"

license = "Apache-2.0"

description = "把一堆给 AI 看的 skill 印成一个给人看的站点：内容管线、通用门、构建期上色"

preferred_target = "js"

import {
  "mizchi/markdown@0.8.3",
}
