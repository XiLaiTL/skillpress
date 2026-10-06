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
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
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


/**
 * 子页沿用**内容侧 `kids.mjs` 的两条规矩**（遍历顺序与排序也是逐字节判据的一部分，
 * 所以照抄它，不要在 MoonBit 侧另排一次）：
 *   · `mdFiles(skillDir)`：任何子目录里的 `.md`（`SKILL.md` 除外）；**点开头与产物目录一律跳过**；
 *     每层按 `localeCompare` 排。
 *   · `scriptFiles(skillDir)`：`scripts/` 下**直接放的**非 md 文件，按默认 `sort()` 排。
 * MoonBit 那边只负责"怎么起名字、谁是 ref 谁是 script、标题与摘要怎么来"。
 */
const SKIP_DIRS = new Set(["node_modules", "_build", "dist", "target", ".mooncakes", ".git", ".scratch"]);
const skipName = (name) => SKIP_DIRS.has(name) || name.startsWith(".");

function mdKids(skillDir) {
  const out = [];
  const walk = (dir, prefix) => {
    for (const e of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (skipName(e.name)) continue;
      const rel = prefix ? `${prefix}/${e.name}` : e.name;
      const abs = join(dir, e.name);
      if (e.isDirectory()) walk(abs, rel);
      else if (e.name.endsWith(".md") && rel !== "SKILL.md") out.push(rel);
    }
  };
  walk(skillDir, "");
  return out;
}

function scriptKids(skillDir) {
  const dir = join(skillDir, "scripts");
  try {
    return readdirSync(dir)
      .filter((f) => !skipName(f) && !f.endsWith(".md") && statSync(join(dir, f)).isFile())
      .sort()
      .map((f) => `scripts/${f}`);
  } catch {
    return [];
  }
}

/** 内容根 + 带 `SKILL.md` 的目录（按名字排序；顺序是判据的一部分，所以只在这儿排一次）。 */
function prepareRoot(arg, needSkills = true) {
  if (!arg || !existsSync(arg)) {
    console.error(`✗ 内容根不存在：${arg ?? "(没给)"}`);
    process.exit(2);
  }
  const abs = resolve(arg);
  const root = abs.split("\\").join("/");
  globalThis.__skillpress_ts.dumpRoot = root;
  if (needSkills) {
    globalThis.__skillpress_ts.skillDirs = readdirSync(abs, { withFileTypes: true })
      .filter((e) => e.isDirectory() && existsSync(join(abs, e.name, "SKILL.md")))
      .map((e) => e.name)
      .sort();
  }
  return root;
}

/** 装 tree-sitter + 五份语法（名字取自 `grammars/<名字>.wasm`，与 scm 同名）。 */
async function boot() {
  // 运行时是**随包 vendored** 的那份（与 `launcher/skillpress.mjs` 同一口径，见
  // `vendor/web-tree-sitter/PROVENANCE.md`）：用**路径**导入而不是裸包名 —— 裸名会去 node_modules
  // 里找，而我们要保证的正是"**没有** node_modules 也能跑"。
  // ⚠️ **旧实现**（`lib/*.mjs` 那些冻结的参照物）仍然是裸包名 ⇒ 它们仍要 node_modules。
  //    那也正是 `package.json` 里那个依赖今天存在的**唯一**理由：判据要跑旧实现现场产出基准。
  const ts = await import(
    new URL("../vendor/web-tree-sitter/web-tree-sitter.js", import.meta.url).href
  );
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
  globalThis.__skillpress_ts = {
    ts,
    langs,
    scms,
    root: ROOT.split("\\").join("/"),
    mdFiles: mdFiles(),
    mdKids,
    scriptKids,
  };
  return Object.keys(langs).sort();
}

const names = await boot();

/**
 * `dump-blocks <内容根>`：内容根下**带 `SKILL.md` 的目录**（按名字排序）。
 *
 * 为什么排序放在引导层：生成物里 doc 的顺序就是**同一个 `sort()`** 的结果 ——
 * 顺序也是逐字节判据的一部分，两处各排一次早晚会漂。
 */
for (const cmd of ["dump-blocks", "gen-file"]) {
  const at = process.argv.indexOf(cmd);
  if (at >= 0) {
    prepareRoot(process.argv[at + 1]);
  }
}
if (process.env.SKILLPRESS_DEBUG_LANGS === "1") {
  console.error(`引导层装好的语法：${names.join(", ")}`);
  console.error(`语料根=${process.env.SKILLPRESS_CORPUS ?? "(没设)"} ｜ 列出的 .md = ${globalThis.__skillpress_ts.mdFiles.length}`);
}
// ⚠️ 必须走 file:// URL：ESM 的 `import()` 不认 Windows 盘符路径（报 ERR_UNSUPPORTED_ESM_URL_SCHEME）
await import(pathToFileURL(builtCli()).href);
