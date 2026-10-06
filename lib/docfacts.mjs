#!/usr/bin/env node
/**
 * docfacts —— **文档里的事实 ↔ 代码里的真相** 对账门。
 *
 * 为什么有这个文件：skillpress 的门只能保证 **skill 不撒谎**；skill 的事实来自 docs，
 * 所以 docs 撒谎同样致命。2026-10-04 实测 7 处漂移（见 ../DRIFT.md），
 * 它们不是七次意外，是**一类**问题 —— 手抄的、可计算的事实。
 *
 *   node tools/docfacts.mjs                        # 对账 moobile（默认 ../moobile）
 *   node tools/docfacts.mjs --root <dir>           # 换根目录
 *   node tools/docfacts.mjs --selftest             # 证伪：造一个假仓库，门必须点名
 *
 * 判据的取舍（★ 最重要的设计决定）：
 *   **只查"能从代码算出来"的事实**。算不出来的（比如"某个门的项数"）**不猜**，
 *   只在**多处互相矛盾**时点名 —— 因为"谁对"需要真跑，而"两处不一致"本身就是 bug。
 *
 * 只依赖 Node 内置模块。
 */
import { readFileSync, readdirSync, existsSync, statSync, mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { join, dirname, resolve, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { PROGRAM as PROGRAM0, REPO as REPO0 } from "./roots.mjs";

/** 本文件在 <程序>/lib；要查的事实住在 <仓库>（= moobile 的根，程序就在它下面）。 */
const HERE = dirname(fileURLToPath(import.meta.url));
const PROGRAM = PROGRAM0;
const SKILLPRESS = PROGRAM;
const DEFAULT_ROOT = resolve(process.env.MOOBILE_ROOT || REPO0);

/**
 * **当前态文档**：这些文件描述"现在是什么样"，里面的数字必须是当下的真相。
 * 其余的一律当**记录**（历史日志允许留旧数字，这正是它们存在的意义）——
 * 所以 CHANGELOG / FINDINGS / STATUS / _scratch 刻意**不在**扫描范围里。
 */
const CURRENT_DOCS = [
  "README.md",
  "AGENTS.md",
  "DEV.md",
  "CONTRIBUTING.md",
  "FORK.md",
  "THIRD-PARTY-NOTICE.md",
  "docs/README.md",
  "docs/ARCHITECTURE.md",
  "docs/HANDOVER.md",
  "docs/STATUS.md",
  "docs/PERF.md",
  "docs/PERF-RECIPES.md",
  "docs/design/LAYERS.md",
  "docs/design/DESIGN.md",
  "docs/design/DESIGN-COMPONENT-LIBRARY.md",
  "docs/design/DESIGN-FEASIBILITY.md",
  "docs/design/DESIGN-README.md",
  "docs/design/DESKTOP-RNW.md",
  "docs/design/SCAFFOLD.md",
  "npm/moobile-host/README.md",
];

/**
 * 记录类文件（在扫描范围外，写在这里是为了让"为什么不算"一目了然）。
 *
 * ⚠️ **2026-10-04 更正**：`docs/STATUS.md` 原先列在这里，是个**设计错误** ——
 * 它自称"现状与分数（唯一来源）"，是**当前态**文档，不是历史。
 * 排除它等于让"唯一来源"免于检查，而实测它恰恰是陈旧的那一方
 * （把已在真机量到像素的"文字字形"仍写成未验）。现在它**在**扫描范围里。
 *
 * 真正属于"历史"的只有这三份：CHANGELOG（按版本记）、FINDINGS（按轮次记证据）、
 * PLAN（计划，频繁重排）。它们留旧数字是对的。
 */
const RECORD_DOCS = ["CHANGELOG.md", "docs/FINDINGS.md", "PLAN.md"];

/**
 * **当前态文档的全集**：固定清单 + 按目录展开的那批。
 *
 * 为什么把 `examples/apps/<app>/README.md` 也纳进来：2026-10-04 修完根上 19 份之后，
 * 立刻发现 `examples/apps/canvas-spike/README.md` 还写着"画布上画中文**没上过真机**" ——
 * 而真机像素证据早有了。**门不扫的地方一定会漂**：范围该按"谁在描述现状"来定，
 * 而不是按"文件在哪个目录"。
 */
/**
 * **代码注释里的"当前态"断言**：`npm/moobile-host/*.js` 的文件头长期承担着
 * "验证到哪一步了 / 还没验什么"的职责 —— 而它们是**代码**，不在 `docs/**` 里，
 * 所以门的 D1–D5/D7/D8 抓不到。2026-10-04 的活样本：`canvas-skia.js` 的文件头还写着
 * "真机上的组件挂载没跑过"，而宿主 README 早已改口并给出真机像素证据。
 *
 * 这里**只对它们跑 D6**（缺席说法 vs 已落地台账）—— 因为代码注释里的路径/版本
 * 大量是"上游的、依赖内部的"，硬判会造出一堆误杀。
 */
function claimFiles(root) {
  const dir = join(root, "npm", "moobile-host");
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith(".js"))
    .map((f) => `npm/moobile-host/${f}`);
}

function currentDocs(root) {
  const docs = CURRENT_DOCS.filter((d) => existsSync(join(root, d)));
  const appsDir = join(root, "examples", "apps");
  if (existsSync(appsDir)) {
    for (const app of readdirSync(appsDir).sort()) {
      const rel = `examples/apps/${app}/README.md`;
      if (existsSync(join(root, rel))) docs.push(rel);
    }
  }
  return docs;
}

const TOP_DIRS = new Set([
  "tools", "docs", "examples", "npm", "vendor", "canvas", "style", "html", "cmd", "sub", "http", "sqlite", "gesture",
  ".github", ".scratch", ".mooncakes",
]);

/**
 * **搬家前的一级目录**：它们曾经在仓库根，现在不在。
 *
 * 为什么必须单独列：D3 原先只查"一级目录在白名单里"的路径 ⇒ 这几种**旧路径根本不被检查**，
 * 而它们恰恰是漂移的重灾区。实测来源：`DEV.md` 里的 `internal/vdom/vdom.mbt`、
 * `docs/ARCHITECTURE.md` 里 14 处 `internal/**`、`cd server`（后端已挪到 `examples/services/`）。
 *
 * 2026-09 那次 vendor 搬家把 fork 从模块根摊平到 `vendor/rabbita/<包>/`，
 * 于是 `internal/rabbita/{rabbita,vdom,runtime}`、根上的 `svg/`、`dom/` 都不再存在。
 */
const STALE_ROOTS = new Set(["internal", "dom", "svg", "server"]);

/** 裸文件名（无 `/`）在**全仓库任何位置**找得到就算存在 —— 免得把"泛指的 App.js"误杀。 */
function buildBasenameIndex(root) {
  const names = new Set();
  const skip = new Set(["_build", "node_modules", ".git", ".mooncakes", ".scratch", "target"]);
  const walk = (dir, depth) => {
    if (depth > 12) return;
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      if (skip.has(e.name)) continue;
      if (e.isDirectory()) walk(join(dir, e.name), depth + 1);
      else names.add(e.name);
    }
  };
  walk(root, 0);
  return names;
}

