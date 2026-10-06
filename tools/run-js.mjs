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


/** 语料库：把 `SKILLPRESS_CORPUS` 指到的目录下所有 `.md` 列出来（排序，逐字节可复现）。 */
function mdFiles() {
  const root = process.env.SKILLPRESS_CORPUS;
  if (!root || !existsSync(root)) return [];
  const out = [];
  const walk = (dir) => {
    for (const e of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (e.name.startsWith(".") || e.name === "node_modules" || e.name === "_build" || e.name === "dist") continue;
      const p = join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith(".md")) out.push(p.split("\\").join("/"));
    }
  };
  walk(root);
  return out.sort();
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
  // query 也一起预装：MoonBit 侧要做的是"挑包装 → 刷色号 → 拼片段"，
  // 读 .scm 这种 IO 归引导层（两边的分工与 P8.0 的结论一致）
  const scms = {};
  for (const name of Object.keys(langs)) {
    const p = join(dir, `${name}.highlights.scm`);
    if (existsSync(p)) scms[name] = readFileSync(p, "utf8");
  }
  globalThis.__skillpress_ts = { ts, langs, scms, root: ROOT.split("\\").join("/"), mdFiles: mdFiles() };
  return Object.keys(langs).sort();
}

const names = await boot();
if (process.env.SKILLPRESS_DEBUG_LANGS === "1") {
  console.error(`引导层装好的语法：${names.join(", ")}`);
  console.error(`语料根=${process.env.SKILLPRESS_CORPUS ?? "(没设)"} ｜ 列出的 .md = ${globalThis.__skillpress_ts.mdFiles.length}`);
}
// ⚠️ 必须走 file:// URL：ESM 的 `import()` 不认 Windows 盘符路径（报 ERR_UNSUPPORTED_ESM_URL_SCHEME）
await import(pathToFileURL(builtCli()).href);
