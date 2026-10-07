#!/usr/bin/env node
/**
 * sidebar-audit.mjs —— 量**侧栏**与**断点阶梯**（真 Chrome，逐视口）。
 *
 * 为什么要它：`demo-probe.mjs` 量的是"行为对不对"（路由/搜索/主题/窄屏两级交互），
 * 它**从来没有量过侧栏自己**——于是"侧栏看着不好看"这种话没有判据，只能靠嘴。
 * 这份仪器把"不好看"拆成可量的几条：文字在什么底上、对比度多少、层级符号多大、
 * 子级标题和父级标题差几像素、hover 反馈有多弱、侧栏里出现了几个机器名、
 * 以及"宽度不够时目录去哪了"。
 *
 * 用法：node sidebar-audit.mjs [--file demo.html] [--sizes "1440,900;1100,900;420,900"]
 *      [--hash "#/s/moobile-app-development/styles/"] [--json]
 */
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
function argOf(n, d) { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
const file = resolve(here, argOf("--file", "demo.html"));
const hash = argOf("--hash", "#/s/moobile-app-development/styles/");
const sizes = argOf("--sizes", "1440,900;1100,900;420,900").split(";").map((s) => s.trim()).filter(Boolean);
const asJson = process.argv.includes("--json");

const chrome = [process.env.CHROME,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].filter(Boolean).find((p) => existsSync(p));
if (!chrome) { console.error("找不到 Chrome"); process.exit(2); }

const PROBE = `
<script>
(function () {
  var out = { vw: innerWidth, vh: innerHeight }, errs = [], fatal = null;
  window.addEventListener('error', function (e) { errs.push(String(e.message)); });
  function q1(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function cs(el, p, pe) { return el ? getComputedStyle(el, pe)[p] : null; }
  function tok(n) { return getComputedStyle(document.documentElement).getPropertyValue(n).trim(); }
  function num(v) { var f = parseFloat(v); return isNaN(f) ? null : Math.round(f * 100) / 100; }
  function rgba(s) {
    s = String(s).trim();
    var h = s.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
    if (h) { var v = h[1]; if (v.length === 3) v = v[0]+v[0]+v[1]+v[1]+v[2]+v[2];
      return { r: parseInt(v.slice(0,2),16), g: parseInt(v.slice(2,4),16), b: parseInt(v.slice(4,6),16), a: 1 }; }
    var m = String(s).match(/rgba?\\(([^)]+)\\)/); if (!m) return null;
    var p = m[1].split(',').map(function (x) { return parseFloat(x); });
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  }
  function over(fg, bg) {           // 半透明叠在实底上 ⇒ 真实生效色
    var f = rgba(fg), b = rgba(bg); if (!f || !b) return null;
    var a = f.a + b.a * (1 - f.a);
    return 'rgb(' + [0,1,2].map(function (i) {
      var k = [f.r, f.g, f.b][i], j = [b.r, b.g, b.b][i];
      return Math.round((k * f.a + j * b.a * (1 - f.a)) / (a || 1));
    }).join(', ') + ')';
  }
  function lum(c) {
    var o = rgba(c); if (!o) return null;
    var ch = [o.r, o.g, o.b].map(function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
  }
  function ratio(a, b, bg) {
    var A = bg ? over(a, bg) : a, B = bg ? over(b, bg) : b;
    var la = lum(A), lb = lum(B); if (la === null || lb === null) return null;
    var hi = Math.max(la, lb), lo = Math.min(la, lb);
    return Math.round(((hi + 0.05) / (lo + 0.05)) * 100) / 100;
  }

  try {
    var sb = q1('.sidebar'), main = q1('#main'), art = q1('#article');
    var sideBox = sb.getBoundingClientRect();
    var sideBg = cs(sb, 'backgroundColor');

    /* ── 结构：侧栏吐出来的 DOM 到底命中了哪几条 CSS ── */
    var a0 = q1('a', sb), cur = q1('a[aria-current="page"]', sb);
    out.dom = {
      treeWrappers: qa('.sidebar .tree').length,      // 0 ⇒ 整块 .tree 规则全废
      directLi: qa('.sidebar > li').length,
      ulsInSidebar: qa('.sidebar ul').length,
      anchor: a0 ? { color: cs(a0, 'color'), fs: num(cs(a0, 'fontSize')), display: cs(a0, 'display'),
        padTop: num(cs(a0, 'paddingTop')), padLeft: num(cs(a0, 'paddingLeft')), bg: cs(a0, 'backgroundColor'),
        radius: cs(a0, 'borderRadius') } : null,
      currentRowStyled: cur ? { bg: cs(cur, 'backgroundColor'), color: cs(cur, 'color'),
        bar: cs(cur, 'backgroundColor', '::before'), fontWeight: cs(cur, 'fontWeight') } : null,
    };

    out.layout = {
      cols: cs(q1('.layout'), 'gridTemplateColumns'),
      rail: document.documentElement.dataset.rail || null,
      sidebar: { display: cs(sb, 'display'), width: Math.round(sideBox.width), bg: sideBg, padTop: num(cs(sb, 'paddingTop')) },
      tocRail: { display: cs(q1('.toc'), 'display'), width: Math.round(q1('.toc').getBoundingClientRect().width) },
      tocInSidebar: !!q1('#side-toc[data-in="side"]'),
      tocLinksRail: qa('#toc a[data-sec]').length,
      tocLinksSide: qa('#side-toc a[data-sec]').length,
      fabs: cs(q1('.fabs'), 'display'),
      main: { width: Math.round(main.getBoundingClientRect().width), padL: num(cs(main, 'paddingLeft')) },
    };

    /* ── 行长（A2：38–46 个中文字） ── */
    var p = q1('#body p') || q1('#article p');
    var pW = p ? Math.round(p.getBoundingClientRect().width) : null;
    out.line = p ? { width: pW, fs: num(cs(p, 'fontSize')), lh: num(cs(p, 'lineHeight')),
      chars: pW ? Math.round((pW / parseFloat(cs(p, 'fontSize'))) * 10) / 10 : null,
      inRange: pW ? (pW / parseFloat(cs(p, 'fontSize')) >= 38 && pW / parseFloat(cs(p, 'fontSize')) <= 47) : null } : null;

    /* ── 侧栏里的文字：在什么底上、对比度多少 ── */
    var grp = q1('.sidebar .grp');
    var nm = q1('.sidebar .tree .slnk');
    var mono = qa('.sidebar *').filter(function (e) { return /mono|Consolas|Menlo/i.test(cs(e, 'fontFamily')); });
    out.sidebarText = {
      grp: grp ? { fs: num(cs(grp, 'fontSize')), ls: num(cs(grp, 'letterSpacing')), tt: cs(grp, 'textTransform'),
        color: cs(grp, 'color'), onSideBg: ratio(cs(grp, 'color'), sideBg) } : null,
      nm: nm ? { fs: num(cs(nm, 'fontSize')), color: cs(nm, 'color'), onSideBg: ratio(cs(nm, 'color'), sideBg) } : null,
      monoInSidebar: mono.map(function (e) { return (e.className || e.tagName) + '=' + String(e.textContent).trim().slice(0, 24); }),
      fg3OnSideBg: ratio(tok('--fg-3'), sideBg), fg3Raw: tok('--fg-3'), sideBgRaw: sideBg,
      footLink: q1('.sidebar .sb-foot a') ? ratio(cs(q1('.sidebar .sb-foot a'), 'color'), sideBg) : null,
    };

    /* ── 行几何：父子标题对不对齐、层级符号多大、有没有左条 ── */
    var rows = qa('.sidebar .tree .slnk').slice(0, 12).map(function (a) {
      var t = a, slot = q1('.schev', a.closest('.srow'));
      var r = a.getBoundingClientRect(), tr = t ? t.getBoundingClientRect() : null;
      var sb0 = !!a.closest('.ssub');
      return {
        lv: sb0 ? 2 : 1,
        title: t ? t.textContent.trim() : null,
        x: tr ? Math.round(tr.left - sideBox.left) : null,      // 标题文字相对侧栏左缘
        h: Math.round(r.height),
        fs: t ? num(cs(t, 'fontSize')) : null,
        lh: t ? num(cs(t, 'lineHeight')) : null,
        padTop: num(cs(a, 'paddingTop')), padL: num(cs(a, 'paddingLeft')),
        visible: a.getBoundingClientRect().height > 0,
        chevCenterX: slot ? Math.round(slot.getBoundingClientRect().left - sideBox.left + slot.getBoundingClientRect().width / 2) : null,
        clip: cs(a, 'textOverflow') + '/' + cs(a, 'whiteSpace'),
        current: (a.closest('.srow') || {}).dataset ? a.closest('.srow').dataset.current === '1' : false,
        barColor: cs(a.closest('.srow'), 'backgroundColor', '::before'),
        rowBg: cs(a.closest('.srow'), 'backgroundColor'),
        rowBgReal: over(cs(a.closest('.srow'), 'backgroundColor'), sideBg),
        bg: cs(a, 'backgroundColor'),
        color: cs(a, 'color'),
      };
    });
    var lv1 = rows.filter(function (r) { return r.lv === 1 && r.title; })[0];
    var lv2 = rows.filter(function (r) { return r.lv === 2 && r.title; })[0];
    out.rows = rows;
    out.align = {
      parentTitleX: lv1 ? lv1.x : null, kidTitleX: lv2 ? lv2.x : null,
      delta: (lv1 && lv2) ? lv2.x - lv1.x : null,
      guideLine: q1('.sidebar .ssub') ? { left: num(cs(q1('.sidebar .ssub'), 'left', '::before')),
        width: num(cs(q1('.sidebar .ssub'), 'width', '::before')),
        color: cs(q1('.sidebar .ssub'), 'backgroundColor', '::before') } : null,
      rowHeights: rows.map(function (r) { return r.h; }),
    };

    /* ── 状态通道：hover 有多弱、当前项靠什么认出来 ── */
    var st = { hover: tok('--state-hover'), side: tok('--state-hover-side'), soft: tok('--brand-soft') };
    var hoverOnSide = over(st.side, sideBg);
    out.states = {
      hoverToken: st.hover, sideHoverToken: st.side, hoverCompositeOnSide: hoverOnSide,
      hoverRatioVsSide: ratio(hoverOnSide, sideBg),
      hoverRatioVsCanvas: ratio(over(st.hover, tok('--canvas')), tok('--canvas')),
      currentRow: rows.filter(function (r) { return r.current; }).map(function (r) {
        return { title: r.title, rowBg: r.rowBgReal, color: r.color, bar: r.barColor,
          textOnRow: ratio(r.color, r.rowBgReal) }; }),
    };

    /* ── 侧栏里到底有多少种字号/颜色（"乱"的可量代理） ── */
    var fss = {}, cols = {};
    qa('.sidebar *').forEach(function (e) {
      if (!e.textContent || !e.textContent.trim()) return;
      if (!qa('*', e).length) { fss[cs(e, 'fontSize')] = (fss[cs(e, 'fontSize')] || 0) + 1; cols[cs(e, 'color')] = (cols[cs(e, 'color')] || 0) + 1; }
    });
    out.noise = { distinctFontSizes: Object.keys(fss).sort(), distinctColors: Object.keys(cols).sort(),
      textNodes: Object.values(fss).reduce(function (a, b) { return a + b; }, 0),
      sidebarScrollH: sb.scrollHeight, sidebarClientH: sb.clientHeight };

    /* ── 侧栏里有没有非 token 的 px（对着 §3.3 的 7 档间距） ── */
    out.offScale = [];
    qa('.sidebar *, .sidebar').forEach(function (e) {
      [['paddingTop','padT'],['paddingBottom','padB'],['paddingLeft','padL'],['paddingRight','padR'],
       ['marginTop','marT'],['marginBottom','marB'],['gap','gap']].forEach(function (k) {
        var v = parseFloat(cs(e, k[0]));
        if (!v) return;
        if ([4,8,12,16,24,32,48].indexOf(v) < 0) {
          var sig = e.className || e.tagName, tag = (typeof sig === 'string' ? sig.split(' ')[0] : e.tagName);
          var s = tag + '.' + k[1] + '=' + v;
          if (out.offScale.indexOf(s) < 0) out.offScale.push(s);
        }
      });
    });
  } catch (e) { fatal = String(e && e.message || e); }

  out.errors = errs; out.fatal = fatal;
  var pre = document.createElement('pre');
  pre.textContent = 'QC' + JSON.stringify(out) + 'QC';
  document.body.appendChild(pre);
})();
</script>`;

const tmp = mkdtempSync(join(tmpdir(), "side-audit-"));
const patched = join(tmp, "d.html");
writeFileSync(patched, readFileSync(file, "utf8").replace("</body>", PROBE + "</body>"), "utf8");

function shot(size) {
  return new Promise((done) => {
    const [w, h] = size.split(",");
    const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
      "--user-data-dir=" + join(tmp, "p" + w), `--window-size=${w},${h}`, "--virtual-time-budget=6000",
      "--dump-dom", pathToFileURL(patched).href + hash], { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", () => {});
    const guard = setTimeout(() => { try { child.kill(); } catch (e) {} }, 60000);
    child.on("close", () => { clearTimeout(guard);
      const m = [...out.matchAll(/QC(\{.*?\})QC/gs)];
      done(m.length ? { size, ...JSON.parse(m[m.length - 1][1]) } : { size, fail: "没拿到读数" });
    });
  });
}

const runs = [];
for (const s of sizes) runs.push(await shot(s));
if (asJson) { console.log(JSON.stringify(runs, null, 2)); process.exit(0); }

const f = (x) => (x === null || x === undefined ? "—" : x);
for (const r of runs) {
  console.log(`\n══ ${r.size} ══`);
  if (r.fail || r.fatal) { console.log("  ✗ " + (r.fail || ("探针挂了：" + r.fatal))); continue; }
  const L = r.layout;
  console.log(`  视口 innerWidth=${r.vw}（窗口 ${r.size}）阶梯 rail=${f(L.rail)}｜grid=${L.cols}`);
  console.log(`  侧栏 DOM：.tree 容器 ${r.dom.treeWrappers} 个 / 裸 li ${r.dom.directLi} 个 ｜ 首行 a ${JSON.stringify(r.dom.anchor)}`);
  console.log(`  当前项样式：${JSON.stringify(r.dom.currentRowStyled)}`);
  console.log(`  侧栏 ${L.sidebar.display}/${L.sidebar.width}px padTop=${f(L.sidebar.padTop)} bg=${L.sidebar.bg}`);
  console.log(`  目录：右栏 ${L.tocRail.display}/${L.tocRail.width}px 链接 ${L.tocLinksRail} 条 ｜ 侧栏内 ${L.tocInSidebar ? "有" : "无"}（${L.tocLinksSide} 条）`);
  console.log(`  正文列 ${L.main.width}px → 段落 ${f(r.line && r.line.width)}px = ${f(r.line && r.line.chars)} 字（38–47 ${r.line && r.line.inRange ? "✅" : "✗"}）`);
  const T = r.sidebarText;
  console.log(`  文字对比（底=${L.sidebar.bg}）：分组 ${f(T.grp && T.grp.onSideBg)} / 行标题 ${f(T.nm && T.nm.onSideBg)} / 页脚链接 ${f(T.footLink)} ｜ --fg-3 基准 ${f(T.fg3OnSideBg)}（raw=${f(T.fg3Raw)} / 底 ${f(T.sideBgRaw)}）`);
  console.log(`  侧栏里的等宽文字 ${T.monoInSidebar.length} 处：${T.monoInSidebar.join(" ")}`);
  console.log(`  字号 ${r.noise.distinctFontSizes.join(" ")} ｜ 颜色 ${r.noise.distinctColors.length} 种 ｜ 行高 ${r.align.rowHeights.join(" ")}`);
  console.log(`  对齐：父级标题 x=${f(r.align.parentTitleX)} 子级标题 x=${f(r.align.kidTitleX)} Δ=${f(r.align.delta)} ｜ 引导线 ${f(r.align.guideLine && r.align.guideLine.left)}px`);
  console.log(`  hover 叠在侧栏底上 ${f(r.states.hoverCompositeOnSide)}（对比 ${f(r.states.hoverRatioVsSide)}）｜ 引导线 ${JSON.stringify(r.align.guideLine)}`);
  console.log(`  当前项：${JSON.stringify(r.states.currentRow)}`);
  if (r.offScale.length) console.log(`  非 token 间距：${r.offScale.join(" ")}`);
  if ((r.errors || []).length) console.log(`  JS 报错：${r.errors.join(" | ")}`);
}