// ─────────────────────────────────────────────────────────── 真相解析器

function truthPatchCount(root) {
  const dir = join(root, "tools", "patches");
  if (!existsSync(dir)) return null;
  return readdirSync(dir).filter((f) => f.endsWith(".patch")).length;
}

/** 库版本：真相在 `moon.mod` 的 `version = "x.y.z"`。 */
function truthLibVersion(root) {
  const f = join(root, "moon.mod");
  if (!existsSync(f)) return null;
  const m = readFileSync(f, "utf8").match(/^\s*version\s*=\s*"(\d+\.\d+\.\d+)"/m);
  return m ? m[1] : null;
}

/** 宿主包版本：真相在 `npm/moobile-host/package.json`。 */
function truthHostVersion(root) {
  const f = join(root, "npm", "moobile-host", "package.json");
  if (!existsSync(f)) return null;
  try {
    return JSON.parse(readFileSync(f, "utf8")).version || null;
  } catch {
    return null;
  }
}

function truthVendorVersion(root) {
  const f = join(root, "tools", "vendor.lock");
  if (!existsSync(f)) return null;
  const m = readFileSync(f, "utf8").match(/RABBITA_VERSION=(\d+\.\d+\.\d+)/);
  return m ? m[1] : null;
}

/**
 * 路径是否存在。**两档严重度**（这是本文件最重要的取舍）：
 *   · 带 `/` 且一级目录在白名单里 → 参照系确定 ⇒ **硬**（不存在就是错）
 *   · 裸文件名 → 只在**全仓库任何位置都不存在**时算**软**（警告，不判红）
 * 理由：裸名多半是行文泛指（`App.js`、`create.js`），硬判会造出几百条误杀，
 * 而一条误杀满天飞的门，下场是被关掉。
 */
