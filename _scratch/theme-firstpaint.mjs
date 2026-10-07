#!/usr/bin/env node
/**
 * theme-firstpaint.mjs —— ③ 的验收（真 Chrome）：**首屏不闪** + **三态语义** + **持久化**。
 *
 * 三条读法（都取"生效的读数"）：
 *   ① 种 `localStorage['sp-theme']='dark'` 再加载 ⇒ **第一帧的底色就是深色**（不是先亮后暗）；
 *   ② 种 `'light'` ⇒ 第一帧白；③ 不种 ⇒ 宿主那格的 `dark` **必须等于** `matchMedia` 的真值（Auto = 跟系统），
 *      且第一帧底色与它一致（说明应用**真的读了**那格，不是自己猜的）；
 *   ④ 点一下主题开关 ⇒ `localStorage['sp-theme']` **真的变了**（持久化那条通道）。
 *
 * ⚠️ "第一帧"怎么算：探针脚本注在 `</body>` 之后 ⇒ 它跑的时刻 bundle 已经同步挂载完、
 *    还**没有任何定时器/tick**跑过 ⇒ 此刻读到的底色就是首帧那一套（后来才变会被下一条抓到）。
 * ⚠️ 种子脚本必须注在**宿主那段主题脚本之前**（同一份 HTML 的 head 顶部），否则它读不到种子。
 *
 * 用法：node _scratch/theme-firstpaint.mjs [--app <实例目录>]
 */
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync, cpSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
function argOf(n, d) { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
const app = resolve(here, "..", argOf("--app", "skills/skillpress/scripts/.skillpress"));
const chrome = [process.env.CHROME,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].filter(Boolean).find((p) => existsSync(p));
if (!chrome) { console.error("找不到 Chrome"); process.exit(2); }

const { createStaticServer } = await import(pathToFileURL(join(app, "serve-web.mjs")).href);
const server = createStaticServer(join(app, "dist"));
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const port = server.address().port;

const PROBE = `
<script>
(function () {
  var out = { hint: globalThis.__skillpress_theme || null, mm: !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches),
    stored: (function () { try { return localStorage.getItem('sp-theme'); } catch (e) { return null; } })(),
    canvas: null, shellBg: null, baked: null };
  // 壳 = 从 #root 单子下降到的那个 div（它有背景色 = 主题的 canvas）
  var el = document.getElementById('root');
  while (el && el.children.length === 1) el = el.children[0];
  out.shellBg = el ? getComputedStyle(el).backgroundColor : null;
  out.canvas = getComputedStyle(document.documentElement).getPropertyValue('--canvas').trim() || null;
  // 点一下主题开关（顶栏里那个 ◐，Pressable 渲成 tabindex=0）
  var head = el ? el.children[0] : null, btns = [];
  if (head) head.querySelectorAll('[tabindex="0"]').forEach(function (b) { btns.push(b); });
  // 「主题」是最后那一格（站名与 nav 在左，开关在右）
  var t = btns.length ? btns[btns.length - 1] : null;
  if (t) t.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  setTimeout(function () {
    out.storedAfterClick = (function () { try { return localStorage.getItem('sp-theme'); } catch (e) { return null; } })();
    var pre = document.createElement('pre'); pre.style.display = 'none';
    pre.textContent = 'QC' + JSON.stringify(out) + 'QC';
    document.body.appendChild(pre);
  }, 400);
})();
</script>`;

async function shot(seed) {
  const tmp = mkdtempSync(join(tmpdir(), "fp-"));
  cpSync(join(app, "dist"), tmp, { recursive: true });
  let html = readFileSync(join(tmp, "index.html"), "utf8");
  if (seed) html = html.replace(/<head([^>]*)>/, `<head$1><script>try{localStorage.setItem('sp-theme','${seed}')}catch(e){}</script>`);
  writeFileSync(join(tmp, "index.html"), html.replace("</body>", PROBE + "</body>"), "utf8");
  const srv = createStaticServer(tmp);
  await new Promise((r) => srv.listen(0, "127.0.0.1", r));
  const p = srv.address().port;
  const out = await new Promise((done) => {
    const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
      "--window-size=1440,900", "--virtual-time-budget=20000", "--dump-dom",
      `http://127.0.0.1:${p}/index.html#/`], { stdio: ["ignore", "pipe", "pipe"] });
    let o = "";
    child.stdout.on("data", (d) => (o += d));
    child.stderr.on("data", () => {});
    const g = setTimeout(() => { try { child.kill(); } catch (e) {} }, 90000);
    child.on("close", () => { clearTimeout(g); done(o); });
  });
  srv.close();
  const m = out.match(/QC(\{[\s\S]*?\})QC/);
  return m ? JSON.parse(m[1]) : { fail: "没读到探针（dump 尾巴：" + out.slice(-160) + "）" };
}

const DARK = "rgb(24, 24, 27)", LIGHT = "rgb(255, 255, 255)";
let bad = 0;
const say = (ok, msg) => { console.log((ok ? "  ✓ " : "  ✗ ") + msg); if (!ok) bad++; };

const a = await shot("dark");
console.log(`     种 dark：hint=${JSON.stringify(a.hint)} 首帧壳底=${a.shellBg}`);
say(a.hint && a.hint.pref === "dark" && a.hint.dark === true, "宿主那格记下了 dark 偏好");
say(a.shellBg === DARK, `**首帧就是深色**（壳底 ${a.shellBg}，要 ${DARK}）—— 不是先亮后暗`);

const b = await shot("light");
say(b.shellBg === LIGHT, `种 light ⇒ 首帧白（实测 ${b.shellBg}）`);

const c = await shot(null);
console.log(`     不种：hint=${JSON.stringify(c.hint)} matchMedia=${c.mm}`);
say(c.hint && c.hint.pref === "auto", "没种偏好时按 auto 起");
say(c.hint && c.hint.dark === c.mm, `**Auto = 跟系统**：宿主那格的 dark(${c.hint && c.hint.dark}) 与 matchMedia(${c.mm}) 一致`);
say(c.shellBg === (c.mm ? DARK : LIGHT), `首帧底色与"该用哪套"一致（${c.shellBg}）—— 说明应用真的读了那格`);

say(a.storedAfterClick !== undefined && a.storedAfterClick !== a.stored,
  `点一下主题开关 ⇒ 偏好**写回宿主**：${JSON.stringify(a.stored)} → ${JSON.stringify(a.storedAfterClick)}`);

console.log(`\n${bad === 0 ? "③ 的首屏/三态/持久化验收通过" : bad + " 条不过"}`);
process.exit(bad === 0 ? 0 : 1);
