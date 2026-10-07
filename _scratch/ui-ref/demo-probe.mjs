#!/usr/bin/env node
/**
 * demo-probe.mjs —— 给理想形态 demo 做一次**真浏览器体检**（多视口 × 明暗两套）。
 *
 * 为什么：这份 demo 是要拿去当"设计依据"的，它自己歪了后面全歪。
 * 所以量的是**行为**，不只是"能不能打开"：
 *   ① 阶梯（视口宽度 → <html data-rail>）：目录在 rail 3 挂右栏、在 rail 2/1 **塞进侧栏**
 *   ② 行长（A2）：正文段落 720px 是不是真的拿到了
 *   ③ 侧栏本身（这一版新加）：行高一致 / 父子标题同一列 / 当前项有左条 / 文字对比度
 *   ④ 路由（换页、深链到某一节、标题与 meta 跟着变）
 *   ⑤ 三种读法（渲染 ⇄ 原文，且原文就是那一份 markdown）+ 搜索 + 主题三态
 *   ⑥ rail 1 的三按钮**两级**交互（第一次浮出、第二次弹 sheet、Esc 关）
 *   ⑦ 全视口没有横向溢出、没有 JS 报错
 *
 * ⚠️ 仪器换过一次，两次读数不可混用：
 *   · 旧版用 `--window-size=420,900` 当"420px 视口" —— **错的**：Chrome headless 的窗口有最小宽度
 *     （实测窗口 420 请求 → innerWidth 512），所以当年那张表里的 "420px" 其实是 512px。
 *   · 新版把 demo 装进**指定宽度的 iframe**（iframe 的视口宽度就是它自己的宽度），
 *     `--allow-file-access-from-files` 下父页直接读子页，宽度是真的，还能在同一页里做**动态改宽**测试。
 *
 * 用法：node demo-probe.mjs [--file demo.html] [--widths 1440,1100,1024,768,375]
 */
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
function argOf(n, d) { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
const file = resolve(here, argOf("--file", "demo.html"));
const widths = argOf("--widths", "1440,1100,1024,768,375").split(",").map((s) => Number(s.trim())).filter(Boolean);
const HASH = "#/s/moobile-app-development/styles/";

const chrome = [process.env.CHROME,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].filter(Boolean).find((p) => existsSync(p));
if (!chrome) { console.error("找不到 Chrome/Edge"); process.exit(2); }

/* ══ 子页探针：跑在 demo 自己里面（同步，不留 async 尾巴） ═════════════════ */
const CHILD = `
<script>
(function () {
  var out = { steps: {} }, errs = [], fatal = null;
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
    var m = s.match(/rgba?\\(([^)]+)\\)/); if (!m) return null;
    var p = m[1].split(',').map(function (x) { return parseFloat(x); });
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  }
  function over(fg, bg) {
    var f = rgba(fg), b = rgba(bg); if (!f || !b) return null;
    return 'rgb(' + [0,1,2].map(function (i) {
      var k = [f.r, f.g, f.b][i], j = [b.r, b.g, b.b][i];
      return Math.round(k * f.a + j * b.a * (1 - f.a));
    }).join(', ') + ')';
  }
  function lum(c) {
    var o = rgba(c); if (!o) return null;
    var ch = [o.r, o.g, o.b].map(function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
  }
  function ratio(a, b) { var la = lum(a), lb = lum(b); if (la === null || lb === null) return null;
    var hi = Math.max(la, lb), lo = Math.min(la, lb); return Math.round(((hi + 0.05) / (lo + 0.05)) * 100) / 100; }
  var WSR = new RegExp('[' + String.fromCharCode(9,10,13,32) + ']+', 'g');

  /* 读一眼"此刻目录挂在哪、版面是几栏"——静态读数与动态改宽后都用它 */
  function readRail() {
    var r = document.documentElement, sb = q1('.sidebar'), rail = q1('#toc'), side = q1('#side-toc');
    return {
      rail: r.dataset.rail, top: r.dataset.top, w: innerWidth,
      grid: cs(q1('.layout'), 'gridTemplateColumns'),
      sidebar: cs(sb, 'display'), sidebarW: Math.round(sb.getBoundingClientRect().width),
      railToc: cs(rail, 'display'), railLinks: qa('#toc a[data-sec]').length,
      sideToc: side ? (side.dataset.in === 'side' ? 'side' : 'idle') : 'missing',
      sideLinks: qa('#side-toc a[data-sec]').length,
      fabs: cs(q1('.fabs'), 'display'),
      overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
    };
  }

  try {
    /* ── 0. 归零：清掉上一个 iframe 留在 localStorage 里的主题偏好（五个视口要同条件） ── */
    try { localStorage.removeItem('sp-theme'); } catch (e) {}
    setPref('auto');

    /* ── ① 阶梯 + ② 行长 + ③ 侧栏（先量静态，后面会改 DOM 做行为测试） ── */
    out.rail = readRail();
    var p = q1('#body p') || q1('#article p'), pr = q1('.prose');
    var pW = p ? Math.round(p.getBoundingClientRect().width) : null;
    var fs = p ? parseFloat(cs(p, 'fontSize')) : null;
    out.line = { proseW: pr ? Math.round(pr.getBoundingClientRect().width) : null, pW: pW, fs: fs,
      chars: pW && fs ? Math.round((pW / fs) * 10) / 10 : null,
      mainW: Math.round(q1('#main').getBoundingClientRect().width),
      mainPadL: num(cs(q1('#main'), 'paddingLeft')) };

    out.struct = {
      treeWrappers: qa('.sidebar .tree').length, bareLi: qa('.sidebar > li').length,
      rowCount: qa('.sidebar .tree .slnk').length,
      mainPadL: num(cs(q1('#main'), 'paddingLeft')), mainPadT: num(cs(q1('#main'), 'paddingTop')),
    };

    var sb = q1('.sidebar'), sBox = sb.getBoundingClientRect(), sBg = cs(sb, 'backgroundColor');
    var rows = qa('.sidebar .tree .slnk').map(function (a) {
      var row = a.closest('.srow'), r = row.getBoundingClientRect(), t = a.getBoundingClientRect();
      return { title: a.textContent.trim(), vis: r.height > 0, h: Math.round(r.height),
        x: Math.round(t.left - sBox.left), cur: row.dataset.current === '1',
        bar: cs(row, 'backgroundColor', '::before'), rowBg: over(cs(row, 'backgroundColor'), sBg),
        color: cs(a, 'color'), ellipsis: cs(a, 'textOverflow') === 'ellipsis' && cs(a, 'whiteSpace') === 'nowrap' };
    }).filter(function (r) { return r.vis; });
    var lv1 = rows.filter(function (r) { return !r.kid; });
    var grp = q1('.sidebar .grp'), curRow = rows.filter(function (r) { return r.cur; })[0];
    var monoInSide = qa('.sidebar *').filter(function (e) { return /mono|Consolas|Menlo/i.test(cs(e, 'fontFamily')); });
    var kids = qa('.sidebar .ssub .slnk').map(function (a) { return Math.round(a.getBoundingClientRect().left - sBox.left); })
      .filter(function (_, i, arr) { return arr.indexOf(_) === i; });
    out.sidebar = {
      bg: sBg, padTop: num(cs(sb, 'paddingTop')), mainPadTop: num(cs(q1('#main'), 'paddingTop')),
      rows: rows.length, heights: rows.map(function (r) { return r.h; }).filter(function (v, i, a) { return a.indexOf(v) === i; }),
      parentX: lv1.length ? lv1[0].x : null, kidX: kids.length ? kids[0] : null,
      allEllipsis: rows.every(function (r) { return r.ellipsis; }),
      curBar: curRow ? curRow.bar : null, curBg: curRow ? curRow.rowBg : null,
      curContrast: curRow ? ratio(curRow.color, curRow.rowBg) : null,
      grpContrast: grp ? ratio(cs(grp, 'color'), sBg) : null,
      rowContrast: ratio(cs(q1('.sidebar .tree .slnk'), 'color'), sBg),
      fg3Baseline: ratio(tok('--fg-3'), sBg),
      monoCount: monoInSide.length, monoText: monoInSide.map(function (e) { return String(e.textContent).trim().slice(0, 20); }),
      hoverOnSide: ratio(over(tok('--state-hover-side'), sBg), sBg),
    };

    /* ── ③c 目录在树里的**位置**：必须挂在"正在读的那个文件"节点下面 ── */
    var st = q1('#side-toc');
    out.tocInTree = st ? (function () {
      // "挂在谁下面" = 它父节点自己那一行（子页 = 那一行就是当前页；主题页 = 那份 skill 的行）
      var holder = st.parentElement, row = holder ? q1(':scope > .srow', holder) : null;
      var kid = holder ? q1('.ssub .slnk', holder) : null;
      // ⚠️ 文字的 x 要把行自己的 padding 算进去（块级行的 rect.left 是盒子的左边，不是字）
      var textX = function (el) { return el ? Math.round(el.getBoundingClientRect().left - sBox.left + parseFloat(cs(el, 'paddingLeft') || 0)) : null; };
      return {
        holder: holder ? holder.className : null,
        parentTitle: row ? (q1('.slnk', row) || {}).textContent : null,
        parentIsCurrent: !!(row && (row.dataset.current === '1' || row.querySelector('[aria-current="page"]'))),
        isDescendant: !!st.closest('.snode'),
        x: textX(q1('a[data-sec]', st)), kidX: textX(kid),
      };
    })() : null;

    /* 右栏那条轨自己也得是"被样式化"的（改名 .toc → .tocbox 时最容易漏这一处） */
    var ta = q1('#toc a[data-sec]');
    out.railTocStyle = ta ? { padL: num(cs(ta, 'paddingLeft')), borderL: num(cs(ta, 'borderLeftWidth')),
      fs: num(cs(ta, 'fontSize')), color: cs(ta, 'color') } : null;

    /* ── ④ 路由 ── */
    var page = flat.filter(function (x) { return x.path === '/s/moobile-app-development/styles/'; })[0];
    renderPage(page, null);
    out.steps.route = {
      h1: (q1('h1') || {}).textContent || null, docTitle: document.title,
      crumb: q1('.crumb') ? q1('.crumb').textContent.replace(WSR, ' ').trim() : null,
      sideCurrent: (q1('.sidebar .srow[data-current="1"] .slnk') || {}).textContent || null,
      tocCount: qa('[data-toc] a[data-sec]').length,
      agentSrc: (q1('.agent .row .grow') || {}).textContent || null,
      pager: qa('.pager a').length,
      metaDesc: (document.querySelector('meta[name=description]') || {}).content || null,
      h2Id: (q1('#body h2') || {}).id || null,
    };
    var h2id = out.steps.route.h2Id;
    if (h2id) {
      renderPage(page, h2id);
      out.steps.deeplink = { id: h2id, scrollTop: Math.round(q1('#main').scrollTop) };
      renderPage(page, null);
    }

    /* ── ⑤ 读法 / 搜索 / 主题 ── */
    q1('#v-raw').click();
    out.steps.raw = { renderHidden: q1('#body').hidden, rawShown: !q1('#rawwrap').hidden,
      mdHead: q1('#rawwrap .raw').textContent.slice(0, 12) };
    q1('#v-render').click();
    out.steps.renderBack = { renderShown: !q1('#body').hidden, rawHidden: q1('#rawwrap').hidden };

    q1('#searchBtn').click();
    var q = q1('#q'); q.value = '样式'; q.dispatchEvent(new Event('input'));
    out.steps.search = { open: q1('#overlay').dataset.open === '1', hits: qa('.hit').length,
      first: (q1('.hit .t') || {}).textContent || null };
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    out.steps.searchCloses = q1('#overlay').dataset.open === '0';

    function readPal() { return { canvas: tok('--canvas'), c1: ratio(tok('--fg-1'), tok('--canvas')),
      c2: ratio(tok('--fg-2'), tok('--canvas')), c3: ratio(tok('--brand'), tok('--canvas')) }; }
    // ⚠️ 五个 iframe 共用一份 localStorage：不逐个驱动"三态"，后面几个一开机就是 dark（第一版就栽在这）
    out.steps.theme = { palettes: {} };
    ['auto', 'light', 'dark'].forEach(function (pref) { setPref(pref); out.steps.theme.palettes[pref] = readPal(); });
    out.steps.theme.prefsSeen = Object.keys(out.steps.theme.palettes);
    out.steps.theme.sideInDark = { fg3: ratio(tok('--fg-3'), tok('--surface-2')), fg2: ratio(tok('--fg-2'), tok('--surface-2')) };
    out.elevation = { canvas: tok('--canvas'), overlay: tok('--overlay'), surface2: tok('--surface-2'), theme: document.documentElement.dataset.theme };

    /* ── ⑥ rail 1 的贴边按钮：两级交互 ── */
    if (out.rail.rail === '1') {
      var fab = q1('#fab-toc');
      fab.style.transition = 'none';                 // 不等过渡：不然读到的是中间值（老坑）
      var m = { docked: cs(fab, 'transform'), peekBefore: fab.dataset.peek };
      fab.click(); m.peekAfter = fab.dataset.peek; m.floated = cs(fab, 'transform');
      fab.style.transition = '';
      m.sheetAfter1 = q1('#sheet-toc').dataset.open;
      fab.click(); m.sheetAfter2 = q1('#sheet-toc').dataset.open;
      m.scrim = q1('#scrim').dataset.open === '1';
      m.tocSheetLinks = qa('#sheet-toc a').length;
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      m.closedAfterEsc = q1('#sheet-toc').dataset.open === '0';
      q1('#fab-shelf').click(); q1('#fab-shelf').click();     // 两次：浮出 → 弹 sheet
      m.shelfSheetHasToc = qa('#sheet-shelf #side-toc a, #sheet-shelf [data-toc] a').length;
      m.shelfSheetLinks = qa('#sheet-shelf a').length;
      m.dupIds = qa('#sheet-shelf [id]').length;
      closeSheets();
      out.steps.mobile = m;
    }
    /* ⑦ 全站各页都过一遍：换页不能把"目录挂载点"弄坏（侧栏是每页重建的） */
    out.sweep = {};
    [['/', renderHome], ['/shelf/', renderShelf], ['/llms', renderLLms], ['/nope', render404],
     ['/s/moobile-app-development/', function () { renderPage(flat.filter(function (x) { return x.kind === 'skill'; })[0], null); }]
    ].forEach(function (pair) {
      try {
        pair[1]();
        out.sweep[pair[0]] = {
          h1: (q1('h1') || {}).textContent || null,
          sideRows: qa('.sidebar .tree .slnk').length,
          tocRail: qa('#toc a[data-sec]').length, tocSide: qa('#side-toc a[data-sec]').length,
          tocMounted: !!(q1('#toc').textContent.trim() || (q1('#side-toc') || { textContent: '' }).textContent.trim()),
          tocHolder: (function () { var st = q1('#side-toc'); if (!st || TOC_MOUNT !== 'side') return null;
            var h = st.parentElement, row = h ? q1(':scope > .srow', h) : null;
            return { holder: h ? h.className : null, parent: row ? (q1('.slnk', row) || {}).textContent : null,
              current: !!(row && (row.dataset.current === '1' || row.querySelector('[aria-current="page"]'))) }; })(),
        };
      } catch (e) { out.sweep[pair[0]] = { err: String(e && e.message || e) }; }
    });
    renderPage(page, null);          // 扫完回到"正经页"：后面动态改宽读的是目录的**内容**，别停在 404 上
  } catch (e) { fatal = String(e && e.message || e); }

  out.overflow = document.documentElement.scrollWidth - document.documentElement.clientWidth;
  out.errors = errs; out.fatal = fatal;
  window.__SP = { result: out, recheck: readRail };
})();
</script>`;

/* ══ 父页：把 demo 装进指定宽度的 iframe（宽度是真的） ═══════════════════ */
const PARENT = (url, widths) => `<!doctype html><meta charset="utf-8"><body style="margin:0">
<pre id="out">PENDING</pre><div id="frames"></div>
<script>
var W = ${JSON.stringify(widths)};
var OUT = { phase: 'boot' };
function log() { document.getElementById('out').textContent = 'QC' + JSON.stringify(OUT) + 'QC'; }
log();
(function () {
  var frames = {}, box = document.getElementById('frames');
  W.forEach(function (w) {
    var f = document.createElement('iframe');
    f.style.cssText = 'width:' + w + 'px;height:900px;border:0;display:block';
    f.src = ${JSON.stringify(url)};
    box.appendChild(f); frames[w] = f;
  });
  // ⚠️ 不能拿 contentDocument.readyState 判"好了没"：刚 append 的 iframe 里是那张 about:blank，
  //    readyState 一上来就是 complete ⇒ 会当场放行（第一版就这么飘的：有的视口读到、有的读不到）。
  //    改成轮询"子页有没有留下 __SP"，这才是唯一可信的就绪信号。
  function ready() {
    return W.every(function (w) { var cw = frames[w].contentWindow; return cw && cw.__SP; });
  }
  var tries = 0;
  (function poll() {
    if (!ready() && ++tries < 400) return setTimeout(poll, 20);
    OUT = { ready: ready(), tries: tries };
    W.forEach(function (w) {
      var cw = frames[w].contentWindow;
      OUT['w' + w] = (cw && cw.__SP) ? cw.__SP.result : { fail: '子页没留下 __SP（轮询 ' + tries + ' 次）' };
    });
    log();
    // 动态改宽：1440 → 1100（目录该从右栏搬进侧栏）；375 → 1440（该搬回去）
    frames[W[0]].style.width = '1100px';
    frames[W[W.length - 1]].style.width = '1440px';
    setTimeout(function () {
      OUT.dynamic = {
        from1440to1100: frames[W[0]].contentWindow.__SP.recheck(),
        from375to1440: frames[W[W.length - 1]].contentWindow.__SP.recheck()
      };
      log();
    }, 200);
  })();
})();
</script></body>`;

const tmp = mkdtempSync(join(tmpdir(), "demo-probe-"));
const source = fileURLToPath(pathToFileURL(file));
const childPath = join(tmp, "child.html");
writeFileSync(childPath, readFileSync(source, "utf8").replace("</body>", CHILD + "</body>"), "utf8");
const parentPath = join(tmp, "parent.html");
const parentWidth = widths[0] + 160;
writeFileSync(parentPath, PARENT(pathToFileURL(childPath).href + HASH, widths), "utf8");

const stdout = await new Promise((done) => {
  const child = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
    "--allow-file-access-from-files", "--user-data-dir=" + join(tmp, "prof"),
    `--window-size=${parentWidth},900`, "--virtual-time-budget=20000", "--dump-dom",
    pathToFileURL(parentPath).href], { stdio: ["ignore", "pipe", "pipe"] });
  let out = "";
  child.stdout.on("data", (d) => (out += d));
  child.stderr.on("data", () => {});
  const guard = setTimeout(() => { try { child.kill(); } catch (e) {} }, 90000);
  child.on("close", () => { clearTimeout(guard); done(out); });
});

