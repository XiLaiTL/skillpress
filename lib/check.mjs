#!/usr/bin/env node
/**
 * skillpress 门 —— 判据见 ../SPEC.md §6。
 *
 * 只依赖 Node 内置模块（与本仓库既有工具一致：不装依赖、可直接跑）。
 *
 *   node bin/skillpress.mjs check              # 检查内容根的 skills/**（路径相对**仓库根**）
 *   node bin/skillpress.mjs check --selftest   # 证伪：造坏 skill，门**必须**红
 *
 * 环境变量：MOOBILE_ROOT 指向 moobile 仓库根（默认 ../moobile —— 程序与仓库是兄弟）。
 *
 * 门存在的理由（SPEC §6）：**一个说谎的 skill 比没有 skill 更糟**。
 */
import { readFileSync, readdirSync, existsSync, statSync, mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { join, dirname, resolve, relative, isAbsolute } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { PROGRAM as PROGRAM0, REPO as REPO0, SKILLS as SKILLS0 } from "./roots.mjs";

/**
 * 目录约定：四个根由 `roots.mjs` 统一算（**程序 = 本仓库根**，它与内容仓是兄弟）。
 *   <仓库> = moobile 的根（**事实的家就是它**）｜ <内容> = `<仓库>/skills`
 * 锁与禁语表跟着**程序**走（它们是这套机制的契约），skill 跟着**内容根**走。
 */
// 四个根由 `roots.mjs` 统一算（别再在这里手写"往上几层" —— 那是漂移点）
const PROGRAM = PROGRAM0;
/**
 * G3 / G6 的**第二个根**：讲**程序自己**的路径相对它（`bin/skillpress.mjs`、`lib/check.mjs`…）。
 *
 * ⚠️ 2026-10-06 搬家（程序从 `<仓库>/examples/apps/skillpress/` 搬到兄弟目录
 * `interest/skillpress/`）之前，这个常量指的是**仓库根**，于是第二个根与第一个重复 ——
 * 内容里讲程序的指针实际**一个都没被查**（`bin`/`lib`/`grammars` 也不在 TOP_DIRS 里，
 * 所以是"静默不查"而不是"查了但错了"）。搬家把它补成真的两个根。
 */
const ROOT = PROGRAM0;
const MOOBILE = resolve(process.env.MOOBILE_ROOT || REPO0);
/** 内容根：7 份 skill 住在这儿（`<仓库>/skills` —— harness 也扫这个根）。 */
const SKILLS = SKILLS0;

/** SPEC §3 的体量预算。改这里就等于改规范 —— 两边必须一起动。 */
const LIMITS = { lines: 400, bytes: 20 * 1024, codeBlock: 15, table: 12 };
const REQUIRED_FIELDS = ["name", "description", "whenToUse"];
const APIS = ["html", "style", "cmd", "sub", "canvas", "gesture", "sqlite", "http"];

// ─────────────────────────────────────────────────────────── 前置：索引与禁语

/** moobile 源码里的 `fn <名字>` 与转发包名字清单 —— G5 用。只读一次。 */
function buildMbtIndex(root) {
  const names = new Set();
  const skip = new Set(["_build", "node_modules", ".mooncakes", ".git", "target"]);
  let files = 0;
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
      const p = join(dir, e.name);
      if (e.isDirectory()) {
        walk(p, depth + 1);
        continue;
      }
      if (!e.name.endsWith(".mbt") && !e.name.endsWith(".mbti")) continue;
      files++;
      let text;
      try {
        text = readFileSync(p, "utf8");
      } catch {
        continue;
      }
      for (const m of text.matchAll(/\b(?:fn|struct|enum|type|trait|let|const)\s+([A-Za-z_][A-Za-z0-9_]*)/g)) names.add(m[1]);
      for (const m of text.matchAll(/pub\s+using\s+@[A-Za-z0-9_/.@-]+\s*\{([^}]*)\}/g)) {
        for (const raw of m[1].split(",")) {
          const n = raw.trim().replace(/^type\s+/, "").split(/[\s(]/)[0];
          if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(n)) names.add(n);
        }
      }
    }
  };
  walk(root, 0);
  return { names, files };
}

function loadClaims() {
  const f = join(PROGRAM, "claims.txt");
  if (!existsSync(f)) return [];
  return readFileSync(f, "utf8")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"));
}

