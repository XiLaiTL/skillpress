#!/usr/bin/env node
/**
 * node-side-batch.mjs —— **旧实现的全语料读数**（迁移期对账基准）。
 *
 *   SKILLPRESS_CORPUS=<内容根> node node-side-batch.mjs
 *
 * 输出格式与 MoonBit 侧 `SKILLPRESS_CORPUS=<根> node ../../tools/run-js.mjs batch` **逐字符对齐**
 * （同一份语料、同一种排序、同一行格式）—— 两边的输出直接 `diff` 就是判据。
 *
 * 它直接调旧实现 `lib/highlight.mjs` 的 `highlight()`，不重写一套（免得两边漂）。
 */
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { init, highlight } from "../../lib/highlight.mjs";

const root = process.env.SKILLPRESS_CORPUS;
if (!root || !existsSync(root)) {
  console.error("✗ 用 SKILLPRESS_CORPUS=<内容根> 指定语料");
  process.exit(2);
}

/** 与引导层 `mdFiles()` **同一套**遍历与排序（两边的文件顺序必须一致才能 diff）。 */
function mdFiles(dir) {
  const out = [];
  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (e.name.startsWith(".") || e.name === "node_modules" || e.name === "_build" || e.name === "dist") continue;
      const p = join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith(".md")) out.push(p.split("\\").join("/"));
    }
  };
  walk(dir);
  return out.sort();
}

/** 与 `fences()` 同一套扫法（真值 = 纯文本扫）。 */
function fences(src) {
  const out = [];
  const lines = src.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.startsWith("```")) continue;
    const tag = line.slice(3).trim();
    const body = [];
    i++;
    while (i < lines.length && !lines[i].trim().startsWith("```")) {
      body.push(lines[i]);
      i++;
    }
    out.push({ lang: tag, code: body.join("\n") });
  }
  return out;
}

await init();
const files = mdFiles(root);
console.log(`== 旧实现（Node 版 lib/highlight.mjs）：全语料对账（${files.length} 份 .md）==`);
const tally = new Map();
for (const file of files) {
  const src = readFileSync(file, "utf8");
  for (const f of fences(src)) {
    const total = [...f.code].filter((ch) => !/\s/.test(ch)).length;
    const r = await highlight(f.code, f.lang);
    if (!r) {
      console.log(`${file}|${f.lang}|（没配语法，照原文渲染）|${total}`);
      continue;
    }
    console.log(`${file}|${f.lang}|${r.lang}|${r.wrapper}|dark=${r.dark}|${total}`);
    const cur = tally.get(r.lang) ?? { blocks: 0, dark: 0, total: 0 };
    tally.set(r.lang, { blocks: cur.blocks + 1, dark: cur.dark + r.dark, total: cur.total + total });
  }
}
console.log("== 汇总（按语言）==");
for (const key of ["moonbit", "bash", "json", "javascript", "toml"]) {
  const t = tally.get(key);
  if (!t) continue;
  const pct = t.total === 0 ? 0 : (t.dark / t.total) * 100;
  console.log(`  ${key}|${t.blocks} 块|dark=${t.dark}|${t.total}|${pct}%`);
}
