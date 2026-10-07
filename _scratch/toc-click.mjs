#!/usr/bin/env node
// toc-click.mjs —— 「目录可点」这一条的验收（真 Chrome + CDP **真鼠标**）。
//
//   node _scratch/toc-click.mjs [--app <实例目录>] [--keep]
//
// ## 它验什么（三条，缺一条都不算通）
//
//   ① **正文标题挂了锚点**（`id="sec-<i>"` 那些在 DOM 里）—— 这条是"节点寻址"的地基；
//   ② **点一下真的跳**：目标那一节**顶到内容区上沿**（不是"滚动量大于 0"这种弱条件）；
//   ③ **跳的是对的那一节**：点右栏靠后的那一行，落点必须是 `sec-<较大编号>`，不是第一段
//      —— 防"点哪都跳第一段"这种**看起来成功**的错。
//
// ⚠️ 为什么必须真鼠标：合成事件在这套宿主上**触达不到 RNW 的 responder 记账**（站点 M5 实测），
//    合成派发即使"成功"也可能什么都没发生。
// ⚠️ CDP 那套用仓里的 `tools/cdp.mjs`（它已经踩过"端口不能写死"那条坑）。
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
if (KEEP) console.log('（--keep：Chrome 留着）');
await cdp.call('Page.navigate', { url: `http://127.0.0.1:${port}/index.html#/s/moobile-app-development/` });
for (let i = 0; i < 120; i++) { await sleep(200); if (await cdp.eval('!!document.querySelector(\'[tabindex="0"]\')')) break; }
await sleep(1500); // 首屏渲染 + 字体

console.log('目录可点 —— 真 Chrome + CDP 真鼠标\n');

// ① 正文标题的锚点
const anchors = await cdp.eval(`(() => {
  const out = [];
  for (let i = 0; i < 16; i++) { const el = document.getElementById('sec-' + i); if (el) { const b = el.getBoundingClientRect(); out.push({ id: 'sec-' + i, top: Math.round(b.top) }); } }
  return out;
})()`);
say(Array.isArray(anchors) && anchors.length >= 2, `正文标题挂了锚点：${anchors ? anchors.map((a) => a.id).join(' ') : '（没读到）'}`);

// ② 内容区那个"自己滚"的容器 —— ⚠️ **按锚点的可滚祖先找**，不按"页面里第一个可滚元素"找。
//    第一版就是后者，结果抓到的是**另一个**元素（可见高 690 / 内容 750）：它的 `top` 恰好也是 56，
//    于是"顶到上沿"那条判据**看起来是绿的**、`scrollTop` 那条却是 0→0。读数自相矛盾 ⇒ 仪器错了。
//    教训与仓里那条同源：**判据必须指到它对的那个对象**，不然"绿"是巧合。
const SCROLLER = `(() => {
  let el = document.getElementById('sec-0');
  while (el && el !== document.body) {
    const cs = getComputedStyle(el);
    if (el.scrollHeight > el.clientHeight + 20 && /(auto|scroll)/.test(cs.overflowY)) return el;
    el = el.parentElement;
  }
  return null;
})()`;
const pane = await cdp.eval(`(() => { const el = ${SCROLLER}; if (!el) return null; const b = el.getBoundingClientRect();
  return { tag: el.tagName, h: el.clientHeight, sh: el.scrollHeight, top: Math.round(b.top), st: Math.round(el.scrollTop) }; })()`);
say(!!pane, `内容区容器：${pane ? `${pane.tag} 可见高 ${pane.h} / 内容 ${pane.sh} / 上沿 y=${pane.top}` : '**没找到可滚容器**'}`);

// ③ 右栏（轨）那些目录行：靠屏幕右侧、短文字、可点
const rows = await cdp.eval(`(() => {
  const w = document.documentElement.clientWidth;
  return [...document.querySelectorAll('[tabindex="0"]')]
    .map((e, i) => { const b = e.getBoundingClientRect(); return { i, text: (e.textContent || '').trim(), x: b.left + b.width / 2, y: b.top + b.height / 2, left: Math.round(b.left) }; })
    .filter(r => r.left > w * 0.7 && r.text.length > 1 && r.text.length < 40);
})()`);
say(!!rows && rows.length >= 2, `右栏目录行 ${rows ? rows.length : 0} 条：${rows ? rows.map((r) => '「' + r.text + '」').join(' ') : ''}`);

