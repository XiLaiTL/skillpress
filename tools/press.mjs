#!/usr/bin/env node
/**
 * press.mjs —— **内容源 → 站点实例的产物**（P6 起由**新引擎**干这件事）。
 *
 * 旧的 Node 引擎（`lib/gen-content.mjs`）仍然在，但从 P6 开始它有了新身份：
 * **真相的参照实现** —— 对账时拿它在**同一份副本**上现印一份与新引擎比
 * （`tools/engine-fixtures.sh`（与入库 golden 逐字节比）；旧的冻结基线已退役，见 PLAN 的 D29）。
 * 往**实例**里写产物的这条日常路径换成新引擎（`cmd/skillpress gen-file`）。
 *
 *   node tools/press.mjs            # 生成并写进实例
 *   node tools/press.mjs --check    # 只校验（门：磁盘上那份与现跑一致）
 *   node tools/press.mjs --app <实例目录> [--skills <内容根>]
 *
 * ## 三件产物（**一次解析、一条纪律**）
 *
 * | 产物 | 是什么 | 谁要它 |
 * |---|---|---|
 * | `content/content.generated.mbt` | 站点的全部内容值 | 站点本身 |
 * | `llms.txt` | **给 Agent 的整站索引**（每份 skill 一段：中文 title + 一行 desc + 原文路径） | Agent（人机共读那条线的出口） |
 * | `md/**` | **每页的原文**（内容源那份 `.md` 的逐字节拷贝） | Agent（"看原文"那条出口） |
 *
 * ⚠️ **`llms.txt` 与内容包同源**：同一套前置、同一次解析（`gen-file … --llms` 只换吐哪一份）——
 *    两边各解析一遍内容根就是两份口径，本仓明令禁止同一件事两个副本。
 * ⚠️ **`md/**` 的清单也从 `llms.txt` 里取**（那些 `原文:` 行），**不另外解析内容根**（同上）。
 *
 * ⚠️ **先写临时文件、成功才替换**：引擎在"认不出的构造"等情形下会**退出码非零且一个字节都不吐**
 *    （刻意的，见 `cmd/skillpress/cli/cli.mbt`）。如果直接 `> 产物文件`，shell 会先把它**清空**，
 *    于是"一次失败的生成"会顺手毁掉上一份好产物 —— 那正是这个脚本存在的理由之一。
 *
 * ⚠️ 为什么用 Node 而不是 shell 里那几行：`npm run press` 在 Windows 上由 `cmd.exe` 执行，
 *    重定向 + `mv` + `diff` 那一套不可移植。这里三样都要（临时文件 / 改名 / 比对），只能自己写。
 */
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, renameSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
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
const LLMS = join(APP, "llms.txt");
const MD_DIR = join(APP, "md");
const CHECK = process.argv.includes("--check");

if (!existsSync(SKILLS)) {
  console.error(`✗ 内容根不存在：${SKILLS}（用 --skills 或 SKILLPRESS_SKILLS 指定）`);
  process.exit(2);
}
if (!existsSync(join(APP, "content"))) {
  console.error(`✗ 实例目录不像站点实例（没有 content/）：${APP}`);
  process.exit(2);
}

let bad = 0;                                    // `--check` 下攒着：一处不一致不等于"别的都对"