function fileExists(ctx, tok) {
  if (existsSync(join(ctx.root, tok))) return true;
  if (tok.includes("/")) return false;
  return ctx.basenames.has(tok);
}

function isHardPath(tok) {
  return tok.includes("/");
}

// ─────────────────────────────────────────────────────────── D6：已落地能力台账

/**
 * D6 的台账：「已落地能力」的**人工索引**。
 *
 * 为什么需要它：D1–D5 只查"能从代码算出来"的事实；而
 * **「README 说未做、源码里早就做了」机器算不出来** —— 2026-10-04 人工核实抓到 5 处。
 * 台账每行 `关键词1+关键词2 | 证据文件 | 说明`；证据文件不存在 ⇒ 台账自己说谎（D6-self）。
 */
function loadDoneClaims() {
  const f = join(SKILLPRESS, "done-claims.txt");
  if (!existsSync(f)) return [];
  const out = [];
  for (const line of readFileSync(f, "utf8").split("\n")) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const [kws, evidence, note] = t.split("|").map((s) => (s || "").trim());
    if (!kws || !evidence) continue;
    out.push({ kws: kws.split("+").map((s) => s.trim()).filter(Boolean), evidence, note: note || "" });
  }
  return out;
}

/** "缺席说法"的措辞 —— 命中它才值得看同一行有没有踩到已落地的能力。 */
const ABSENCE = /未做|未实现|未提供|还没有|尚未|暂时用不了|不透明|没上过|未上过|没验|未验|未量|没量/;

/**
 * **历史语境豁免**：明确在讲"过去"的句子，说"当时没做"是**对的**，不该报。
 * 实测样本：`docs/design/DESIGN-COMPONENT-LIBRARY.md` 的"**当时没做的（§5 T1）**：载荷在那个阶段还是不透明的"。
 * 这也是 D6 刻意做成**软**判据的原因 —— 机器分不清"现在没做"和"当时没做"。
 */
const HISTORICAL = /当时|那时|起初|当初|原先|此前|曾经|历史上|那一轮|本轮之前/;

// ─────────────────────────────────────────────────────────── 断言模式

/**
 * 每个检查 = 一个"真相解析器" + 一组"文档里的说法"模式。
 * 命中且与真相不符 ⇒ 红。
 */
const ASSERTIONS = [
  {
    id: "D1",
    about: "patch 系列的长度",
    truth: truthPatchCount,
    unit: "个",
    patterns: [
      /(\d+)\s*个\s*patch/g, // 「33 个 patch」「15 个 patch」
      /patches\/\*\.patch[^\n|]{0,24}?\*\*(\d+)\s*个\*\*/g, // 「（**14 个**，按编号顺序…）」
    ],
  },
  {
    id: "D2",
    about: "vendor 的基准版本（rabitta 注册表制品）",
    truth: truthVendorVersion,
    unit: "",
    patterns: [/rabbita@(\d+\.\d+\.\d+)/g, /RABBITA_VERSION=(\d+\.\d+\.\d+)/g],
  },
  {
    // ★ 2026-10-04 补：README 里的 `@x.y.z` **原本没有任何门守着** ——
    // `tools/readme_probe.py` 只从 README 抽 import **路径**、版本用 moon.mod 顶替，
    // 不校验 README 里写的版本串 ⇒ 每次发版都会漂，而且没人会发现。
    id: "D7",
    about: "README 里抄的库版本",
    truth: truthLibVersion,
    unit: "",
    only: /^README\.md$/,
    patterns: [/XiLaiTL\/moobile@(\d+\.\d+\.\d+)/g],
  },
  {
    id: "D8",
    about: "宿主包 README 里抄的宿主包版本",
    truth: truthHostVersion,
    unit: "",
    only: /^npm\/moobile-host\/README\.md$/,
    patterns: [/moobile-host@(\d+\.\d+\.\d+)/g],
  },
];

/**
 * 算不出真相、但**多处互相矛盾**就一定是 bug 的事实。
 * `scope`：该行还必须提到这个命令 —— 否则会把"另一个门的项数"当成同一件事（实测误报过一次）。
 */