// ─────────────────────────────────────────────────────────── 解析与抽取

/**
 * 与 DSH 注册表**同款**的解析语义：只认 name / description / whenToUse 三个标量。
 * 参照实现：dsh-godot-skill 的 lib/index.js。多写的字段会被丢掉，所以这里也丢掉。
 */
function parseFrontmatter(text) {
  const firstLineEnd = text.indexOf("\n");
  const fenced = firstLineEnd >= 0 && text.slice(0, firstLineEnd).replace(/\r$/, "") === "---";
  if (!fenced) return { data: null, body: text };
  const end = text.indexOf("\n---", firstLineEnd + 1);
  if (end === -1) return { data: null, body: text };
  const all = {};
  for (const rawLine of text.slice(firstLineEnd + 1, end).split("\n")) {
    // ⚠️ **必须 trim**：CRLF 文件里每行尾部是 `\r`，而 JS 的 `.` 不匹配 `\r`
    // ⇒ `(.*)$` 匹配不到，整份 frontmatter 会**静默丢失**（实测踩过：一次 CRLF 写入
    // 让 name/description/whenToUse 全部消失，而报错只是"frontmatter 缺 name"）。
    // 参照实现 dsh-godot-skill 也是先 trim 再匹配 —— 这里与它对齐。
    const line = rawLine.trim();
    const m = line.match(/^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$/);
    if (!m) continue;
    let v = m[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    all[m[1]] = v;
  }
  const data = {};
  for (const k of REQUIRED_FIELDS) if (all[k] !== undefined) data[k] = all[k];
  data.__all = all;
  return { data, body: text.slice(end + 4) };
}

function fencedBlocks(body) {
  const out = [];
  const re = /^```([^\n`]*)\n([\s\S]*?)^```\s*$/gm;
  let m;
  while ((m = re.exec(body)) !== null) out.push({ lang: m[1].trim().toLowerCase(), code: m[2] });
  return out;
}

/** 反引号里的短片段（行内代码）。 */
function inlineCodes(body) {
  return [...body.matchAll(/`([^`\n]+)`/g)].map((m) => m[1]);
}

const PLACEHOLDER = /[<>{}$*?|\\\s]|^@|^https?:|^\.\.?\//;

/** moobile 仓库的一级目录 —— 只有以它们开头的 token 才当"仓库内路径"查（免得把 `作者/模块` 误判）。 */
const TOP_DIRS = new Set([
  "tools", "docs", "examples", "npm", "vendor", "canvas", "style", "html", "cmd", "sub", "http", "sqlite", "gesture",
  ".github", ".scratch", ".mooncakes", "target",
  // skillpress 自己的两个一级目录 —— 本仓库也发 skill（`skills/skillpress-dev/`），它的路径得能对上账
  "skills", "site", "references",
  // 内容根的**老**位置（`.agents/skills`，harness 的项目扫描根）—— 2026-10-06 搬去 `skills/` 了，
  // 但内容里还有"harness 的扫描根是 `.agents/skills`"这类**说明性**的话，留着它免得那些话变红。
  ".agents",
  // skill 自带的脚本目录（引擎就住在这种目录里）—— 加了它，`scripts/.skillpress/x.mjs`
  // 这种引用才会被查；解析时会把**这个 skill 自己的目录**也算一个根（见 judge()）。
  "scripts",
  // **程序自己的三个一级目录** —— 内容里"程序在哪儿"的指针（`bin/skillpress.mjs`、
  // `lib/check.mjs`、`grammars/PROVENANCE.md`）走这一条；它们相对**程序根**（见上面的 ROOT）。
  // 不加这三个，那些指针是**静默不查**的：门绿着，而死链没人管 —— 与 G3 存在的理由正相反。
  "bin", "lib", "grammars",
  // ⚠️ 刻意**不**收 `.dsh` / `.claude` 这类 agent 宿主的目录名：它们是**外部工具的约定**，
  // 不是本项目的目录。曾经加过一次（当时程序自己的 skill 临时住 `.dsh/skills/`），
  // 结果内容里那句"harness 的 rank 100 是 `.dsh/skills`"被当成仓库内路径去查 —— 而程序仓里
  // 并没有这个目录 ⇒ 一句**说明性的话**变成了红。程序自己的 skill 现在住 `skills/`（见上）。
]);

