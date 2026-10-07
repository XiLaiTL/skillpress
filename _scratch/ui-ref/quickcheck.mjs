#!/usr/bin/env node
// quickcheck.mjs —— 给任意单文件稿做最小体检：① 无横向溢出 ② 无 JS 报错 ③ 打印三块面板的**实际计算色**
// （第 ③ 条才是关键：它证明"我写的值真的生效了"，能抓住 CSS 变量泄漏/优先级写错）。
// 用法：node quickcheck.mjs <file.html> [--dark]
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const file = resolve(here, process.argv[2] || "palette-compare.html");
const dark = process.argv.includes("--dark");
const chrome = [
  process.env.CHROME,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].filter(Boolean).find((p) => existsSync(p));
const PROBE = `
<script>
window.addEventListener('error', e => { window.__e = (window.__e||[]).concat(String(e.message)); });
window.addEventListener('DOMContentLoaded', () => {
  ${dark ? "document.documentElement.dataset.theme='dark';" : ""}
  const cs = (el, p) => el ? getComputedStyle(el)[p] : null;
  const panels = {};
  document.querySelectorAll('.panel').forEach(p => {
    const cls = [...p.classList].find(c => c.startsWith('p-'));
    panels[cls] = {
      bg: cs(p.querySelector('.mmain'), 'backgroundColor'),
      side: cs(p.querySelector('.mside'), 'backgroundColor'),
      nav: cs(p.querySelector('.mnav'), 'backgroundColor'),
      text: cs(p.querySelector('.mmain p'), 'color'),
      brand: cs(p.querySelector('.mtabs b'), 'borderBottomColor'),
      desc: cs(p.querySelector('.mdesc'), 'color'),
    };
  });
  const out = { overlap: document.documentElement.scrollWidth - document.documentElement.clientWidth,
                errors: window.__e || [], panels };
  const pre = document.createElement('pre');
  pre.textContent = 'QC' + JSON.stringify(out) + 'QC';
  document.body.appendChild(pre);
});
</script>`;
const tmp = mkdtempSync(join(tmpdir(), "qc-"));
const patched = join(tmp, "p.html");
writeFileSync(patched, readFileSync(file, "utf8").replace("</body>", PROBE + "</body>"), "utf8");
const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run",
  "--user-data-dir=" + join(tmp, "prof"), "--window-size=1440,900",
  "--virtual-time-budget=3000", "--dump-dom", pathToFileURL(patched).href], { stdio: ["ignore", "pipe", "pipe"] });
let out = "";
child.stdout.on("data", d => (out += d));
child.on("close", () => {
  const m = [...out.matchAll(/QC(\{.*?\})QC/gs)];
  if (!m.length) return console.error("没拿到读数");
  const r = JSON.parse(m[m.length - 1][1]);
  console.log(`横向溢出 ${r.overlap}px ｜ JS 报错 ${r.errors.length} 条${r.errors.length ? "：" + r.errors.join(" | ") : ""}`);
  for (const k of Object.keys(r.panels)) console.log(`  ${k}: ${JSON.stringify(r.panels[k])}`);
});