const CONTRADICTIONS = [
  { id: "D5", about: "真机判据项数", pattern: /真机\s*(\d+)\s*项/g, scope: /verify_android\.py/ },
  { id: "D5", about: "离线判据项数", pattern: /离线\s*(\d+)\s*项/g, scope: /verify_all\.sh/ },
];

// ─────────────────────────────────────────────────────────── 扫描

const PLACEHOLDER = /[<>{}$*?|\\\s]|^@|^https?:|^\.\.?\//;

function inlineCodes(line) {
  return [...line.matchAll(/`([^`\n]+)`/g)].map((m) => m[1]);
}

function isPathToken(tok) {
  if (PLACEHOLDER.test(tok) || tok.includes("…") || tok.startsWith("-") || tok.includes("@")) return false;
  if (tok.includes("/")) {
    const first = tok.split("/")[0];
    return TOP_DIRS.has(first) || STALE_ROOTS.has(first);
  }
  // 裸文件名：只查带已知扩展名的，且不含中文、不是光秃秃的扩展名（`.mjs` 是行文，不是文件）
  if (tok.startsWith(".")) return false;
  return /\.(md|mbt|mbti|js|mjs|cjs|json|jsonc|sh|py|ps1|toml|yml|yaml|txt)$/i.test(tok) && !/[\u4e00-\u9fff]/.test(tok);
}

/**
 * 扫描一份当前态文档。
 *
 * **豁免机制**（故意做成显式的、可审计的）：
 *   · 行内写 `docfacts:ignore` → 该行所有检查跳过（多半是"搬家前的旧布局"这类历史引用）
 *   · `<!-- docfacts:off -->` … `<!-- docfacts:on -->` → 区间跳过
 * 豁免**必须写在文档里**，不能藏在脚本里 —— 否则下一个人不知道这里为什么没报。
 */
function scanDoc(ctx, rel) {
  const abs = join(ctx.root, rel);
  if (!existsSync(abs)) return [];
  const findings = [];
  const lines = readFileSync(abs, "utf8").split("\n");
  let off = false;

  lines.forEach((line, i) => {
    if (/docfacts:off/.test(line)) off = true;
    if (/docfacts:on/.test(line)) {
      off = false;
      return;
    }
    if (off || /docfacts:ignore/.test(line)) return;

    // D3：被引用的仓库文件必须存在
    for (const tok of inlineCodes(line)) {
      if (!isPathToken(tok)) continue;
      // 剥掉行文残留与 `路径:行号` 后缀（`html/attrs.mbt:425`、`vdom.mbt:221-223`）
      const tok2 = tok.replace(/[，。；、)）]+$/, "").replace(/:\d+(?:[-/]\d+)*$/, "");
      if (!tok2 || fileExists(ctx, tok2)) continue;
      findings.push({
        id: "D3",
        severity: isHardPath(tok2) ? "hard" : "soft",
        file: rel,
        line: i + 1,
        msg: STALE_ROOTS.has(tok2.split("/")[0])
          ? `引用了**搬家前的旧一级目录**：\`${tok2}\`（该目录在仓库根已不存在；见 docfacts 的 STALE_ROOTS 注释）`
          : `${isHardPath(tok2) ? "引用的路径不存在" : "这个文件名在仓库里一处都找不到"}：\`${tok2}\``,
      });
    }

    // D6：缺席说法 vs「已落地能力」台账（软 —— 可能是"另一半没做"，要人看一眼）
    if (ABSENCE.test(line) && !HISTORICAL.test(line)) {
      for (const c of ctx.doneClaims) {
        if (!c.kws.every((k) => line.includes(k))) continue;
        findings.push({
          id: "D6",
          severity: "soft",
          file: rel,
          line: i + 1,
          msg: `说"未做/没验"，但台账记它**已落地**（${c.note}）；证据：\`${c.evidence}\``,
        });
      }
    }

    // D1/D2：可计算的事实
    for (const a of ASSERTIONS) {
      if (a.only && !a.only.test(rel)) continue; // 有些事实只对某几份文档成立（例：D7 只看根 README）
      const t = a.truth(ctx.root);
      if (t === null) continue;
      for (const p of a.patterns) {
        for (const m of line.matchAll(p)) {
          if (m[1] === String(t)) continue;
          findings.push({
            id: a.id,
            severity: "hard",
            file: rel,
            line: i + 1,
            msg: `${a.about}：文档写 \`${m[1]}${a.unit}\`，代码里是 \`${t}${a.unit}\`（真相可计算）`,
          });
        }
      }
    }
  });
  return findings;
}

