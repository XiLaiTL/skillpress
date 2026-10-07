// skillpress —— 把写给 AI 看的 skill 印成给人看的站点。
//
// 布局（一个包装下三件事）：
//   engine/**  —— 引擎：markdown → 内容包、内容门（G1–G8）、构建期上色、脚手架
//   shell/**   —— 站点界面：顶栏 / 书架树 / 正文渲染 / 目录 / 搜索 / 主题 / 路由
//   cmd/**     —— CLI（`cmd/skillpress` 跑 js；`cmd/skillpress-native` 多一条站点判据 `verify`）
//   skills/**  —— 程序自己的 skill（随包发）
//
// ⚠️ `tools/**`（判据与开发脚本）与 `_scratch/**` **不进包** —— 见 `.moonignore`。

name = "XiLaiTL/skillpress"

version = "0.1.2"

license = "Apache-2.0"

description = "把写给 AI 看的 skill 印成给人看的站点：书架树 / 本页目录 / 站内搜索 / 代码高亮，另出 llms.txt 与每页原文"

readme = "README.md"

repository = "https://github.com/XiLaiTL/skillpress"

preferred_target = "js"

// ⚠️ `XiLaiTL/moobile` 是 **shell 包**带来的依赖：站点界面本身就是个 moobile 应用
//    （`@html` / `@style` / `@cmd` / `@moobile`）。模块级依赖**随包发布** ⇒ 用引擎的人也会下载 moobile
//    （见 moobile 自己的 AGENTS.md 那条）。这是 P6「一个月亮包装下引擎 + 界面」的必然代价；
//    要拆开只能把 skillpress 拆成两个模块（引擎一个、界面一个）。
//
// ⚠️ `moonbitlang/async` 是 **P8.3 站点判据**带来的依赖（`engine/site/`：自起静态服务 +
//    起无头 Chrome + 走 CDP 跑 23 条断言）。**它不额外增加任何下载**：这个版本本来就已经是
//    传递依赖（`mizchi/markdown` 要 `async@0.20.3`、`XiLaiTL/moobile` 要 `async@0.21.0`
//    ⇒ 解析出来就是下面这个 0.21.0）。直接声明只是"我确实要用它"的如实记录。
//    ⚠️ **代价照写**：`async` 的 websocket / http-server / process 在 **js 上没有实现**
//    （那些文件只编 `native`/`wasm`）⇒ 站点判据只能跑 **native**（要 C 工具链）。
//    这条与"js 那条路只要 Node"是两回事，别混着读。
import {
  "mizchi/markdown@0.8.3",
  "XiLaiTL/moobile@0.6.0",
  "moonbitlang/x@0.5.5",
  "moonbitlang/async@0.21.0",
}