/**
 * 看起来像"仓库内路径"的 token —— 宁可漏报也不误报（G3 误杀比漏报更伤，会逼人删掉真引用）。
 * 判据：有 `/`、无占位符、且**一级目录在白名单里**。
 */
function looksLikePath(tok) {
  if (PLACEHOLDER.test(tok) || tok.includes("…")) return false;
  if (tok.startsWith("-") || tok.includes("@")) return false;
  if (!tok.includes("/")) return false;
  return TOP_DIRS.has(tok.split("/")[0]);
}

/**
 * 路径判定要**宽进严出**：
 *   ① 原样存在 → 过；
 *   ② 去掉尾部的"行文残留"（中文/标点，例如 `docs/FINDINGS.md的补记`）后存在 → 过，但记一条提示；
 *   ③ 都不存在 → 红。
 * 第 ② 条是刻意的：G3 误杀比漏报更伤（会逼人删掉真引用）。
 *
 * ⚠️ **按三个根查**：moobile 根（多数 skill 讲它）｜ **程序根**（`bin/` `lib/` `grammars/` —— 讲这套
 * 工具自己的那份）｜ **这个 skill 自己的目录**（`scripts/**`，引擎与站点实例住在那儿）。
 * 只认一个根会让另两边的引用**全红**，而红了以后人的处置通常是"把真引用删掉" —— 那正是最坏的结果。
 */
function resolvePath(roots, tok) {
  if (roots.some((r) => existsSync(join(r, tok)))) return { ok: true };
  const trimmed = tok.replace(/[^\w./-]+$/, "");
  if (trimmed && trimmed !== tok && roots.some((r) => existsSync(join(r, trimmed)))) {
    return { ok: true, note: `G3 提示：\`${tok}\` 尾部有行文残留，建议写成 \`${trimmed}\`` };
  }
  return { ok: false };
}

/** G4：从命令块里挑出"必须存在的脚本文件"。 */
function commandFiles(code) {
  const out = [];
  for (const rawLine of code.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || line.startsWith("//")) continue;
    for (const m of line.matchAll(/(?:^|\s|&&\s*|\|\|\s*)(?:bash\s+|sh\s+|python3?\s+|node\s+)?((?:tools|npm|examples|docs|vendor)\/[^\s'"]+\.(?:sh|py|mjs|cjs|js))/g)) {
      out.push(m[1]);
    }
  }
  return [...new Set(out)];
}

/**
 * G6：`file.md` §N 的**节号必须真的存在**。
 *
 * 为什么值得单做一条：skill 到处写"见 `docs/STATUS.md` §2"这种指针，
 * 而**指向一个不存在的节**是静默的 —— 读者点过去只会一脸茫然（或以为整份文档都相关）。
 * 判据：目标文件里必须有一个标题的数号与它相等（`## 2.` / `### 3.7.4` / `## 二、`）。
 */
const CJK_NUM = "一二三四五六七八九十";

/** 标题 → 它的"节号"。支持 `## 2. 契约` / `### 3.7.4 xxx` / `## 二、想改这个库`。 */
function headingIds(text) {
  const ids = new Set();
  for (const line of text.split("\n")) {
    const m = line.match(/^#{1,6}\s+(.*)$/);
    if (!m) continue;
    const body = m[1].trim();
    const arabic = body.match(/^([0-9]+(?:\.[0-9]+)*)(?=[\s.、:：)）]|$)/);
    if (arabic) ids.add(arabic[1]);
    const cjk = body.match(new RegExp(`^([${CJK_NUM}]+)[、.]`));
    if (cjk) ids.add(cjk[1]);
  }
  return ids;
}

/** 解析 skill 里的文档引用目标：先按 moobile 根，再按 skillpress 根。 */
function resolveDoc(ctx, tok) {
  for (const root of [ctx.moobile, ctx.root]) {
    const p = join(root, tok);
    if (existsSync(p)) return p;
  }
  return null;
}

function checkSectionRefs(ctx, body, fails, notes) {
  const cache = new Map();
  const idsFor = (abs) => {
    if (!cache.has(abs)) cache.set(abs, headingIds(readFileSync(abs, "utf8")));
    return cache.get(abs);
  };
  body.split("\n").forEach((line, i) => {
    const fileTokens = [...line.matchAll(/`([^`\n]+\.(?:md|mbt\.md))`/g)].map((m) => ({
      tok: m[1],
      at: m.index,
      end: m.index + m[0].length, // 到**收尾反引号之后**为止 —— 距离要从这里算
    }));
    if (!fileTokens.length) return;
    for (const m of line.matchAll(/§\s*([0-9]+(?:\.[0-9]+)*|[一二三四五六七八九十]+)/g)) {
      // 最近的、且在它前面的文件引用（12 字符内）
      const owner = [...fileTokens].reverse().find((f) => f.end <= m.index && m.index - f.end < 12);
      if (!owner) continue;
      const abs = resolveDoc(ctx, owner.tok);
      if (!abs) continue; // 路径不存在由 G3 负责，这里不重复报
      const ids = idsFor(abs);
      const want = m[1];
      if (!ids.size) {
        notes.push(`G6 提示：\`${owner.tok}\` §${want} —— 该文件没有可识别的编号标题，无法对账`);
        continue;
      }
      if (!ids.has(want)) {
        const sample = [...ids].slice(0, 8).join(" / ");
        fails.push(`G6 节号不存在：\`${owner.tok}\` §${want}（正文 L${i + 1}；该文件只有 ${sample} …）`);
      }
    }
  });
}

