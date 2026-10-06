#!/usr/bin/env node
/**
 * old-doc-blocks.mjs —— 从**旧实现已经产出的** `content.generated.mbt` 里，
 * 精确切出每份 skill 的 `blocks: [ … ]` 原文（含缩进），作为移植期的**逐字节判据**。
 *
 *   node tools/spike/old-doc-blocks.mjs <content.generated.mbt>
 *
 * 为什么要"逐字节"而不是"数一数块数"：块数对上只说明粗结构对，
 * 而这份生成物是**旧实现的产物**——它就是真相。新实现要能原样吐出来。
 *
 * 输出：`### <slug>` 一行，然后是那段原文（不含 `blocks: [` 与结尾的 `],` 之外的东西，
 * 但**包含**内层所有缩进与换行），块之间用空行隔开，末尾一行 `### end`。
 */
import { readFileSync } from "node:fs";

const file = process.argv[2];
if (!file) {
  console.error("用法：node old-doc-blocks.mjs <content.generated.mbt>");
  process.exit(2);
}
const text = readFileSync(file, "utf8");

/** 从 `blocks: [` 的下一行起，按括号深度找配对的 `],`（**跳过字符串字面量**里的括号）。 */
function takeBlocks(lines, startAt) {
  const body = [];
  let depth = 1; // 已经吃掉了行尾的 `[`
  let inStr = false;
  let esc = false;
  for (let i = startAt + 1; i < lines.length; i++) {
    const line = lines[i];
    let cut = -1;
    for (let j = 0; j < line.length; j++) {
      const ch = line[j];
      if (inStr) {
        if (esc) esc = false;
        else if (ch === "\\") esc = true;
        else if (ch === '"') inStr = false;
        continue;
      }
      if (ch === '"') inStr = true;
      else if (ch === "[") depth++;
      else if (ch === "]") {
        depth--;
        if (depth === 0) {
          cut = j;
          break;
        }
      }
    }
    if (cut >= 0) {
      if (line.slice(0, cut).trim()) body.push(line.slice(0, cut));
      return body.join("\n");
    }
    body.push(line);
  }
  throw new Error("括号没配对（生成物被改坏了？）");
}

const lines = text.split("\n");
let cur = null;
const out = [];
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/^\s*slug: "([^"]+)",\s*$/);
  if (m) cur = m[1];
  if (/^\s*blocks: \[$/.test(lines[i])) {
    if (!cur) continue;
    out.push(`### ${cur}`);
    out.push(takeBlocks(lines, i));
    out.push("");
    cur = null;
  }
}
out.push("### end");
process.stdout.write(out.join("\n") + "\n");
