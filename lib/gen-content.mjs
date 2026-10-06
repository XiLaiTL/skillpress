#!/usr/bin/env node
/**
 * gen-content.mjs —— 把内容源编成**站点用的 MoonBit 内容包**。
 *
 *   node gen-content.mjs                 # 生成 <站点应用>/content/content.generated.mbt
 *   node gen-content.mjs --check         # 只校验磁盘上的与生成的一致（门用）
 *   node gen-content.mjs --root <目录> --app <目录>   # 换项目根 / 换站点应用（便携与调试用）
 *
 * ## 内容源（**一个 skill = 一个主题**，不是"一个 md"）
 *
 * ```
 * skills/skillpress/SKILL.md       → 站点**首页**：H1 + 引言 = 首屏，每个 `##` = 顶栏的一栏
 * skills/<name>/SKILL.md           → 主题主文档（≤400 行，正文）
 * skills/<name>/references/*.md    → 可选：深水区（长表 / 证据 / 清单），**不占主文档预算**
 * skills/<name>/scripts/*          → 可选：可跑的小工具（在站点上按代码块展示）
 * ```
 *
 * 这个形状是为了**渐进披露**：主文档人人要读、必须短；refs 只在需要细节时展开。
 * 站点的左侧树就是照这个结构长出来的（skill → 展开 → 它的 refs / scripts）。
 *
 * ⚠️ **首页就是 `skills/skillpress/SKILL.md` 这一份 skill**（"自己既是 skill，也是主页"）：
 * 它没有特权内容 —— 顶栏的分栏就是它的 `##`，它同时也仍然出现在文档区的树里。
 * 找不到它就**报错**（不猜一个首页出来）：便携目录由 `pack` 生成那份 skill，见 `references/layout.md`。
 *
 * ## 为什么在**构建期**解析 markdown（而不是运行期）
 *
 * 运行期渲染 markdown 要一个 RN/RNW 的 markdown 组件库，而**自定义渲染规则过不了 prop 通道**
 * （`rules` 是函数，我们的通道只能传 JSON 文本 —— 见 moobile 的
 * `docs/design/DESIGN-COMPONENT-LIBRARY.md` §5）。**代码块高亮**恰恰要靠自定义渲染规则。
 * 所以内容在构建期变成**类型化数据**，运行期只剩"画"。
 *
 * ## 边界（刻意的）
 *
 * 只支持**内容源里实际用到**的构造：标题 / 段落 / 列表（两级，有序无序）/ 表格 /
 * 围栏代码块 / 引用 / 分隔线；内联只认 `code` / **bold** / 链接。
 * 遇到不认识的构造**逐条点名报错**（不静默丢内容 —— 跟 moobile 学的："解不开的必须看得见"）。
 *
 * ## 代码块：这里**只贴色号**，颜色在站点那边
 *
 * 每个围栏代码块交给 `highlight.mjs`（tree-sitter，构建期）切成"带色号的片段"，
 * 色号是那个文件里 `PALETTE` 的索引；**颜色本身在站点应用的 `app.mbt`**（"怎么画"是站点的事）。
 * 这台引擎里**唯一**的 npm 依赖就是高亮那个（`web-tree-sitter`）。
 *
 * 只依赖 Node 内置模块 + 那一个高亮引擎。
 */
