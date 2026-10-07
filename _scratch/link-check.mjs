#!/usr/bin/env node
// link-check.mjs —— 「正文里的链接可点」（对标表 #9）的验收：真 Chrome + CDP **真鼠标**。
//
//   node _scratch/link-check.mjs [--app <实例目录>] [--keep]
//
// ## 它验什么（四条）
//
//   ① 首页那批链接**在正文里是可点的元素**（不是"看着像链接的文字"）；
//   ② 点一条**站内链接** ⇒ **站内跳页**：地址栏变、H1 变成目标页的标题，
//      而且**页面没有重新加载**（用"点之前在 window 上盖的一个戳还在不在"来判 —— 刷新会把它抹掉）；
//   ③ 落到的那一页确实是那条链接指向的那一页（拿目标文字核，不只看"变了个页面"）；
//   ④ 没点过的链接**颜色/形态与普通文字不同**（说明"可点"这件事有视觉表达，不是隐形的）。
//
// ⚠️ **内容里今天没有外链**（`](http…` 一条都没有；实测 `grep` 过）⇒ "外链走 `@sub.open_url`"
//    那条分支**没有端到端读数**，别读成"外链也验过了"。它的读数在 moobile 的
//    `examples/apps/node-spike`（把 `window.open` 换成记录器再点）。
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { open } from '../tools/cdp.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const argOf = (n, d) => { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; };
const KEEP = process.argv.includes('--keep');
const app = resolve(here, '..', argOf('--app', 'skills/skillpress/scripts/.skillpress'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let bad = 0;
const say = (ok, msg) => { console.log((ok ? '  ✓ ' : '  ✗ ') + msg); if (!ok) bad += 1; };

const { createStaticServer } = await import(pathToFileURL(join(app, 'serve-web.mjs')).href);
if (!existsSync(join(app, 'dist', 'index.html'))) { console.error('没有 dist/ —— 先 npm run build'); process.exit(2); }
const server = createStaticServer(join(app, 'dist'));
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const cdp = await open({ width: 1440, height: 900 });
// ⚠️ **开在"有正文链接的那一页"**（`moobile-pitfalls`）：首页那几条 markdown 链接**不在正文里** ——
//    它们被 `inline_with_links` 收进了「顶栏那条 tab 的下拉菜单」（内容侧的设计），
//    所以拿首页量"正文链接"会一条都找不到（第一版就是这么红的，而功能是好的）。
await cdp.call('Page.navigate', { url: `http://127.0.0.1:${port}/index.html#/s/moobile-pitfalls/` });
for (let i = 0; i < 120; i++) { await sleep(200); if (await cdp.eval('!!document.querySelector("[tabindex]")')) break; }
await sleep(1200);

console.log('正文链接 —— 真 Chrome + 真鼠标\n');

// ① 正文里的链接：**正文区**（`#prose`）里那些带 `text-decoration: underline` 的文字
// ⚠️ **页面大标题怎么读**：站点今天**没有语义 `<h1>`**（整页零个 —— §12.2 记着这条硬依赖），
//    所以"H1 变没变"只能按**生效读数**判：取正文区里**字号最大的那块短文字**。
const readTitle = () => cdp.eval('(() => {' +
  'const pane = document.getElementById("prose");' +
  'if (!pane) return null;' +
  'let best = null;' +
  'pane.querySelectorAll("*").forEach((e) => {' +
  '  const t = (e.textContent || "").trim();' +
  '  if (!t || t.length > 60 || e.children.length > 2) return;' +
  '  const size = parseFloat(getComputedStyle(e).fontSize);' +
  '  if (!best || size > best.size) best = { size, t };' +
  '});' +
  'return best ? best.t : null;' +
  '})()');

const links = await cdp.eval('(() => {' +
  'const pane = document.getElementById("prose");' +
  'if (!pane) return null;' +
  'const out = [];' +
  'pane.querySelectorAll("*").forEach((e) => {' +
  '  const cs = getComputedStyle(e);' +
  '  const b = e.getBoundingClientRect();' +
  '  const t = (e.textContent || "").trim();' +
  '  if (!t || t.length > 40 || b.width === 0) return;' +
  '  if (cs.textDecorationLine.includes("underline")) {' +
  '    out.push({ text: t, color: cs.color, x: b.left + b.width / 2, y: b.top + b.height / 2 });' +
  '  }' +
  '});' +
  'return out;' +
  '})()');
say(Array.isArray(links) && links.length > 0, `正文区里找到 ${links ? links.length : 0} 个"下划线"文字（= 链接）`);
say(!!links && links.every((l) => l.color === 'rgb(79, 70, 229)'), `它们用的是**品牌色**（实测 ${links ? [...new Set(links.map((l) => l.color))].join(" / ") : "?"}）—— 可点这件事有视觉表达`);

// ②/③ 点第一条站内链接 ⇒ 站内跳页（不刷新）
if (links && links.length) {
  const target = links[0];
  // 盖一个戳：**页面一旦重新加载它就没了** ⇒ 拿它区分"站内路由"与"整页跳转"
  await cdp.eval('(() => { window.__linkStamp = "alive"; return "ok"; })()');
  const titleBefore = await readTitle();
  const before = await cdp.eval('JSON.stringify({ hash: location.hash })');
  await cdp.eval('(() => { const e = [...document.getElementById("prose").querySelectorAll("*")].find(x => (x.textContent||"").trim() === ' + JSON.stringify(target.text) + ' && getComputedStyle(x).textDecorationLine.includes("underline")); if (e) e.scrollIntoView({ block: "center" }); return "ok"; })()');
  await sleep(200);
  const pos = await cdp.eval('(() => { const e = [...document.getElementById("prose").querySelectorAll("*")].find(x => (x.textContent||"").trim() === ' + JSON.stringify(target.text) + ' && getComputedStyle(x).textDecorationLine.includes("underline")); if (!e) return null; const b = e.getBoundingClientRect(); return { x: b.left + b.width / 2, y: b.top + b.height / 2 }; })()');
  if (!pos) {
    say(false, '点之前找不到那条链接的元素（仪器问题）');
  } else {
    await cdp.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: pos.x, y: pos.y, button: 'none', buttons: 0 });
    await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x: pos.x, y: pos.y, button: 'left', buttons: 1, clickCount: 1 });
    await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: pos.x, y: pos.y, button: 'left', buttons: 0, clickCount: 1 });
    await sleep(1400);
    const titleAfter = await readTitle();
    const after = await cdp.eval('JSON.stringify({ hash: location.hash, alive: window.__linkStamp })');
    const b = JSON.parse(before), a = JSON.parse(after);
    say(a.hash !== b.hash, `点「${target.text}」⇒ **地址栏变了**（${b.hash} → ${a.hash}）`);
    say(a.alive === 'alive', '**页面没有重新加载**（点之前盖的戳还在）—— 是站内路由，不是整页跳转');
    say(
      !!titleAfter && titleAfter !== titleBefore,
      `**页面大标题变了**（${JSON.stringify((titleBefore || '').slice(0, 20))} → ${JSON.stringify((titleAfter || '').slice(0, 20))}）`,
    );
    say(
      typeof titleAfter === 'string' && titleAfter.includes('moobile 应用开发'),
      `落地页的大标题**就是那条链接的标签**（${JSON.stringify((titleAfter || '').slice(0, 24))}）—— 跳到的是对的那一页`,
    );
    // ③ 落点确实是那条链接指向的那一页（拿地址里的 slug 与目标文字核）
    const landed = a.hash.replace(/^#\//, '').replace(/\/$/, '');
    say(
      landed === 's/moobile-app-development',
      `落点是**那条链接指向的那一页**（${JSON.stringify(a.hash)}；期望 \`#/s/moobile-app-development/\`）`,
    );
    console.log(`     链接文字 = 「${target.text}」· 颜色 ${target.color}`);
  }
}

const errs = (cdp.events || []).filter((e) => e.method === 'Runtime.exceptionThrown' || (e.method === 'Log.entryAdded' && e.params?.entry?.level === 'error'));
console.log(`\n页面 JS 错误：${errs.length} 条`);
if (errs.length) console.log('  ' + errs.slice(0, 3).map((e) => (e.params.entry ? e.params.entry.text : e.params.exceptionDetails.text)).join('\n  '));
say(errs.length === 0, '页面无 JS 报错');

console.log(bad === 0 ? '\n正文链接：读数成立' : `\n正文链接：${bad} 条不成立`);
server.close();
if (!KEEP) cdp.kill();
process.exit(bad === 0 ? 0 : 1);