const marks = [...stdout.matchAll(/QC(\{.*?\})QC/gs)];
if (!marks.length) { console.error("没拿到体检结果（dump 尾巴）：" + stdout.slice(-300)); process.exit(2); }
const R = JSON.parse(marks[marks.length - 1][1]);

function lum(hex) {
  const h = String(hex).replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(h.length === 3 ? h + h : h)) return null;
  const v = h.length === 3 ? h[0] + h[0] + h[1] + h[1] + h[2] + h[2] : h;
  const ch = [0, 1, 2].map((i) => { const x = parseInt(v.substr(i * 2, 2), 16) / 255;
    return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); });
  return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
}

let bad = 0;
const say = (ok, msg) => { console.log((ok ? "  ✓ " : "  ✗ ") + msg); if (!ok) bad++; };
const EXPECT_TOC = (w) => (w >= 1280 ? "rail" : "side");

console.log(`跑 ${widths.join(" / ")}（真 iframe 视口宽度）`);
for (const w of widths) {
  const r = R["w" + w];
  console.log(`\n── ${w}px ──`);
  if (!r || r.fail) { say(false, "没拿到这个视口的读数" + (r && r.fail ? "：" + r.fail : "")); continue; }
  const rail = r.rail, s = r.steps;
  say(!r.fatal, `仪器自证：探针跑到底${r.fatal ? "（挂了：" + r.fatal + "）" : ""}`);
  say(r.overflow <= 1, `横向溢出 ${r.overflow}px`);
  say((r.errors || []).length === 0, `JS 报错 ${(r.errors || []).length} 条${(r.errors || []).length ? "：" + r.errors.join(" | ") : ""}`);

  /* ① 阶梯 */
  const wantRail = w >= 1280 ? "3" : w >= 1024 ? "2" : "1";
  say(rail.rail === wantRail, `阶梯：${w}px → data-rail=${rail.rail}（要 ${wantRail}）｜grid=${rail.grid}`);
  if (wantRail === "3") {
    say(rail.sidebar !== "none" && rail.railToc !== "none", "rail 3：侧栏与目录轨都在");
    say(rail.railLinks >= 2 && rail.sideToc !== "side", `目录挂在右栏轨里（${rail.railLinks} 条）；树里那份不存在（${rail.sideToc}）`);
    const ts = r.railTocStyle;
    say(!!ts && ts.padL === 12 && ts.fs === 12.5, `那条轨真的被样式化了：padding-left ${ts && ts.padL} / 字号 ${ts && ts.fs} / 当前段 border-left ${ts && ts.borderL}px`);
  } else {
    say(rail.railToc === "none", "rail 2/1：右栏目录轨收起");
    say(rail.sideToc === "side" && rail.sideLinks >= 2, `**目录塞进了侧栏**（${rail.sideLinks} 条，data-in=${rail.sideToc}）`);
    say(rail.sidebar === (wantRail === "2" ? "block" : "none"), `侧栏 display=${rail.sidebar}`);
    say(rail.fabs === (wantRail === "1" ? "block" : "none"), `贴边按钮 display=${rail.fabs}`);
  }

  /* ② 行长 */
  const chars = r.line.chars, pW = r.line.pW;
  if (w >= 1024) say(chars >= 38 && chars <= 47, `行长：段落 ${pW}px = ${chars} 字（38–47 ✅ 720px=46.5 字）`);
  else say(Math.abs(pW - Math.min(720, w - 32)) <= 3, `行长：段落 ${pW}px = ${chars} 字（窄屏 = min(720, 视口-32)）`);

  /* ③ 结构：类名有没有真的命中元素（`.tree` / `.main` 两个 bug 都是这么漏的） */
  say(r.struct.treeWrappers === 1 && r.struct.bareLi === 0, `侧栏树有 .tree 外壳（裸 li ${r.struct.bareLi} 个）、行 ${r.struct.rowCount} 条`);
  const wantPad = wantRail === "1" ? 16 : 32;
  say(r.struct.mainPadL === wantPad, `正文内边距：左 ${r.struct.mainPadL}px（rail ${wantRail} 要 ${wantPad}px）—— 不是 0（.main 这个类以前根本没命中）`);

  /* ③c 目录挂在哪（用户这条要求的正面判据） */
  if (wantRail === "3") {
    say(r.tocInTree === null, "rail 3：树里不放目录（只有右栏那条轨）");
  } else {
    const t = r.tocInTree;
    say(!!t && t.isDescendant && t.parentIsCurrent, `目录挂在"正在读的那个文件"下面：父级 = ${t && t.parentTitle}（是当前项 ✓）`);
    if (rail.sidebar !== "none") {   // rail 1 侧栏是 display:none，量不到几何（它就活在 sheet 里）
      say(!!t && t.x !== null && t.kidX !== null && t.x - t.kidX === 16, `目录比同级条目再进一格：x=${t && t.x} vs 同级 ${t && t.kidX}（+16px）`);
    }
  }

  /* ③b 侧栏：看得见的时候才量几何；文字与对比度任何时候都成立 */
  const sb = r.sidebar;
  if (rail.sidebar !== "none") {
    say(sb.heights.length === 1, `侧栏行高一致：${sb.heights.join("/")}px（${sb.rows} 行可见）`);
    say(sb.parentX !== null && sb.parentX === sb.kidX, `父子标题同一列：x=${sb.parentX} / ${sb.kidX}`);
    say(!!sb.curBar && sb.curBar !== "rgba(0, 0, 0, 0)", `当前项有左条：${sb.curBar}`);
    say(sb.curContrast >= 4.5, `当前项文字对比 ${sb.curContrast}`);
    say(sb.allEllipsis, "每个行标题都是单行省略（不换行 ⇒ 不参差）");
    say(sb.padTop === sb.mainPadTop, `侧栏顶 ${sb.padTop}px 与正文顶 ${sb.mainPadTop}px 对齐`);
    console.log(`     （参考读数：hover 叠在侧栏底上对比 ${sb.hoverOnSide} —— 弱，所以状态主要靠左条认）`);
  }
  say(sb.grpContrast >= 4.5 && sb.rowContrast >= 4.5, `侧栏文字对比（底 ${sb.bg}）：分组 ${sb.grpContrast} / 行 ${sb.rowContrast}（都 ≥4.5；--fg-3 基准只有 ${sb.fg3Baseline}）`);
  say(sb.monoCount === 1 && /sha256/.test(sb.monoText[0] || ""), `侧栏里只有一处等宽文字（${sb.monoText.join(" / ")}）—— 机器名不再进侧栏`);

  /* ④ 路由 */
  say(s.route.h1 === "样式", `路由：h1 = ${JSON.stringify(s.route.h1)}`);
  say(/样式 · skillpress$/.test(s.route.docTitle), `文档标题跟着变：${s.route.docTitle}`);
  say(s.route.sideCurrent === "样式", `侧栏当前项 = ${JSON.stringify(s.route.sideCurrent)}`);
  say(s.route.tocCount >= 2, `本页目录 ${s.route.tocCount} 条（当前落点）`);
  say(/references\/styles\.md$/.test(s.route.agentSrc || ""), `Agent 面板指向源文件：${s.route.agentSrc}`);
  say(s.route.pager === 2, `上下页 ${s.route.pager} 个`);
  say(/首页/.test(s.route.crumb || "") && /样式/.test(s.route.crumb || "") && /styles\.md/.test(s.route.crumb || ""), `面包屑：${s.route.crumb}`);
  say(!!s.route.metaDesc && !/把 skills 目录印成站点/.test(s.route.metaDesc), `meta description 跟着变：${s.route.metaDesc}`);
  say(s.deeplink && s.deeplink.scrollTop > 0, `深链到某一节：scrollTop=${s.deeplink && s.deeplink.scrollTop}`);

  /* ⑤ 读法 / 搜索 / 主题 */
  say(s.raw.rawShown && s.raw.renderHidden, `原文视图：md 开头 ${JSON.stringify(s.raw.mdHead)}`);
  say(s.renderBack.renderShown && s.renderBack.rawHidden, "切回渲染视图");
  say(s.search.open && s.search.hits > 0, `搜索：命中 ${s.search.hits} 条（首条 ${JSON.stringify(s.search.first)}）`);
  say(s.searchCloses, "Esc 关闭搜索");
  const prefs = s.theme.prefsSeen;
  say(prefs.includes("auto") && prefs.includes("light") && prefs.includes("dark"), `主题三态都在：${prefs.join("/")}`);
  const canvases = new Set(Object.keys(s.theme.palettes).map((k) => s.theme.palettes[k].canvas));
  say(canvases.size >= 2, `明暗真的不同（canvas ${canvases.size} 种：${[...canvases].join(" / ")}）`);
  for (const [k, pal] of Object.entries(s.theme.palettes)) {
    say(pal.c1 >= 4.5 && pal.c2 >= 4.5 && pal.c3 >= 4.5, `对比度 ${k}：正文 ${pal.c1} / 次要 ${pal.c2} / 链接 ${pal.c3}（都 ≥4.5）`);
  }
  const el2 = r.elevation;
  say(el2.theme === "dark" && lum(el2.overlay) > lum(el2.canvas) && lum(el2.surface2) < lum(el2.canvas),
    `暗色海拔：overlay ${el2.overlay}(亮) > canvas ${el2.canvas} > surface-2 ${el2.surface2}(暗)`);
  say(s.theme.sideInDark.fg2 >= 4.5, `暗色侧栏：--fg-2 落在 surface-2 上 ${s.theme.sideInDark.fg2}（--fg-3 只有 ${s.theme.sideInDark.fg3}，所以不用它）`);

  /* ⑦ 全站各页 */
  const sweep = Object.entries(r.sweep || {});
  say(sweep.length === 5 && sweep.every(([, v]) => !v.err), `五个页面都渲染得过：${sweep.map(([k, v]) => k + (v.err ? "✗" : "✓")).join(" ")}`);
  say(sweep.every(([, v]) => v.sideRows > 0), `换页之后侧栏还在（${sweep.map(([, v]) => v.sideRows).join("/")} 行）`);
  say(sweep.every(([, v]) => v.tocMounted), `每页的目录挂载点都写进了东西：${sweep.map(([k, v]) => k + (v.tocMounted ? "✓" : "✗")).join(" ")}`);
  if (wantRail !== "3") {
    const sk = (r.sweep["/s/moobile-app-development/"] || {}).tocHolder;
    say(!!sk && sk.current && /snode/.test(sk.holder), `主题页（不是子页）也挂在它自己的节点下面：holder=${sk && sk.holder} 父级=${sk && sk.parent}`);
    const home = (r.sweep["/"] || {}).tocHolder;
    say(!!home && /stocwrap/.test(home.holder), `树里没有的页（首页）走兜底：holder=${home && home.holder}`);
  }

  /* ⑥ rail 1 的两级交互 */
  if (wantRail === "1") {
    const m = s.mobile;
    say(m.peekBefore === "0" && m.peekAfter === "1", `两级交互：第一次点 peek ${m.peekBefore}→${m.peekAfter}`);
    say(m.docked !== m.floated, `浮出真的位移了：贴边 ${m.docked} → 浮出 ${m.floated}`);
    say(m.sheetAfter1 === "0" && m.sheetAfter2 === "1", `第二次点才弹 sheet（${m.sheetAfter1}→${m.sheetAfter2}）`);
    say(m.scrim && m.tocSheetLinks > 0, `遮罩打开、目录 sheet 里 ${m.tocSheetLinks} 条链接`);
    say(m.closedAfterEsc, "Esc 关 sheet");
    say(m.shelfSheetLinks >= 6 && m.dupIds === 0, `书架 sheet：${m.shelfSheetLinks} 条链接、零重复 id（带目录 ${m.shelfSheetHasToc} 条）`);
  }
}

/* ⑦ 动态阶梯：改宽之后，目录得自己搬家 */
console.log("\n── 动态改宽（同一页里改 iframe 宽度） ──");
const d = R.dynamic;
if (!d) say(false, "没拿到动态读数");
else {
  say(d.from1440to1100.rail === "2" && d.from1440to1100.sideToc === "side" && d.from1440to1100.railLinks === 0,
    `1440 → 1100：rail ${d.from1440to1100.rail}、目录搬到侧栏（${d.from1440to1100.sideLinks} 条）、右栏清空（${d.from1440to1100.railLinks} 条）`);
  say(d.from375to1440.rail === "3" && d.from375to1440.sideToc !== "side" && d.from375to1440.railLinks >= 2,
    `375 → 1440：rail ${d.from375to1440.rail}、目录搬回右栏轨（${d.from375to1440.railLinks} 条）、侧栏那段清空`);
}
console.log(`\n${bad === 0 ? "全部通过（" + widths.length + " 个视口）" : bad + " 条不过"}`);
process.exit(bad === 0 ? 0 : 1);