// ─────────────────────────────────────────────────────────── 判据主体

/** 唯一的判据实现：给定 SKILL.md 的正文与它所在目录名，返回失败清单。 */
/**
 * G3 / G4 的候选根：moobile、项目根，**以及这个 skill 自己的目录**。
 *
 * 最后那个是"skill 自带脚本"要的：`skills/skillpress/SKILL.md` 里写 `scripts/.skillpress/check.mjs`
 * 时，它相对的是**那个 skill 目录**（引擎就住在里面），不是项目根。
 */
function skillRoots(ctx, name) {
  return [...ctx.roots, join(SKILLS, name)];
}

function judge(text, name, ctx, kind = "skill") {
  const fails = [];
  const notes = [];
  const lines = text.split("\n").length;
  const bytes = Buffer.byteLength(text, "utf8");
  const { data, body } = parseFrontmatter(text);

  // G1 frontmatter —— **主文档必须有**；`references/` 与 `FAQ.md` 是可选（有就检查，不强制）
  if (!data) {
    if (kind === "skill") fails.push("G1 frontmatter 缺失或未闭合（必须是文件开头的 --- … ---）");
  } else {
    if (kind === "skill") {
      for (const k of REQUIRED_FIELDS) if (!data[k] || !data[k].trim()) fails.push(`G1 frontmatter 缺 ${k}`);
      if (data.name && data.name.trim() !== name) fails.push(`G1 name="${data.name}" 与目录名 "${name}" 不一致`);
    }
    const extra = Object.keys(data.__all).filter((k) => !REQUIRED_FIELDS.includes(k));
    if (extra.length) notes.push(`G1 提示：字段 ${extra.join(", ")} 注册表不读（可留作打包元数据，见 SPEC §3）`);
  }

  // G2 体量
  if (lines > LIMITS.lines) fails.push(`G2 体量 ${lines} 行 > ${LIMITS.lines} 行`);
  if (bytes > LIMITS.bytes) fails.push(`G2 体量 ${bytes} B > ${LIMITS.bytes} B`);
  // G2 行尾：必须 LF（与 moobile 自己的规矩一致；CRLF 还会让 frontmatter 静默失效，见 parseFrontmatter）
  if (text.includes("\r")) fails.push(`G2 行尾含 CR（${(text.match(/\r/g) || []).length} 处）—— skill 文件一律 LF`);
  for (const b of fencedBlocks(body)) {
    const n = b.code.replace(/\n$/, "").split("\n").length;
    if (n > LIMITS.codeBlock) fails.push(`G2 代码块 ${n} 行 > ${LIMITS.codeBlock} 行（长示例指向 examples/apps/**）`);
  }
  const bodyLines = body.split("\n");
  let tableStart = -1;
  for (let i = 0; i <= bodyLines.length; i++) {
    const isRow = i < bodyLines.length && /^\s*\|/.test(bodyLines[i]);
    if (isRow && tableStart === -1) tableStart = i;
    if (!isRow && tableStart !== -1) {
      const n = i - tableStart;
      if (n > LIMITS.table) fails.push(`G2 表格 ${n} 行 > ${LIMITS.table} 行（正文 L${tableStart + 1} 起，拆两节）`);
      tableStart = -1;
    }
  }

  // G3 路径 / G5 API 名（都扫行内代码）
  for (const tok of inlineCodes(body)) {
    if (looksLikePath(tok)) {
      const r = resolvePath(skillRoots(ctx, name), tok);
      if (!r.ok) fails.push(`G3 路径不存在：${tok}`);
      else if (r.note) notes.push(r.note);
    }
    const m = tok.match(new RegExp(`^@(${APIS.join("|")})\\.([^\\s(（[\\],，;；)）]+)`));
    if (!m) continue;
    const api = m[2].split("::")[0]; // `@style.Style::new()` —— 名字部分是 Style
    if (api && !ctx.index.names.has(api)) fails.push(`G5 源码里没有这个 API：${tok}`);
  }

  // G4 命令
  for (const b of fencedBlocks(body)) {
    if (!["bash", "sh", "console", "shell", ""].includes(b.lang)) continue;
    for (const f of commandFiles(b.code)) {
      // 同 G3：三个根都认（引擎自己的 scripts/ 相对那个 skill 目录也存在）
      if (!skillRoots(ctx, name).some((r) => existsSync(join(r, f)))) fails.push(`G4 命令引用的脚本不存在：${f}`);
    }
  }

  // G6 节号对账
  checkSectionRefs(ctx, body, fails, notes);

  // G7 禁语（否定语境放行：命中点前 4 字符内有 不/非/别/没）
  for (const phrase of ctx.claims) {
    let at = body.indexOf(phrase);
    let guilty = false;
    while (at !== -1) {
      const before = body.slice(Math.max(0, at - 4), at);
      if (!/[不非别没]/.test(before)) {
        guilty = true;
        break;
      }
      at = body.indexOf(phrase, at + phrase.length);
    }
    if (guilty) fails.push(`G7 出现禁语「${phrase}」（SPEC §6：不许把未做写成已支持）`);
  }

  return { fails, notes, stats: { lines, kb: (bytes / 1024).toFixed(1) } };
}

