#!/usr/bin/env node
// image-check.mjs —— 「图片」（对标表 #10）的验收：**真 Chrome + CDP**，跑的是一份**用夹具语料印出来的站点**。
//
//   node _scratch/image-check.mjs [--keep]
//
// ## 为什么不在程序实例上量
//
// 程序实例的内容根是 `moobile/skills` —— 那份**真内容里今天一张图都没有**（刻意的：内容是给 Agent
// 读的文字，没有配图）。而 #10 要的回答是"图片这条通道到底通没通"：拿一份**没有图的语料**去量，
// 量出来的"页面里没有图"分不清是"功能坏了"还是"本来就没有图"（这正是**判据要能证伪**那条规矩）。
//
// 所以这里**现搭一份夹具站点**：拿 `tools/fixtures/corpus/skills`（引擎 golden 用的那份冻结语料，
// 里面 `gamma-skill/SKILL.md` 有一条 `![一张夹具图](../assets/fixture.png)`）当内容根，
// 走**和真实站点完全同一条路**：`engine.mjs press`（引擎折 URL + 拷图）→ `moon build` →
// `build-web.mjs`（拷进 `dist/`）→ 静态服务 → 真 Chrome。差别的只有"内容源是哪一份"。
//
// ## 它验什么（五条，各自独立）
//
//   ① 页面里真有一个"图片元素"（`aria-label` = 那句 alt）；
//   ② 它**看得见的那一层**（RNW 把图铺在 `background-image` 上）就是那张图；
//   ③ 浏览器**真的解码了它**（`naturalWidth/Height` = 夹具 PNG 的真实尺寸 160×90；
//      要按这个尺寸生成这张图见 `tools/fixtures/make-fixture-png.py`）；
//   ④ `alt` 接到了两处（根上的 `aria-label` + 无障碍那层的 `<img alt>`）；
//   ⑤ **那个地址在站点上真的拿得到**：按 URL 请求 `/img/assets/fixture.png`，200 + 字节数与
//      `tools/fixtures/corpus/skills/assets/fixture.png` **逐字节相同**（"拷进来了"这件事必须自己去取一次）。
//
// ⚠️ ③ 与 ⑤ 是两件事，别并成一条：③ 只证明"浏览器解码了一张图"，⑤ 才证明"解码的是**内容里那张**"。
//    少任何一条，`img` 指向一个 404 的空壳都能半绿。
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { get } from 'node:http';
import { spawnSync } from 'node:child_process';
import { open } from '../tools/cdp.mjs';

const here = dirname(fileURLToPath(import.meta.url));      // skillpress/_scratch
const ROOT = resolve(here, '..');                          // 程序根（skillpress）
const MOOBILE = resolve(ROOT, '..', 'moobile');
const REAL = join(ROOT, 'skills', 'skillpress', 'scripts', '.skillpress'); // 借它的 node_modules / .mooncakes
const FIXTURE = join(ROOT, 'tools', 'fixtures', 'corpus', 'skills');
const FIXTURE_PNG = join(FIXTURE, 'assets', 'fixture.png');
// 夹具站点落在**程序实例的 `_build/`** 里：Node 解析模块会往上找，于是它白得
// `.skillpress/node_modules`（esbuild / react / react-native-web）—— 不用再 `npm install` 一次。
const SCRATCH = join(REAL, '_build', 'img-site');
const KEEP = process.argv.includes('--keep');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let bad = 0;
const say = (ok, msg) => { console.log((ok ? '  ✓ ' : '  ✗ ') + msg); if (!ok) bad += 1; };
/** 相对路径一律**正斜杠**（Windows 的反斜杠进 moon 的配置里是另一回事）。 */
const rel = (from, to) => relative(from, to).split('\\').join('/');
const run = (cmd, args, opts = {}) => {
  const r = spawnSync(cmd, args, { encoding: 'utf8', ...opts });
  if (r.status !== 0) {
    console.error(`✗ 命令失败（${cmd} ${args.join(' ')}）：\n${(r.stderr || '').trim() || (r.stdout || '').trim()}`);
    process.exit(2);
  }
  return r.stdout || '';
};

// ── ⓪ 现搭夹具站点 ──────────────────────────────────────────────────────────────
// 拷的是**模板那一份**（`template/instance/`）而不是程序实例：程序实例里带着"真内容"的产物
// （content/、md/、llms.txt），拷过来会让这一步看起来像"站点本来就长这样"。
console.log('图片 —— 真 Chrome（内容源：冻结夹具语料）\n');
console.log(`  · 夹具站点：${SCRATCH}`);
rmSync(SCRATCH, { recursive: true, force: true });
mkdirSync(SCRATCH, { recursive: true });
const TPL = join(ROOT, 'template', 'instance');
const COPY = ['moon.mod', 'moon.pkg', 'app.mbt', 'App.js', 'index.js', 'index.html',
              'build-web.mjs', 'serve-web.mjs', 'engine.mjs', 'verify.mjs', 'registry.generated.js'];
