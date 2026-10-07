#!/usr/bin/env node
// search-check.mjs —— 「本地搜索」（对标表 #12）的验收：真 Chrome + CDP **真鼠标 + 真按键**。
//
//   node _scratch/search-check.mjs [--app <实例目录>] [--keep]
//
// ## 它验什么（六条）
//
//   ① 顶栏那条「搜索」**点了会开**（浮层里有输入框）；
//   ② **⌘K / Ctrl+K** 也能开（真按键 + 修饰位）—— 这条单独验，因为它是"载荷里带修饰键"才认得出的；
//   ③ 输入**真文字**之后出结果，且首条结果里**含着我搜的那个词**；
//   ④ 点一条结果 ⇒ **切页 + 跳到那一节**（那一节顶到内容区上沿）+ 浮层自己关掉；
//   ⑤ **搜不到就是搜不到**（乱敲一串 ⇒ 0 条 + 一行说明，不编"猜你想搜"）；
//   ⑥ Esc 关浮层。
//
// ⚠️ 为什么全用真输入：合成事件在这套宿主上触达不到 RNW 的 responder 记账（站点 M5 实测）。
// ⚠️ 输入文字用 `Input.insertText`（它走浏览器的插入路径、会触发 `input` 事件 ⇒ RNW 的 onChangeText）。
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
await cdp.call('Page.navigate', { url: `http://127.0.0.1:${port}/index.html#/` });
for (let i = 0; i < 120; i++) { await sleep(200); if (await cdp.eval('!!document.querySelector("[tabindex]")')) break; }
await sleep(1200);

console.log('本地搜索 —— 真 Chrome + 真鼠标 + 真按键\n');

const clickById = async (id) => {
  const r = await cdp.eval('(() => {' +
    'const el = document.getElementById(' + JSON.stringify(id) + ');' +
    'if (!el) return null;' +
    'el.scrollIntoView({ block: "center" });' +
    'const b = el.getBoundingClientRect();' +
    'return { x: b.left + b.width / 2, y: b.top + b.height / 2 };' +
    '})()');
  if (!r) return 'missing';
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: r.x, y: r.y, button: 'none', buttons: 0 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x: r.x, y: r.y, button: 'left', buttons: 1, clickCount: 1 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: r.x, y: r.y, button: 'left', buttons: 0, clickCount: 1 });
  return 'ok';
};
/** 顶栏那条 nav（按文字找 —— 它没有节点名，是 nav_items 生成的） */
const clickTopbarNav = async (label) => {
  const r = await cdp.eval('(() => {' +
    'const w = document.documentElement.clientWidth;' +
    'const el = [...document.querySelectorAll("[tabindex]")].find(e => (e.textContent || "").trim() === ' + JSON.stringify(label) + ' && e.getBoundingClientRect().top < 80);' +
    'if (!el) return null;' +
    'const b = el.getBoundingClientRect();' +
    'return { x: b.left + b.width / 2, y: b.top + b.height / 2 };' +
    '})()');
  if (!r) return 'missing';
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: r.x, y: r.y, button: 'none', buttons: 0 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x: r.x, y: r.y, button: 'left', buttons: 1, clickCount: 1 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: r.x, y: r.y, button: 'left', buttons: 0, clickCount: 1 });
  return 'ok';
};

/** 界面读数：浮层 / 输入框 / 结果 / 当前页 H1 / 内容区上沿那一节 */
const read = () => cdp.eval('(() => {' +
  'const panel = document.getElementById("search-panel");' +
  'const input = document.getElementById("search-input");' +
  'const hits = [...document.querySelectorAll("[id^=hit-]")].map(e => (e.textContent || "").trim());' +
  'const h1 = document.querySelector("#root div div div div h1, h1");' +
  'const text = (document.body.innerText || "");' +
  'const pane = (() => { let el = document.getElementById("sec-0");' +
  'while (el && el !== document.body) { const cs = getComputedStyle(el);' +
  'if (el.scrollHeight > el.clientHeight + 20 && /(auto|scroll)/.test(cs.overflowY)) return el; el = el.parentElement; } return null; })();' +
  'const secs = []; for (let i = 0; i < 40; i++) { const s = document.getElementById("sec-" + i); if (s) secs.push({ id: "sec-" + i, top: Math.round(s.getBoundingClientRect().top) }); }' +
  'return { open: !!panel, focused: input && document.activeElement === input, value: input ? input.value : null,' +
  'hits, pageTitle: text.split(String.fromCharCode(10)).map(s => s.trim()).filter(s => s && s.indexOf("搜索") !== 0)[0] || "",' +
  'paneTop: pane ? Math.round(pane.getBoundingClientRect().top) : null, secs,' +
  'noHit: text.indexOf("没有匹配") >= 0 };' +
  '})()');