import { readFileSync, readdirSync, existsSync, writeFileSync, mkdirSync, statSync } from "node:fs";
import { join, dirname, resolve, relative, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { init as hlInit, highlight } from "./highlight.mjs";
import { mdFiles, scriptFiles, nameKids, posix } from "./kids.mjs";
import { PROGRAM as PROGRAM0, REPO as REPO0, SKILLS as SKILLS0, APP as APP0 } from "./roots.mjs";

/**
 * 目录约定（**程序 / 仓库 / 内容 / 站点实例** 四个根，别混）：
 *
 *   <程序>  = `<仓库>/examples/apps/skillpress`      ← 本文件住在它的 `lib/`
 *   <仓库>  = moobile 的根                        ← `.agents/skills` 在它下面
 *   <内容>  = <仓库>/.agents/skills                  ← 7 份 skill（含首页那份）
 *   <实例>  = <内容>/skillpress/scripts/.skillpress  ← 一个"用 skillpress 的 MoonBit 工程"
 *
 * ⚠️ **程序与仓库是兄弟，不是包含关系**（2026-10-06 搬家后的形状）：
 * 搬家前程序住在 `<仓库>/examples/apps/skillpress/`，往上三层就是仓库根；
 * 搬家后往上三层会跑到 `D:\` —— 所以下面**先找兄弟里的 moobile**，找不到才退回老约定。
 * 两个根不在一起是刻意的：程序要能独立发布（npm / moonbit 包），而内容必须住在
 * `<仓库>/.agents/skills/`（harness 只扫仓库内的那个根，见内容侧的 `references/layout.md`）。
 */
const PROGRAM = PROGRAM0;
const REPO = REPO0;
const SKILLS = SKILLS0;

/**
 * 站点实例在哪：它是**内容侧**的一个 MoonBit 工程（`<内容>/skillpress/scripts/.skillpress/`），
 * 生成物（内容包）写进它的 `content/` 目录。
 *
 * 顺序：`--app` → `SKILLPRESS_APP_DIR` → 约定位置（内容根下那份 skill 的 scripts/ 里）。
 * 都不中就直接红 —— 别猜一个目录出来（猜错的表现是"站点没更新"，很难查）。
 */
const APP = APP0;
const OUT = join(APP, "content", "content.generated.mbt");

/**
 * 首页内容源 = **`skills/skillpress/SKILL.md`**（"自己既是 skill，也是主页"）。
 *
 * 为什么不读项目根那份 `README.md`：站点是"一堆 skill 印出来的东西"，
 * 首页也该是其中一份 skill —— 这样首页的**内容、体量、门**都跟别的 skill 同一套规矩；
 * 项目根的 README 留给人（仓库首页），不必长得像站点。找不到就报错，见 `references/layout.md`。
 */

function parseFrontmatter(text) {
  const firstLineEnd = text.indexOf("\n");
  const fenced = firstLineEnd >= 0 && text.slice(0, firstLineEnd).trim() === "---";
  if (!fenced) return { data: {}, body: text };
  const end = text.indexOf("\n---", firstLineEnd + 1);
  if (end === -1) return { data: {}, body: text };
  const data = {};
  for (const raw of text.slice(firstLineEnd + 1, end).split("\n")) {
    const m = raw.trim().match(/^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$/);
    if (m) data[m[1]] = m[2].trim();
  }
  return { data, body: text.slice(end + 4) };
}

/** 一行摘要：给左侧树用（去掉行内标记，截断）。 */
function summarize(s, max = 46) {
  const t = s
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/\s+/g, " ")
    .trim();
  return t.length <= max ? t : t.slice(0, max - 1) + "…";
}

/**
 * 内联 → Span 序列。
 *
 * 链接的处置**刻意为"当台词读"**：这是静态阅读页，没有路由也不跳外链，
 * 所以 `[text](url)` 渲染成：文字 +（相对目标时）跟在后面的代码样式路径。
 * 链接文字与目标相同时（README 里大量 `[`SPEC.md`](SPEC.md)`）**只留一份**。
 */
function inline(s, links) {
  const spans = [];
  const re = /`([^`]+)`|\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)]+)\)/g;
  let last = 0;
  let m;
  const emit = (span) => {
    const prev = spans[spans.length - 1];
    if (span.k === "Txt" && prev && prev.k === "Txt") prev.v += span.v;
    else spans.push(span);
  };
  const text = (t) => {
    const norm = t.replace(/\s+/g, " ");
    if (norm) emit({ k: "Txt", v: norm });
  };
  while ((m = re.exec(s)) !== null) {
    if (m.index > last) text(s.slice(last, m.index));
    if (m[1] !== undefined) emit({ k: "Code", v: m[1] });
    else if (m[2] !== undefined) emit({ k: "Bold", v: m[2] });
    else {
      const rawLabel = m[3];
      const label = rawLabel.replace(/`/g, "");
      const target = m[4].trim();
      const external = /^https?:/i.test(target);
      if (links && target && !external) links.push(target);
      if (label === target || external) emit({ k: /^[\w./-]+$/.test(label) ? "Code" : "Txt", v: label });
      else {
        emit({ k: "Txt", v: label });
        emit({ k: "Code", v: target });
      }
    }
    last = m.index + m[0].length;
  }
  if (last < s.length) text(s.slice(last));
  return spans;
}

/**
 * `## [这一节的名字](目标)` —— **整条标题就是一个链接**。
 *
 * 这就是 D3 说的"纯链接节"：节名本身指向一个文件。它是**入口页**的写法，
 * 不同于"节的正文里有链接"（那是普通分栏，点栏位只换正文）。
 * 判定刻意**严**：只有"方括号 + 圆括号"占满整条标题、且没有别的文字时才算。
 */
const PURE_LINK = /^\[([^\]]+)\]\(([^)]+)\)$/;

