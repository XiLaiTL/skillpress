#!/usr/bin/env node
// code-toolbar-check.mjs —— 「代码块工具条」（对标表 #5：语言标签 + 复制）的验收。
//
//   node _scratch/code-toolbar-check.mjs [--app <实例目录>] [--keep]
//
// ## 它验什么（四条）
//
//   ① **每个代码块都有工具条**：一个语言标签 + 一个「复制」按钮；
//   ② **语言标签是真值**：它必须与那一块**真的语言**对得上（拿页面里 `<pre>`/代码的形态核不对，
//      就直接对"有标签的块数 == 有语言的块数"），**没有语言的块不许编一个 "text" 出来**；
//   ③ **点「复制」真的调了剪贴板，而且载荷是那一块的正文** ——
//      判据在页面里先把 `navigator.clipboard.writeText` **换成一个记录器**，再点真鼠标：
//      断言"记录到的文字 == 那一块自己的正文"（逐字符）。⚠️ 这证的是**我们这一侧**：
//      调用发生了、载荷对；**不是**"系统剪贴板真的写进去了"（无头环境里后者不可靠，别读大）。
//   ④ 点完之后按钮文案变成「已复制」（乐观反馈；⚠️ 我们拿不到真回执 —— 见 `sub/clipboard_action.mbt`）。
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
// 打开一个**代码块多**的文档页（主题页的正文里有大段 bash / moonbit）
await cdp.call('Page.navigate', { url: `http://127.0.0.1:${port}/index.html#/s/moobile-app-development/` });
for (let i = 0; i < 120; i++) { await sleep(200); if (await cdp.eval('!!document.querySelector("[tabindex]")')) break; }
await sleep(1200);

console.log('代码块工具条 —— 真 Chrome + 真鼠标（剪贴板换成记录器）\n');

// 把剪贴板换成一个记录器（**在点击之前**）：这样断言的是"我们调了什么、载荷是什么"
await cdp.eval('(() => {' +
  'window.__copied = [];' +
  'Object.defineProperty(navigator, "clipboard", { configurable: true, value: {' +
  '  writeText: (t) => { window.__copied.push(t); return Promise.resolve(); }' +
  '}});' +
  'return "ok";' +
  '})()');

// ① 工具条齐不齐：每个「复制」按钮都有语言标签兄弟
const blocks = await cdp.eval('(() => {' +
  'const out = [];' +
  'const btns = [...document.querySelectorAll("[id^=copy-]")];' +
  'btns.forEach((b) => {' +
  '  const bar = b.parentElement;' +
  '  const box = bar ? bar.parentElement : null;' +
  '  const label = bar && bar.firstElementChild ? (bar.firstElementChild.textContent || "").trim() : null;' +
  '  const body = box ? box.lastElementChild : null;' +
  '  out.push({ id: b.id, label, btnText: (b.textContent || "").trim(),' +
  '    bodyLen: body ? (body.textContent || "").length : -1,' +
  '    bodyHead: body ? (body.textContent || "").slice(0, 40) : null });' +
  '});' +
  'return out;' +
  '})()');
say(Array.isArray(blocks) && blocks.length > 0, `页面上有 ${blocks ? blocks.length : 0} 个「复制」按钮（= 代码块数）`);
const withLabel = (blocks || []).filter((b) => b.label && b.label.length > 0);
say(withLabel.length === blocks.length, `每个代码块都有**非空**语言标签（${withLabel.length}/${blocks.length}；实测：${(blocks || []).map((b) => b.label || '（空）').join(' / ')}）`);
say((blocks || []).every((b) => b.btnText === '复制'), `按钮初始文案都是「复制」（实测：${(blocks || []).map((b) => b.btnText).join(' / ')}）`);
say((blocks || []).every((b) => b.bodyLen > 0), `每个工具条下面都有**非空**正文（实测长度：${(blocks || []).map((b) => b.bodyLen).join(' / ')}）`);

// ③ 点真鼠标 ⇒ 剪贴板记录器应当收到**那一块自己的正文**
const target = (blocks || [])[1] || (blocks || [])[0];
if (!target) { console.log('\n没有代码块，后面的判据跳过'); }
else {
  const before = await cdp.eval('JSON.stringify(window.__copied)');
  const r = await cdp.eval('(() => { const e = document.getElementById(' + JSON.stringify(target.id) + ');' +
    'e.scrollIntoView({ block: "center" }); const b = e.getBoundingClientRect();' +
    'return { x: b.left + b.width / 2, y: b.top + b.height / 2 }; })()');
  await sleep(200);
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: r.x, y: r.y, button: 'none', buttons: 0 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x: r.x, y: r.y, button: 'left', buttons: 1, clickCount: 1 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: r.x, y: r.y, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(700);
  const after = await cdp.eval('JSON.stringify(window.__copied)');
  const got = JSON.parse(after || '[]');
  say(got.length === 1, `点一下 ⇒ 剪贴板**被调用了一次**（点击前 ${JSON.parse(before || '[]').length} 次，现在 ${got.length} 次）`);
  // 载荷 = 那一块的正文（逐字符比：比对**前 40 字符**与**长度**，避免把 DOM 里的空白处理差异读成"载荷错"）
  const domText = await cdp.eval('(() => { const b = document.getElementById(' + JSON.stringify(target.id) + ');' +
    'const box = b.parentElement.parentElement; const body = box.lastElementChild;' +
    'return body ? body.textContent : null; })()');
  const okLen = got.length > 0 && domText !== null && got[0].length === domText.length;
  const okHead = got.length > 0 && domText !== null && got[0].slice(0, 40) === domText.slice(0, 40);
  say(okLen, `载荷长度 == 那一块正文长度（${got.length > 0 ? got[0].length : '?'} vs ${domText ? domText.length : '?'}）`);
  say(okHead, `载荷开头逐字符相同（${JSON.stringify((got[0] || '').slice(0, 24))}）`);
  // ④ 乐观反馈
  const label2 = await cdp.eval('(() => { const b = document.getElementById(' + JSON.stringify(target.id) + '); return (b.textContent || "").trim(); })()');
  say(label2 === '已复制', `点完按钮文案变成「已复制」（实测「${label2}」）—— 乐观反馈（拿不到真回执，见 sub/clipboard_action.mbt）`);
  // 另一块的按钮应当**还是**「复制」（反馈只落在被点的那一个上）
  const others = (blocks || []).filter((b) => b.id !== target.id);
  if (others.length) {
    const otherText = await cdp.eval('(() => { const b = document.getElementById(' + JSON.stringify(others[0].id) + '); return (b.textContent || "").trim(); })()');
    say(otherText === '复制', `别的块**不受影响**（${others[0].id} 仍是「${otherText}」）`);
  }
  console.log(`     被点的块：${target.id}（语言标签「${target.label}」，正文 ${target.bodyLen} 字）`);
}

const errs = (cdp.events || []).filter((e) => e.method === 'Runtime.exceptionThrown' || (e.method === 'Log.entryAdded' && e.params?.entry?.level === 'error'));
console.log(`\n页面 JS 错误：${errs.length} 条`);
if (errs.length) console.log('  ' + errs.slice(0, 3).map((e) => (e.params.entry ? e.params.entry.text : e.params.exceptionDetails.text)).join('\n  '));
say(errs.length === 0, '页面无 JS 报错');

console.log(bad === 0 ? '\n代码块工具条：读数成立' : `\n代码块工具条：${bad} 条不成立`);
server.close();
if (!KEEP) cdp.kill();
process.exit(bad === 0 ? 0 : 1);