// ─────────────────────────────────────────────────────────── G8：漂移锁

/**
 * G8 —— **体量 / 条目数变化必须人复核**。
 *
 * 为什么：skill 的失效方式不是"写错一个字"，而是**悄悄膨胀**
 * （每次补一条、每次加一版，半年后从 100 行涨到 600 行，而没人注意到）。
 * 判据不是"不许改"，而是"**改了要有人说一声**"：
 * 指纹对不上就红，复核后用 `--update-lock` 落锁。
 */
function fingerprint(text) {
  const { body } = parseFrontmatter(text);
  const rows = body.split("\n").filter((l) => /^\s*\|/.test(l)).length;
  return { lines: text.split("\n").length, bytes: Buffer.byteLength(text, "utf8"), rows, codeBlocks: fencedBlocks(body).length };
}

/**
 * 一个 skill 的全部文本文件（SPEC §3 的固定结构）。
 *
 * ⚠️ **`references/` 与 `FAQ.md` 也是 skill 的一部分** —— 它们进指纹、也要过门。
 * 只把 `SKILL.md` 纳入，等于给"塞进 refs 就没人管"开了一道后门。
 */
function skillFiles(d) {
  const base = join(SKILLS, d);
  const out = [];
  // ⚠️ `rel` 相对**内容根**（`<仓库>/skills`）—— 读写都拿它拼，别再套一层
  if (existsSync(join(base, "SKILL.md"))) out.push({ rel: `${d}/SKILL.md`, kind: "skill" });
  const refs = join(base, "references");
  if (existsSync(refs)) {
    for (const f of readdirSync(refs).filter((f) => f.endsWith(".md")).sort()) {
      out.push({ rel: `${d}/references/${f}`, kind: "aux" });
    }
  }
  if (existsSync(join(base, "FAQ.md"))) out.push({ rel: `${d}/FAQ.md`, kind: "aux" });
  return out;
}