/** 跑一次引擎，收 stdout（stderr 是诊断，透传给人看）。空产物按失败处理。 */
function engine(...extra) {
  const r = spawnSync(process.execPath, [join(ROOT, "tools", "run-js.mjs"), "gen-file", SKILLS, ...extra], {
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
  return text;
}

/** 一处产物：与磁盘比 → `--check` 就报差异（退出码 1）；否则临时文件 + 改名。 */
function sync(file, text, what) {
  const lines = text.split("\n").length - (text.endsWith("\n") ? 1 : 0);
  const onDisk = existsSync(file) ? readFileSync(file, "utf8") : null;
  if (onDisk === text) {
    console.log(`✓ 一致：${file}（${lines} 行）`);
    return;
  }
  if (CHECK) {
    bad = 1;
    console.error(`✗ 不一致：磁盘那份与现跑不同 —— ${file}（${what}）`);
    if (onDisk === null) {
      console.error("  （磁盘上根本没有这个文件）");
      return;
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
    return;
  }
  const tmp = file + ".tmp";
  try {
    writeFileSync(tmp, text);
    renameSync(tmp, file);
  } catch (e) {
    try {
      unlinkSync(tmp);
    } catch {}
    console.error(`✗ 写失败（磁盘上那份没动）：${e.message}`);
    process.exit(2);
  }
  console.log(`✓ 写入 ${file}（${lines} 行${onDisk === null ? "；之前没有这份文件" : ""}）`);
}

// ⓪ 站点**许可**：真源是站点配置的 `footer.license`（DESIGN-site.md §7，那份配置还不存在）
//    ⇒ 过渡期读**实例自己的 `moon.mod` 声明**（真实可读的值，不是编的）。
//    读不到就是空串 —— 生成物里那一项留空，页脚**不画**（不写占位、更不写死一个假值）。
const MOON_MOD = join(APP, "moon.mod");
let license = "";
if (existsSync(MOON_MOD)) {
  const m = readFileSync(MOON_MOD, "utf8").match(/^\s*license\s*=\s*"([^"]*)"/m);
  if (m) license = m[1];
}

// ① 内容包（`gen-file`）
const mbtText = engine("--license", license);
sync(OUT, mbtText, "站点的内容值");

// ② llms.txt（**同一套前置、同一份解析**的另一件产物：只换吐哪一份）
const llmsText = engine("--license", license, "--llms");
sync(LLMS, llmsText, "给 Agent 的整站索引");

// ③ md/**：每页原文的逐字节拷贝。
//    清单**从 llms.txt 里取**（那些 `原文:` 行），不另外解析内容根。
//    落盘布局 = 去掉 `skills/` 前缀后的相对路径（例：`md/moobile-app-development/references/x.md`）
//    ⇒ 浏览器按 `/md/<slug>/…` 直达，与站点的 slug/name 命名是同一套。
const wanted = [];
for (const line of llmsText.split("\n")) {
  const m = line.match(/(?:原文: |：)(skills\/[^\s]+)$/);
  if (m) wanted.push(m[1].slice("skills/".length));
}
if (wanted.length === 0) {
  console.error("✗ llms.txt 里一条「原文:」都没有 —— 原文出口的清单是空的不正常");
  process.exit(2);
}
const abs = (rel) => join(SKILLS, rel);
const missing = wanted.filter((rel) => !existsSync(abs(rel)));
if (missing.length) {
  console.error("✗ 内容根里找不到这些原文（llms.txt 与内容根对不上）：");
  for (const rel of missing) console.error(`    ${rel}`);
  process.exit(2);
}

/** 递归列 `md/**` 的相对路径（多出来的也要看见 —— 否则产物会带着已经不存在的页）。 */
function walk(dir, base, out) {
  if (!existsSync(dir)) return out;
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, base, out);
    else out.push(relative(base, p).replace(/\\/g, "/"));
  }
  return out;
}

if (CHECK) {
  const stale = [];
  for (const rel of wanted) {
    const dst = join(MD_DIR, rel);
    if (!existsSync(dst)) stale.push(rel + "（产物里缺）");
    else if (!readFileSync(dst).equals(readFileSync(abs(rel)))) stale.push(rel + "（逐字节不同）");
  }
  for (const rel of walk(MD_DIR, MD_DIR, [])) {
    if (!wanted.includes(rel)) stale.push(rel + "（产物里有、内容根里没有）");
  }
  if (stale.length === 0) console.log(`✓ 一致：${MD_DIR}/（${wanted.length} 份原文，逐字节相同）`);
  else {
    bad = 1;
    console.error(`✗ 不一致：原文产物 ${stale.length} 处 ——`);
    for (const rel of stale.slice(0, 5)) console.error(`    ${rel}`);
  }
} else {
  for (const rel of wanted) {
    const dst = join(MD_DIR, rel);
    mkdirSync(dirname(dst), { recursive: true });
    copyFileSync(abs(rel), dst);
  }
  console.log(`✓ 写入 ${MD_DIR}/（${wanted.length} 份原文拷贝）`);
}

// ④ **对得上**：每份 skill 的中文 title 都出现在 llms.txt 里（两份产物同源的自证）。
//    这不是"再解析一遍内容根"（那会变成第二份口径），只是拿**生成物里已有的** title 去索引里找。
const titles = [...mbtText.matchAll(/^\s+title: "([^"]*)",$/gm)].map((m) => m[1]);
const missed = titles.filter((t) => t && !llmsText.includes(t));
if (missed.length) {
  console.error(`✗ llms.txt 漏了这些 title（内容包里有、索引里没有）：${missed.join(" / ")}`);
  process.exit(2);
}
console.log(`✓ 同源自证：内容包里的 ${titles.length} 个 title 都在 llms.txt 里`);

// ⑤ 陈旧检查（只在 `--check` 下）：**产物比内容源旧** ⇒ 这份产物已经不代表内容了。
//    ⚠️ 这条与"生成得对不对"是两件事：`sync()` 比的是"现跑 vs 磁盘"，看不出来"内容改过没重跑"。
if (CHECK) {
  const prod = [LLMS, OUT].filter(existsSync).map((p) => statSync(p).mtimeMs);
  const src = wanted.map((rel) => statSync(abs(rel)).mtimeMs);
  if (prod.length && src.length && Math.min(...prod) < Math.max(...src)) {
    console.error("✗ 产物比内容源旧 ⇒ 重跑一次 press（内容改过、产物还没跟）");
    bad = 1;
  }
  process.exit(bad);
}