if (rows && rows.length >= 2) {
  // 点**最后**那一行（靠后的那一节）—— 这样"落点是不是第一段"才有区分度
  const target = rows[rows.length - 1];
  const clickAt = async (x, y) => {
    await cdp.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, button: 'none', buttons: 0 });
    await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
    await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
  };
  const before = await cdp.eval(`(() => { const el = ${SCROLLER}; return el ? Math.round(el.scrollTop) : null; })()`);
  await clickAt(target.x, target.y);
  await sleep(900);
  const after = await cdp.eval(`(() => {
    const el = ${SCROLLER};
    const out = [];
    for (let i = 0; i < 16; i++) { const s = document.getElementById('sec-' + i); if (s) out.push({ id: 'sec-' + i, top: Math.round(s.getBoundingClientRect().top) }); }
    return { st: el ? Math.round(el.scrollTop) : null, secs: out };
  })()`);
  say(after.st > before, `内容区真的滚了：scrollTop ${before} → ${after.st}`);
  const near = (after.secs || []).map((s) => ({ ...s, d: Math.abs(s.top - pane.top) })).sort((a, b) => a.d - b.d)[0];
  say(!!near && near.d <= 24, `点「${target.text}」之后，${near ? near.id : '?'} 落在内容区上沿（差 ${near ? near.d : '?'}px，容差 24）`);
  const idx = Number((near ? near.id : 'sec-x').replace('sec-', ''));
  say(idx >= 1, `落点是 **sec-${idx}**（不是 sec-0）—— 防"点哪都跳第一段"`);
  console.log('     落点明细：' + (after.secs || []).map((s) => `${s.id}@${s.top}`).join('  '));

  // ④ 再点**第一**行 ⇒ 必须跳回上面（证明"按条目跳"而不是"一直往下滚"）
  const first = rows[0];
  await clickAt(first.x, first.y);
  await sleep(900);
  const back = await cdp.eval(`(() => {
    const el = ${SCROLLER};
    const out = [];
    for (let i = 0; i < 16; i++) { const s = document.getElementById('sec-' + i); if (s) out.push({ id: 'sec-' + i, top: Math.round(s.getBoundingClientRect().top) }); }
    return { st: el ? Math.round(el.scrollTop) : null, secs: out };
  })()`);
  const near2 = (back.secs || []).map((s) => ({ ...s, d: Math.abs(s.top - pane.top) })).sort((a, b) => a.d - b.d)[0];
  say(!!near2 && near2.d <= 24, `点第一行「${first.text}」⇒ 落在 ${near2 ? near2.id : '?'}（差 ${near2 ? near2.d : '?'}px）`);
  say(near2 && near2.id !== near.id, `两次点击落到**不同**的节（${near ? near.id : '?'} vs ${near2 ? near2.id : '?'}）—— 目录是按条目跳的`);
}

// ── ⑤⑥ **跟读高亮**：目录行要跟着"内容区滚到哪"换 ──────────────────────────────
//
// 判定用**生效读数**（计算样式），不是应用自己报的 state：
// 高亮 = 品牌色（浅色主题 --brand）+ 加重；并且**必须有且只有一条**是高亮的（"全都高亮"也算红）。
const BRAND = 'rgb(79, 70, 229)';
const readRows = () =>
  cdp.eval(
    '(() => {' +
      'const w = document.documentElement.clientWidth;' +
      'return [...document.querySelectorAll("[tabindex]")]' +
      '.map((e) => { const b = e.getBoundingClientRect(); const cs = getComputedStyle(e);' +
      'return { text: (e.textContent || "").trim(), left: Math.round(b.left), x: b.left + b.width / 2, y: b.top + b.height / 2, color: cs.color, weight: cs.fontWeight }; })' +
      '.filter(r => r.left > w * 0.7 && r.text.length > 1 && r.text.length < 40);' +
      '})()',
  );
const activeOf = (rows) => rows.map((r, i) => (r.color === BRAND ? i : -1)).filter((i) => i >= 0);
console.log('');
console.log('⑤ 跟读高亮（看**计算样式**：品牌色 ' + BRAND + ' + 加重）');
const rows0 = await readRows();
{
  const a0 = activeOf(rows0);
  say(a0.length === 1, '装载后**有且只有一条**高亮（实测 ' + a0.length + ' 条）');
  say(a0[0] === 0, '装载后高亮在第 **0** 条（实测第 ' + a0[0] + ' 条）—— 首屏就有高亮，不必等用户先滚');
  const weights = rows0.map((r) => r.weight).join('/');
  say(
    rows0.every((r, i) => (i === a0[0] ? r.weight === '600' : r.weight === '400')),
    '加重跟着走：高亮那条 600、其余 400（实测 ' + weights + '）',
  );
}

console.log('');
console.log('⑥ 滚动内容区 ⇒ 高亮跟着换（这才是"跟读"）');
const target = rows0.length >= 5 ? 4 : rows0.length - 1;
{
  const scrolled = await cdp.eval(
    '(() => {' +
      'const sec = document.getElementById("sec-' + target + '");' +
      'const pane = (() => { let el = document.getElementById("sec-0");' +
      'while (el && el !== document.body) { const cs = getComputedStyle(el);' +
      'if (el.scrollHeight > el.clientHeight + 20 && /(auto|scroll)/.test(cs.overflowY)) return el; el = el.parentElement; } return null; })();' +
      'if (!sec || !pane) return null;' +
      'const delta = sec.getBoundingClientRect().top - pane.getBoundingClientRect().top;' +
      'pane.scrollTop = pane.scrollTop + delta + 30;' +
      'return Math.round(pane.scrollTop);' +
      '})()',
  );
  await sleep(700);
  const rows1 = await readRows();
  const a1 = activeOf(rows1);
  say(scrolled !== null, '把内容区滚到第 ' + target + ' 节附近（scrollTop=' + scrolled + '）');
  say(a1.length === 1, '滚动之后仍**有且只有一条**高亮（实测 ' + a1.length + ' 条）');
  say(a1[0] === target, '高亮**跟着滚**换到第 ' + target + ' 条（实测第 ' + a1[0] + ' 条）');
}


const errs = (cdp.events || []).filter((e) => e.method === 'Runtime.exceptionThrown' || (e.method === 'Log.entryAdded' && e.params?.entry?.level === 'error'));
console.log(`\n页面 JS 错误：${errs.length} 条`);
say(errs.length === 0, '页面无 JS 报错');

console.log(bad === 0 ? '\n目录可点：读数成立' : `\n目录可点：${bad} 条不成立`);
server.close();
if (!KEEP) cdp.kill();
process.exit(bad === 0 ? 0 : 1);