/** 一个 skill 的指纹 = 它**所有**文本文件的合计（把内容搬进 refs 也会被看见）。 */
function fingerprintSkill(d) {
  const agg = { files: 0, lines: 0, bytes: 0, rows: 0, codeBlocks: 0 };
  for (const f of skillFiles(d)) {
    const fp = fingerprint(readFileSync(join(SKILLS, f.rel), "utf8"));
    agg.files++;
    agg.lines += fp.lines;
    agg.bytes += fp.bytes;
    agg.rows += fp.rows;
    agg.codeBlocks += fp.codeBlocks;
  }
  return agg;
}

function loadLock() {
  const f = join(PROGRAM, "skills.lock.json");
  if (!existsSync(f)) return null;
  try {
    return JSON.parse(readFileSync(f, "utf8"));
  } catch {
    return null;
  }
}

/** 这条锁记录属于**当前这个内容根**吗？（老格式没记根 ⇒ 按当前根算，与从前行为一致） */
const belongsHere = (rec) => rec === undefined || rec.root === undefined || rec.root === SKILLS;

/**
 * 打印用的路径：优先相对**它所在的那个根**（内容仓根 / 程序根），都不在就相对 cwd。
 *
 * ⚠️ 原先这里硬编码写 `skills/${rel}` —— 程序自己也有一批 skill（住 `skills/`）之后，
 * 那份清单会**指着不存在的路径**（明明查的是 `skills/`，却印成 `skills/`）。
 * 输出撒谎和文档撒谎一样致命：看的人会照着它去改一个不存在的文件。
 */
function displayPath(abs) {
  for (const base of [MOOBILE, PROGRAM]) {
    const rel = relative(base, abs);
    if (rel && !rel.startsWith("..") && !isAbsolute(rel)) return rel.split("\\").join("/");
  }
  return relative(process.cwd(), abs).split("\\").join("/");
}

/**
 * 落锁。**可以只锁一个**（`--update-lock <名字>`）—— 多代理并行改不同的 skill 时，
 * 整文件重写会把别人正在改的那份指纹一起锁掉，等他们改完 G8 就无辜地红（实测踩过：
 * 三个 skill 同时在写，谁先落锁谁把别人的指纹也定了）。
 */
function writeLock(onlyName) {
  const lock = loadLock() || { skills: {} };
  lock._note = "由 `node ../skillpress/bin/skillpress.mjs check --update-lock [名字]` 生成。改动 skill 后必须重跑并复核（SPEC §6 G8）。";
  lock.skills = lock.skills || {};
  const targets = onlyName ? [onlyName] : skillDirs();
  for (const d of targets) {
    if (!existsSync(join(SKILLS, d, "SKILL.md"))) return null; // 指名了一个不存在的 skill
    // ⚠️ 记下**这个指纹属于哪个内容根**：程序可以面对多个内容根（内容仓的 `skills`
    // 与程序自己的 `skills/`），而锁是**一份**共用的。不记根的话，查 A 根就会把 B 根的
    // 条目报成"已删除的 skill" —— 提示一多，真提示就被淹了（正是这门最不想要的形状）。
    lock.skills[d] = { ...fingerprintSkill(d), root: SKILLS };
  }
  // 落锁时顺手清掉"根已经不在磁盘上"的条目（比如程序自己的 skill 从小根挪到大根之后）：
  // 留着它们只会让锁越攒越旧；清掉之后那条 skill 在新根上会以"新增 skill"的**提示**出现，
  // 正好是要人复核一次的形状。
  for (const [d, rec] of Object.entries(lock.skills)) {
    if (rec && rec.root && rec.root !== SKILLS && !existsSync(rec.root)) delete lock.skills[d];
  }
  // 锁跟着**程序**走（它是机制的契约，不是这一份内容的数据）
  writeFileSync(join(PROGRAM, "skills.lock.json"), JSON.stringify(lock, null, 2) + "\n");
  return lock;
}

