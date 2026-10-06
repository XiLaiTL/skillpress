#!/usr/bin/env node
/**
 * shell-traps.mjs —— **脚本自己会安静咬人的坑**（判据脚本也是代码，也会说谎）。
 *
 *   node tools/shell-traps.mjs              # 站岗
 *   node tools/shell-traps.mjs --selftest   # 诱饵：塞一行真反引号 ⇒ 必须点名；转义/单引号里的不算
 *
 * ## 坑①：**双引号里的反引号 = 命令替换**（这条不是为了风格统一，它真的执行过东西）
 *
 * 2026-10-06 我写了一句提示：
 *     echo "还没发布这一版（那就先 `moon publish`）"
 * 于是这条**判据在跑的时候真的执行了一次 `moon publish`**。它失败纯属侥幸 —— 那个临时探针工程的
 * `moon.mod` 缺 `license` 字段，服务端 400 拒了；**如果它有 license，就会朝 registry 发一个包**。
 * 前科不止一次：`acceptance.sh` 里「（`moon add` 装已发布的版本）」那句也在读数里留下过一个空档
 * （反引号被吃掉 ⇒ 消息少了一截）。
 *
 * 所以规矩是：**要打反引号就写 `\``**（转义），或者把那段用「」括起来。
 *
 * ## 为什么用 Node 而不是 grep
 *
 * 第一版写成 `grep -E 'echo "[^"]*`'` ⇒ **四种误报**全来了：转义过的（`\``）、注释里的、
 * 单引号里的（那是数据）、以及判据自己造诱饵的那几行。**一个会误报的门会逼人删消息**，
 * 那是反效果。引号与转义得用状态机看，正则干不了这活。
 */
import { readFileSync, readdirSync } from "node:fs";

/** 一行里找出"双引号字符串中未转义的反引号"。返回 `null` 或该行的说明。 */
export function scanLine(line) {
  const t = line.trimStart();
  if (t.startsWith("#")) return null; // 注释：那是散文，不算
  let inSingle = false;
  let inDouble = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === "\\" && !inSingle) {
      i++; // 转义掉下一个字符（含 \`）
      continue;
    }
    if (inSingle) {
      if (ch === "'") inSingle = false;
      continue;
    }
    if (ch === "'") {
      inSingle = true;
      continue;
    }
    if (inDouble) {
      if (ch === '"') inDouble = false;
      else if (ch === "`") return "双引号里的反引号（会被当命令替换执行）";
      continue;
    }
    if (ch === '"') inDouble = true;
  }
  return null;
}

function scanFiles(files) {
  const hits = [];
  for (const f of files) {
    const text = readFileSync(f, "utf8");
    text.split("\n").forEach((line, i) => {
      const why = scanLine(line);
      if (why) hits.push({ file: f, line: i + 1, text: line.trim(), why });
    });
  }
  return hits;
}

const files = readdirSync("tools")
  .filter((f) => f.endsWith(".sh"))
  .map((f) => `tools/${f}`)
  .sort();

// 空集合守卫：一条脚本都没扫到时"没问题"是**假绿**
if (files.length < 10) {
  console.error(`✗ 只扫到 ${files.length} 个脚本（实测应有 20+）—— 路径写坏了？（不允许在空集合上通过）`);
  process.exit(1);
}

const hits = scanFiles(files);

if (process.argv.includes("--selftest")) {
  // ⚠️ 用例里的反引号与反斜杠**不用字面量拼**：这个仓库的工具链/我的编辑器会把 `\\` 收成一个 `\`
  //    （实测：写进文件的两个反斜杠变成一个 ⇒ "转义过的"那条用例其实塞了个**裸**反引号 ⇒
  //    判据（正确地）报命中，而错的是**用例自己**）。用 `fromCharCode` 拼，任何转义层都动不了它。
  const BT = String.fromCharCode(96); // `
  const BS = String.fromCharCode(92); // \
  const cases = [
    [`echo "先跑 ${BT}moon publish${BT} 吧"`, true, "真反引号"],
    [`echo "先跑 ${BS}${BT}moon publish${BS}${BT} 吧"`, false, "转义过的反引号"],
    [`echo '先跑 ${BT}moon publish${BT} 吧'`, false, "单引号里的（那是数据）"],
    [`# echo "先跑 ${BT}moon publish${BT} 吧"`, false, "注释里的"],
  ];
  let ok = true;
  for (const [line, wantHit, name] of cases) {
    const got = scanLine(line) !== null;
    if (got !== wantHit) {
      ok = false;
      console.log(`✗ 诱饵「${name}」：期望${wantHit ? "命中" : "不命中"}，实得${got ? "命中" : "不命中"}`);
    } else {
      console.log(`✓ 诱饵「${name}」：${wantHit ? "被点名" : "不误报"}`);
    }
  }
  if (ok && hits.length === 0) {
    console.log("✓ 诱饵生效：真的反引号被点名，转义 / 单引号 / 注释三种都不误报（四向都活着）");
    process.exit(0);
  }
  console.log("✗ 诱饵没生效（或仓库里本来就有命中）—— 这条判据不可信");
  process.exit(1);
}

if (hits.length > 0) {
  console.log(`✗ ${hits.length} 处把反引号写进了**双引号**字符串里 —— bash 会把它当命令替换（**会真的执行**）：`);
  for (const h of hits) console.log(`      ${h.file}:${h.line}  ${h.text}`);
  console.log("    改法：写成 \`…\`（转义），或者把那段用「」括起来。");
  process.exit(1);
}
console.log(`✓ shell 坑位检查通过：扫了 ${files.length} 个脚本，双引号字符串里没有未转义的反引号`);
