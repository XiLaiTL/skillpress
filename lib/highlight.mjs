#!/usr/bin/env node
/**
 * highlight.mjs —— 构建期高亮：**代码块 → 带色号的片段**（tree-sitter）。
 *
 *   node tools/highlight.mjs --audit     # 看召回率与"漏色"报告（改语法/改内容后跑它）
 *
 * ## 为什么是 tree-sitter（而不是 TextMate / 编辑器 LSP）
 *
 * 三条都是实测出来的，不是口味：
 *   ① **LSP 当不了高亮器**：`moon-lsp` 的 `semanticTokensProvider.legend` 只有
 *      `function_call` / `function_decl` 两种类型，且对包里真文件请求 semanticTokens 返回空数组。
 *      它是给 hover / 定义 / 重命名 用的。
 *   ② **TextMate 语法（tmLanguage）能上色，但那是 10 KB 正则汤**：靠正则猜，不建树，
 *      拿不到结构 —— 而"大纲 / 折叠 / 结构化搜索"要的正是树。
 *   ③ tree-sitter 用的是**语法**（grammar），配一份 `highlights.scm` 就能把节点映射到颜色，
 *      一套引擎管所有语言，还顺手给了我们语法树。
 *
 * ## 片段是常态，所以有"包装候选"
 *
 * 文档里的代码块**大多不是完整可编译的代码**（`@html.div(...)` 直接贴在顶层的表达式最常见）。
 * tree-sitter 遇到这种会产出 ERROR 节点，ERROR 里的东西**一个 capture 都拿不到** ——
 * 实测裸解析的字符串召回只有 12%。
 *
 * 解法：每种包装试一遍（裸着 / 包进函数体 / let 绑定 / 调用参数 / 数组元素 / struct 字段 / match 分支），
 * **取"没被上色的非空白字符最少"的那个**。实测把召回从 66.7% 拉到 93.3%（字符串 12% → 88%）。
 *
 * ## 一条硬不变量
 *
 * 颜色是**按字符**贴上去的（`Int8Array` 与原文一一对应），所以拼回去必须**逐字节等于原文**。
 * 拼不回去就抛错 —— 高亮绝不许悄悄改代码。
 *
 * ## 配色的分工
 *
 * 这里只产出**色号**（小整数，`PALETTE` 的索引），颜色本身在 `site/app.mbt` 里定义 ——
 * 那是"怎么画"的事，属于站点；这里是"什么是什么"的事。
 */
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Parser, Language, Query } from "web-tree-sitter";
import { PROGRAM as PROGRAM0, REPO as REPO0, SKILLS as SKILLS0 } from "./roots.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
/** 语法资产在**程序根**下（与 `lib/`、`bin/` 并列）—— 不是 `lib/grammars`。 */
const GRAMMARS = join(HERE, "..", "grammars");
/** 目录约定：本文件在 <程序>/lib；`<仓库>/skills` 是内容根。 */
const argOf = (name) => {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : null;
};
const PROGRAM = PROGRAM0;
const REPO = REPO0;
const SKILLS = SKILLS0;

/**
 * 语言表：**fence 上写的标记 → 语法资产**（配方只有这一处）。
 * 一个语言一份 wasm + 一份 `highlights.scm`，出处与 sha256 见 `grammars/PROVENANCE.md`。
 */
const LANGS = {
  moonbit: { wasm: "moonbit.wasm", query: "moonbit.highlights.scm", wrap: true, label: "moonbit" },
  mbt: { wasm: "moonbit.wasm", query: "moonbit.highlights.scm", wrap: true, label: "moonbit" },
  bash: { wasm: "bash.wasm", query: "bash.highlights.scm", label: "bash" },
  sh: { wasm: "bash.wasm", query: "bash.highlights.scm", label: "bash" },
  shell: { wasm: "bash.wasm", query: "bash.highlights.scm", label: "bash" },
  console: { wasm: "bash.wasm", query: "bash.highlights.scm", label: "bash" },
  json: { wasm: "json.wasm", query: "json.highlights.scm", label: "json" },
  jsonc: { wasm: "json.wasm", query: "json.highlights.scm", label: "json" },
  javascript: { wasm: "javascript.wasm", query: "javascript.highlights.scm", label: "javascript" },
  js: { wasm: "javascript.wasm", query: "javascript.highlights.scm", label: "javascript" },
  mjs: { wasm: "javascript.wasm", query: "javascript.highlights.scm", label: "javascript" },
  toml: { wasm: "toml.wasm", query: "toml.highlights.scm", label: "toml" },
};

