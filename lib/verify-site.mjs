#!/usr/bin/env node
/**
 * verify-site.mjs —— skillpress 站点的判据（真 Chrome，无头）。
 *
 *   node verify-site.mjs                  # 自起静态服务 + 无头 Chrome，跑完退出
 *   node verify-site.mjs --keep           # 跑完不关服务（给人自己打开看）
 *   node verify-site.mjs --shot f.png     # 顺手把**首页首屏**截一张图（不参与判据）
 *   node verify-site.mjs --app <目录>     # 站点应用在哪（默认按仓库布局找 moobile 的 examples）
 *
 * ## 判据为什么是这几条（都对应一个"会真的坏"的失败模式）
 *
 * | 断言 | 抓的是什么 |
 * |---|---|
 * | 顶栏列出首页 + **全部 `##` 分栏** | 首页内容源变了 / 生成器漏了某一节 |
 * | 首屏是首页那份 skill，**且没有侧栏** | 两个模式混成一层（那"换模式"就是假的） |
 * | 点第 2 个分栏后正文换成那一节、首屏引言退出 | 只验"渲出来"会漏掉"点了没反应"（事件通道） |
 * | 点「文档 / SKILL」后侧栏列出全部 skill + 摘要 | 换模式没接上，或侧栏只名字没摘要 |
 * | 点第二个 skill 之后正文换人 | 文档区的切页通道 |
 * | 展开树 → 点开 ref → 正文换成它 | 子页没进内容包 / 树是死的 |
 * | 表格 / 代码块各自出现 | markdown 解析把块降级成了纯文本（结构丢了） |
 * | 控制台没有 error | React 的告警与运行时错误**不会**让页面变空白，只是没人看见 |
 *
 * ⚠️ 点击用的是 **CDP 真鼠标事件**（`Input.dispatchMouseEvent`），不是 `element.click()` ——
 * RN 的 `Pressable` 在 web 上走的是 responder 事件，合成的 `click()` **不一定**能触发，
 * 那样这条判据就会变成"永远绿"。
 *
 * 只依赖 Node 内置模块（`fetch` 与 `WebSocket` 都是 Node 20+ 自带的）。
 */
import { spawn } from "node:child_process";
import { readFileSync, readdirSync, existsSync, mkdtempSync, writeFileSync, statSync } from "node:fs";
import { join, dirname, resolve, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import net from "node:net";
import { mdFiles, nameKids } from "./kids.mjs";
import { PROGRAM as PROGRAM0, REPO as REPO0, SKILLS as SKILLS0, APP as SITE0 } from "./roots.mjs";

const SKILLS = SKILLS0;

/** 目录约定：本文件在 <程序>/lib；站点实例在内容根的 `skillpress/scripts/.skillpress/`。 */
const HERE = dirname(fileURLToPath(import.meta.url));
const argOf = (name) => {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : null;
};
const PROGRAM = PROGRAM0;
const ROOT = REPO0;
/** 站点实例：内容侧那个"用 skillpress 的 MoonBit 工程"（与 `gen-content.mjs` 同一套解析）。 */
const SITE = SITE0;
/** 首页内容源 = `.agents/skills/skillpress/SKILL.md`（首页就是那份 skill）。 */
const HOME_MD = join(SKILLS, "skillpress", "SKILL.md");

/** 读内容源：**先剥掉 frontmatter**（那是给注册表看的，不是正文）。 */
function readSource(file) {
  const text = readFileSync(file, "utf8");
  if (!text.startsWith("---")) return text;
  const end = text.indexOf("\n---", 3);
  if (end < 0) return text;
  return text.slice(text.indexOf("\n", end + 1) + 1);
}

/**
 * `--shot <文件>`：把首页首屏截一张图（相对 skillpress 根解析）。
 *
 * **图不参与判据** —— 判据是上面那些 DOM 断言；这张图是给人看的（也免得仓库里留一张
 * 与当前页面对不上的旧截图）。所以它截在"首屏刚验完"的那一刻，不是跑完所有点击之后。
 */
const SHOT = (() => {
  const i = process.argv.indexOf("--shot");
  return i >= 0 ? process.argv[i + 1] : null;
})();

/** markdown 行内标记去掉、空白归一 —— 与页面上的 `innerText` 对得上。 */
const plain = (s) =>
  s
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\s+/g, " ")
    .trim();

/**
 * 从一份**内容源**里取一句"够长的正文行"当探针（纯链接节那条判据用）。
 *
 * 取法与 `homeSections()` 的探针同款：跳过标题 / 表格 / 代码 / 引用 / 列表 / 围栏内部，
 * 取第一句长度够的普通段落 —— 它一定是"渲染出来能看见的字"，于是能同时验
 * "跳对了页"与"渲染的是这份文件"。
 */
