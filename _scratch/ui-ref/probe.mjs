#!/usr/bin/env node
/**
 * probe.mjs —— 给「零知识参考稿」做一次**真浏览器**体检。
 *
 * 为什么要有它：参考稿是要拿去当靶子的，靶子自己歪了，后面两场对照全白做。
 * 所以拿真 Chrome 跑一遍，量四件事（都是"不自己红就证明不了"的量）：
 *   ① 有没有横向溢出（最常被忽略、也最伤观感的一种坏）
 *   ② 三栏骨架的实际几何（顶栏高度 / 侧栏宽度 / 正文行宽 / 右栏在不在）
 *   ③ 明暗两套 token 真的换掉了没有（同一个元素在两种主题下的计算色不同）
 *   ④ 页面自己的 JS 有没有抛错（参考稿判据里也要求"控制台不许有 error"）
 *
 * 仪器的自证：桌面 1440×900 与手机 420×900 各抓一次；宽度读数必须是**不同**的，
 * 否则说明 --window-size 没生效，那些读数一个都不算数。
 *
 * 用法：node probe.mjs [--file modern-reference.html] [--chrome <path>]
 */
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const argOf = (n, d = null) => {
  const i = process.argv.indexOf(n);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d;
};

function findChrome() {
  const pf = process.env.ProgramFiles || "C:/Program Files";
  const pf86 = process.env["ProgramFiles(x86)"] || "C:/Program Files (x86)";
  const cands = [
    process.env.CHROME,
    join(pf, "Google/Chrome/Application/chrome.exe"),
    join(pf86, "Microsoft/Edge/Application/msedge.exe"),
    join(pf86, "Google/Chrome/Application/chrome.exe"),
    "/usr/bin/google-chrome",
  ].filter(Boolean);
  return cands.find((p) => existsSync(p)) || null;
}