const BREAK = (nt, raw) =>
  !nt ||
  /^#{1,4}\s/.test(nt) ||
  /^```/.test(nt) ||
  /^\|/.test(nt) ||
  /^>\s?/.test(nt) ||
  /^[-*]\s+/.test(raw) ||
  /^\s*\d+[.)]\s+/.test(raw) ||
  /^-{3,}$/.test(nt);

function parseBlocks(body, where) {
  const lines = body.split("\n");
  const blocks = [];
  const problems = [];
  /** 第一处 `# ` 标题的纯文本 —— 官网页眉与首屏标题用它（H1 本身不作为一个块）。 */
  let title = "";
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const t = line.trim();
    if (!t) {
      i++;
      continue;
    }

    if (/^```/.test(t)) {
      const lang = t.slice(3).trim();
      const buf = [];
      i++;
      while (i < lines.length && !/^```/.test(lines[i].trim())) {
        buf.push(lines[i]);
        i++;
      }
      if (i >= lines.length) problems.push(`${where}:${i} 代码块没闭合`);
      i++;
      blocks.push({ k: "Code", lang, text: buf.join("\n") });
      continue;
    }

    if (/^-{3,}$/.test(t)) {
      blocks.push({ k: "Hr" });
      i++;
      continue;
    }

    const m = t.match(/^(#{2,4})\s+(.*)$/);
    if (m) {
      const lvl = m[1].length;
      const head = m[2].trim();
      const pl = head.match(PURE_LINK);
      if (lvl === 2 && pl) {
        // 纯链接节：标题就是一个链接 —— 记下目标，交给 readHome 认它对应站点上的哪一页（D3）
        blocks.push({ k: "H2", spans: inline(pl[1]), link: pl[2].trim(), links: [] });
      } else {
        blocks.push({ k: lvl === 2 ? "H2" : lvl === 3 ? "H3" : "H4", spans: inline(head), links: [] });
      }
      i++;
      continue;
    }
    if (/^#\s+/.test(t)) {
      if (!title) title = summarize(t.replace(/^#\s+/, ""), 200);
      i++;
      continue;
    }

    if (/^\|/.test(t)) {
      const rows = [];
      while (i < lines.length && /^\s*\|/.test(lines[i])) {
        rows.push(lines[i].trim());
        i++;
      }
      if (rows.length < 2 || !/^\|[\s:|-]+\|$/.test(rows[1])) {
        problems.push(`${where}:${i - rows.length + 1} 表格缺分隔行`);
      }
      const cells = (r) => r.replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
      const links = [];
      blocks.push({
        k: "Table",
        header: cells(rows[0]).map((c) => inline(c, links)),
        rows: rows.slice(2).map((r) => cells(r).map((c) => inline(c, links))),
        links,
      });
      continue;
    }

    if (/^>\s?/.test(t)) {
      const buf = [];
      while (i < lines.length && /^>\s?/.test(lines[i].trim())) {
        buf.push(lines[i].trim().replace(/^>\s?/, ""));
        i++;
      }
      const links = [];
      blocks.push({ k: "Quote", spans: inline(buf.join(" "), links), links });
      continue;
    }

    if (/^[-*]\s+/.test(t) || /^\d+[.)]\s+/.test(t)) {
      const items = [];
      const ordered = /^\d+[.)]\s+/.test(t);
      const re = ordered ? /^\s*\d+[.)]\s+/ : /^\s*[-*]\s+/;
      const links = [];
      while (i < lines.length && re.test(lines[i])) {
        const raw = lines[i];
        const indent = raw.match(/^\s*/)[0].length >= 2 ? 1 : 0;
        const num = ordered ? raw.trim().match(/^(\d+)/)[1] + ". " : "";
        // 每一项各自记下它的链接：判"整项就是一个链接"要用（顶栏下拉的判据）
        const mine = [];
        const spans = inline(raw.trim().replace(re, ""), mine);
        items.push({ indent, num, spans, links: mine });
        for (const L of mine) links.push(L);
        i++;
      }
      blocks.push({ k: "Ul", items, links });
      continue;
    }

    if (/^!\[/.test(t)) {
      problems.push(`${where}:${i + 1} 不支持的构造（图片）：${t.slice(0, 40)}`);
      i++;
      continue;
    }
    if (/^</.test(t)) {
      problems.push(`${where}:${i + 1} 不支持的构造（原始 HTML）：${t.slice(0, 40)}`);
      i++;
      continue;
    }

    const buf = [t];
    i++;
    while (i < lines.length && !BREAK(lines[i].trim(), lines[i])) {
      buf.push(lines[i].trim());
      i++;
    }
    const links = [];
    blocks.push({ k: "P", spans: inline(buf.join(" "), links), links });
  }
  return { blocks, problems, title };
}

/**
 * **页面键**：把站点上某一页写成字符串（D3 的纯链接节要指向它）。
 *
 * **必须与站点应用里 `page_of` 的编号对账**：skill 主文档 = `<slug>`，
 * 子页 = `<slug>/<kind>/<name>`（`kind` 是 `ref` / `script`，`name` 是 `kids.mjs` 起的那个名字）。
 * 这里只认**站点真的收了的**页 —— 认不出来就不给跳转，并点名（见 `readHome`）。
 */
const docKey = (slug) => slug;
const kidKey = (slug, kid) => `${slug}/${kid.kind}/${kid.name}`;

