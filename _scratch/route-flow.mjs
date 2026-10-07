#!/usr/bin/env node
/**
 * route-flow.mjs —— 路由**流程**验收（真 Chrome）：点一下 hash 跟不跟、**后退**回不回。
 *
 * 与 `route-check.mjs` 的分工：那件量"**带着地址进来**会怎样"（一次性加载就够），
 * 这件量"**在页面里操作**会怎样"（要多步 + 计时）⇒ 只能往页面里注入一段流程脚本。
 *
 * ⚠️ 读数一律取**生效的**：`location.hash` 的真值 + DOM 里真的出现哪一页的 H1；
 *    不许拿"我们调用了 pushState"当证据（那正是本仓反复栽过的"写了 ≠ 生效"）。
 *
 * 用法：node _scratch/route-flow.mjs [--app <实例目录>]
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

const FLOW = `
<script>
(function () {
  var out = { steps: [] }, t = 0;
  var h1 = function () {
    var best = null;
    document.querySelectorAll('div,span').forEach(function (el) {
      if (el.children.length || !el.textContent.trim()) return;
      if (parseFloat(getComputedStyle(el).fontSize) === 30) best = el.textContent.trim();
    });
    return best;
  };
  var step = function (name, fn) { setTimeout(function () {
    try { out.steps.push({ name: name, hash: location.hash, h1: h1() }); } catch (e) { out.steps.push({ name: name, err: String(e) }); }
    fn && fn();
  }, (t += 700)); };
  step('开机', function () {
    // 侧栏里第一条能进文档页的可点格（Pressable 渲出来就是 tabindex=0）
    var cols = document.querySelector('#root').firstElementChild;
    while (cols && cols.children.length === 1) cols = cols.children[0];
    var side = cols && cols.children[1] ? cols.children[1].children[0] : null;
    var cand = null;
    if (side) side.querySelectorAll('[tabindex="0"]').forEach(function (el) {
      var s = (el.textContent || '').trim();
      if (!cand && s.length > 6 && !/^[▸▾·–]/.test(s)) cand = el;
    });
    window.__cand = cand;
  });
  step('点侧栏一条', function () { if (window.__cand) window.__cand.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
  step('点完', function () { history.back(); });
  step('后退后', function () {
    var pre = document.createElement('pre');
    pre.style.display = 'none';
    pre.textContent = 'QC' + JSON.stringify(out) + 'QC';
    document.body.appendChild(pre);
  });
})();
</script>`;

const tmp = mkdtempSync(join(tmpdir(), "route-flow-"));
cpSync(join(app, "dist"), tmp, { recursive: true });
const html = readFileSync(join(tmp, "index.html"), "utf8");
if (!html.includes("</body>")) { console.error("✗ dist/index.html 里没有 </body>"); process.exit(2); }
writeFileSync(join(tmp, "index.html"), html.replace("</body>", FLOW + "</body>"), "utf8");

const { createStaticServer } = await import(pathToFileURL(join(app, "serve-web.mjs")).href);
const server = createStaticServer(tmp);
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const port = server.address().port;

const stdout = await new Promise((done) => {
  const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
    "--window-size=1440,900", "--virtual-time-budget=30000", "--dump-dom",
    `http://127.0.0.1:${port}/index.html#/`], { stdio: ["ignore", "pipe", "pipe"] });
  let out = "";
  child.stdout.on("data", (d) => (out += d));
  child.stderr.on("data", () => {});
  const guard = setTimeout(() => { try { child.kill(); } catch (e) {} }, 120000);
  child.on("close", () => { clearTimeout(guard); done(out); });
});
server.close();

const m = stdout.match(/QC(\{[\s\S]*?\})QC/);
if (!m) { console.error("没拿到流程读数（dump 尾巴）：" + stdout.slice(-200)); process.exit(2); }
const R = JSON.parse(m[1]);
const by = (n) => R.steps.find((s) => s.name === n) || {};
let bad = 0;
const say = (ok, msg) => { console.log((ok ? "  ✓ " : "  ✗ ") + msg); if (!ok) bad++; };

for (const s of R.steps) console.log(`     · ${s.name}：hash=${JSON.stringify(s.hash)} h1=${JSON.stringify(s.h1 || s.err)}`);
const boot = by("开机"), clicked = by("点完"), back = by("后退后");
say(/skillpress/.test(boot.h1 || ""), "开机在首页（H1 是首页源那句）");
say(clicked.hash !== boot.hash, `点一条之后 **hash 变了**：${boot.hash} → ${clicked.hash}`);
say((clicked.h1 || "").length > 6 && clicked.h1 !== boot.h1, `点一条之后**正文换了**：${JSON.stringify(clicked.h1)}`);
say(back.hash === boot.hash && back.h1 === boot.h1, `按**后退**回到上一页：hash=${JSON.stringify(back.hash)} h1=${JSON.stringify(back.h1)}`);
console.log(`\n${bad === 0 ? "流程验收通过" : bad + " 条不过"}`);
process.exit(bad === 0 ? 0 : 1);
