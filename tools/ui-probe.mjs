#!/usr/bin/env node
/**
 * ui-probe.mjs —— **真站界面的体检**（真 Chrome × 多个真视口 × **真输入**）。
 *
 * ## 交互一律走 CDP 真输入（2026-10-07 改）
 *
 * 起因是一条查不清的红：窄屏"关掉浮层之后再点同一批按钮，连点 13 次一次都没进到应用"，
 * 而 `window.onerror` 与 `console.error` **各 0 条**。逐条排查之后缩到：
 * **页面里合成事件（`dispatchEvent(new MouseEvent(...))`）在这套宿主上会静默失效**
 * （按钮不高亮、面板不出、零报错；同一批按钮在"关"之前是响应的 ⇒ 不是状态机 —— `shell/state.mbt`
 * 的 `Tap` 三分支正确、`CloseSheet`/Esc 都两值齐归零、Esc 后 `left` 实测回到贴边位 -22）。
 *
 * 既然"点没点着"连报错都不给，那么**所有靠合成点击得出的绿都可能是假的**。
 * ⇒ 这个文件里的交互（点站名 / 点侧栏标题 / 点下一页 / 两级点击 / Esc）**全部**改走
 * `Input.dispatchMouseEvent` 与 `Input.dispatchKeyEvent`（见 `tools/cdp.mjs`，Node 自带 WebSocket，零依赖）。
 *
 * **口径没动**：断言仍只认"生效的读数"（几何、computed style、点完之后真的变了），阈值一个没放宽。
 *
 * ### 判定：**是仪器，不是应用**（2026-10-07，改完当轮）
 *
 * 同一批判据换真输入后，那条红**连着三次全绿**；加上"关之前响应、关之后不响应"的读数，
 * 结论是**页面内合成事件触达不到 RNW 的 responder 记账**，与 `shell/state.mbt` 的状态机无关。
 * ⇒ 交互从此一律真输入；**合成事件那条路不再作为任何判据的依据**。
 *
 * ### 换真输入时**当场逮到两条假绿**（这就是为什么要换）
 *
 * 1. **`点「下一页」真的换页`**：原来"绿"是因为合成事件**不需要元素看得见** ——
 *    量出来的坐标是 `y=3800`（视口只有 900），`document.elementFromPoint` 给 `null`，
 *    也就是说**那一下点在页面外**，而合成派发照样"成功"。真鼠标点下去什么都不发生。
 *    修法：凡是要点的坐标，**先 `scrollIntoView` 滚进可视区再量**（`ui-probe-page.mjs` 的 `reveal`）。
 *    ⇒ 现在这条绿是"真人滚下去点得到"的绿。
 * 2. **`窄屏从 sheet 进文档页`**：原来合成点击红着，真输入下绿 —— 见上面的判定。
 *
 * ### 一条纪律（写给下一个改探针的人）
 *
 * **"点了没反应"要先怀疑输入层**：合成事件在这套宿主上会**静默**失效（按钮不高亮、面板不出、
 * `window.onerror` 与 `console.error` 各 0 条）。真输入是唯一可信的交互层；
 * 而"能不能看到"（视口内/外）是**真输入才有的约束**，合成事件会帮你作弊。
 *
 * ## 量什么
 *
 *   ① 阶梯（1200+/1024+/<1024 三档：栏数、侧栏 272、目录轨 220）
 *   ② 侧栏行语言（中文标题 / 没有机器名 / 只有一条当前项左条）
 *   ③ 目录的落点（rail 3 在右栏轨；rail 2/1 挂在树里当前文件节点下）
 *   ④ 文档页骨架（H1 中文名、kicker 机器名、面包屑、代码块底色、上下页**点了真的换页**）
 *   ⑤ 顶栏（高 56、点站名回首页）
 *   ⑥ 窄屏入口（三个贴边按钮、两级、Esc）
 *   ⑦ 结构（每栏自己滚、页面本身不滚、无横向溢出、无报错）
 *
 * 用法：node tools/ui-probe.mjs [--app <实例目录>] [--widths 1440,1100,768] [--keep]
 */