// ① 顶栏「搜索」点了会开
say((await clickTopbarNav('搜索')) === 'ok', '顶栏有「搜索」这一条 nav，并且点得到');
await sleep(600);
let s = await read();
say(s.open, '点一下 ⇒ **浮层开了**（面板在 DOM 里）');
say(s.focused === true, `输入框**自动获得焦点**（activeElement === input：${s.focused}）—— 打开就能打字`);

// ③ 真文字 ⇒ 真结果
const QUERY = '滚动';
await cdp.call('Input.insertText', { text: QUERY });
await sleep(700);
s = await read();
say(s.hits.length > 0, `输入「${QUERY}」⇒ 出了 ${s.hits.length} 条结果（首条：${JSON.stringify((s.hits[0] || '').slice(0, 40))}）`);
say((s.hits[0] || '').includes(QUERY), `首条结果里**含着我搜的词**（${QUERY}）`);

// ④ 点一条**小节**命中 ⇒ 切页 + **跳那一节** + 浮层自关
//
// ⚠️ 必须挑"带 · 的那种"（`页面 · 小节`）：命中有**两种粒度**，整页那条（不带 ·）本来就
//    不该跳节（`anchor = -1`）。第一版随手点了第 0 条 —— 那是一条**整页**命中，
//    于是判据红在"没跳节"上，而**行为是对的**。（仪器要指到它对的那个对象。）
const sectionHit = await cdp.eval('(() => {' +
  'const els = [...document.querySelectorAll("[id^=hit-]")];' +
  'const e = els.find(x => !/-a-1$/.test(x.id));' +
  'if (!e) return null; const b = e.getBoundingClientRect();' +
  'return { id: e.id, text: (e.textContent || "").trim(), x: b.left + b.width / 2, y: b.top + b.height / 2 };' +
  '})()');
say(!!sectionHit, `结果里有**小节级**命中：${JSON.stringify(sectionHit ? sectionHit.text.slice(0, 46) : '（没有）')}`);
if (sectionHit) {
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: sectionHit.x, y: sectionHit.y, button: 'none', buttons: 0 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x: sectionHit.x, y: sectionHit.y, button: 'left', buttons: 1, clickCount: 1 });
  await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: sectionHit.x, y: sectionHit.y, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(1400);
  s = await read();
  say(!s.open, '点完之后**浮层自己关了**');
  const near = (s.secs || []).map((x) => ({ ...x, d: Math.abs(x.top - s.paneTop) })).sort((a, b) => a.d - b.d)[0];
  say(!!near && near.d <= 24, `**跳到了那一节**：${near ? near.id : '?'} 落在内容区上沿（差 ${near ? near.d : '?'}px，容差 24）`);
  say(!!near && near.id !== 'sec-0', `跳的是**后面那一节**（${near ? near.id : '?'}，不是 sec-0）—— 防"点哪都回第一段"`);
  console.log(`     落点明细：` + (s.secs || []).slice(0, 6).map((x) => `${x.id}@${x.top}`).join('  '));
}
// ④′ 点**整页**那条 ⇒ 只切页、不跳节（这是有意的两种粒度）
{
  const opened = await clickTopbarNav('搜索');
  await sleep(600);
  const op = await read();
  say(opened === 'ok' && op.open, `再开一次搜索浮层（${opened} / open=${op.open}）`);
  // ⚠️ **插入文字之前先点输入框**：`Input.insertText` 是发给"当前焦点"的，
  //    焦点不在输入框上时它会**悄悄发给别人**（第一版就吃了这个亏：查询没变，
  //    于是"0 条结果"那条判据红在一个**假**症状上 —— 仪器自己没盯住焦点）。
  await clickById('search-input');
  await sleep(200);
  const focused = await cdp.eval('document.activeElement && document.activeElement.id');
  say(focused === 'search-input', `插入文字前先确认焦点在输入框（activeElement = ${focused}）`);
  // ⚠️ **先全选再打**：`insertText` 是"在光标处插入"，而查询词**关掉浮层时不会被清空**
  //    ⇒ 直接再插一次会拼成"滚动滚动"（0 条结果），判据就红在一个**假**症状上。
  //    全选（Ctrl+A，真按键）之后插入 = 像用户那样替换掉旧词。
  await cdp.call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'a', code: 'KeyA', modifiers: 2, windowsVirtualKeyCode: 65, nativeVirtualKeyCode: 65 });
  await cdp.call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'a', code: 'KeyA', modifiers: 2, windowsVirtualKeyCode: 65, nativeVirtualKeyCode: 65 });
  await sleep(150);
  await cdp.call('Input.insertText', { text: QUERY });
  await sleep(700);
  const q = await cdp.eval('document.getElementById("search-input") && document.getElementById("search-input").value');
  say(q === QUERY, `查询词被**替换**成「${QUERY}」（实测 ${JSON.stringify(q)}）`);
  const pageHit = await cdp.eval('(() => {' +
    'const els = [...document.querySelectorAll("[id^=hit-]")];' +
    'const e = els.find(x => /-a-1$/.test(x.id));' +
    'if (!e) return null; const b = e.getBoundingClientRect();' +
    'return { id: e.id, text: (e.textContent || "").trim(), x: b.left + b.width / 2, y: b.top + b.height / 2 };' +
    '})()');
  say(!!pageHit, `结果里也有**整页级**命中（不带 · 的那种）：${JSON.stringify(pageHit ? pageHit.text.slice(0, 40) : '（没有）')}`);
  if (pageHit) {
    await cdp.call('Input.dispatchMouseEvent', { type: 'mousePressed', x: pageHit.x, y: pageHit.y, button: 'left', buttons: 1, clickCount: 1 });
    await cdp.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: pageHit.x, y: pageHit.y, button: 'left', buttons: 0, clickCount: 1 });
    await sleep(1000);
    const st = await read();
    const near2 = (st.secs || []).map((x) => ({ ...x, d: Math.abs(x.top - st.paneTop) })).sort((a, b) => a.d - b.d)[0];
    say(!st.open && !!near2 && near2.id === 'sec-0', `整页那条 ⇒ 只切页、**停在开头**（${near2 ? near2.id : '?'}，这是有意的两种粒度）`);
  }
}