/**
 * 调色板：**capture 名 → 色号**（色号 0 = 不特意上色，用正文墨色）。
 *
 * 顺序 = 优先级：越靠前越"专有"（`keyword.control` 与 `keyword` 都该走关键字那一档）。
 * 没匹配上的 capture（`spell`、`error` 之类）不上色 —— 它们本来就不是颜色。
 */
export const PALETTE = [
  [1, /^keyword/, "关键字"],
  [2, /^string|^escape|^character/, "字符串"],
  [3, /^comment/, "注释"],
  [4, /^number|^constant|^boolean/, "数字 / 字面量"],
  [5, /^type|^constructor|^attribute|^support\.type/, "类型"],
  [6, /^function/, "函数"],
  [7, /^module|^namespace/, "模块"],
  [8, /^variable|^property|^field|^parameter|^label/, "变量 / 字段"],
  [9, /^operator|^punctuation/, "标点 / 运算符"],
];

/** 片段包装候选（**只有 moonbit 需要**：它的文档块大量是裸表达式）。 */
const WRAPS = [
  ["裸着解析", "", ""],
  ["包进函数体", "fn __snip() {\n", "\n}"],
  ["包进函数体（Unit）", "fn __snip() -> Unit {\n", "\n}"],
  ["let 绑定", "fn __snip() {\n  let __x = ", "\n}"],
  ["调用参数", "fn __snip() {\n  __f(", "\n  )\n}"],
  ["数组元素", "fn __snip() {\n  let __a = [", "\n  ]\n}"],
  ["struct 字段", "struct __S {\n", "\n}"],
  ["match 分支", "fn __snip(x : Int) {\n  match x {\n", "\n  }\n}"],
];

/** capture 名 → [色号, 优先级]。没匹配上的（`spell` / `error` / `embedded` 之类）不上色。 */
function captureColor(name) {
  for (let i = 0; i < PALETTE.length; i++) {
    if (PALETTE[i][1].test(name)) return { idx: PALETTE[i][0], prio: i };
  }
  return null;
}

/** 只加载一次：语言按需装载（wasm 实例化不便宜，别每次重来）。 */
const loaded = new Map();
let inited = false;

export async function init() {
  if (inited) return;
  await Parser.init();
  inited = true;
}

/**
 * 一种语言 = 一个 wasm + 一份查询 + **一个自己的 Parser**。
 *
 * ⚠️ Parser **必须每语言一个**：`setLanguage` 是"改这个 parser 的状态"，
 * 而按需加载只在**第一次**调用，于是"最后装载的那个语言"会污染之后所有解析 ——
 * 实测踩过：审计里 moonbit 的漏色从 106 变成 425，因为中途装了 bash。
 * （错得还很安静：解析还能出结果，只是按错的语法出的。）
 */
function lang(spec) {
  const key = spec.wasm;
  if (!loaded.has(key)) {
    const wasmPath = join(GRAMMARS, spec.wasm);
    if (!existsSync(wasmPath)) {
      throw new Error(`高亮语法缺失：${wasmPath}（见程序根 grammars/PROVENANCE.md 的取法）`);
    }
    loaded.set(
      key,
      Language.load(wasmPath).then((L) => {
        const p = new Parser();
        p.setLanguage(L);
        return { L, parser: p, q: new Query(L, readFileSync(join(GRAMMARS, spec.query), "utf8")) };
      }),
    );
  }
  return loaded.get(key);
}

/** 一种包装下一次解析的结果：每个字符的色号（-1 = 没上色）。 */
async function shade(spec, code, pre, post) {
  const { parser: p, q } = await lang(spec);
  const tree = p.parse(pre + code + post);
  const flags = new Int8Array(code.length).fill(-1);
  const caps = q
    .captures(tree.rootNode)
    .map((c) => (Array.isArray(c) ? { name: c[1], node: c[0] } : c))
    .map((c) => ({ ...captureColor(c.name), start: c.node.startIndex, end: c.node.endIndex, name: c.name }))
    .filter((c) => c.idx !== undefined)
    // 高优先级的先占；同级之间按位置，先到先得（同色号，谁占都一样）
    .sort((a, b) => a.prio - b.prio || a.start - b.start);
  for (const c of caps) {
    for (let i = c.start; i < c.end; i++) {
      const j = i - pre.length;
      if (j >= 0 && j < code.length && flags[j] === -1) flags[j] = c.idx;
    }
  }
  let dark = 0;
  for (let i = 0; i < code.length; i++) if (!/\s/.test(code[i]) && flags[i] === -1) dark++;
  return { flags, dark, errors: (tree.rootNode.descendantsOfType("ERROR") || []).length };
}

