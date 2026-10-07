#!/usr/bin/env node
/**
 * route-check.mjs —— **路由的行为验收**（真 Chrome，两条最硬的）：
 *   ① 深链直达：`#/s/<slug>/<kid>/` 一进去就是那一页（**不是先首页再跳**）
 *   ② 认不出的地址：`#/nope` **渲染 404**
 *
 * 为什么单独一件（不进 `tools/ui-probe.mjs`）：探针量的是**版面与文档页骨架**（它是"点进去"的），
 * 而路由要量的是"**带着地址进来**会怎样" —— 两件事的入口不同（一个从首页点、一个直接给 URL）。
 *
 * ⚠️ 页面是**异步**渲的 ⇒ 必须等（`--virtual-time-budget`），抓早了是一具空壳（`dom-dump.mjs` 记过这条）。
 * ⚠️ 判据只看**生效的读数**：DOM 里真的出现了那一页的中文 H1 / "没找到"那句，而不是"路由函数返回了什么"。
 *
 * 用法：node _scratch/route-check.mjs [--app <实例目录>]
 */
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
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

function dump(hash) {
  return new Promise((done) => {
    const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
      `--window-size=1440,900`, "--virtual-time-budget=20000", "--dump-dom",
      `http://127.0.0.1:${port}/index.html${hash}`], { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", () => {});
    const guard = setTimeout(() => { try { child.kill(); } catch (e) {} }, 90000);
    child.on("close", () => { clearTimeout(guard); done(out); });
  });
}
const text = (html) => html.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ");

let bad = 0;
const say = (ok, msg) => { console.log((ok ? "  ✓ " : "  ✗ ") + msg); if (!ok) bad++; };

// ① 深链直达：子页（`#/s/<slug>/<kid>/`）
const DEEP = "#/s/moobile-app-development/styles/";
const deepDom = await dump(DEEP);
const deepText = text(deepDom);
say(/样式/.test(deepText) && /SKILL|references/.test(deepText), `深链 ${DEEP} ⇒ 直接就是那一页（页面上出现「样式」与源文件路径）`);
say(!/把 skills? 目录印成|站点的形状|书架上有什么/.test(deepText) || /样式/.test(deepText),
  '深链不是「先渲染首页再跳」（首页那几句没作为最终态留在页面上）');

// ② 认不出的地址 ⇒ 404
const badDom = await dump("#/nope/nope/");
const badText = text(badDom);
say(/没找到|404/.test(badText), "`#/nope/nope/` ⇒ 渲染的是「没找到这一页」（404 有到达路径）");

// ③ 首页（`#/`）仍是首页
const homeText = text(await dump("#/"));
say(/skillpress/.test(homeText) && !/没找到这一页/.test(homeText), "`#/` ⇒ 首页（不是 404）");

server.close();
console.log(`\n${bad === 0 ? "两条行为验收通过" : bad + " 条不过"}`);
process.exit(bad === 0 ? 0 : 1);
