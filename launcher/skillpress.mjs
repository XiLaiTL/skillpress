#!/usr/bin/env node
/**
 * skillpress.mjs —— **随包发出去的启动器**（js target 的 CLI 要有一个 Node 启动器）。
 *
 * 为什么必须有它：`web-tree-sitter` 的 `Parser.init()` 与 `Language.load()` 都是 **Promise**，
 * 而 `moon build --target js` 产出的是 **CJS**（顶层 await 不成立）。所以分工是：
 *   · **这里**（Node，能 await）：装好 tree-sitter + 这份包自带的 `grammars/*.wasm` 与 `.scm`，
 *     挂到 `globalThis.__skillpress_ts`；
 *   · **MoonBit 那边**只做同步调用（`engine/highlight/ts_shim.mbt`），色号与拼装都在 MoonBit 里。
 * 开发仓里同一件事由 `tools/run-js.mjs` 干（那个文件是**判据用的**，不进包）。
 *
 * ## 拿到这个包的人怎么用它（R6 要回答的那一问）
 *
 * ```bash
 * PKG=<你项目>/.mooncakes/XiLaiTL/skillpress      # 包被 moon 装到这里（或任何你解压出来的目录）
 * npm i web-tree-sitter                          # ← 运行时唯一的 npm 依赖（装在**你项目**里即可，
 *                                                #    Node 从包内往上一层层找得到）
 * moon -C "$PKG" build cmd/skillpress --target js # 编一次（产物落在包自己的 _build/ 里）
 *
 * node "$PKG/launcher/skillpress.mjs" check  --skills ./skills        # 门：G1–G4 / G7 / G8
 * node "$PKG/launcher/skillpress.mjs" gen-file ./skills > content.generated.mbt
 * ```
 *
 * ⚠️ **`check` 不需要 tree-sitter**（门不碰高亮）—— 那一条在 `gen-file` 之前就分发掉了，
 *    所以没装 npm 依赖时 `check` 照样能跑（实测）。需要高亮的只有 `gen-file` / `hl` / `batch`
 *    / `dump-blocks`（`dump-blocks` 里也带高亮片段）。
 *
 * ⚠️ **如实记下的代价**：`grammars/`（wasm + scm）随包发（署名见 `THIRD-PARTY-NOTICE.md`），
 *    但 `web-tree-sitter` 只能由使用者 `npm i` —— 这是"js target + 树剖析"这条路本身的账。
 */
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** 编好的 js 产物路径（`moon build cmd/skillpress --target js` 的输出）。 */
function builtCli() {
  const p = join(ROOT, "_build", "js", "debug", "build", "cmd", "skillpress", "skillpress.js");
  if (!existsSync(p)) {
    // ⚠️ 这句提示是**给拿到包的人**看的 ⇒ 给一条能直接粘的命令（`moon -C <包目录> …`）：
    //    包的目录不在你项目的构造根里，`cd` 过去编再 cd 回来是没必要的绕路。
    console.error(
      `✗ 这份包还没编出 CLI：${p}\n  先跑：moon -C "${ROOT}" build cmd/skillpress --target js`,
    );
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
  // ⚠️ 缺依赖时**说人话**：`import` 抛的 ENOENT 栈对"拿到包的人"毫无信息量
  //    （他会以为包坏了）。所以这里把话讲清：要装什么、在哪装、以及"只想跑门的话不用装"。
  let ts;
  try {
    ts = await import("web-tree-sitter");
  } catch (e) {
    console.error(
      "✗ 缺 npm 依赖 web-tree-sitter（高亮要用它；**门不需要**）。\n" +
        "  在你的项目里装一次即可：npm i web-tree-sitter\n" +
        "  （Node 从这份包往上一层层找 node_modules，所以装在项目根就行）",
    );
    process.exit(2);
  }
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

// ── `check` **不需要高亮** ⇒ 这条路上连 tree-sitter 都不 import ────────────────────────
// 为什么值得为它写一段：门与高亮没有任何依赖关系，而 `web-tree-sitter` 是使用者唯一要自己
// `npm i` 的东西 —— "只想跑门的人不该被一个 npm 依赖挡住"（`cmd/skillpress` 那边也是先分发
// `check` 再查"引导层装好了没有"，两处是同一条口径）。
const wantsCheck = process.argv.includes("check");
if (wantsCheck) {
  globalThis.__skillpress_ts = {
    root: ROOT.split("\\").join("/"),
    mdFiles: [],
    mdKids: () => [],
    scriptKids: () => [],
  };
  await import(pathToFileURL(builtCli()).href);
  process.exit(process.exitCode ?? 0);
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
