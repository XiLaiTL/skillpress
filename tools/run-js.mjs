#!/usr/bin/env node
/**
 * run-js.mjs —— 跑 js 那条图的**引导层**。
 *
 * 为什么需要它：`web-tree-sitter` 的 `Parser.init()` 与 `Language.load()` 都是 **Promise**，
 * 而 `moon build --target js` 产出的是 **CJS**（顶层 await 不成立）。
 * 所以分工是：
 *   · **这里**（Node，能 await）：装好 tree-sitter + 我们自己 vendor 的 5 份 wasm 语法，挂到
 *     `globalThis.__skillpress_ts` 上；
 *   · **MoonBit 那边**只做同步调用（`engine/highlight/ts_shim.mbt`），色号与拼装都在 MoonBit 里。
 *
 * 用法：
 *   node tools/run-js.mjs <给 CLI 的参数…>
 * 例：
 *   node tools/run-js.mjs hl ../moobile/skills/moobile-pitfalls/SKILL.md bash
 *
 * ⚠️ 这也是"这个包怎么发出去"的雏形：js target 的 CLI 本来就要有一个 Node 启动器。
 * 那条路要付的代价已经写在 `PLAN.md` 的 P8 里：**运行时仍需要一个 npm 依赖**（`web-tree-sitter`）。
 */
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** 编好的 js 产物路径（`moon build cmd/skillpress --target js` 的输出）。 */
function builtCli() {
  const p = join(ROOT, "_build", "js", "debug", "build", "cmd", "skillpress", "skillpress.js");
  if (!existsSync(p)) {
    console.error(`✗ 还没编：${p}\n  先跑：moon build cmd/skillpress --target js`);
    process.exit(2);
  }
  return p;
}

/** 装 tree-sitter + 五份语法（名字取自 `grammars/<名字>.wasm`，与 scm 同名）。 */
async function boot() {
  const ts = await import("web-tree-sitter");
  await ts.Parser.init();
  const dir = join(ROOT, "grammars");
  const langs = {};
  for (const f of readdirSync(dir).filter((f) => f.endsWith(".wasm")).sort()) {
    const name = f.replace(/\.wasm$/, "");
    langs[name] = await ts.Language.load(readFileSync(join(dir, f)));
  }
  globalThis.__skillpress_ts = { ts, langs, root: ROOT.split("\\").join("/") };
  return Object.keys(langs).sort();
}

const names = await boot();
if (process.env.SKILLPRESS_DEBUG_LANGS === "1") {
  console.error(`引导层装好的语法：${names.join(", ")}`);
}
// ⚠️ 必须走 file:// URL：ESM 的 `import()` 不认 Windows 盘符路径（报 ERR_UNSUPPORTED_ESM_URL_SCHEME）
await import(pathToFileURL(builtCli()).href);