/**
 * 一个代码块 → `[[文本, 色号], …]`（相邻同色已合并；拼回去**逐字节等于原文**）。
 *
 * 语言认不出来时返回 `null` —— 调用方照原文渲染即可（不是错误：内容里允许出现没配语法的语言）。
 */
export async function highlight(code, langTag) {
  const spec = LANGS[String(langTag || "").toLowerCase()];
  if (!spec) return null;
  const wraps = spec.wrap ? WRAPS : [["裸着解析", "", ""]];
  let best = null;
  for (const [wname, pre, post] of wraps) {
    const r = await shade(spec, code, pre, post);
    const cand = { ...r, wrapper: wname };
    if (!best || cand.dark < best.dark) best = cand;
    if (best.dark === 0) break;
  }
  // 按字符色号切段（相邻同色合并）
  const runs = [];
  for (let i = 0; i < code.length; i++) {
    const idx = best.flags[i] === -1 ? 0 : best.flags[i];
    const last = runs[runs.length - 1];
    if (last && last[1] === idx) last[0] += code[i];
    else runs.push([code[i], idx]);
  }
  // ★ 硬不变量：拼回去必须逐字节等于原文
  const back = runs.map((r) => r[0]).join("");
  if (back !== code) {
    throw new Error(`高亮把代码改坏了（拼回来与原文不一致）：${JSON.stringify(code.slice(0, 60))}`);
  }
  return { runs, dark: best.dark, wrapper: best.wrapper, errors: best.errors, lang: spec.label };
}

/** 一行摘要（给 gen-content 与 --audit 用）。 */
export function summarize(code, result) {
  const total = [...code].filter((ch) => !/\s/.test(ch)).length;
  return `${result.lang}（${result.wrapper}，未上色 ${result.dark}/${total}）`;
}

// ─────────────────────────────────────────────────────────── --audit：召回率

/** 真值表：这些词法元素**必须**被上色（与引擎无关，纯正则；够用且可复核）。 */
const TRUTH = [
  ["keyword", /\b(pub|priv|fn|let|mut|type|enum|struct|trait|impl|match|if|else|while|for|in|return|break|continue|guard|async|extern|derive|test|suberror|raise|try|catch|throw|const|self|true|false)\b/g],
  ["string", /"(?:[^"\\\n]|\\.)*"/g],
  ["comment", /\/\/[^\n]*|#[^\n]*/g],
  ["number", /(?<![\w.])\d+(?:\.\d+)?(?![\w.])/g],
];