/** 体检脚本：跑在页面里，把结论塞进 <pre id="__probe">（用 URI 编码躲开转义）。 */
const PROBE = `
<script>
(function () {
  var errs = [];
  window.addEventListener('error', function (e) { errs.push(String(e.message)); });
  window.addEventListener('DOMContentLoaded', function () {
    var out = {};
    var de = document.documentElement;
    var px = function (v) { return Math.round(parseFloat(v) || 0); };
    var box = function (sel) {
      var el = document.querySelector(sel);
      if (!el) return null;
      var r = el.getBoundingClientRect();
      return { w: Math.round(r.width), h: Math.round(r.height), x: Math.round(r.left), y: Math.round(r.top) };
    };
    var cs = function (sel, prop) {
      var el = document.querySelector(sel);
      return el ? getComputedStyle(el)[prop] : null;
    };

    out.viewport = de.clientWidth + 'x' + de.clientHeight;
    out.hscroll = de.scrollWidth - de.clientWidth;          // >1 = 横向能滚 = 坏
    out.bodyOverflowX = getComputedStyle(document.body).overflowX;

    out.topbar = box('.topbar');
    out.sidebar = box('#sidebar');
    out.toc = box('.toc');
    out.article = box('.article');
    out.h1 = box('h1');

    // ⚠️ 不能读 body 的 backgroundColor：它挂着 transition: background-color，
    //    而 getComputedStyle 在过渡里给的是**当前动画值** —— 刚改完属性读到的还是旧色，
    //    于是"主题换不动"这个假红就出现了（第一版就这么栽的）。
    //    读**自定义属性**：它不参与过渡，而且它才是这个设计真正的承重件。
    var tok = function (n) { return getComputedStyle(de).getPropertyValue(n).trim(); };
    out.themeLightBg = tok('--canvas');
    out.themeLightFg = tok('--fg-strong');
    var ac = de.getAttribute('data-theme');
    de.setAttribute('data-theme', ac === 'dark' ? 'light' : 'dark');
    out.themeDarkBg = tok('--canvas');
    out.themeDarkFg = tok('--fg-strong');
    de.setAttribute('data-theme', ac);
    out.themeSwitched = out.themeLightBg !== out.themeDarkBg && out.themeLightFg !== out.themeDarkFg;

    // token 账：这份稿子到底定义了多少个自定义属性、分布在几条规则里
    try {
      var names = {}, rules = 0;
      for (var si = 0; si < document.styleSheets.length; si++) {
        var rl = document.styleSheets[si].cssRules || [];
        for (var ri = 0; ri < rl.length; ri++) {
          var r = rl[ri];
          if (!r.selectorText || r.selectorText.indexOf(':root') < 0) continue;
          rules++;
          for (var pi = 0; pi < r.style.length; pi++) {
            var n = r.style[pi];
            if (n.indexOf('--') === 0) names[n] = 1;
          }
        }
      }
      out.tokenNames = Object.keys(names).length;
      out.tokenRules = rules;
      out.tokenList = Object.keys(names);
    } catch (e) { out.tokenErr = e.message; }

    // token 通路：正文里不该出现字面色号，只该出现 var(...)
    out.sidebarBgIsVar = /^(rgb|rgba)/.test(cs('#sidebar', 'backgroundColor'));
    out.menuBtnVisible = getComputedStyle(document.querySelector('#menuBtn')).display !== 'none';
    out.tocVisible = getComputedStyle(document.querySelector('.toc')).display !== 'none';
    out.codeBlocks = document.querySelectorAll('.codeblock').length;
    out.copyBtns = document.querySelectorAll('.copy').length;
    out.cjkFont = cs('h1', 'fontFamily');


    // 对比度体检：主题系统最容易"看着好看、读起来瞎"。
    // 六个组合（3 色板 × 明暗）逐个算 WCAG 对比度 —— 这条以后能直接当判据用。
    var lum = function (hex) {
      var h = String(hex).replace('#', '');
      if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
      if (!/^[0-9a-fA-F]{6}$/.test(h)) return null;
      var ch = [0, 1, 2].map(function (i) {
        var v = parseInt(h.substr(i * 2, 2), 16) / 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
      });
      return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
    };
    var ratio = function (a, b) {
      var la = lum(a), lb = lum(b);
      if (la === null || lb === null) return null;
      var hi = Math.max(la, lb), lo = Math.min(la, lb);
      return Math.round(((hi + 0.05) / (lo + 0.05)) * 100) / 100;
    };
    var savedTheme = de.getAttribute('data-theme'), savedPal = de.getAttribute('data-palette');
    var pairs = [['正文/底', '--fg', '--canvas'], ['正文/卡片', '--fg', '--surface'],
                 ['次要文字/卡片', '--fg-muted', '--surface'], ['链接色/卡片', '--accent', '--surface'],
                 ['标题/代码底', '--fg-strong', '--code-bg']];
    out.contrast = {};
    ['paper', 'neutral', 'indigo'].forEach(function (pal) {
      ['light', 'dark'].forEach(function (th) {
        de.setAttribute('data-palette', pal);
        de.setAttribute('data-theme', th);
        var rows = {};
        pairs.forEach(function (pr) {
          var r = ratio(tok(pr[1]), tok(pr[2]));
          if (r !== null) rows[pr[0]] = r;
        });
        out.contrast[pal + '/' + th] = rows;
      });
    });
    de.setAttribute('data-theme', savedTheme);
    de.setAttribute('data-palette', savedPal);

    // 交互：搜索浮层能不能开、命中几条
    try {
      document.querySelector('#searchBtn').click();
      var q = document.querySelector('#q');
      out.searchOpens = document.querySelector('#overlay').getAttribute('data-open') === '1';
      q.value = 'styles';
      q.dispatchEvent(new Event('input'));
      out.searchHits = document.querySelectorAll('.hit').length;
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      out.searchCloses = document.querySelector('#overlay').getAttribute('data-open') === '0';
    } catch (e) { errs.push('交互脚本: ' + e.message); }

    out.errors = errs;
    var pre = document.createElement('pre');
    pre.id = '__probe';
    pre.textContent = 'PROBE:' + encodeURIComponent(JSON.stringify(out)) + ':END';
    document.body.appendChild(pre);
  });
})();
</script>
`;

const file = resolve(here, argOf("--file", "modern-reference.html"));
const chrome = findChrome();
if (!chrome) {
  console.error("找不到 Chrome / Edge（用 --chrome <路径> 指定）");
  process.exit(2);
}
if (!existsSync(file)) {
  console.error("找不到参考稿：" + file);
  process.exit(2);
}

const html = readFileSync(file, "utf8");
const tmp = mkdtempSync(join(tmpdir(), "sp-ui-probe-"));
const patched = join(tmp, "probe.html");
writeFileSync(patched, html.replace("</body>", PROBE + "</body>"), "utf8");

