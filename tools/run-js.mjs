#!/usr/bin/env node
/**
 * run-js.mjs —— js 那条图的引导层，**开发期的入口**。
 *
 * ## 它没有自己的实现，只有一条转发
 *
 * 真正干活的是 `launcher/skillpress.mjs` —— 那份**进包**（拿到包的人要用它），这份**不进包**
 * （`.moonignore` 排掉整个 `/tools/`），所以"一份实现"只能落在 `launcher/` 那边。
 *
 *   · **为什么留着这个名字**：判据（`engine-fixtures` / `blocks-fixtures` /
 *     `site-source` / `attach-check` / `native-parity` …）跑的是**工作区里刚编出来的 js**，
 *     而 `launcher/` 那份的报错话术是写给"拿到包的人"的。开发期留一个名字，比让 20 处判据
 *     去 import 一个叫"启动器"的东西清楚。两个名字，一份实现。
 *   · **为什么不许再抄一遍**（2026-10-07 实测的账）：这两份曾经逐字重复 —— 390 行里只差 82 行，
 *     差的那些全在"报错写给谁看"上。抄两遍的代价**真的发生过**：`launcher` 那侧的 `check` 快路径
 *     （门不碰高亮 ⇒ 连 tree-sitter 都不 import）是后加的，`tools/` 这份一直没跟上
 *     ⇒ 判据里每一次 `check` 都白等一次 wasm 引导。同一件事的两个副本，早晚只更新一个。
 *
 * ## 用法（与启动器**完全一致**，因为就是它）
 *
 *   node tools/run-js.mjs gen-file <内容根>
 *   node tools/run-js.mjs dump-blocks <内容根>
 *   node tools/run-js.mjs check --repo <仓库根> --skills <内容根>
 *   node tools/run-js.mjs batch ｜ hl <文件> <语言> ｜ audit
 *
 * ⚠️ 三条规矩全在 `launcher/skillpress.mjs` 里，别在这儿另立一份：
 *    `--target js` 的产物路径（`_build/js/debug/build/cmd/skillpress/skillpress.js`）、
 *    `globalThis.__skillpress_ts` 的挂法（tree-sitter 的 Promise 只能在引导层 await）、
 *    以及"必须走 `file://` URL 才能 import"（ESM 不认 Windows 盘符路径）。
 *    ⚠️ `moon build --target js` 出的是 **CJS** ⇒ 顶层 await 不成立 ⇒ 这一层去不掉。
 */
await import(new URL("../launcher/skillpress.mjs", import.meta.url).href);