function checkLock() {
  const lock = loadLock();
  const dirs = skillDirs();
  if (!lock) return { fails: ["G8 没有 skills.lock.json —— 跑一次 `node ../skillpress/bin/skillpress.mjs check --update-lock`"], notes: [] };
  const fails = [];
  const notes = [];
  const seen = new Set();
  for (const d of dirs) {
    if (!existsSync(join(SKILLS, d, "SKILL.md"))) continue;
    seen.add(d);
    const now = fingerprintSkill(d);
    const was = lock.skills[d];
    if (was && !belongsHere(was)) continue; // 别的内容根的条目：不比对、也不算"已删除"
    if (!was) {
      notes.push(`G8 新增 skill：${d}（${now.lines} 行 / ${now.rows} 表格行）—— 确认后用 --update-lock 落锁`);
      continue;
    }
    const diff = Object.keys(now).filter((k) => now[k] !== was[k]);
    if (diff.length) {
      const detail = diff.map((k) => `${k} ${was[k]} → ${now[k]}`).join("；");
      // **硬**：指纹变了必须有人看过。提示会被淹没，而这个门的全部意义就是"不许悄悄膨胀"。
      fails.push(`G8 指纹变了：${d}（${detail}）—— 复核这次体量变化，然后 \`node ../skillpress/bin/skillpress.mjs check --update-lock\``);
    }
  }
  for (const d of Object.keys(lock.skills)) {
    if (seen.has(d) || !belongsHere(lock.skills[d])) continue;
    notes.push(`G8 锁里还有已删除的 skill：${d} —— 复核后 --update-lock`);
  }
  return { fails, notes };
}

// ─────────────────────────────────────────────────────────── 入口

function skillDirs() {
  const dir = SKILLS;
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((d) => statSync(join(dir, d)).isDirectory());
}

function run(ctx) {
  console.log(`skillpress check —— moobile 根：${ctx.moobile}`);
  console.log(`索引：${ctx.index.files} 个 .mbt 文件 / ${ctx.index.names.size} 个名字（供 G5 对账）`);
  const dirs = skillDirs();
  if (!dirs.length) {
    console.log("（skills/ 下还没有 skill —— 先写一个，门才有东西可查）");
    return 0;
  }
  let bad = 0;
  for (const d of dirs) {
    if (!existsSync(join(SKILLS, d, "SKILL.md"))) {
      console.log(`✗ ${d}\n    ✗ 缺 SKILL.md`);
      bad++;
      continue;
    }
    // 一个 skill = 主文档 + references/** + FAQ.md（SPEC §3）—— **全都过门**
    const files = skillFiles(d);
    let skillBad = 0;
    const printed = [];
    for (const f of files) {
      const r = judge(readFileSync(join(SKILLS, f.rel), "utf8"), d, ctx, f.kind);
      printed.push({ f, r });
      if (r.fails.length) skillBad++;
    }
    const total = printed.reduce((n, p) => n + p.r.stats.lines, 0);
    console.log(
      `${skillBad ? "✗" : "✓"} ${d}  ${files.length} 个文件 / ${total} 行${files.length > 1 ? `（主文档 ${printed[0].r.stats.lines} 行）` : ""}`,
    );
    for (const { f, r } of printed) {
      if (files.length > 1) console.log(`    · ${displayPath(join(SKILLS, f.rel))}  ${r.stats.lines} 行 / ${r.stats.kb} KB`);
      for (const n of r.notes) console.log(`    · ${n}`);
      for (const x of r.fails) console.log(`    ✗ ${x}`);
    }
    if (skillBad) bad++;
  }
  const lock = checkLock();
  for (const n of lock.notes) console.log(`    · ${n}`);
  for (const f of lock.fails) console.log(`    ✗ ${f}`);
  bad += lock.fails.length;

  console.log(bad ? `\n${bad} 项不合格` : `\n全部通过（${dirs.length} 个 skill）`);
  return bad ? 1 : 0;
}