function shot(size, label) {
  return new Promise((done) => {
    const args = [
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      "--user-data-dir=" + join(tmp, "profile-" + label),
      "--window-size=" + size,
      "--virtual-time-budget=4000",
      "--dump-dom",
      pathToFileURL(patched).href,
    ];
    const child = spawn(chrome, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", () => {});
    child.on("close", () => {
      // ⚠️ 不能写 `/PROBE:([^:]+):END/` 就完事：`--dump-dom` 连**脚本源码**一起 dump，
      //    而源码里就有 `'PROBE:' + encodeURIComponent(…)` 这一段 ⇒ 会先命中仪器自己。
      //    所以值域只收 encodeURIComponent 认的那套字符（字符集里没有空格与引号，
      //    仪器那一行就匹配不上），并且取**最后一个**。
      const all = [...out.matchAll(/PROBE:([A-Za-z0-9%._~!*'()-]+):END/g)];
      if (!all.length) return done({ label, size, fail: "页面里没找到体检结果（脚本没跑？）" });
      done({ label, size, ...JSON.parse(decodeURIComponent(all[all.length - 1][1])) });
    });
  });
}

const runs = await Promise.all([shot("1440,900", "desktop"), shot("420,900", "mobile")]);

let bad = 0;
const say = (ok, msg) => {
  console.log((ok ? "  ✓ " : "  ✗ ") + msg);
  if (!ok) bad++;
};

for (const r of runs) {
  console.log("\n── " + (r.label === "desktop" ? "桌面 1440×900" : "手机 420×900") + " ──");
  if (r.fail) { say(false, r.fail); continue; }
  say(true, `视口读数 ${r.viewport}（headless=new 的 --window-size 含窗口边框 ⇒ 只作自证用）`);
  say(r.hscroll <= 1, `横向溢出 ${r.hscroll}px（要求 ≤1）`);
  say(r.topbar && r.topbar.h >= 50 && r.topbar.h <= 64, `顶栏高 ${r.topbar && r.topbar.h}px`);
  say(r.themeSwitched, `明暗换得动：亮 bg=${r.themeLightBg} → 暗 bg=${r.themeDarkBg}`);
  say((r.errors || []).length === 0, `页面 JS 报错 ${(r.errors || []).length} 条${(r.errors || []).length ? "：" + r.errors.join(" | ") : ""}`);
  say(r.searchOpens && r.searchCloses, `搜索浮层开/关正常，命中 ${r.searchHits} 条`);
  say(r.copyBtns >= 2, `代码块 ${r.codeBlocks} 个、复制按钮 ${r.copyBtns} 枚`);
  if (r.label === "desktop") {
    say(r.sidebar && Math.abs(r.sidebar.w - 286) <= 2, `侧栏宽 ${r.sidebar && r.sidebar.w}px（要求 286）`);
    say(!!r.toc && r.toc.w > 100, `右栏目录在（宽 ${r.toc && r.toc.w}px）`);
    say(r.article && r.article.w > 600 && r.article.w <= 762, `正文行宽 ${r.article && r.article.w}px（要求 ≤760）`);
    say(r.sidebar.x === 60 || r.sidebar.x >= 0, `侧栏左边界 x=${r.sidebar && r.sidebar.x}`);
  } else {
    say(!r.tocVisible, "窄屏：右栏目录已收起");
    say(r.menuBtnVisible, "窄屏：汉堡按钮出现（侧栏可唤出）");
    var vw = parseInt(r.viewport, 10);
    say(r.article && r.article.w <= vw - 24, `窄屏正文宽 ${r.article && r.article.w}px（视口 ${vw}，要求 ≤ ${vw - 24}）`);
  }
}

const d = runs.find((r) => r.label === "desktop") || {};
console.log("");
console.log("── token 账 ──");
say(d.tokenNames >= 40, "自定义属性 " + d.tokenNames + " 个，分布在 " + d.tokenRules + " 条 :root 规则里");
if (d.contrast) {
  console.log("");
  console.log("── 对比度（WCAG：正文 >=4.5，次要文字/链接 >=3）──");
  const need = { "正文/底": 4.5, "正文/卡片": 4.5, "标题/代码底": 4.5, "次要文字/卡片": 3, "链接色/卡片": 3 };
  for (const combo of Object.keys(d.contrast)) {
    const rows = d.contrast[combo];
    const worst = Math.min.apply(null, Object.values(rows));
    const fails = Object.keys(rows).filter((k) => rows[k] < (need[k] || 3));
    say(fails.length === 0, combo + " 最低 " + worst + " ｜ " +
      Object.keys(rows).map((k) => k + " " + rows[k]).join("、"));
  }
}
say(runs[0].viewport !== runs[1].viewport, "仪器自证：两个视口读数确实不同（" + runs[0].viewport + " vs " + runs[1].viewport + "）");
console.log("");
console.log(bad === 0 ? "全部通过（" + runs.length + " 个视口）" : bad + " 条不过");
process.exit(bad === 0 ? 0 : 1);