for (const f of COPY) cpSync(join(TPL, f), join(SCRATCH, f));
// ⚠️ 模板里有**占位符**（`{{MODULE}}` 那类），替换是生成器（`skillpress attach`）的活。
//    这里是**现搭**、不走生成器，所以自己替 —— 漏一处，`moon build` 会报
//    `Cannot find import '{{MODULE}}/content'`（第一跑就是这么红的：只替了 `moon.mod`，
//    而 `moon.pkg` 里那条 `@content` 的 import 也带占位符）。
//    ⚠️ **替换清单不许手抄**：这里按"生成器会碰的那几个文件"来，并且**逐个断言一个占位符都不剩**
//    （模板将来加了新占位符，这一条会当场红，而不是编出一个莫名其妙的名字）。
// 五个占位符（真源：`engine/scaffold/names.mbt` 的 `all_tokens()`；模板改了这里会红）
const TOKENS = {
  '{{MODULE}}': 'skillpress-img-check',
  '{{ENGINE_REL}}': rel(SCRATCH, ROOT),
  '{{HOST_DEP}}': 'file:' + rel(SCRATCH, join(MOOBILE, 'npm', 'moobile-host')),
  '{{SITE_TITLE}}': 'skillpress 图片读数（夹具站点）',
  '{{SKILLPRESS_VERSION}}': (readFileSync(join(ROOT, 'moon.mod'), 'utf8').match(/^version\s*=\s*"([^"]*)"/m) || [])[1] || '0.1.0',
};
for (const f of COPY) {
  const p = join(SCRATCH, f);
  const before = readFileSync(p, 'utf8');
  const after = before.replace(/\{\{[A-Z_]+\}\}/g, (m) => TOKENS[m] ?? m);
  if (after !== before) writeFileSync(p, after);
}
for (const f of COPY) {
  const left = readFileSync(join(SCRATCH, f), 'utf8').match(/\{\{[A-Z_]+\}\}/);
  if (left) {
    console.error(`✗ ${f} 里还有没替换的占位符 ${left[0]} —— 模板变了，这里的替换要跟上`);
    process.exit(2);
  }
}
// `content/` 那个包：模板里有它的 `moon.pkg`（内容包只有数据 + 两个入口），`press` 只往里写
// `content.generated.mbt` —— 忘了拷 `moon.pkg` 的话 `moon build` 报
// `Cannot find import '<模块>/content'`（第二跑就是这么红的）。
mkdirSync(join(SCRATCH, 'content'), { recursive: true });
cpSync(join(TPL, 'content', 'moon.pkg'), join(SCRATCH, 'content', 'moon.pkg'));
// 工作区：`[".", 程序根, moobile]` —— 后两条是"吃本地源码"（未发布的那几个 API 靠它）。
// ⚠️ **绝对路径**是允许的：`moon.work` 的文件头写明"相对路径算不出来时跨盘用绝对路径"。
writeFileSync(join(SCRATCH, 'moon.work'),
  ['// 由 `_scratch/image-check.mjs` 现写（夹具站点，不是给人用的工程）', 'members = [',
   '  ".",', `  ${JSON.stringify(ROOT)},`, `  ${JSON.stringify(MOOBILE)},`, ']', ''].join('\n'));
// `.mooncakes`：26 MB，**目录联接**过去（拷一份纯属浪费；它只是 registry 依赖的缓存）
symlinkSync(join(REAL, '.mooncakes'), join(SCRATCH, '.mooncakes'), 'junction');
// 宿主：**本地那份** npm 包（`Image` 还没随包发出去 —— 发布顺序见 PLAN §7）
mkdirSync(join(SCRATCH, 'node_modules'), { recursive: true });
cpSync(join(MOOBILE, 'npm', 'moobile-host'), join(SCRATCH, 'node_modules', 'moobile-host'), { recursive: true });

// ── ① press：引擎折 URL + **把图拷进实例** ──────────────────────────────────────
run(process.execPath, [join(SCRATCH, 'engine.mjs'), 'press', '--app', '.', '--skills', FIXTURE], {
  cwd: SCRATCH, env: { ...process.env, SKILLPRESS_ENGINE: ROOT },
});
const copied = join(SCRATCH, 'img', 'assets', 'fixture.png');
const srcBytes = readFileSync(FIXTURE_PNG);
say(existsSync(copied), `press 把图拷进了实例（img/assets/fixture.png，${srcBytes.length} 字节）`);
say(existsSync(copied) && readFileSync(copied).equals(srcBytes),
  '拷进来的那份与语料里那份**逐字节相同**（不是"差不多"）');