/**
 * **只跑 D6** 的扫描器（给"代码注释"这类文件用）。
 * 为什么要单独一份：`npm/moobile-host/*.js` 的文件头在做"当前态声明"，
 * 但同时也塞满了上游路径、依赖内部文件名 —— 那些硬判会误杀，所以只查缺席说法。
 */
function scanAbsenceClaims(ctx, rel) {
  const abs = join(ctx.root, rel);
  if (!existsSync(abs)) return [];
  const findings = [];
  readFileSync(abs, "utf8")
    .split(/\r?\n/)
    .forEach((line, i) => {
      if (!ABSENCE.test(line) || HISTORICAL.test(line)) return;
      for (const c of ctx.doneClaims) {
        if (!c.kws.every((k) => line.includes(k))) continue;
        findings.push({
          id: "D6",
          severity: "soft",
          file: rel,
          line: i + 1,
          msg: `说"未做/没验"，但台账记它**已落地**（${c.note}）；证据：\`${c.evidence}\``,
        });
      }
    });
  return findings;
}

/** 跨文件的"同一事实给出不同数字"—— 不判断谁对，只点名矛盾。 */
function scanContradictions(root, docs) {
  const findings = [];
  for (const c of CONTRADICTIONS) {
    const hits = new Map(); // 值 → [文件:行]
    for (const rel of docs) {
      const abs = join(root, rel);
      if (!existsSync(abs)) continue;
      readFileSync(abs, "utf8")
        .split("\n")
        .forEach((line, i) => {
          if (c.scope && !c.scope.test(line)) return;
          for (const m of line.matchAll(c.pattern)) {
            if (!hits.has(m[1])) hits.set(m[1], []);
            hits.get(m[1]).push(`${rel}:${i + 1}`);
          }
        });
    }
    if (hits.size > 1) {
      const detail = [...hits.entries()].map(([v, where]) => `${v} 项 ← ${where.join("、")}`).join("；");
      findings.push({ id: c.id, severity: "hard", file: "(多处)", line: 0, msg: `${c.about}互相矛盾：${detail}` });
    }
  }
  return findings;
}

// ─────────────────────────────────────────────────────────── 入口

function check(root, mo = root) {
  const doneClaims = loadDoneClaims();
  const ctx = { root, mo, basenames: buildBasenameIndex(root), doneClaims };
  const docs = currentDocs(root);
  const claims = claimFiles(root);
  const findings = [
    ...docs.flatMap((d) => scanDoc(ctx, d)),
    ...claims.flatMap((f) => scanAbsenceClaims(ctx, f)),
    ...scanContradictions(root, docs),
  ];
  // D6-self：台账引用的证据文件必须存在 —— 台账自己说谎比文档漂移更严重
  for (const c of doneClaims) {
    if (!existsSync(join(mo, c.evidence))) {
      findings.push({
        id: "D6-self",
        severity: "hard",
        file: "done-claims.txt",
        line: 0,
        msg: `台账引用的证据不存在：\`${c.evidence}\`（关键词 ${c.kws.join("+")}）`,
      });
    }
  }
  return { docs, claims, findings };
}

function report(root) {
  const { docs, claims, findings } = check(root);
  console.log(`docfacts —— 根：${root}`);
  console.log(
    `扫描 ${docs.length} 份**当前态**文档 + ${claims.length} 份**代码注释**（只查 D6）（记录类不扫：${RECORD_DOCS.join("、")}）`,
  );
  console.log(
    `真相：patch=${truthPatchCount(root)} ｜ RABBITA_VERSION=${truthVendorVersion(root)} ｜ ` +
      `库版本=${truthLibVersion(root)} ｜ 宿主包版本=${truthHostVersion(root)}`,
  );
  const hard = findings.filter((f) => f.severity === "hard");
  const soft = findings.filter((f) => f.severity !== "hard");

  const dump = (list, title) => {
    if (!list.length) return;
    console.log(`\n──────── ${title}（${list.length} 处）`);
    const byId = new Map();
    for (const f of list) byId.set(f.id, [...(byId.get(f.id) || []), f]);
    for (const [id, l] of byId) {
      console.log(`\n── ${id}（${l.length} 处）`);
      for (const f of l) console.log(`   ${f.file}${f.line ? ":" + f.line : ""}  ${f.msg}`);
    }
  };
  dump(hard, "硬：可计算的真相对不上");
  dump(soft, "软：仓库里一处都找不到的文件名（警告，不判红）");

  if (!hard.length && !soft.length) {
    console.log("\n✓ 没有发现漂移");
    return 0;
  }
  console.log(
    `\n硬 ${hard.length} 处 ／ 软 ${soft.length} 处` +
      (hard.length ? " —— 红了：**先改文档的家，别只改一处**（改完重跑）" : " —— 没红，但值得看一眼"),
  );
  return hard.length ? 1 : 0;
}

