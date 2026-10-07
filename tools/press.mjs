#!/usr/bin/env node
// tools/press.mjs —— **一行转发**（开发期从程序根调；实现住在随包发的那一侧）。
//
//   node tools/press.mjs [--app <实例>] [--skills <内容根>] [--check]
//
// ⚠️ 为什么实现不在这儿：站点工程里那条 `npm run press` 要能在**用户装下来的包**里跑，
//    而 `.moonignore` 把 `/tools/` 整个排掉了 ⇒ 放 `tools/` 的版本对用户**不存在**
//    （实测：从 registry 装的包生成出来的工程跑 `npm run press`，报的是
//    「在程序根里找不到工具 —— <包>/tools/press.mjs」）。
//    ⇒ 真源搬到 `launcher/press.mjs`，这里只留转发 —— 与 D35 对 `tools/run-js.mjs`
//    的处理同一个形状（**一份实现只能落在随包发的那一侧**）。
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const r = spawnSync(process.execPath, [join(here, '..', 'launcher', 'press.mjs'), ...process.argv.slice(2)], {
  stdio: 'inherit',
});
process.exit(r.status === null ? 2 : r.status);