// ── ② 编 + 打 ──────────────────────────────────────────────────────────────────
run('moon', ['build', '--target', 'js'], { cwd: SCRATCH });
run(process.execPath, [join(REAL, 'node_modules', 'moobile-host', 'bin', 'cli.js'), 'build'], { cwd: SCRATCH });
run(process.execPath, [join(SCRATCH, 'build-web.mjs')], { cwd: SCRATCH });
say(existsSync(join(SCRATCH, 'dist', 'img', 'assets', 'fixture.png')), 'build-web 把 img/ 拷进了 dist/');

// 【证伪开关】`--drop-asset`：把拷进 `dist/` 的那张图**删掉**再量 ——
// 要的是"资产没到位"这件事**必须红**。一个加载不到的 `src` 在页面上**不报错**（就是个空框），
// 所以这一格只能靠判据自己抓住。
//
// 实测（这一跑的真读数，别照直觉写）：404 之下 **② 仍然绿**（`src` 写得没错）、
// **⑤ 也仍然绿**（浏览器的"破图"占位符**本身有高度**，720×24）——
// 真正抓住它的是 **③（解码 0×0）** 与 **⑤′（HTTP 码 + 字节数）**。
// 这条读数值得单独记：**"看起来对"不等于"取到了"**；只断言"元素在、有 src、有尺寸"的判据
// 在 404 面前是瞎的。
if (process.argv.includes('--drop-asset')) {
  rmSync(join(SCRATCH, 'dist', 'img'), { recursive: true, force: true });
  console.log('  · 【证伪】已删掉 dist/img/ —— 这一跑必须红');
}

// ── ③ 真 Chrome ────────────────────────────────────────────────────────────────
const { createStaticServer } = await import(pathToFileURL(join(SCRATCH, 'serve-web.mjs')).href);
const server = createStaticServer(join(SCRATCH, 'dist'));
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;
const cdp = await open({ width: 1440, height: 900 });
await cdp.call('Page.navigate', { url: `http://127.0.0.1:${port}/index.html#/s/gamma-skill/` });
for (let i = 0; i < 120; i++) { await sleep(200); if (await cdp.eval('!!document.querySelector("[tabindex]")')) break; }
await sleep(1200);

const img = await cdp.eval('(() => {' +
  'const el = [...document.querySelectorAll("img")].find((n) => (n.getAttribute("alt") || "").includes("夹具图"));' +
  'if (!el) return null;' +
  'const r = el.getBoundingClientRect();' +
  'return { tag: el.tagName, src: el.getAttribute("src"),' +
  ' nat: el.complete ? el.naturalWidth + "x" + el.naturalHeight : "（还没加载完）",' +
  ' alt: el.getAttribute("alt"), w: Math.round(r.width), h: Math.round(r.height) };' +
  '})()');
say(!!img, `页面里有一个**真的** \`<img>\`（${img ? '<' + img.tag.toLowerCase() + '>' : '（没有）'}）`);
say(!!img && img.src === 'img/assets/fixture.png',
  `它的 \`src\` 是站点地址（${img ? JSON.stringify(img.src) : '-'}）`);
say(!!img && img.nat === '160x90', `浏览器**真的解码**了它（实测 ${img ? img.nat : '?'}，夹具图是 160×90）`);
say(!!img && img.alt === '一张夹具图', `\`alt\` 在（${img ? JSON.stringify(img.alt) : '-'}）—— 读屏与兜底文案`);
// ⚠️ **这一条是这次最值钱的读数**：第一版（用 RNW 的 `Image`）这里量出来是 `720×0` ——
//    宽占满一栏、**高为 0** ⇒ 页面上什么都看不见。而"DOM 里有图片元素""naturalWidth 对"
//    那两条**都是绿的**（假绿）。判据里必须有一条是"它真的占了版面"。
say(!!img && img.w > 0 && img.h > 0, `它真的占了版面（${img ? img.w + '×' + img.h + 'px' : '?'}）`);

// ⑤ 那个地址**在站点上真的拿得到**：按 URL 取一次，比字节
const got = await new Promise((res) => {
  const req = get({ host: '127.0.0.1', port, path: '/img/assets/fixture.png' }, (r) => {
    const cs = [];
    r.on('data', (c) => cs.push(c));
    r.on('end', () => res({ status: r.statusCode, body: Buffer.concat(cs) }));
  });
  req.on('error', () => res({ status: 0, body: Buffer.alloc(0) }));
});
say(got.status === 200, `按 src 请求那个地址：HTTP ${got.status}`);
say(got.body.equals(srcBytes),
  `拿回来的字节 == 语料里那张图（${got.body.length} vs ${srcBytes.length} 字节）—— 解码的是**内容里那一张**`);

console.log('');
console.log(bad === 0 ? '图片（站点侧）：全部读数成立' : `图片（站点侧）：${bad} 条不成立`);
server.close();
if (!KEEP) cdp.close();
process.exit(bad === 0 ? 0 : 1);