/** 证伪：造一个假仓库，每个检查都必须点名；再加一个正确仓库，必须全绿。 */
function selftest() {
  const tmp = mkdtempSync(join(tmpdir(), "docfacts-"));
  const mk = (rel, content) => {
    const p = join(tmp, rel);
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, content);
  };
  mk("tools/vendor.lock", "RABBITA_VERSION=9.9.9\n");
  mk("tools/patches/001-a.patch", "");
  mk("tools/patches/002-b.patch", "");
  mk("tools/patches/003-c.patch", "");
  mk("tools/real.sh", "");
  mk("tools/verify_all.sh", "");
  mk("tools/verify_android.py", "");
  mk("docs/keep.md", "");

  // 坏仓库：四个诱饵（**刻意写成真实用法的样子** —— 带 scope 上下文，否则不算诱饵）
  mk("README.md", [
    "版本是 rabbita@1.2.3。", // D2（真相 9.9.9）
    "`tools/verify_all.sh` —— 离线 34 项。", // D5 的一半
    "见 `tools/不存在.sh`。", // D3
    "见 `internal/vdom/vdom.mbt`。", // D3（搬家前的旧一级目录）
    "事件载荷还是不透明的，受控组件暂时用不了。", // D6（台账说已落地）
  ].join("\n"));
  mk("FORK.md", [
    "共 7 个 patch。", // D1（真相 3）
    "`tools/verify_all.sh` —— 离线 32 项。", // D5 矛盾的另一半
    "`tools/verify_android.py` —— 真机 21 项。",
  ].join("\n"));
  mk("DEV.md", ["`tools/verify_android.py` —— 真机 27 项。"].join("\n")); // D5

  const bad = check(tmp, DEFAULT_ROOT);
  const want = [
    ["D1", /patch/],
    ["D2", /rabitta|vendor/],
    ["D3", /不存在/],
    ["D3", /搬家前的旧一级目录/],
    ["D5", /矛盾/],
    ["D6", /已落地/],
  ];
  console.log(`docfacts 证伪自检 —— ${tmp}`);
  let miss = 0;
  for (const [id, re] of want) {
    const hit = bad.findings.some((f) => f.id === id && re.test(f.msg));
    console.log(`${hit ? "✓" : "✗"} ${id} 诱饵 ${hit ? "被点名" : "**没被抓到**（门有洞）"}`);
    if (!hit) miss++;
  }

  // 好仓库：把坏仓库里的说法全改对，必须零发现
  mk("README.md", ["版本是 rabbita@9.9.9。", "`tools/verify_all.sh` —— 离线 34 项。", "见 `tools/real.sh`。"].join("\n"));
  mk("FORK.md", ["共 3 个 patch。", "`tools/verify_all.sh` —— 离线 34 项。", "`tools/verify_android.py` —— 真机 21 项。"].join("\n"));
  mk("DEV.md", ["`tools/verify_android.py` —— 真机 21 项。"].join("\n"));
  const good = check(tmp, DEFAULT_ROOT);
  const ok = good.findings.length === 0;
  console.log(`${ok ? "✓" : "✗"} 正例 —— ${ok ? "零发现（没有误杀）" : "被误杀：" + good.findings.map((f) => f.id + " " + f.msg).join("；")}`);
  if (!ok) miss++;
  console.log(miss ? `\n自检未通过（${miss} 项）—— 门本身有问题` : `\n自检通过（${want.length + 1} 项）`);
  return miss ? 1 : 0;
}

const argv = process.argv.slice(2);
const rootIdx = argv.indexOf("--root");
const root = rootIdx !== -1 ? resolve(argv[rootIdx + 1]) : DEFAULT_ROOT;
if (argv.includes("--selftest")) process.exit(selftest());
if (!existsSync(root)) {
  console.error(`✗ 根目录不存在：${root}`);
  process.exit(2);
}
process.exit(report(root));