/** 站点上所有页的键（按 slug 排序，与站点应用同一顺序）。 */
function pageKeys() {
  const dirs = existsSync(SKILLS)
    ? readdirSync(SKILLS).filter((d) => existsSync(join(SKILLS, d, "SKILL.md"))).sort()
    : [];
  const keys = new Set();
  for (const d of dirs) {
    keys.add(docKey(d));
    const skillDir = join(SKILLS, d);
    for (const k of nameKids(mdFiles(skillDir))) keys.add(kidKey(d, { kind: "ref", name: k.name }));
    for (const s of scriptFiles(skillDir)) {
      keys.add(kidKey(d, { kind: "script", name: s.rel.replace(/^scripts\//, "") }));
    }
  }
  return keys;
}

/**
 * **文件路径 → 页面键**：给纯链接节用（D3）。
 *
 * 为什么要这张表而不是直接拿路径比 `pageKeys()`：页面键用的是**站点上的显示名**
 * （md 去掉 `.md`；脚本保留扩展名），而节的链接写的是**文件路径**（`references/layout.md`）。
 * 两者差一层映射，靠字符串猜会错 —— 所以这里把"两种写法"都显式登记一遍。
 *
 * 同时登记**相对内容根**与**相对仓库根**两种前缀，于是节的链接写成
 * `references/layout.md`（相对首页那份 skill）与 `.agents/skills/skillpress/references/layout.md`
 * 都能认出来（见 `readHome` 的 `resolve`）。
 */
function pageIndex() {
  const dirs = existsSync(SKILLS)
    ? readdirSync(SKILLS).filter((d) => existsSync(join(SKILLS, d, "SKILL.md"))).sort()
    : [];
  const index = new Map();
  const put = (abs, key) => {
    const rel = posix(relative(SKILLS, abs));
    if (!rel.startsWith("..")) index.set(rel, key);
  };
  for (const d of dirs) {
    const skillDir = join(SKILLS, d);
    put(join(skillDir, "SKILL.md"), docKey(d));
    for (const k of nameKids(mdFiles(skillDir))) {
      put(k.abs, kidKey(d, { kind: "ref", name: k.name }));
    }
    for (const s of scriptFiles(skillDir)) {
      put(s.abs, kidKey(d, { kind: "script", name: s.rel.replace(/^scripts\//, "") }));
    }
  }
  return index;
}

/**
 * 首页：`skills/skillpress/SKILL.md` → 首屏（`lede`）+ 分栏（`sections`）。
 *
 * 切法就一条规矩：**每个 `##` 起一个新分栏**，它下面的内容（含 `###`）都归那一栏；
 * 第一个 `##` 之前的东西是首屏（H1 已抽成 `title`，不再当块）。
 * 于是"顶部栏有几个分栏"完全由那份 README 决定 —— 加一节就自动多一条，不用改代码。
 *
 * **纯链接节**（`## [名字](目标)`，D3）：目标先按"首页这份 skill 的目录"解析成绝对路径，
 * 再按仓库根 / 内容根折成"页面键"。认得出来就记进 `link`，点那一栏 = **直接渲染那一页**；
 * 认不出来就**点名**（不给静默的死链），并把它当普通分栏。
 */
function readHome(problems) {
  const readme = join(SKILLS, "skillpress", "SKILL.md");
  if (!existsSync(readme)) {
    problems.push(
      `找不到首页：${relative(REPO, readme)} —— 站点的首页**就是**这份 skill（见 references/layout.md）。` +
        `便携目录由 pack 生成它；项目里也可以自己写一份。`,
    );
    return null;
  }
  const { body } = parseFrontmatter(readFileSync(readme, "utf8"));
  const where = relative(REPO, readme).split("\\").join("/");
  const p = parseBlocks(body, where);
  problems.push(...p.problems);
  const lede = [];
  const sections = [];
  // `at` 是"这一栏起自哪个块"，只为下面认纯链接节时对得上号（不写进生成物）
  for (let i = 0; i < p.blocks.length; i++) {
    const b = p.blocks[i];
    if (b.k === "H2") {
      sections.push({ title: b.spans, blocks: [], link: "", nav: [], at: i });
      continue;
    }
    if (sections.length) sections[sections.length - 1].blocks.push(b);
    else lede.push(b);
  }
  if (!sections.length) problems.push(`${where} 里没有 \`##\` 标题 —— 官网首页的分栏就是它们，一条都没有就只剩首屏了`);

  // 纯链接节：把 `## [名字](目标)` 的目标认成站点上的一页（D3）
  const homeSkillDir = dirname(readme);
  const index = pageIndex();
  for (const sec of sections) {
    const b = p.blocks[sec.at];
    if (!b || !b.link) continue;
    const abs = resolve(homeSkillDir, b.link);
    const hit = index.get(posix(relative(SKILLS, abs))) || "";
    if (hit) {
      sec.link = hit;
      if (sec.blocks.length) {
        console.log(
          `（纯链接节「${summarize(plainOf(b.spans), 20)}」还带着 ${sec.blocks.length} 块正文 —— 点它会跳到 ${hit}，正文只在"不跳"时才看得到）`,
        );
      }
    } else {
      problems.push(
        `${where}：纯链接节「${summarize(plainOf(b.spans), 20)}」的目标 \`${b.link}\` 认不出对应站点上的哪一页 —— ` +
          `只能指向已收录的 skill 主文档（\`<slug>\`）或它的子页（如 \`references/layout.md\`）。`,
      );
    }
  }
  // 分栏下的"链接列表"：某个 `##` 的**第一个列表**，每一项**整项就是一个链接**、且都指向站点上收了的页
  // ⇒ 它就成了顶栏那条 tab 的**下拉菜单**（鼠标悬停，或触摸时点一下展开）。
  //
  // 判据刻意严（每个条件都要满足）：
  //   ① 是这一节的**第一个**列表；② 整项只有一个链接、没有别的文字（`- [名字](目标)`）；
  //   ③ 每一项的目标都解析得到页面键（认不出就**报错**，不给死链）。
  // 于是"正文里恰好有个列表"不会误判成菜单 —— 误判的代价是那一节的内容在正文里**少了一块**。
  for (const sec of sections) {
    const b = p.blocks[sec.at];
    // ⚠️ **纯链接节也可以有菜单**（两者可以叠加：标题指向一页、下面那个列表当把手下拉）。
    // 曾经这里写着 `if (!b || b.link) continue` —— 那会让「标题是链接 + 下面是链接列表」
    // 这种最想要的组合反而拿不到菜单（实测踩过）。
    if (!b) continue;
    const ul = sec.blocks.find((x) => x.k === "Ul");
    if (!ul || !ul.items.length) continue;
    const allLinks = ul.items.every((it) => {
      if (it.links?.length !== 1) return false;
      // ⚠️ 一条链接在渲染里是**两个片段**：`[Txt(名字), Code(目标)]`（见 `inline()` 的处置）。
      // 所以判据是"**整项就是 名字 + 目标**，没有别的散文" —— 不是"只有一个 span"（实测踩过）。
      const at = it.spans.findIndex((s) => s.k === "Code" && s.v === it.links[0]);
      if (at === -1) return false;
      return it.spans.slice(at + 1).every((s) => !s.v.trim());
    });
    if (!allLinks) continue;
    const nav = [];
    let bad = null;
    for (const it of ul.items) {
      const target = it.links[0];
      const key = index.get(posix(relative(SKILLS, resolve(homeSkillDir, target)))) || "";
      if (!key) {
        bad = target;
        break;
      }
      const at = it.spans.findIndex((s) => s.k === "Code" && s.v === target);
      // 名字 = **目标路径之前**的那些片段（链接在渲染里是"名字 + 路径"，路径不是名字的一部分）
      nav.push({ label: plainOf(at > 0 ? it.spans.slice(0, at) : it.spans), key });
    }
    if (bad) {
      problems.push(
        `${where}：分栏「${summarize(plainOf(sec.title), 20)}」里那个列表看着像**下拉菜单**，` +
          `但 \`${bad}\` 认不出对应站点上的哪一页 —— 要么改成真能跳的页（skill 主文档 / 它的子页），` +
          `要么在它前面加一句别的文字，让它**不当菜单**（当菜单的话它就不会渲染在正文里了）。`,
      );
      continue;
    }
    sec.nav = nav;
  }
  for (const sec of sections) delete sec.at;
  return { title: p.title || "首页", lede, sections };
}

/** Span 序列 → 纯文本（只给提示语用）。 */
const plainOf = (spans) => spans.map((s) => s.v).join("");


// ─────────────────────────────────────────────────────────── MoonBit 代码生成

const esc = (s) =>
  s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "").replace(/\t/g, "  ").replace(/\n/g, "\\n");

const spanList = (list) =>
  list.length ? `[${list.map((s) => `${s.k}("${esc(s.v)}")`).join(", ")}]` : "([] : Array[Span])";

/** 代码块的高亮片段 → MoonBit 的 `Array[(String, Int)]`（文本, 色号）。 */
const runList = (runs) =>
  runs && runs.length
    ? `[${runs.map(([t, i]) => `("${esc(t)}", ${i})`).join(", ")}]`
    : "([] : Array[(String, Int)])";

function emitBlock(b, pad) {
  switch (b.k) {
    case "Hr":
      return `${pad}Hr,`;
    case "H2":
      return `${pad}H2(${spanList(b.spans)}),`;
    case "H3":
      return `${pad}H3(${spanList(b.spans)}),`;
    case "H4":
      return `${pad}H4(${spanList(b.spans)}),`;
    case "P":
      return `${pad}P(${spanList(b.spans)}),`;
    case "Quote":
      return `${pad}Quote(${spanList(b.spans)}),`;
    case "Code":
      return `${pad}Code("${esc(b.lang)}", "${esc(b.text)}", ${runList(b.runs)}),`;
    case "Ul":
      return `${pad}Ul([${b.items.map((it) => `(${it.indent}, "${esc(it.num)}", ${spanList(it.spans)})`).join(", ")}]),`;
    case "Table":
      return `${pad}Table([${b.header.map(spanList).join(", ")}], [${b.rows
        .map((r) => `[${r.map(spanList).join(", ")}]`)
        .join(", ")}]),`;
    default:
      throw new Error(`未知块类型：${b.k}`);
  }
}

const LANG_BY_EXT = {
  ".mjs": "javascript",
  ".js": "javascript",
  ".mbt": "moonbit",
  ".sh": "bash",
  ".py": "python",
  ".json": "json",
  ".toml": "toml",
  ".yml": "yaml",
};

function readSkill(dir, problems) {
  const base = join(SKILLS, dir);
  const { data, body } = parseFrontmatter(readFileSync(join(base, "SKILL.md"), "utf8"));
  const parsed = parseBlocks(body, `skills/${dir}/SKILL.md`);
  problems.push(...parsed.problems);

  // ── 子页：**任何子目录里的 md**（`references/` 只是推荐位置）+ `scripts/` 下的非 md 脚本。
  // 规矩与"名字怎么起"都在 kids.mjs 里（三处共用，免得各写一份各漂一份）。
  const kids = [];
  for (const k of nameKids(mdFiles(base))) {
    const { data: rf, body: rb } = parseFrontmatter(readFileSync(k.abs, "utf8"));
    const p = parseBlocks(rb, `skills/${dir}/${k.rel}`);
    problems.push(...p.problems);
    const h1 = (rb.match(/^#\s+(.*)$/m) || [, ""])[1].trim();
    kids.push({
      kind: "ref",
      name: k.name,
      title: rf.title || h1 || k.name,
      desc: summarize(rf.description || rb.trim().split(String.fromCharCode(10)).find((l) => l.trim()) || ""),
      blocks: p.blocks,
    });
  }
  for (const f of scriptFiles(base)) {
    kids.push({
      kind: "script",
      name: f.rel.replace(/^scripts\//, ""),
      title: f.rel.replace(/^scripts\//, ""),
      desc: "随这个 skill 一起发的可跑脚本",
      blocks: [
        {
          k: "Code",
          lang: LANG_BY_EXT[extname(f.abs)] || "",
          text: readFileSync(f.abs, "utf8").replace(/\n$/, ""),
        },
      ],
    });
  }

  return {
    slug: dir,
    desc: summarize(data.description || "", 60),
    full_desc: data.description || "",
    when: data.whenToUse || "",
    blocks: parsed.blocks,
    kids,
  };
}

/** 生成一个 Doc 字面量（标题取 slug 或 README 的 H1）。 */
function docLit(d, pad, comma) {
  const out = [];
  out.push(`${pad}{`);
  out.push(`${pad}  slug: "${esc(d.slug)}",`);
  out.push(`${pad}  desc: "${esc(d.desc)}",`);
  out.push(`${pad}  full_desc: "${esc(d.full_desc)}",`);
  out.push(`${pad}  when: "${esc(d.when)}",`);
  out.push(`${pad}  blocks: [`);
  for (const b of d.blocks) out.push(emitBlock(b, pad + "    "));
  out.push(`${pad}  ],`);
  out.push(`${pad}  kids: [`);
  for (const k of d.kids) {
    out.push(`${pad}    {`);
    out.push(`${pad}      kind: "${esc(k.kind)}",`);
    out.push(`${pad}      name: "${esc(k.name)}",`);
    out.push(`${pad}      title: "${esc(k.title)}",`);
    out.push(`${pad}      desc: "${esc(k.desc)}",`);
    out.push(`${pad}      blocks: [`);
    for (const b of k.blocks) out.push(emitBlock(b, pad + "        "));
    out.push(`${pad}      ],`);
    out.push(`${pad}    },`);
  }
  out.push(`${pad}  ],`);
  out.push(`${pad}}${comma ? "," : ""}`);
  return out;
}

/** 生成一个 `Home` 字面量（官网首页：首屏 + 分栏）。 */
function homeLit(h, pad) {
  const out = [];
  out.push(`${pad}{`);
  out.push(`${pad}  title: "${esc(h.title)}",`);
  out.push(`${pad}  lede: [`);
  for (const b of h.lede) out.push(emitBlock(b, pad + "    "));
  out.push(`${pad}  ],`);
  out.push(`${pad}  sections: [`);
  for (const s of h.sections) {
    const nav =
      s.nav && s.nav.length
        ? `[${s.nav.map((n) => `{ label: "${esc(n.label)}", key: "${esc(n.key)}" }`).join(", ")}]`
        : "([] : Array[NavItem])";
    out.push(
      `${pad}    { title: ${spanList(s.title)}, link: "${esc(s.link || "")}", nav: ${nav}, blocks: [`,
    );
    for (const b of s.blocks) out.push(emitBlock(b, pad + "      "));
    out.push(`${pad}    ] },`);
  }
  out.push(`${pad}  ],`);
  out.push(`${pad}}`);
  return out;
}

/**
 * 就地给所有代码块贴上高亮片段（tree-sitter，见 `tools/highlight.mjs`）。
 *
 * 认不出语言的块**不算错**：内容里允许出现没配语法的标记（`lang` 空的那些多半是结构图），
 * 它们按原文渲染。**拼不回原文**才是错 —— 那条不变量在 `highlight()` 里硬拦。
 */
async function highlightAll(home, skills) {
  const stats = { blocks: 0, highlighted: 0, runs: 0, dark: 0, white: 0 };
  const doBlocks = async (blocks) => {
    for (const b of blocks) {
      if (b.k !== "Code" || !b.text.trim()) continue;
      stats.blocks++;
      const r = await highlight(b.text, b.lang);
      if (!r) continue;
      b.runs = r.runs;
      stats.highlighted++;
      stats.runs += r.runs.length;
      stats.dark += r.dark;
      stats.white += [...b.text].filter((c) => !/\s/.test(c)).length;
    }
  };
  if (home) {
    await doBlocks(home.lede);
    for (const s of home.sections) await doBlocks(s.blocks);
  }
  for (const d of skills) {
    await doBlocks(d.blocks);
    for (const k of d.kids) await doBlocks(k.blocks);
  }
  return stats;
}

async function generate() {
  const problems = [];
  const dirs = existsSync(SKILLS)
    ? readdirSync(SKILLS).filter((d) => existsSync(join(SKILLS, d, "SKILL.md"))).sort()
    : [];
  if (!dirs.length) problems.push("skills/ 下没有 SKILL.md");
  const skills = dirs.map((d) => readSkill(d, problems));
  const home = readHome(problems);
  // ★ 构建期高亮：代码块 → 带色号的片段（tree-sitter）
  await hlInit();
  const hl = await highlightAll(home, skills);
  if (hl.white > 0 && hl.blocks !== hl.highlighted && !process.argv.includes("--check")) {
    // 没配语法的标记是允许的（内容里那些结构图），但要说一声
    console.log(`（${hl.blocks - hl.highlighted}/${hl.blocks} 个代码块没配语法或为空，按原文渲染）`);
  }

  const out = [];
  out.push("// 由 `tools/gen-content.mjs` 生成 —— **别手改**（跑 `--check` 会红）。");
  out.push("//");
  out.push("// 内容源：`skills/skillpress/SKILL.md`（首页）+ `skills/<name>/{SKILL.md,references/*.md,scripts/*}`。");
  out.push("// 为什么在构建期解析 markdown：见 `tools/gen-content.mjs` 的文件头。");
  out.push("");
  out.push("///| 一段行内内容。");
  out.push("pub enum Span {");
  out.push("  Txt(String)");
  out.push("  Code(String)");
  out.push("  Bold(String)");
  out.push("}");
  out.push("");
  out.push("///| 正文里的一个块。");
  out.push("pub enum Block {");
  out.push("  Hr");
  out.push("  H2(Array[Span])");
  out.push("  H3(Array[Span])");
  out.push("  H4(Array[Span])");
  out.push("  P(Array[Span])");
  out.push("  Quote(Array[Span])");
  out.push("  Code(String, String, Array[(String, Int)]) // 语言, 正文, 高亮片段（文本, 色号）");
  out.push("  Ul(Array[(Int, String, Array[Span])]) // 缩进, 序号前缀(有序列表用), 内容");
  out.push("  Table(Array[Array[Span]], Array[Array[Array[Span]]]) // 表头, 行");
  out.push("}");
  out.push("");
  out.push("///| 一个子页：skill 的 references/（深水区）或 scripts/（随 skill 发的脚本）。");
  out.push("pub struct Kid {");  out.push("  kind : String // \"ref\" | \"script\"");
  out.push("  name : String");
  out.push("  title : String");
  out.push("  desc : String");
  out.push("  blocks : Array[Block]");
  out.push("}");
  out.push("");
  out.push("///| 一页 = 一个 skill。");
  out.push("pub struct Doc {");
  out.push("  slug : String        // 目录名（= skill 名）");
  out.push("  desc : String        // 侧栏用的一行摘要");
  out.push("  full_desc : String   // frontmatter 的完整 description");
  out.push("  when : String        // frontmatter 的 whenToUse");
  out.push("  blocks : Array[Block]");
  out.push("  kids : Array[Kid]");
  out.push("}");
  out.push("");
  out.push("///| 分栏下拉菜单里的一条（来自那一节的第一个链接列表）。");
  out.push("pub struct NavItem {");
  out.push("  label : String  // 显示的名字");
  out.push("  key : String    // 页面键（给 `find_page` 换成第几页）");
  out.push("}");
  out.push("");
  out.push("///| 官网首页的一个**分栏** = 首页那份 skill 里的一个 `##`（顶部栏的一条）。");
  out.push("pub struct Section {");
  out.push("  title : Array[Span]  // 分栏名（就是那个 `##` 的标题文本）");
  out.push("  blocks : Array[Block]");
  out.push("  link : String        // 纯链接节：这一节指向的**页面键**（空 = 普通分栏，点了只换正文）");
  out.push("  nav : Array[NavItem] // 这一节的下拉菜单（空 = 没有）；有它时点一下先展开");
  out.push("}");
  out.push("");
  out.push("");
  out.push("///| 首页（来自 `skills/skillpress/SKILL.md`：H1 + 首个 `##` 之前 = 首屏）。");
  out.push("pub struct Home {");
  out.push("  title : String       // H1 —— 页眉的站名");
  out.push("  lede : Array[Block]  // 首屏正文");
  out.push("  sections : Array[Section]");
  out.push("}");
  out.push("");
  out.push("///| 首页（来自 `skills/skillpress/SKILL.md`）。");
  out.push("pub fn home() -> Home {");
  if (home) out.push(...homeLit(home, "  "));
  else out.push('  { title: "moobile", lede: [], sections: [] },');
  out.push("}");
  out.push("");
  out.push("///| 全部 skill（按 slug 排序，保证生成物稳定）。");
  out.push("pub fn skills() -> Array[Doc] {");
  out.push("  [");
  for (const d of skills) out.push(...docLit(d, "    ", true));
  out.push("  ]");
  out.push("}");
  out.push("");
  out.push("///| 页面键 → `(kind, skill 下标, 子页下标)`；认不出来给 `(-1, -1, -1)`。");
  out.push("///");
  out.push("/// 键的形状与生成器里的 `docKey` / `kidKey` **必须对账**：");
  out.push("/// 主文档 = `<slug>`，子页 = `<slug>/<kind>/<name>`（kind 是 `ref` / `script`）。");
  out.push("/// 站在**生成物**这一侧做这个查找，是为了让「第几页」这个编号只有一处定义（`skills()` 的顺序）。");
  out.push("pub fn find_page(key : String) -> (Int, Int, Int) {");
  out.push("  let ks = skills()");
  out.push("  for i = 0; i < ks.length(); i = i + 1 {");
  out.push("    let d = ks[i]");
  out.push("    if key == d.slug {");
  out.push("      return (1, i, 0)");
  out.push("    }");
  out.push("    for j = 0; j < d.kids.length(); j = j + 1 {");
  out.push("      let k = d.kids[j]");
  out.push('      if key == "\\{d.slug}/\\{k.kind}/\\{k.name}" {');
  out.push("        return (2, i, j)");
  out.push("      }");
  out.push("    }");
  out.push("  }");
  out.push("  (-1, -1, -1)");
  out.push("}");
  return { text: out.join("\n") + "\n", skills, home, problems, hl };
}

const { text, skills, home, problems, hl } = await generate();

/**
 * ⚠️ 出口一律用 `process.exitCode`，**不调 `process.exit()`**。
 *
 * 实测（Windows + Node 24）：`process.exit()` 会在 WASM 运行时还挂着异步句柄时强行收摊，
 * libuv 直接断言 `!(handle->flags & UV_HANDLE_CLOSING)` 并让进程**以 127 退出** ——
 * 而屏幕上刚刚还打印着"一致"。**一个退出码不对的门比没有门更糟**（`&&` 链会误判、
 * CI 会红在一个根本没错的地方）。设 `exitCode` 后自然退出，句柄有机会正常关闭。
 */
if (problems.length) {
  console.error("gen-content：内容里有解不开的东西（**不静默丢**，逐条点名）：");
  for (const p of problems) console.error(`  ✗ ${p}`);
  process.exitCode = 2;
} else if (process.argv.includes("--check")) {
  if (!existsSync(OUT)) {
    console.error(`✗ 生成物不存在：${relative(REPO, OUT)} —— 跑一次不带 --check 的`);
    process.exitCode = 1;
  } else {
    const disk = readFileSync(OUT, "utf8");
    if (disk === text) {
      console.log(`gen-content --check：一致（首页 + ${skills.length} 份 skill）`);
    } else {
      console.error("✗ 生成物与源不一致（内容改过但没重跑生成器，或有人手改了生成物）");
      const a = disk.split("\n");
      const b = text.split("\n");
      for (let i = 0; i < Math.max(a.length, b.length); i++) {
        if (a[i] !== b[i]) {
          console.error(`  第一处差异在第 ${i + 1} 行：`);
          console.error(`    盘上：${(a[i] ?? "(缺)").slice(0, 100)}`);
          console.error(`    生成：${(b[i] ?? "(缺)").slice(0, 100)}`);
          break;
        }
      }
      process.exitCode = 1;
    }
  }
} else {
  mkdirSync(dirname(OUT), { recursive: true });
  writeFileSync(OUT, text);
  const blocks = skills.reduce((n, d) => n + d.blocks.length, 0);
  const kids = skills.reduce((n, d) => n + d.kids.length, 0);
  console.log(
    `gen-content：官网首页${home ? `（首屏 ${home.lede.length} 块 + ${home.sections.length} 个分栏）` : "（读不到）"} + ${skills.length} 份 skill / ${blocks} 块 / ${kids} 个子页 → ${relative(REPO, OUT)}`,
  );
  for (const d of skills) {
    console.log(
      `  · ${d.slug}  ${d.blocks.length} 块${d.kids.length ? ` + ${d.kids.length} 子页（${d.kids.map((k) => k.name).join(", ")}）` : ""}`,
    );
  }
}