import { createServer } from "node:http";
import { existsSync, readFileSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { open } from "./cdp.mjs";
import { PAGE_JS } from "./ui-probe-page.mjs";

const here = dirname(fileURLToPath(import.meta.url));
function argOf(n, d) { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
const app = resolve(here, "..", argOf("--app", "skills/skillpress/scripts/.skillpress"));
const widths = argOf("--widths", "1440,1100,768").split(",").map((s) => Number(s.trim())).filter(Boolean);
const dist = join(app, "dist");
const bundle = join(dist, "bundle.js");
if (!existsSync(bundle)) { console.error(`✗ ${bundle} 不在 —— 先 cd 实例 && npm run build`); process.exit(2); }
// ⚠️ 新鲜度：bundle 比源旧 ⇒ 这套判据量的是**旧代码**（表现是"两次跑出来一模一样"，最容易骗过自己）。
{
  const { statSync, readdirSync } = await import("node:fs");
  const bt = statSync(bundle).mtimeMs;
  const newer = [];
  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (/\.(mbt|mjs|js|html)$/.test(e.name) && !p.includes("dist") && statSync(p).mtimeMs > bt) newer.push(p);
    }
  };
  walk(join(here, "..", "shell"));
  walk(app);
  if (newer.length) console.log(`⚠️ 有 ${newer.length} 个源文件比 dist/bundle.js 新（先重建再读数）：${newer.slice(0, 3).join(" / ")}`);
}

const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".json": "application/json" };
const server = createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split("?")[0]);
  const file = join(dist, rel === "/" ? "index.html" : rel);
  if (!file.startsWith(dist) || !existsSync(file)) { res.writeHead(404).end("nope"); return; }
  res.writeHead(200, { "content-type": MIME[extname(file)] || "application/octet-stream" });
  res.end(readFileSync(file));
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const url = `http://127.0.0.1:${server.address().port}/index.html`;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let bad = 0;
const say = (ok, msg) => { console.log((ok ? "  ✓ " : "  ✗ ") + msg); if (!ok) bad++; };

const cdp = await open({ width: widths[0] + 160, height: 900 });
const ready = async () => {
  for (let i = 0; i < 200; i++) {
    const t = await cdp.eval("document.body.innerText.trim().length").catch(() => 0);
    if (t > 20) { await sleep(400); return true; }
    await sleep(100);
  }
  return false;
};
const load = async (w) => {
  await cdp.viewport(w, 900);
  await cdp.call("Page.navigate", { url });
  await ready();
  await cdp.eval(PAGE_JS);
  await sleep(200);
};
const P = (expr) => cdp.eval(`window.__p.${expr}`);
/** 导航到某个 hash（空串 = 不带 hash）并等页面画出来 —— 路由那一段要用它做"深链/刷新"。 */
const loadAt = async (h) => {
  await cdp.call("Page.navigate", { url: url + h });
  await ready();
  await cdp.eval(PAGE_JS);
  await sleep(200);
};
/** 真鼠标点一次（坐标由页面里的 `window.__p.*` 给），点完等重渲。 */
const clickAt = async (pt, ms = 320) => { if (!pt) return false; await cdp.click(pt.x, pt.y); await sleep(ms); return true; };

console.log(`跑 ${widths.join(" / ")}（CDP 真输入 + 真视口）`);
const railOf = (w) => (w >= 1280 ? 3 : w >= 1024 ? 2 : 1);