async function audit(entries) {
  await init();
  const hit = {};
  const perLang = {};
  let dark = 0;
  let white = 0;
  for (const { code, lang } of entries) {
    const r = await highlight(code, lang);
    if (!r) continue;
    perLang[r.lang] = perLang[r.lang] || { blocks: 0, dark: 0, white: 0 };
    perLang[r.lang].blocks++;
    const colored = new Array(code.length).fill(false);
    let off = 0;
    for (const [text, idx] of r.runs) {
      for (let i = 0; i < text.length; i++) if (idx > 0) colored[off + i] = true;
      off += text.length;
    }
    for (let i = 0; i < code.length; i++) {
      if (/\s/.test(code[i])) continue;
      white++;
      perLang[r.lang].white++;
      if (!colored[i]) {
        dark++;
        perLang[r.lang].dark++;
      }
    }
    for (const [kind, re] of TRUTH) {
      re.lastIndex = 0;
      let m;
      while ((m = re.exec(code)) !== null) {
        hit[kind] = hit[kind] || [0, 0];
        hit[kind][1]++;
        let all = true;
        for (let i = m.index; i < m.index + m[0].length; i++) if (!colored[i]) { all = false; break; }
        if (all) hit[kind][0]++;
      }
    }
  }
  const a = Object.values(hit).reduce((x, y) => x + y[0], 0);
  const t = Object.values(hit).reduce((x, y) => x + y[1], 0);
  if (!entries.length || t === 0) {
    // ⚠️ **空集合不许算通过**：路径写错时（引擎搬过家，实测踩过）这里会一个块都收不到，
    // 而 `NaN < 阈值` 是 false ⇒ 门会**绿着**放过去 —— 假绿比红更糟。
    console.error("✗ 一个代码块都没数到 —— 内容源的路径不对？（这条判据不允许在空集合上通过）");
    console.error(`  找过：${SKILLS}`);
    return { recall: 0, darkRatio: 1, empty: true };
  }
  console.log("高亮召回复核（真值 = 关键字 / 字符串 / 注释 / 数字，纯正则数出来的）：");
  for (const k of Object.keys(hit)) console.log(`  ${k.padEnd(8)} ${hit[k][0]}/${hit[k][1]}  ${((hit[k][0] / hit[k][1]) * 100).toFixed(0)}%`);
  console.log(`  ${"合计".padEnd(7)} ${a}/${t}  ${((a / t) * 100).toFixed(1)}%`);
  console.log(`未上色的非空白字符：${dark}/${white}（${((dark / white) * 100).toFixed(1)}%）`);
  for (const [k, v] of Object.entries(perLang)) {
    console.log(`  ${k.padEnd(12)} ${v.blocks} 块 ｜ 未上色 ${v.dark}/${v.white}`);
  }
  return { recall: a / t, darkRatio: dark / white, empty: false };
}

/** 收集内容源里的所有代码块（**内容根 `**`** —— 首页那份 skill 也在里面）。 */
export function collectBlocks() {
  const out = [];
  const grab = (text, where) => {
    const re = /```([a-zA-Z0-9+#-]*)\n([\s\S]*?)```/g;
    let m;
    while ((m = re.exec(text)) !== null) out.push({ where, lang: m[1], code: m[2].replace(/\n$/, "") });
  };
  const walk = (dir) => {
    for (const e of readdirSyncSafe(dir)) {
      const p = join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (p.endsWith(".md")) grab(readFileSync(p, "utf8"), p);
    }
  };
  walk(SKILLS);
  return out;
}

function readdirSyncSafe(dir) {
  try {
    return readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }
}

/**
 * 审计的**回归闸门**：召回率与"漏色比例"越线就红。
 *
 * 为什么要有：高亮坏起来是**安静**的 —— 换个语法版本、包装策略失效、调色板正则改窄，
 * 页面照样渲染，只是颜色变少。这几个数字是唯一能看出来的地方。
 * 阈值定得松（不是追求满分，而是"拦住塌方"）；真要调，改这里并说明为什么。
 */
const GATE = { recall: 0.9, dark: 0.4 };

if (process.argv[1] && process.argv[1].endsWith("highlight.mjs")) {
  const blocks = collectBlocks();
  const r = await audit(blocks.filter((b) => LANGS[b.lang.toLowerCase()]));
  const unknown = blocks.filter((b) => !LANGS[b.lang.toLowerCase()]);
  if (unknown.length) {
    console.log(`\n没有配语法的标记（按原文渲染）：${[...new Set(unknown.map((b) => b.lang || "(空)"))].join(", ")}`);
  }
  const bad = [];
  if (r.empty) bad.push("一个块都没数到（路径错了？）");
  if (r.recall < GATE.recall) bad.push(`召回率 ${(r.recall * 100).toFixed(1)}% < ${GATE.recall * 100}%`);
  if (r.darkRatio > GATE.dark) bad.push(`未上色比例 ${(r.darkRatio * 100).toFixed(1)}% > ${GATE.dark * 100}%`);
  if (bad.length) {
    // ⚠️ 用 exitCode 而不是 process.exit()：WASM 还挂着句柄时强行收摊会让进程以 **127** 退出
    //（实测：屏幕上刚打印完"一致"，退出码却是 127）—— 退出码不对的门比没有门更糟。
    console.error(`\n✗ 高亮退化了：${bad.join("；")}`);
    process.exitCode = 1;
  } else {
    console.log(`\n✓ 在闸门内（召回率 ≥ ${GATE.recall * 100}%，未上色 ≤ ${GATE.dark * 100}%）`);
  }
}
