#!/usr/bin/env node
/**
 * node-side-hl.mjs —— **旧实现（Node 版）对某一段代码块的输出**，作为探针/迁移期的对账基准。
 *
 *   node node-side-hl.mjs <markdown 文件> <语言> <第几个该语言的围栏块（从 1 数）>
 *
 * 为什么要它：迁移铁律是"**新实现与旧实现逐条对账**"，而"看起来差不多"不算数。
 * 这条命令把旧实现对一个**确定的输入**的输出钉成可复现的读数（wrapper / 未上色比例 / 前几段色号），
 * MoonBit 侧探针打印同样的三样东西，两边一比就知道有没有退步。
 *
 * 它**直接调旧实现**（`lib/highlight.mjs` 的 `highlight()`），不重写一套 —— 免得两边漂。
 */
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { init, highlight, summarize } from "../../lib/highlight.mjs";

const [file, lang, nthRaw] = process.argv.slice(2);
if (!file || !lang) {
  console.error("用法：node node-side-hl.mjs <markdown 文件> <语言> [第几个（默认 1）]");
  process.exit(2);
}
const nth = Number(nthRaw ?? 1);

/** 从 markdown 里取出第 n 个 ```<lang> 围栏块（真值 = 纯文本扫，不依赖任何解析器）。 */
function fencedBlocks(text, want) {
  const out = [];
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^```([^\s`]*)\s*$/);
    if (!m) continue;
    const tag = m[1] || "";
    const body = [];
    i++;
    while (i < lines.length && !/^```\s*$/.test(lines[i])) {
      body.push(lines[i]);
      i++;
    }
    if (tag === want) out.push(body.join("\n"));
  }
  return out;
}

const src = readFileSync(resolve(file), "utf8");
const blocks = fencedBlocks(src, lang);
if (!blocks.length) {
  console.error(`✗ ${file} 里没有 \`\`\`${lang} 的围栏块`);
  process.exit(1);
}
if (nth > blocks.length) {
  console.error(`✗ 只有 ${blocks.length} 个 \`\`\`${lang} 块，要第 ${nth} 个`);
  process.exit(1);
}
const code = blocks[nth - 1];

await init();
const r = await highlight(code, lang);
if (!r) {
  console.error(`✗ 旧实现认不出这个语言：${lang}`);
  process.exit(1);
}

const total = [...code].filter((ch) => !/\s/.test(ch)).length;
console.log(`== 旧实现（Node 版 lib/highlight.mjs）==`);
console.log(`文件 = ${resolve(file)}`);
console.log(`块   = \`\`\`${lang} 第 ${nth} 个（${code.split("\n").length} 行 / ${total} 个非空白字符）`);
console.log(`读数 = ${summarize(code, r)}`);
console.log(`未上色比例 = ${((r.dark / total) * 100).toFixed(1)}%`);
console.log(`前 6 段 = ${JSON.stringify(r.runs.slice(0, 6))}`);
console.log(`拼接后与原文逐字节相同 = ${r.runs.map(([t]) => t).join("") === code}`);