for (const w of widths) {
  const rail = railOf(w);
  console.log(`\n── ${w}px（rail ${rail}）──`);
  await load(w);
  const s = await P("snapshot()");
  if (!s || s.why) { say(false, "拿不到版面快照" + (s && s.why ? "：" + s.why : "")); continue; }

  /* ① 结构 */
  say(s.cols.every((c) => c.oy === "auto" || c.oy === "scroll"),
    `每一栏自己滚：overflow-y = ${s.cols.map((c) => c.oy).join(" / ")}`);
  say(!s.pageScrolls, `页面本身不滚（顶栏不动）：html 滚动高 ${s.pageScrolls ? ">" : "="} 视口高`);
  say(s.overflowX <= 1, `横向溢出 ${s.overflowX}px`);

  /* ⑤ 顶栏 */
  say(s.topbar.h === 56, `顶栏高 ${s.topbar.h}px（要 56）· 底色 ${s.topbar.bg}`);
  say(s.topbar.labels.length >= 3 && !s.topbar.labels.some((t) => /^[一二三四五六七八九十]、/.test(t)),
    `顶栏有 ${s.topbar.labels.length} 条 nav、且没有正文序号条目：${s.topbar.labels.join(" / ")}`);

  /* ① 阶梯 */
  if (rail === 3) {
    say(s.cols.length === 3, `rail 3：三栏（实测 ${s.cols.length} 栏）`);
    say(s.cols[0].w === 272 && s.cols[2].w === 220, `侧栏 ${s.cols[0].w}px / 目录轨 ${s.cols[2].w}px（要 272 / 220）`);
  } else if (rail === 2) {
    say(s.cols.length === 2, `rail 2：两栏（实测 ${s.cols.length} 栏）`);
    say(s.cols[0].w === 272, `侧栏 ${s.cols[0].w}px（要 272）`);
  } else {
    say(s.cols.length === 1, `rail 1：一栏（实测 ${s.cols.length} 栏）—— 侧栏整栏不画`);
  }

  /* ②/③ 侧栏与目录 */
  if (rail >= 2) {
    const sd = s.side;
    say(sd.rows >= 2, `侧栏是一棵树：${sd.rows} 行条目标题（前几行 ${sd.titles.join(" / ")}）`);
    say(sd.machine.length === 0, `侧栏里没有机器名（slug）：${sd.machine.length ? sd.machine.join(",") : "干净"}`);
    say(sd.bars.length === 1 && /79, 70, 229/.test(sd.bars[0]),
      `当前项只有一条品牌色左条：${sd.bars.join(" / ") || "没有"}`);
    say(new Set(sd.heights).size <= 2, `侧栏行高一致：${[...new Set(sd.heights)].join("/")}px`);
  }
  if (rail === 3) {
    say(s.tocRail.rows >= 1, `rail 3：目录在右栏那条轨里（${s.tocRail.rows} 行）`);
    say((s.side ? s.side.toc : 0) === 0, `rail 3：树里不再挂目录（${s.side ? s.side.toc : 0} 行）`);
  } else if (rail === 2) {
    say(s.side.toc >= 1, `rail 2：目录那一层挂在侧栏里（${s.side.toc} 行）`);
    // ⚠️ "挂在当前文件节点下面"这条**要在进了文档页之后**量：首页/书架在树里没有对应节点，
    //    它们走的是**树末兜底**（`underCurrent` 本来就是 false）。在首页上量 = 拿错前提。
  }

  /* ④ 正文行长 */
  const chars = s.prose ? s.prose.chars : null;
  if (rail >= 2) say(chars && chars >= 38 && chars <= 47, `正文段落 ${s.prose && s.prose.w}px = ${chars} 字（要 38–47）`);
  else say(!!s.prose, `正文段落 ${s.prose && s.prose.w}px = ${chars} 字（窄屏：能多宽多宽）`);

  /* ⑤ 点站名回首页（**真鼠标**） */
  const homeH1 = s.doc && s.doc.h1;
  if (rail >= 2) {
    // 先离开首页（点侧栏第一条标题），再点站名回来 —— 否则"没动"也能假绿
    const entered = await clickAt(await P("sidebarTitle()"), 700);
    const afterEnter = await P("snapshot()");
    say(entered && afterEnter.doc && afterEnter.doc.h1 && afterEnter.doc.h1 !== homeH1,
      `点侧栏标题真的进了一页：H1 ${JSON.stringify(homeH1)} → ${JSON.stringify(afterEnter.doc && afterEnter.doc.h1)}`);
    // 文档页骨架
    const d = afterEnter.doc;
    say(!!d.h1 && !/^[a-z][a-z0-9-]+$/.test(d.h1), `文档页 H1 是中文名（不是 slug）：${JSON.stringify(d.h1)}`);
    say(!!d.kicker && d.kicker.length > 2, `kicker = ${JSON.stringify(d.kicker)}（机器名，mono）`);
    if (rail === 2) {
      const t2 = afterEnter.tocTree;
      say(!!t2 && t2.rows >= 1 && t2.underCurrent,
        `rail 2：进了文档页之后，目录挂在**当前文件**那个节点下面：${JSON.stringify(t2)}`);
    }
    say(d.crumbs.length >= 3, `面包屑 ${d.crumbs.length} 格：${d.crumbs.slice(0, 4).join(" / ")}`);
    say(d.codeBg === "rgb(247, 247, 248)", `代码块底色 = code_bg（实测 ${d.codeBg}）`);
    say(d.overflowX <= 1, `文档页横向溢出 ${d.overflowX}px`);
    // 点"下一页"——**真鼠标**
    const next = await P("nextPage()");
    const clicked = await clickAt(next, 700);
    const afterNext = clicked ? await P("snapshot()") : null;
    say(!!clicked && !!afterNext.doc && afterNext.doc.h1 !== d.h1,
      `点「下一页」真的换页：${JSON.stringify(d.h1)} → ${JSON.stringify(afterNext && afterNext.doc && afterNext.doc.h1)}`);
    // 点站名回首页
    await clickAt(await P("brand()"), 700);
    const back = await P("snapshot()");
    say(!!back.doc && !!back.doc.h1 && back.doc.h1 === homeH1,
      `点顶栏站名回首页：H1 = ${JSON.stringify(back.doc && back.doc.h1)}`);
  }

  /* ⑥ 窄屏入口（rail 1 才量；**每一步都是真鼠标，且等状态真的变了再走下一步**） */
  if (rail === 1) {
    const f0 = (await P("snapshot()")).fabs;
    say(f0.length === 3, `rail 1：三个贴边按钮都在（实测 ${f0.length} 个：${f0.map((f) => f.label).join(" ")}）`);
    const before = (await P("snapshot()")).fabs.find((f) => /目录/.test(f.label));
    await clickAt(await P("fab('☰ 目录')"), 400);           // 第一次：浮出
    const after1 = (await P("snapshot()")).fabs.find((f) => /目录/.test(f.label));
    const moved = after1.left - before.left;
    say(Math.abs(moved) >= 20, `两级①：第一次点**浮出**（几何位移 ${moved}px，离开贴边）`);
    // **位移是 transform 做的，不是布局**（2026-10-07 起把"负偏移"换成 `Translate`）：
    // 判据读的是"布局位置 `offsetLeft` 不变、而计算出来的 `transform` 变了" —— 两条一起才成立。
    say(
      before.offLeft === after1.offLeft && before.tf !== after1.tf,
      `两级①的位移来自 **transform**（布局 offsetLeft 不变 = ${before.offLeft}；transform ${before.tf} → ${after1.tf}）`,
    );
    await clickAt(await P("fab('☰ 目录')"), 400);           // 第二次：弹 sheet
    const sheet1 = (await P("snapshot()")).sheet;
    say(!!sheet1, `两级②：第二次点才弹 sheet（面板高 ${sheet1 && sheet1.h}px）`);
    // **Esc 用真按键**（合成 Escape 会污染后续合成点击；真按键没有这个顾虑 —— 顺带复核那笔账）
    await cdp.key("Escape");
    await sleep(400);
    const sheet2 = (await P("snapshot()")).sheet;
    say(!!sheet1 && !sheet2, `Esc 关 sheet（真按键）：${sheet1 ? "开→" : "没开→"}${sheet2 ? "仍开着" : "关掉了"}`);
    // 走两级进"书架"，再从面板里点一条 ⇒ 应当在 rail 1 也能进文档页
    for (let i = 0; i < 4; i++) {
      if ((await P("snapshot()")).sheet) break;
      await clickAt(await P("fab('▤ 书架')"), 400);
    }
    const rows = await P("sheetRows()");
    say(rows.length >= 1, `书架 sheet 里有 ${rows.length} 条可点条目（首条：${rows[0] ? rows[0].t : "无"}）`);
    let doc1 = null;
    // 面板里可能混着不可点的行（分组标题那种）⇒ **按顺序试**（真人也会这么点）
    for (const r of rows.slice(0, 4)) {
      await cdp.click(r.x, r.y);
      await sleep(700);
      doc1 = (await P("snapshot()")).doc;
      if (doc1 && doc1.h1 && homeH1 && doc1.h1 !== homeH1) break;
    }
    say(rows.length > 0 && !!doc1 && !!doc1.h1 && !!homeH1 && doc1.h1 !== homeH1,
      `rail 1 从 sheet 进文档页：试了 ${Math.min(rows.length, 4)} 条，H1 = ${JSON.stringify(doc1 && doc1.h1)}`);
  }

  /* ⑧ 路由（DESIGN §2.2 / PLAN-ui §13.6）：深链 · 地址回写 · 后退 · 刷新 · 404 */
  //
  // ⚠️ 这一段的"首屏"是**真的首屏**：一进去就每 40ms 采一次 30px 标题，
  //    看**第一次画出来的**是哪一页（用来证明"深链不是先首页再跳"）。
  //    它的诚实边界：40ms 内的闪一下采不到 —— 但"先首页、等 JS 起来再跳"那种
  //    量级是几百毫秒，采得到。
  {
    const h1raw = "(()=>{let b=null;document.querySelectorAll('div,span').forEach(e=>{if(e.children.length)return;const t=(e.textContent||'').trim();if(!t)return;if(parseFloat(getComputedStyle(e).fontSize)===30)b=t;});return b;})()";
    const sampleH1 = async (n) => {
      const out = [];
      for (let i = 0; i < n; i++) { out.push(await cdp.eval(h1raw).catch(() => null)); await sleep(40); }
      return out;
    };
    const hash = () => cdp.eval("location.hash").catch(() => "");
    // ⚠️ 先记下"上一步（⑥）留下的真地址"：rail 1 没有侧栏可点，深链的目标只能从这儿拿
    //    —— 这样两端都不写死内容（不猜 slug），也不假装测过没测的东西。
    const leftOver = await hash();
    // ⚠️ 期望的 H1 必须**在离开那一页之前**取（下面 `loadAt("")` 一跑，页面就变回首页了）
    const leftOverH1 = ((await P("snapshot()")).doc || {}).h1;

    // 基线：不带 hash 打开 ⇒ 首页，且地址栏**不**被写（我们自己不在首屏乱加历史）
    await loadAt("");
    const base = await P("snapshot()");
    const home = base.doc && base.doc.h1;
    say(!!home && (await hash()) === "", `路由·基线：不带 hash 打开 = 首页（H1 ${JSON.stringify(home)}），地址栏没被动过`);

    // 地址回写（点出来的）：主题页 `#/s/<slug>/` → 子页 `#/s/<slug>/<kid>/`
    let kidHash = null, kidH1 = null, skillHash = null, skillH1 = null;
    if (rail >= 2) {
      await clickAt(await P("sidebarTitle()"), 700);
      const d1 = await P("snapshot()");
      skillHash = await hash(); skillH1 = d1.doc && d1.doc.h1;
      say(/^#\/s\/[a-z0-9-]+\/$/.test(skillHash), `路由·点进主题页 ⇒ 地址写回 ${JSON.stringify(skillHash)}（形如 #/s/<slug>/）`);
      await clickAt(await P("nextPage()"), 700);
      const d2 = await P("snapshot()");
      kidHash = await hash(); kidH1 = d2.doc && d2.doc.h1;
      say(/^#\/s\/[a-z0-9-]+\/[a-z0-9-]+\/$/.test(kidHash) && kidHash !== skillHash,
        `路由·点「下一页」⇒ 地址跟着变 ${JSON.stringify(skillHash)} → ${JSON.stringify(kidHash)}`);
      // 后退：应当回到上一页（**地址驱动**：popstate → on_url_changed → 模型跟着改）
      await cdp.eval("history.back()");
      await sleep(700);
      const d3 = await P("snapshot()");
      const h3 = await hash();
      say(d3.doc && d3.doc.h1 === skillH1 && h3 === skillHash,
        `路由·后退：回到 ${JSON.stringify(skillHash)}（H1 ${JSON.stringify(d3.doc && d3.doc.h1)}）`);
    }

    // 深链：**一进去就是那一页**（首屏同步读一次 —— `on_url_changed` 首屏不推）
    // rail 1：目标取"⑥ 里点进文档页之后留下的那条真地址"（形如 `#/s/<slug>/`）
    if (rail < 2 && !skillHash && /^#\/s\/[a-z0-9-]+\/$/.test(leftOver)) {
      skillHash = leftOver;
      skillH1 = leftOverH1;
    }
    const target = kidHash || skillHash;
    if (target) {
      await cdp.call("Page.navigate", { url: url + target });
      const samples = await sampleH1(12);            // 从导航那一刻就开始采
      await ready();
      await cdp.eval(PAGE_JS);
      await sleep(200);
      const landed = await P("snapshot()");
      const first = samples.find((x) => !!x) || null;
      const wantH1 = kidHash ? kidH1 : skillH1;
      say(!!wantH1, `路由·深链用的目标（从真实导航里取的）：${JSON.stringify(target)} ⇒ 期望 H1 ${JSON.stringify(wantH1)}`);
      say(!!first && first === wantH1,
        `路由·深链首屏：${JSON.stringify(target)} 第一帧就是 ${JSON.stringify(first)}（不是先首页再跳）`);
      say(landed.doc && landed.doc.h1 === wantH1, `路由·深链落点：H1 = ${JSON.stringify(landed.doc && landed.doc.h1)}`);
      // 刷新同一个 hash ⇒ 还是那一页
      await cdp.call("Page.reload");
      await ready();
      await cdp.eval(PAGE_JS);
      await sleep(200);
      const after = await P("snapshot()");
      say(after.doc && after.doc.h1 === wantH1 && (await hash()) === target,
        `路由·刷新同一 hash：还是 ${JSON.stringify(after.doc && after.doc.h1)}，地址没丢`);
    }

    // 认不出的地址 ⇒ 404（这是 404 今天**唯一**的到达路径，正好把它从"渲染得出但够不着"变成可验）
    await loadAt("#/nope");
    const nf = await P("snapshot()");
    say(nf.doc && nf.doc.h1 === "没找到这一页",
      `路由·#/nope ⇒ 404 页（H1 = ${JSON.stringify(nf.doc && nf.doc.h1)}）`);
  }

  /* ⑦ 报错（两路都要看：页面异常 + 控制台 error —— React 的渲染异常只走后者） */
  const perr = cdp.pageErrors();
  const cerr = cdp.consoleErrors().filter((t) => !/favicon/i.test(t));
  say(perr.length === 0 && cerr.length === 0,
    `报错：页面异常 ${perr.length} 条 / 控制台 error ${cerr.length} 条${perr.length || cerr.length ? "：" + [...perr, ...cerr].slice(0, 2).join(" ｜ ") : ""}`);
}

await cdp.close();
if (!process.argv.includes("--keep")) cdp.kill();
server.close();
console.log(`\n${bad === 0 ? "全部通过（" + widths.length + " 个视口）" : bad + " 条不过"}`);
process.exit(bad === 0 ? 0 : 1);
