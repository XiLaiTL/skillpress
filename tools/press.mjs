#!/usr/bin/env node
/**
 * press.mjs —— **内容源 → 站点实例的 `content` 包**（P6 起由**新引擎**干这件事）。
 *
 * 旧的 Node 引擎（`lib/gen-content.mjs`）仍然在，但从 P6 开始它有了新身份：
 * **真相的参照实现** —— 对账时拿它在**同一份副本**上现印一份与新引擎比
 * （`tools/file-parity.sh` + `tools/mk-parity-corpus.sh`；旧的冻结基线已退役，见 PLAN 的 D29）。
 * 往**实例**里写产物的这条日常路径换成新引擎（`cmd/skillpress gen-file`）。
 *
 *   node tools/press.mjs            # 生成并写进实例的 content/content.generated.mbt
 *   node tools/press.mjs --check    # 只校验（门：磁盘上那份与现跑一致）
 *   node tools/press.mjs --app <实例目录> [--skills <内容根>]
 *
 * ⚠️ **先写临时文件、成功才替换**：引擎在"认不出的构造"等情形下会**退出码非零且一个字节都不吐**
 *    （刻意的，见 `cmd/skillpress/main.mbt`）。如果直接 `> 产物文件`，shell 会先把它**清空**，
 *    于是"一次失败的生成"会顺手毁掉上一份好产物 —— 那正是这个脚本存在的理由之一。
 *
 * ⚠️ 为什么用 Node 而不是 shell 里那几行：`npm run press` 在 Windows 上由 `cmd.exe` 执行，
 *    重定向 + `mv` + `diff` 那一套不可移植。这里三样都要（临时文件 / 改名 / 比对），只能自己写。
 */
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** `--key value`。 */
function argOf(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : null;
}

/** 内容根：`--skills` → `SKILLPRESS_SKILLS` → 兄弟 `../moobile/skills`（与 lib/roots.mjs 同一条规矩）。 */
function defaultSkills() {
  const sibling = resolve(ROOT, "..", "moobile", "skills");
  return existsSync(sibling) ? sibling : resolve(ROOT, "skills");
}

const SKILLS = resolve(argOf("--skills") || process.env.SKILLPRESS_SKILLS || defaultSkills());
const APP = resolve(
  argOf("--app") || process.env.SKILLPRESS_APP_DIR || join(SKILLS, "skillpress", "scripts", ".skillpress"),
);
const OUT = join(APP, "content", "content.generated.mbt");
const CHECK = process.argv.includes("--check");

if (!existsSync(SKILLS)) {
  console.error(`✗ 内容根不存在：${SKILLS}（用 --skills 或 SKILLPRESS_SKILLS 指定）`);
  process.exit(2);
}
if (!existsSync(join(APP, "content"))) {
  console.error(`✗ 实例目录不像站点实例（没有 content/）：${APP}`);
  process.exit(2);
}

// ① 现跑引擎（stdout 收进内存；stderr 是诊断，直接透传给人看）
const r = spawnSync(process.execPath, [join(ROOT, "tools", "run-js.mjs"), "gen-file", SKILLS], {
  encoding: "utf8",
  maxBuffer: 256 * 1024 * 1024,
});
if (r.stderr) process.stderr.write(r.stderr);
if (r.status !== 0) {
  console.error(`✗ 引擎没吐出产物（退出码 ${r.status}）—— 磁盘上那份**一个字没动**`);
  process.exit(2);
}
const text = r.stdout || "";
if (text.trim() === "") {
  console.error("✗ 引擎退出码是 0 但**产物是空的** —— 按失败处理（空产物从来不是合法的）");
  process.exit(2);
}
const lines = text.split("\n").length - (text.endsWith("\n") ? 1 : 0);

// ② 与磁盘上那份比
const onDisk = existsSync(OUT) ? readFileSync(OUT, "utf8") : null;
if (onDisk === text) {
  console.log(`✓ 一致：${OUT}（${lines} 行）`);
  process.exit(0);
}

if (CHECK) {
  console.error(`✗ 不一致：磁盘那份与现跑不同 —— ${OUT}`);
  if (onDisk === null) {
    console.error("  （磁盘上根本没有这个文件）");
    process.exit(1);
  }
  const a = onDisk.split("\n");
  const b = text.split("\n");
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if (a[i] !== b[i]) {
      console.error(`  第一处差异在第 ${i + 1} 行：`);
      console.error(`    磁盘：${a[i] === undefined ? "(没有这一行)" : a[i].slice(0, 120)}`);
      console.error(`    现跑：${b[i] === undefined ? "(没有这一行)" : b[i].slice(0, 120)}`);
      break;
    }
  }
  process.exit(1);
}

// ③ 写：临时文件 → 改名（同目录，改名是原子的；失败时上一份产物还在）
const tmp = OUT + ".tmp";
try {
  writeFileSync(tmp, text);
  renameSync(tmp, OUT);
} catch (e) {
  try {
    unlinkSync(tmp);
  } catch {}
  console.error(`✗ 写失败（磁盘上那份没动）：${e.message}`);
  process.exit(2);
}
console.log(`✓ 写入 ${OUT}（${lines} 行${onDisk === null ? "；之前没有这份文件" : ""}）`);