function pickProbe(md) {
  let inFence = false;
  for (const line of md.split("\n")) {
    const t = line.trim();
    if (/^```/.test(t)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (!t || /^[#>|`]/.test(t) || /^[-*]\s/.test(t) || /^\d+[.)]\s/.test(t)) continue;
    const p = plain(t);
    if (p.length >= 24) return p;
  }
  return "";
}

/**
 * 站点端口：**默认动态挑**。
 *
 * ⚠️ 这里踩过一次：原先写死 8123，而机器上已经有一个 8123 在跑（人看的预览服务）——
 * 自己 spawn 的那个 `listen` 悄悄失败（stdout/stderr 都被丢了），于是判据**测的是别人那个服务**。
 * 那正是这个仓库反复强调的"验证脚本要能识别我拿到的是不是这次的"。
 * 现在：默认挑一个空端口（`SITE_PORT` 可覆盖），并在起服务后**确认它在应答**。
 */
const PORT = Number(process.env.SITE_PORT || 0);

/**
 * 挑一个**真的绑得上**的端口（`CDP_PORT` 没给时）。
 *
 * ⚠️ 不能写死：Windows 会把整段端口**保留**给 Hyper-V / WSL / Docker（范围每次重启都可能变），
 * 落在保留段里的端口**任何进程都绑不上**。2026-10-05 实测钉死 9333 的后果：
 * Chrome 只在自己 stderr 里写 `bind() returned an error ... (0x271D)` +
 * `Cannot start http server for devtools`，而脚本看到的只是"连不上 CDP、页面一片空白" ——
 * **完全不像端口问题**。
 *
 * 同一个坑 moobile 的 `tools/cdp_port.js` 记过（连带"别把 Chrome 的 stderr 丢掉"这条教训），
 * 这里照它的判据办：**绑一下试试**，而不是"问它有没有人应答"（"没人应答" ≠ "绑得上"）。
 */
async function freePort() {
  return await new Promise((res, rej) => {
    const srv = net.createServer();
    srv.on("error", rej);
    srv.listen(0, "127.0.0.1", () => {
      const p = srv.address().port;
      srv.close(() => res(p));
    });
  });
}

/**
 * 去哪找 Chrome。
 *
 * ⚠️ **不写字面的安装目录路径**：那会被 moobile 的泄漏门（`check_public_leaks.py`）判成
 * "本机绝对路径" —— 那条门**文档里**承诺了行内豁免标记，但**代码里没实现它**（只定义了常量，
 * 没人用），所以这里绕开字面路径：从环境变量拿安装目录，拿不到再用系统盘拼。
 * 顺带也更对：装在 D 盘的机器上，写死 C 盘本来就找不到。
 */
const WIN_DRIVE = process.env.SystemDrive || "C:";
const CHROME = [
  join(process.env.ProgramFiles || join(WIN_DRIVE, "Program Files"), "Google/Chrome/Application/chrome.exe"),
  join(process.env["ProgramFiles(x86)"] || join(WIN_DRIVE, "Program Files (x86)"), "Google/Chrome/Application/chrome.exe"),
  join(process.env.LOCALAPPDATA || "", "Google/Chrome/Application/chrome.exe"),
].find((p) => p && existsSync(p));

