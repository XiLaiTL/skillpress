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

readme = "README.md"

repository = "https://github.com/XiLaiTL/skillpress"

preferred_target = "js"

// ⚠️ `XiLaiTL/moobile` 是 **shell 包**带来的依赖：站点界面本身就是个 moobile 应用
//    （`@html` / `@style` / `@cmd` / `@moobile`）。模块级依赖**随包发布** ⇒ 用引擎的人也会下载 moobile
//    （见 moobile 自己的 AGENTS.md 那条）。这是 P6「一个月亮包装下引擎 + 界面」的必然代价；
//    要拆开只能把 skillpress 拆成两个模块（引擎一个、界面一个）。
//
// ⚠️ `moonbitlang/async` 是 **P8.3 站点判据**带来的依赖（`engine/site/`：自起静态服务 +
//    起无头 Chrome + 走 CDP 跑 22 条断言）。**它不额外增加任何下载**：这个版本本来就已经是
//    传递依赖（`mizchi/markdown` 要 `async@0.20.3`、`XiLaiTL/moobile` 要 `async@0.21.0`
//    ⇒ 解析出来就是下面这个 0.21.0）。直接声明只是"我确实要用它"的如实记录。
//    ⚠️ **代价照写**：`async` 的 websocket / http-server / process 在 **js 上没有实现**
//    （那些文件只编 `native`/`wasm`）⇒ 站点判据只能跑 **native**（要 C 工具链）。
//    这条与"js 那条路只要 Node"是两回事，别混着读。
import {
  "mizchi/markdown@0.8.3",
  "XiLaiTL/moobile@0.5.0",
  "moonbitlang/x@0.5.5",
  "moonbitlang/async@0.21.0",
}