/** 证伪自检：每个诱饵都**必须**被点名，正例**必须**通过。全绿才算门是好的。 */
function selftest(ctx) {
  const tmp = mkdtempSync(join(tmpdir(), "skillpress-"));
  const fm = (n, extra = "") => `---\nname: ${n}\ndescription: d\nwhenToUse: w\n${extra}---\n\n`;
  const cases = [
    ["name-mismatch", fm("别的名字") + "正文\n", /G1/],
    ["missing-field", `---\nname: missing-field\ndescription: d\n---\n\n正文\n`, /G1/],
    ["no-frontmatter", "# 没有 frontmatter\n", /G1/],
    ["too-big", fm("too-big") + "填充\n".repeat(LIMITS.lines + 10), /G2/],
    ["big-codeblock", fm("big-codeblock") + "```moonbit\n" + "x\n".repeat(LIMITS.codeBlock + 2) + "```\n", /G2/],
    ["bad-path", fm("bad-path") + "见 `docs/这份文档不存在.md`\n", /G3/],
    // 这条专测"多根"那半边：`tools/…` 在 moobile / 项目根 / skill 目录里都没有 ⇒ 仍然必须红
    ["bad-path-skillpress", fm("bad-path-skillpress") + "见 `tools/没有这个工具.mjs`\n", /G3/],
    // 这条专测**程序根**那半边（`bin/` `lib/` `grammars/`）：程序里没有它 ⇒ 必须红。
    // 搬家前这些 token **一个都不查**（不在 TOP_DIRS 里），所以必须有个诱饵看着它别退回去。
    ["bad-program-path", fm("bad-program-path") + "见 `bin/没有这个门面.mjs`\n", /G3/],
    ["bad-script", fm("bad-script") + "```bash\nbash tools/没有这个脚本.sh\n```\n", /G4/],
    ["bad-api", fm("bad-api") + "用 `@html.没这个函数`\n", /G5/],
    ["bad-section", fm("bad-section") + "见 `docs/STATUS.md` §99。\n", /G6/],
    ["crlf", (fm("crlf") + "正文\n").replace(/\n/g, "\r\n"), /行尾含 CR/],
    ["forbidden", fm("forbidden") + (ctx.claims[0] || "载荷等价") + "\n", /G7/],
  ];
  console.log(`skillpress 证伪自检 —— ${tmp}`);
  let bad = 0;
  for (const [name, content, want] of cases) {
    const r = judge(content, name, ctx);
    const hit = r.fails.some((f) => want.test(f));
    console.log(`${hit ? "✓" : "✗"} 诱饵 ${name} —— ${hit ? "被点名" : "**没被抓到**（门有洞）"}`);
    if (!hit) bad++;
  }
  const goodText = fm("good") + "见 `docs/STATUS.md` §1，也见 `CONTRIBUTING.md` §1。\n\n```bash\nbash tools/verify_all.sh\n```\n";
  const rg = judge(goodText, "good", ctx);
  const ok = rg.fails.length === 0;
  console.log(`${ok ? "✓" : "✗"} 正例 good —— ${ok ? "通过（没有误杀）" : "被误杀：" + rg.fails.join("；")}`);
  if (!ok) bad++;
  console.log(bad ? `\n自检未通过（${bad} 项）—— 门本身有问题` : `\n自检通过（${cases.length + 1} 项）`);
  return bad ? 1 : 0;
}

const ctx = {
  root: ROOT,
  moobile: MOOBILE,
  // G3 / G4 的路径按**两个根**查：moobile（多数 skill 讲它）与**程序根**（讲本工具自己的那份）；
  // 再加"这个 skill 自己的目录"，由 skillRoots() 补上。
  roots: [MOOBILE, ROOT],
  index: buildMbtIndex(MOOBILE),
  claims: loadClaims(),
};
if (!existsSync(MOOBILE)) {
  console.error(`✗ 找不到 moobile 根目录（用 MOOBILE_ROOT 指定）：${MOOBILE}`);
  process.exit(2);
}
const mode = process.argv[2];
if (mode === "--selftest") process.exit(selftest(ctx));
/**
 * `--update-lock [名字]`：**不要求它排在 argv[2]**。
 *
 * 原先判据是"`argv[2] === "--update-lock"`"，于是 `check --skills <目录> --update-lock`
 * 会**静默变成一次普通检查**（模式位是 `--skills`）—— 你以为落了锁，其实什么都没发生，
 * 而下一次门又红。现在按"出现在哪儿都认"，名字取它后面那个**不以 `--` 开头**的 token。
 */
const lockIdx = process.argv.indexOf("--update-lock");
if (mode === "--update-lock" || lockIdx >= 0) {
  const after = lockIdx >= 0 ? process.argv[lockIdx + 1] : process.argv[3];
  const only = after && !after.startsWith("--") ? after : undefined;
  const lock = writeLock(only);
  if (!lock) {
    console.error(`✗ --update-lock：没有这个 skill：${only}`);
    process.exit(2);
  }
  console.log(`skills.lock.json 已落锁：${only || Object.keys(lock.skills).length + " 个 skill"}`);
  console.log("⚠️ 落锁 = 你**看过**这次的体量变化；它不是「让门变绿」的手段（SPEC §6 G8）。");
  process.exit(0);
}
process.exit(run(ctx));