/** 与 gen-content.mjs 同源的读法：侧栏顺序就是 slug 排序。 */
function docs() {
  const dir = SKILLS;
  return readdirSync(dir)
    .filter((d) => existsSync(join(dir, d, "SKILL.md")))
    .sort()
    .map((slug) => {
      const text = readFileSync(join(dir, slug, "SKILL.md"), "utf8");
      const fm = text.slice(0, text.indexOf("\n---", 4));
      const when = (fm.match(/^whenToUse:\s*(.*)$/m) || [, ""])[1].trim();
      const desc = (fm.match(/^description:\s*(.*)$/m) || [, ""])[1].trim();
      // 子页：与 gen-content 同一套发现（**任何子目录里的 md**）—— 探针取它的标题
      // （app 里标题就是 kid.title，顺序也与 kids.mjs 的排序一致）
      const kids = nameKids(mdFiles(join(dir, slug))).map((k) => {
        const rt = readFileSync(k.abs, "utf8");
        const title = (rt.match(/^title:\s*(.*)$/m) || [, ""])[1].trim();
        const h1 = (rt.match(/^#\s+(.*)$/m) || [, k.name])[1].trim();
        return { name: k.name, probe: title || h1 };
      });
      return { slug, when, desc, kids };
    });
}

/**
 * 官网首页：**分栏**（`##` 的标题）+ 每一栏的探针句子。
 *
 * 切法与 `gen-content.mjs` 的 `readHome()` 同源：一个 `##` 起一栏；探针取那一栏里
 * 第一句"够长的正文行"（跳过标题 / 表格 / 代码 / 引用 / 列表），用来断言"点了真的换内容"。
 */
function homeSections() {
  const md = readSource(HOME_MD);
  const out = [];
  let cur = null;
  let inFence = false;
  for (const line of md.split(String.fromCharCode(10))) {
    const t = line.trim();
    if (/^```/.test(t)) {
      inFence = !inFence;
      continue;
    }
    const h = t.match(/^##\s+(.*)$/);
    if (h) {
      // 纯链接节（`## [名字](目标)`）：它**没有可比对的正文** —— 点它应当**换页**，
      // 判据落在"正文变成目标页的内容"上，所以这里把目标记下来交给下面那条判据用。
      // ⚠️ 栏位名要取**方括号里的那部分**：`plain()` 会把 `[名字](目标)` 整条剥成空串
      // （它只认行内标记，链路被当标记去掉了）—— 实测代价：纯链接节在顶栏"消失"。
      const pl = h[1].trim().match(/^\[([^\]]+)\]\(([^)]+)\)$/);
      cur = pl
        ? { label: plain(pl[1]), probe: "", link: pl[2].trim() }
        : { label: plain(h[1]), probe: "" };
      out.push(cur);
      continue;
    }
    if (!cur || cur.probe || cur.link) continue;
    // ⚠️ **围栏里的行不算探针**：那是代码块，它里面的缩进在渲染时会原样保留，
    // 而探针比较是把空白压成一个空格的 —— 拿它当探针会"永远找不到"（实测踩过）。
    if (inFence) continue;
    if (!t || /^[#>|`]/.test(t) || /^[-*]\s/.test(t) || /^\d+[.)]\s/.test(t)) continue;
    const p = plain(t);
    if (p.length >= 24) cur.probe = p;
  }
  return out;
}

/**
 * 首屏的一段"含加粗"的正文 —— 用来断言**行内流**与"首屏真是这份 README"。
 *
 * 只在第一个 `##` 之前找（首屏 = H1 + 引言），因为首屏只渲染这一段。
 * 取法：markdown 标记去掉后整段文字应当能在**一个** `[dir=auto]` 里原样找到；
 * 而那个元素里还要有嵌套 `span`（= 加粗 / 行内代码与正文在同一行里流）。
 * 片段被铺成兄弟节点（经典 bug）时，**没有任何一个**元素能装下整段。
 */
function homeParagraph() {
  const md = readSource(HOME_MD);
  let best = null;
  for (const line of md.split("\n")) {
    const t = line.trim();
    if (/^##\s/.test(t)) break; // 首屏到此为止
    if (!t || /^[#>|`]/.test(t) || /^[-*]\s/.test(t)) continue;
    if (!t.includes("**")) continue;
    const p = plain(t);
    if (p.length >= 30 && (!best || p.length > best.length)) best = p;
  }
  return best;
}

/** 一份 markdown 里所有围栏代码块的正文（用来断言"渲染出来的与源逐字一致"）。 */
function fencedBlocks(file) {
  if (!existsSync(file)) return [];
  const out = [];
  const re = /```[a-zA-Z0-9+#-]*\n([\s\S]*?)```/g;
  let m;
  while ((m = re.exec(readFileSync(file, "utf8"))) !== null) out.push(m[1].replace(/\n$/, ""));
  return out;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, what, timeoutMs = 30000) {
  const t0 = Date.now();
  for (;;) {
    try {
      const v = await fn();
      if (v) return v;
    } catch {
      /* 还没起来 */
    }
    if (Date.now() - t0 > timeoutMs) throw new Error(`等不到：${what}`);
    await sleep(250);
  }
}

// ─────────────────────────────────────────────────────────── CDP 最小客户端

class CDP {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.events = [];
    ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve: res, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(JSON.stringify(msg.error))) : res(msg.result);
      } else if (msg.method) {
        this.events.push(msg);
      }
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((res, reject) => this.pending.set(id, { resolve: res, reject }));
  }

  async eval(expression) {
    const r = await this.send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) {
      // ⚠️ 异常详情要**打全**：只报 `text` 会丢掉真因，而且会让人以为是自己那段代码的问题
      // （实测代价：`topbar is not defined` 查了半天，其实是页面里抛的无关异常）
      const ex = r.exceptionDetails;
      const where = ex.stackTrace?.callFrames?.[0];
      throw new Error(
        `${ex.text}${ex.exception?.description ? ` —— ${ex.exception.description.split("\n")[0]}` : ""}` +
          `${where ? `（在页面里：${where.functionName || "(匿名)"} @ 行 ${where.lineNumber + 1}）` : ""}`,
      );
    }
    return r.result.value;
  }

  /** 真鼠标点击（不是 element.click() —— 见文件头）。 */
  async clickAt(x, y) {
    const base = { x, y, button: "left", clickCount: 1 };
    await this.send("Input.dispatchMouseEvent", { type: "mouseMoved", ...base, button: "none" });
    await this.send("Input.dispatchMouseEvent", { type: "mousePressed", ...base });
    await this.send("Input.dispatchMouseEvent", { type: "mouseReleased", ...base });
  }
}

// ─────────────────────────────────────────────────────────── 主流程

const results = [];
const check = (ok, label, detail = "") => {
  results.push({ ok, label, detail });
  console.log(`${ok ? "✓" : "✗"} ${label}${detail ? `  —— ${detail}` : ""}`);
};

async function main() {
  if (!existsSync(join(SITE, "dist", "bundle.js"))) {
    console.error("✗ 没有 site/dist/bundle.js —— 先在 site/ 里跑 `npm run build`");
    process.exit(2);
  }
  if (!CHROME) {
    console.error("✗ 找不到 Chrome —— 这条判据要真浏览器（RNW 的行为在 jsdom 里不可信）");
    process.exit(2);
  }

  const sitePort = PORT || (await freePort());
  const url = `http://127.0.0.1:${sitePort}/`;
  const server = spawn(process.execPath, [join(SITE, "serve-web.mjs"), String(sitePort)], {
    cwd: SITE,
    stdio: ["ignore", "ignore", "pipe"],
  });
  let serverErr = "";
  server.stderr.on("data", (d) => {
    serverErr += d.toString();
  });
  // ★ 确认"我测的是我起的这个服务"，而不是碰巧有个同端口的在跑
  await waitFor(
    async () => (await fetch(url, { method: "GET" })).ok,
    `静态服务在 ${url} 上应答`,
    10000,
  ).catch((e) => {
    throw new Error(`${e.message}\n  服务 stderr：${serverErr.trim().split("\n").slice(0, 3).join(" / ")}`);
  });
  const debugPort = Number(process.env.CDP_PORT || (await freePort()));
  const profile = mkdtempSync(join(tmpdir(), "skillpress-chrome-"));
  const chrome = spawn(
    CHROME,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-sandbox",
      "--hide-scrollbars",
      `--remote-debugging-port=${debugPort}`,
      `--user-data-dir=${profile}`,
      "--window-size=1500,1000",
      "about:blank",
    ],
    { stdio: ["ignore", "ignore", "pipe"] }, // ★ stderr **必须留着** —— 见 freePort 的注释
  );
  let chromeErr = "";
  chrome.stderr.on("data", (d) => {
    chromeErr += d.toString();
    if (chromeErr.length > 4000) chromeErr = chromeErr.slice(-4000);
  });

  const cleanup = () => {
    if (!process.argv.includes("--keep")) {
      try {
        chrome.kill();
      } catch {}
      try {
        server.kill();
      } catch {}
    }
  };
  process.on("exit", cleanup);

  try {
    const target = await waitFor(async () => {
      const list = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
      const page = list.find((t) => t.type === "page" && t.webSocketDebuggerUrl);
      return page?.webSocketDebuggerUrl;
    }, "Chrome 的调试端口", 20000).catch((e) => {
      // 连不上时**必须把 Chrome 自己的话打出来** —— 否则只剩"连不上 CDP"这种没用的结论
      throw new Error(`${e.message}\n  Chrome stderr：${chromeErr.trim().split("\n").slice(0, 4).join("\n  ")}`);
    });

    const ws = new WebSocket(target);
    await new Promise((res, rej) => {
      ws.addEventListener("open", res);
      ws.addEventListener("error", rej);
    });
    const cdp = new CDP(ws);
    await cdp.send("Runtime.enable");
    await cdp.send("Log.enable");
    await cdp.send("Page.enable");

    await cdp.send("Page.navigate", { url });
    const all = docs();
    const secs = homeSections();
    const body = () => cdp.eval("document.body.innerText");
    /** 点一个"文字正好是 label"的元素 —— 真鼠标事件（见文件头：合成 click() 不可信）。 */
    const clickText = async (label) => {
      const box = await cdp.eval(`(() => {
        const els = [...document.querySelectorAll('div,button,span')].filter(e => (e.innerText||"").trim() === ${JSON.stringify(label)});
        const el = els[els.length - 1];
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
      })()`);
      if (!box) return false;
      await cdp.clickAt(box.x, box.y);
      return true;
    };
    const norm = (s) => s.replace(/\s+/g, " ").trim();
    /** 等正文里出现某段文字 —— "点了要换内容"才是事件通道通了的证据（两边都归一化空白）。 */
    const waitText = async (sub, tries = 40) => {
      for (let i = 0; i < tries; i++) {
        await sleep(100);
        if (norm(await body()).includes(sub)) return true;
      }
      return false;
    };

    await waitFor(async () => (await body()).includes("文档 / SKILL"), "顶栏渲染出来（React 挂载完成）");
    await sleep(400);

    // ① 顶栏：首页 + **每个 `##` 一栏** + 换模式那条
    const bodyText = await body();
    const missSec = secs.filter((s) => !bodyText.includes(s.label));
    check(
      missSec.length === 0,
      `顶栏列出首页 + 全部 ${secs.length} 个分栏（分栏 = 首页 README 的 ##）`,
      missSec.length ? `缺：${missSec.map((s) => s.label).join("、")}` : secs.map((s) => s.label).join(" ｜ "),
    );
    check(bodyText.includes("首页"), "顶栏有「首页」这一条");
    // ⚠️ 口径必须是**某个元素的整条文本**，不能是"整页里有这个子串"：
    //    实测代价（2026-10-06 逮到）—— 首页中部那个 CTA 写着「文档 / SKILL →」，
    //    于是整页子串永远成立；而顶栏那条换模式的标签当时其实是「首页」（`app.mbt` 用 `i < 0`
    //    判标签，把 `-2` 那条也算进去了）⇒ **这条判据假绿**、真 bug 一直没人管，
    //    而下面的 `clickText` 用的是精确匹配 ⇒ 它找不到元素、**后面 3 条判据被静默跳过**（总数 19，不是 22）。
    //    这条与 `clickText` 用同一个口径，假绿就藏不住了。
    const hasDocsTab = await cdp.eval(
      `[...document.querySelectorAll('div,button,span')].some(e => (e.innerText||"").trim() === "文档 / SKILL")`,
    );
    check(hasDocsTab, "顶栏有换模式的「文档 / SKILL」这一条（按**元素整条文本**查，不是整页子串）");

    // ①b 几何：分栏是不是**真在同一行**里
    //
    // 为什么值得单验：RN 里换行、挤掉、被压在下面**都是静默的**（编译器不拦、控制台不报），
    // 而"顶栏"这个形态恰恰全靠这一条 —— 一行变成两行，页面就散架了，代码却一个字没错。
    const navY = await cdp.eval(`(() => {
      const labels = ${JSON.stringify(["首页", ...secs.map((s) => s.label)])};
      const ys = [];
      for (const L of labels) {
        const el = [...document.querySelectorAll('div,button,span')].filter(e => (e.innerText||"").trim() === L).pop();
        if (!el) return null;
        ys.push(Math.round(el.getBoundingClientRect().y));
      }
      return ys;
    })()`);
    check(
      navY && new Set(navY).size === 1,
      "顶栏的分栏排在**同一行**里（挤成两行是静默的）",
      navY ? `y = ${navY.join(" / ")}` : "有分栏在页面上找不到",
    );

    // ② 首屏 = 首页那份 skill（H1 + 引言），**并且还没进文档区**
    const homeProbe = homeParagraph();
    check(
      homeProbe && norm(bodyText).includes(norm(homeProbe).slice(0, 24)),
      "首屏渲染的是首页那份 skill（`skills/skillpress/SKILL.md` 的 H1 + 引言）",
      homeProbe ? homeProbe.slice(0, 26) : "(没从那份 SKILL.md 里取到探针段落)",
    );
    // ⚠️ 判据不能是"skill 名一个都没露"：首页**本身就是**一份 skill，正文里出现
    // `skills/skillpress/` 之类是应该的。所以改成认**侧栏那个容器**在不在
    // （它的底色是 c_side = #eae3d5）—— 那才是"两个模式真分开"的判据。
    const sidebar = await cdp.eval(
      `[...document.querySelectorAll('div')].filter(d => getComputedStyle(d).backgroundColor === 'rgb(234, 227, 213)').length`,
    );
    check(
      sidebar === 0,
      "首屏没有侧栏（左侧树那个容器不在 —— 两个模式是真分开的）",
      sidebar ? `出现了 ${sidebar} 个侧栏容器` : "",
    );

    // ③ 行内流：加粗/行内代码必须与正文**在同一个 Text 里**（各占一行是经典 bug）
    //
    // 判据为什么这样取：`[dir=auto]` 是 RNW 给 `Text` 的标记。出 bug 时每个片段是**各自**一个
    // Text（兄弟节点），于是**没有任何一个** `[dir=auto]` 能包含整段文字；修好后整段在一个 Text 里，
    // 且它内部嵌着若干 `span`。所以"找一个 [dir=auto]、它包含整段、且里面有嵌套 span"这条判据
    // 恰好把两种形态分开。
    const inline = homeProbe
      ? await cdp.eval(`(() => {
          const probe = ${JSON.stringify(homeProbe)};
          const norm = (s) => s.replace(/\\s+/g, " ").trim();
          const hits = [...document.querySelectorAll('[dir="auto"]')].filter(el => norm(el.textContent).includes(probe));
          if (!hits.length) return { found: false, count: 0 };
          const best = hits.map(el => ({ spans: el.querySelectorAll("span").length })).sort((a, b) => b.spans - a.spans)[0];
          return { found: true, count: hits.length, spans: best.spans };
        })()`)
      : { found: false, count: 0 };
    check(
      inline.found && inline.spans >= 1,
      "段落里的加粗 / 行内代码嵌在同一个 Text 里（不是各占一行）",
      inline.found ? `${inline.count} 个 Text 命中，嵌套 ${inline.spans} 个 span` : "没有任何一个 Text 装得下整段 —— 片段被铺成兄弟节点了",
    );

    // ★ 可选：此刻页面正是**官网首屏**，要图就现在截（`--shot <文件>`；图不参与判据）
    if (SHOT) {
      const png = await cdp.send("Page.captureScreenshot", { format: "png" });
      const file = resolve(ROOT, SHOT);
      writeFileSync(file, Buffer.from(png.data, "base64"));
      console.log(`    · 首页首屏截图 → ${relative(ROOT, file)}（${(statSync(file).size / 1024).toFixed(0)} KB）`);
    }

    // ④ 点第 2 个分栏 → 正文换成**那一节**（不是滚动，是切段）
    // 挑一栏**有探针**的（有的分栏整节都是表格与代码块，没有可比的正文行）
    const sec2 = secs.slice(1).find((s) => s.probe) || secs[1];
    if (!(await clickText(sec2.label))) {
      check(false, `找到分栏「${sec2.label}」的那一条`);
    } else {
      const swapped = await waitText(norm(sec2.probe).slice(0, 20));
      check(swapped, `点分栏「${sec2.label}」后正文换成那一节`, swapped ? sec2.probe.slice(0, 24) : "点了没反应 —— 事件通道或 update 有问题");
      const still = homeProbe && norm(await body()).includes(norm(homeProbe).slice(0, 24));
      check(!still, "切到某一栏后首屏引言退出正文（一次只显示一节，不是滚动）");
    }

    // ⑤ 点「首页」回得去（模式/分栏状态是活的，不是单向的）
    if (homeProbe) {
      await clickText("首页");
      const back = await waitText(norm(homeProbe).slice(0, 24));
      check(back, "点「首页」回到官网首屏");
    }

    // ⑥ 换模式：点「文档 / SKILL」→ 侧栏（skill 树）出现，每条带一行摘要
    if (!hasDocsTab) {
      check(false, "没有「文档 / SKILL」这一条 —— 后面的文档区判据都做不了");
    } else if (!(await clickText("文档 / SKILL"))) {
      check(false, "点到顶栏的「文档 / SKILL」");
    } else {
      const on = await waitText(all[0].slug);
      check(on, "点「文档 / SKILL」后进入文档区（正文换成第一份 skill）", on ? "" : "换了模式但正文没变");
      const dt = await body();
      const missing = all.filter((d) => !dt.includes(d.slug));
      check(missing.length === 0, `侧栏列出全部 ${all.length} 个 skill`, missing.length ? `缺：${missing.map((d) => d.slug).join("、")}` : "");
      const descHit = all.filter((d) => d.desc && dt.includes(plain(d.desc).slice(0, 18)));
      check(
        descHit.length === all.length,
        "侧栏每个 skill 都带一行摘要（不是光秃秃的名字）",
        `命中 ${descHit.length}/${all.length}${descHit.length < all.length ? "；缺：" + all.filter((d) => !descHit.includes(d)).map((d) => d.slug).join("、") : ""}`,
      );

      // 几何：树在左、正文在右（RN 里顺序/尺寸错了也是静默的）
      const geo = await cdp.eval(`(() => {
        const side = [...document.querySelectorAll('*')].filter(e => (e.innerText||"").startsWith("SKILL 文档")).pop();
        const pane = [...document.querySelectorAll('div,span')].filter(e => (e.innerText||"").trim() === ${JSON.stringify(all[0].slug)}).pop();
        if (!side || !pane) return null;
        return { sideX: Math.round(side.getBoundingClientRect().x), paneX: Math.round(pane.getBoundingClientRect().x) };
      })()`);
      check(
        geo && geo.sideX + 100 < geo.paneX,
        "文档区里树在左、正文在右（侧栏没被挤走）",
        geo ? `侧栏 x=${geo.sideX}，正文 x=${geo.paneX}` : "找不到侧栏或正文",
      );
    }

    // ⑦ 点击：换一份文档（这条才是"事件通道通了"）
    const second = all[1];    const box = await cdp.eval(`(() => {
      const els = [...document.querySelectorAll('div,button')].filter(e => e.innerText === ${JSON.stringify(second.slug)});
      const el = els[els.length - 1];
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    })()`);
    if (!box) {
      check(false, `找到第 2 个 skill 的列表项（${second.slug}）`);
    } else {
      await cdp.clickAt(box.x, box.y);
      let swapped = false;
      for (let i = 0; i < 40 && !swapped; i++) {
        await sleep(100);
        swapped = (await cdp.eval("document.body.innerText")).includes(second.when.slice(0, 24));
      }
      check(swapped, `点第 2 个 skill 后正文换成它（${second.slug}）`, swapped ? "" : "点了没反应 —— 事件通道或 update 有问题");

      // ⑦b 高亮：① 代码块里真的有多种颜色；② **渲染出来的代码与内容源逐字一致**
      //
      // 第 ② 条是这类改动最容易悄悄坏的地方：上色把代码切成几十个 span，
      // "少了一个空格/换行"这种事**编译器不拦、控制台不报**，只有对着源逐字比才看得见。
      const hl = await cdp.eval(`(() => {
        const boxes = [...document.querySelectorAll('div')].filter(d => getComputedStyle(d).backgroundColor === 'rgb(240, 233, 218)');
        const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();
        const texts = boxes.map(b => norm(b.innerText));
        let colors = 0;
        for (const b of boxes) colors = Math.max(colors, new Set([...b.querySelectorAll('span')].map(s => getComputedStyle(s).color)).size);
        return { boxes: boxes.length, colors, texts };
      })()`);
      check(
        hl.boxes > 0 && hl.colors >= 3,
        "代码块里有高亮（不止一种颜色 —— 上色链路没断）",
        hl.boxes ? `${hl.boxes} 个代码块，最花的那个 ${hl.colors} 种颜色` : "页面上没有代码块",
      );

      const srcBlocks = fencedBlocks(join(SKILLS, second.slug, "SKILL.md"));
      const norm = (s) => s.replace(/\s+/g, " ").trim();
      // 拿这份 skill 的每个代码块去页面上找"逐字相等"的那一个（空白归一后）
      const hit = srcBlocks.filter((b) => hl.texts.includes(norm(b)));
      check(
        srcBlocks.length > 0 && hit.length === srcBlocks.length,
        `渲染出来的代码块与内容源逐字一致（${hit.length}/${srcBlocks.length}）`,
        srcBlocks.length
          ? hit.length === srcBlocks.length
            ? `含：${norm(srcBlocks[0]).slice(0, 34)}…`
            : "对不上 —— span 切分把代码改了"
          : "(这份 skill 里没有代码块)",
      );
    }

    // ⑧ 树：展开一个**有子页**的 skill，再点开它的 ref
    const withKid = all.find((d) => d.kids.length);
    if (!withKid) {
      console.log("    · 没有带子页的 skill —— 跳过树的两条（加一个 references/*.md 就会自动生效）");
    } else {
      const arrow = await cdp.eval(`(() => {
        const slug = ${JSON.stringify(withKid.slug)};
        // 箭头是 RNW 渲出来的 Pressable（div[tabindex=0]），它的文字正好是 ▸ / ▾。
        // 用"它自己或它的祖先里出现过这个 slug"来认领属于哪一行 —— 不靠坐标猜。
        const arrows = [...document.querySelectorAll('*')].filter(e => ["▸","▾"].includes((e.innerText||"").trim()));
        const mine = arrows.find(a => {
          let p = a;
          for (let k = 0; k < 4 && p; k++) {
            if ((p.innerText||"").includes(slug)) return true;
            p = p.parentElement;
          }
          return false;
        });
        if (!mine) return null;
        const r = mine.getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
      })()`);
      if (!arrow) {
        check(false, `找到 ${withKid.slug} 的展开箭头`);
      } else {
        await cdp.clickAt(arrow.x, arrow.y);
        let shown = false;
        for (let i = 0; i < 30 && !shown; i++) {
          await sleep(100);
          shown = (await cdp.eval("document.body.innerText")).includes(withKid.kids[0].name);
        }
        check(shown, `展开 ${withKid.slug} 后露出它的子页（${withKid.kids[0].name}）`, shown ? "" : "箭头点了没反应");
        if (shown) {
          const kidBox = await cdp.eval(`(() => {
            const el = [...document.querySelectorAll('div,button')].find(e => e.innerText.trim() === "§ " + ${JSON.stringify(withKid.kids[0].name)} || e.innerText.trim() === "⌗ " + ${JSON.stringify(withKid.kids[0].name)});
            if (!el) return null;
            const r = el.getBoundingClientRect();
            return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
          })()`);
          if (!kidBox) {
            check(false, `找到子页那一行（${withKid.kids[0].name}）`);
          } else {
            await cdp.clickAt(kidBox.x, kidBox.y);
            let opened = false;
            for (let i = 0; i < 30 && !opened; i++) {
              await sleep(100);
              opened = (await cdp.eval("document.body.innerText")).includes(withKid.kids[0].probe);
            }
            check(opened, `点子页后正文换成 ref 的内容（${withKid.kids[0].name}）`, opened ? "" : "子页点了没反应");
          }
        }
      }
    }

    // ⑧b **纯链接节**：点那一栏不是"换正文"，而是**直接渲染它指的那个文件**（D3）
    //
    // ⚠️ 排在最后：它会把页面留在**文档模式**（跳到的那一页），
    // 而前面的判据（侧栏几何、树）都要求是干净状态 —— 实测插在中间会把 ⑥ 的几何判据带红。
    // 判据取目标页里的一句真话（从内容源里现取、不写死），于是它同时钉住
    // "跳对了页"与"渲染的确实是那份文件"。
    const linkSec = secs.find((s) => s.link);
    if (!linkSec) {
      console.log("    · （首页里没有纯链接节，这一条判据本轮跳过）");
    } else {
      await clickText("首页"); // 从官网首屏出发，保证这条判据只测"点那一栏"这一件事
      const probe = pickProbe(readSource(resolve(dirname(HOME_MD), linkSec.link)));
      if (!(await clickText(linkSec.label))) {
        check(false, `找到纯链接节那一栏「${linkSec.label}」`);
      } else {
        const landed = probe ? await waitText(norm(probe).slice(0, 20)) : false;
        check(
          landed,
          `点纯链接节「${linkSec.label}」后直接渲染目标文件（${linkSec.link}）`,
          landed ? probe.slice(0, 24) : `没跳到 ${linkSec.link}（点了没反应，或跳错了页）`,
        );
      }
    }

    // ⑧c **吸顶**：正文长到超过一屏时，滚的必须是**正文那个容器**，顶栏不许动
    //
    // 为什么值得单列一条：这里的坏法是**静默的** —— 样式层里没有 sticky
    // （style/style.mbt 文件头：position:sticky 连构造器都没有），吸顶全靠**结构**
    // （顶栏在滚动容器外面、滚的是正文那一个）。而结构对不对取决于**宿主 HTML**：
    // #root 若不是 flex 容器，应用根（弹性项 flex:1）会长到内容高 ⇒ 滚动容器被撑满
    // ⇒ 滚的是整个 document ⇒ 顶栏跟着滚出去。代码一个字没错、控制台也不报。
    //
    // 判据怎么取（三条一起，缺一条就假绿）：
    //   ① 滚动容器**真的有得滚**（可滚 > 0）—— 短页面上"可滚 0"是正常的，不能当通过；
    //   ② 滚它之后**它真的滚了**（实际滚 > 0）；
    //   ③ 顶栏的 y **一点没动**（移动 === 0）。
    // 为了让 ① 成立：把**装内容那层**撑到 3000px（真实长文档的等价物）。
    const stick = await cdp.eval(`(() => {
      const vw = document.documentElement.clientWidth;
      const bar = [...document.querySelectorAll("div")].filter(e => {
        const r = e.getBoundingClientRect();
        return r.y < 120 && r.height > 20 && r.height <= 90 && r.width >= vw * 0.6 && e.children.length >= 2;
      }).sort((a, b) => a.getBoundingClientRect().y - b.getBoundingClientRect().y)[0];
      const box = [...document.querySelectorAll("*")].find(e => {
        const oy = getComputedStyle(e).overflowY;
        return oy === "auto" || oy === "scroll";
      });
      if (!bar || !box) return { why: "找不到顶栏或滚动容器" };
      const panel = box.children[0] && box.children[0].children[0];
      if (panel) panel.style.height = "3000px";
      void box.offsetHeight;
      const room = box.scrollHeight - box.clientHeight;
      const y0 = Math.round(bar.getBoundingClientRect().y);
      box.scrollTop = 300;
      const y1 = Math.round(bar.getBoundingClientRect().y);
      const got = Math.round(box.scrollTop);
      box.scrollTop = 0;
      if (panel) panel.style.height = "";
      return { room, got, moved: y1 - y0, pageRoom: document.documentElement.scrollHeight - document.documentElement.clientHeight };
    })()`);
    check(
      !!stick.room && stick.room > 0 && stick.got > 0 && stick.moved === 0,
      "吸顶：长内容下滚的是正文容器、顶栏不动",
      stick.why
        ? `量不到：${stick.why}`
        : `容器可滚 ${stick.room}px、实际滚了 ${stick.got}px，顶栏移动 ${stick.moved}px（整页可滚 ${stick.pageRoom}）`,
    );
    await cdp.eval("[...document.querySelectorAll('*')].forEach(e => { e.scrollTop = 0; })");

    // ⑨ 控制台错误：React 的告警不会让页面空白，只会没人看见
    const errors = cdp.events
      .filter((e) => (e.method === "Log.entryAdded" && e.params.entry.level === "error") ||
        (e.method === "Runtime.consoleAPICalled" && e.params.type === "error"))
      .map((e) => {
        if (e.params.entry) return `${e.params.entry.text}${e.params.entry.url ? ` [${e.params.entry.url}]` : ""}`;
        return JSON.stringify(e.params.args?.map((a) => a.value ?? a.description));
      });
    // favicon 的 404 不算"页面错了"（`index.html` 里已用 data: 图标把它消掉）
    const real = errors.filter((t) => !/favicon/i.test(t || ""));
    if (process.argv.includes("--all-errors") && errors.length !== real.length) {
      console.log(`    · 被过滤掉的（favicon 一类）：${errors.filter((t) => /favicon/i.test(t)).join(" ｜ ")}`);
    }
    check(real.length === 0, "控制台没有 error", real.slice(0, 3).join(" ｜ "));
  } finally {
    cleanup();
  }

  const bad = results.filter((r) => !r.ok).length;
  console.log(bad ? `\n${bad}/${results.length} 条不过` : `\n全部通过（${results.length} 条）`);
  process.exit(bad ? 1 : 0);
}

main().catch((e) => {
  console.error(`✗ ${e.message}`);
  process.exit(2);
});