// ⑤ 搜不到就搜不到
await clickTopbarNav('搜索');
await sleep(500);
await cdp.call('Input.insertText', { text: 'zzz不存在的词zzz' });
await sleep(700);
s = await read();
say(s.hits.length === 0 && s.noHit, `乱敲一串 ⇒ **0 条结果**，并给出一行说明（noHit=${s.noHit}）—— 不编"猜你想搜"`);

// ⑥ Esc 关 —— ⚠️ **必须在"输入框还有焦点"的时候测**：这正是本轮逮到真 bug 的地方
//    （RNW 的 TextInput 把非捕获的 keydown 拦住 ⇒ 文档级订阅收不到 ⇒ 浮层关不掉）。
//    修法是把 `on_key_down` 的监听挪到**捕获阶段**（moobile 侧 `sub.mbt`）。
await clickById('search-input'); // 点一下输入框保证焦点在它身上
await sleep(200);
const focusBeforeEsc = await cdp.eval('document.activeElement && document.activeElement.id');
await cdp.call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 });
await cdp.call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 });
await sleep(600);
s = await read();
say(!s.open, `**输入框聚焦时**（activeElement = ${focusBeforeEsc}）按 Esc 也能关 —— 捕获阶段那条账`);

// ② ⌘K / Ctrl+K 也能开（真按键 + 修饰位）
await cdp.call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'k', code: 'KeyK', modifiers: 2, windowsVirtualKeyCode: 75, nativeVirtualKeyCode: 75 });
await cdp.call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'k', code: 'KeyK', modifiers: 2, windowsVirtualKeyCode: 75, nativeVirtualKeyCode: 75 });
await sleep(600);
s = await read();
say(s.open, '**Ctrl+K**（真按键 + 修饰位）也能开 —— 载荷里带了修饰键才认得出（`Msg::Key(String, Bool)`）');

const errs = (cdp.events || []).filter((e) => e.method === 'Runtime.exceptionThrown' || (e.method === 'Log.entryAdded' && e.params?.entry?.level === 'error'));
console.log(`\n页面 JS 错误：${errs.length} 条`);
say(errs.length === 0, '页面无 JS 报错');

console.log(bad === 0 ? '\n本地搜索：读数成立' : `\n本地搜索：${bad} 条不成立`);
server.close();
if (!KEEP) cdp.kill();
process.exit(bad === 0 ? 0 : 1);
