#!/usr/bin/env node
/**
 * demo-shot.mjs —— 给 demo 出图（诊断/给人看用，不参与体检结论）。
 *
 * 两种图：
 *   ① 三档版面：把 demo 装进**指定宽度的 iframe** 再截图 —— 窗口宽度不可信
 *      （Chrome headless 的窗口最小 ~512px，请求 420 实际是 512），iframe 才是真视口。
 *   ② 侧栏放大：只把侧栏拉宽、其余两栏收掉，2x 设备像素比拍 —— 270px 宽的侧栏在整页图里看不清。
 *      样式一行不改，只注入观测用的定位样式。
 *
 * 用法：
 *   node demo-shot.mjs                       # 出全部图到 .audit/
 *   node demo-shot.mjs --only rung           # 只出三档版面
 *   node demo-shot.mjs --only side           # 只出侧栏放大
 */
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
function argOf(n, d) { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
const file = resolve(here, argOf("--file", "demo.html"));
const only = argOf("--only", "all");
const ROUTE = "#/s/moobile-app-development/styles/";
const OUT = resolve(here, ".audit");
mkdirSync(OUT, { recursive: true });

const chrome = [process.env.CHROME,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].filter(Boolean).find((p) => existsSync(p));
if (!chrome) { console.error("找不到 Chrome"); process.exit(2); }

const tmp = mkdtempSync(join(tmpdir(), "demo-shot-"));
const src = readFileSync(file, "utf8");
/* ⚠️ 不能直接改 <html data-theme>：开头的防闪脚本会拿 localStorage 里的偏好把它覆盖回去。
   要"钉住"主题，就得从 demo 自己的机制下手 —— 在它前面塞一句写入偏好。 */
const pinTheme = (html, pref) => html.replace("<head>",
  `<head><script>try{localStorage.setItem('sp-theme',${JSON.stringify(pref)})}catch(e){}</script>`);

function shot(url, { w, h, out, zoom = 1, theme }) {
  const outPath = join(OUT, out);
  return new Promise((done) => {
    const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
      `--force-device-scale-factor=${zoom}`, `--window-size=${w},${h}`, "--virtual-time-budget=5000",
      `--screenshot=${outPath}`, url], { stdio: ["ignore", "pipe", "pipe"] });
    child.stderr.on("data", () => {});
    child.on("close", (c) => done({ out, ok: c === 0, outPath }));
  });
}

/* ① 三档版面：父页里放一个真宽度的 iframe */
const RUNGS = [[1440, "rung3-1440"], [1100, "rung2-1100"], [1024, "rung2-1024"], [768, "rung1-768"], [420, "rung1-420"]];
async function rungShots() {
  const res = [];
  for (const [w, name] of RUNGS) {
    const child = join(tmp, `c-${w}.html`);
    writeFileSync(child, pinTheme(src, "light"), "utf8");
    const parent = join(tmp, `p-${w}.html`);
    writeFileSync(parent, `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#8a8a93">
      <iframe src="${pathToFileURL(child).href}${ROUTE}" style="width:${w}px;height:900px;border:0;display:block;background:#fff"></iframe>`,
      "utf8");
    res.push(await shot(pathToFileURL(parent).href, { w: w + 24, h: 900, out: `${name}.png`, zoom: 1 }));
  }
  return res;
}

/* ② 侧栏放大：窗口开小（只截左上那块），里面塞一个**真宽度**的 iframe ——
   阶梯由 iframe 的宽度决定，裁切由窗口决定，两者互不干扰
   （⚠️ 直接把窗口开到 340 是不行的：Chrome 窗口最小 ~512px，而且 <1024 时侧栏本来就 display:none） */
async function sideShots() {
  const res = [];
  for (const [winW, sideW, name, dark] of [
    [1440, 340, "side-rail3-light", false], [1440, 340, "side-rail3-dark", true],
    [1100, 340, "side-rail2-with-toc-light", false], [1100, 340, "side-rail2-with-toc-dark", true],
  ]) {
    let html = pinTheme(src, dark ? "dark" : "light");
    html = html.replace("</head>", `<style id="zoom">
      .layout{grid-template-columns:${sideW}px 0 0!important}
      .toc{display:none!important}
      .sidebar{width:${sideW}px!important}
      </style></head>`);
    const c = join(tmp, `s-${name}.html`);
    writeFileSync(c, html, "utf8");
    const parent = join(tmp, `sp-${name}.html`);
    writeFileSync(parent, `<!doctype html><meta charset="utf-8"><body style="margin:0;overflow:hidden">
      <iframe src="${pathToFileURL(c).href}${ROUTE}" style="width:${winW}px;height:760px;border:0;display:block"></iframe>`, "utf8");
    res.push(await shot(pathToFileURL(parent).href, { w: 700, h: 760, out: `${name}.png`, zoom: 2 }));
  }
  return res;
}

const list = [];
if (only === "all" || only === "rung") list.push(...(await rungShots()));
if (only === "all" || only === "side") list.push(...(await sideShots()));
for (const r of list) console.log(`${r.ok ? "✓" : "✗"} ${r.outPath}`);
