#!/usr/bin/env node
// ui-probe-page.mjs —— **装进页面的那一半**：读数 + "要点的东西在哪"。
//
// 分工（R9：一个文件一件事）：
//   · 这个文件 = 页面里的**取数**（一页的版面/侧栏/目录/文档页骨架快照）与**坐标查找**；
//   · `ui-probe.mjs` = 起服务、连 CDP、**用真鼠标点**、断言。
//
// ## ⚠️ 两条硬规矩（都是踩出来的）
//
// 1. **交互一律不由这里做**：这个文件**只返回坐标**，真点击由 Node 侧的
//    `Input.dispatchMouseEvent` 发。原因见 `cdp.mjs` 文件头 —— 页面里合成事件在这套宿主上
//    **会静默失效**（点了没反应、两路报错都是 0 条）⇒ 靠它得出的绿不可信。
// 2. **RNW 不产语义标签**（整页零个 `p`/`h1`）：一切按**字号 + 几何 + 文字**认；
//    "正文"必须按字号 15.5 筛，筛不到就报没量到（不许回落到"最宽的那个"）。
//
// 装法：`Page.navigate` 之后 `Runtime.evaluate(PAGE_JS)` 一次，之后用 `window.__p.*` 取数。
// ⚠️ 一个反引号都不许有（这个字符串会被当作 JS 源码求值）。
export const PAGE_JS = `
window.__p = (function () {
  var cs = function (e, p) { return e ? getComputedStyle(e)[p] : null; };
  var box = function (e) { var r = e.getBoundingClientRect();
    return { w: Math.round(r.width), h: Math.round(r.height), x: Math.round(r.left), y: Math.round(r.top) }; };
  var center = function (e) { var r = e.getBoundingClientRect();
    return { x: Math.round(r.left + r.width / 2), y: Math.round(r.top + r.height / 2) }; };
  // ⚠️ 真鼠标点不到视口外的坐标（elementFromPoint 给 null）。而正文栏/面板都是自己滚的
  //    容器 ⇒ 这一格常常在折叠下方。合成事件不需要"看得见"，所以旧探针曾"点"到一个真人
  //    根本点不到的格子上（假绿）。凡是要点的坐标，先滚进可视区，再量。
  var reveal = function (el) {
    if (!el) return null;
    try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch (e) {}
    var r = el.getBoundingClientRect();
    if (r.top < 0 || r.bottom > innerHeight || r.left < 0 || r.right > innerWidth) return null;   // 滚不进来就别点
    return center(el);
  };
  var leaves = function (root) {
    return Array.prototype.slice.call((root || document).querySelectorAll('div,span,button'))
      .filter(function (el) { return !el.children.length && el.textContent && el.textContent.trim(); });
  };
  function shell() {
    var root = document.getElementById('root');
    var s = root && root.firstElementChild, g = 0;
    while (s && s.children.length === 1 && g++ < 8) s = s.children[0];
    return s;
  }
  function cols() {
    var s = shell();
    if (!s || s.children.length < 2) return [];
    return Array.prototype.slice.call(s.children[1].children);
  }
  // ⚠️ rail 3 有三栏、**最后一栏是目录轨** ⇒ 正文是**中间**那一栏。第一版取最后一栏，
  //    结果"文档页 H1 = null"（读数落到了目录轨上）。
  function articleCol() { var c = cols(); return c.length >= 3 ? c[1] : c[c.length - 1]; }
  function absBoxes() {
    return Array.prototype.slice.call(document.querySelectorAll('div')).filter(function (el) {
      return getComputedStyle(el).position === 'absolute'; });
  }
  // sheet 面板 = 贴底的绝对定位块，**而且有字**（遮罩也满足 absolute + bottom:0，但它是空的）
  function panel() {
    return absBoxes().filter(function (el) {
      var st = getComputedStyle(el);
      return st.bottom === '0px' && el.textContent.trim().length > 0;
    })[0] || null;
  }
  function fabBox(label) {
    return absBoxes().filter(function (el) { return (el.textContent || '').trim() === label; })[0] || null;
  }
  function topbar() { var s = shell(); return s ? s.children[0] : null; }
  function clickables(root) {
    if (!root) return [];
    // 可点的是 @html.button（Pressable）；⚠️ div + on_click 在 web 上是死处理器。
    // 退回分支：扫不到 button 时，把"顶栏里有字的叶子"当候选（判据只读它们的**文字**，
    // 不点它们）—— 免得"标签列表是空的"变成一条**恒绿**的假判据。
    var bs = Array.prototype.slice.call(root.querySelectorAll('button')).filter(function (el) { return el.textContent.trim(); });
    return bs.length ? bs : leaves(root);
  }
  return {
    box: box, center: center, shell: shell, cols: cols, panel: panel, clickables: clickables,

    snapshot: function () {
      var s = shell();
      if (!s || s.children.length < 2) return { why: '壳的形状不对（顶栏 + 三栏行）' };
      var bar = s.children[0], row = s.children[1];
      var cc = Array.prototype.slice.call(row.children);
      var prose = null;
      leaves().forEach(function (el) {
        if (parseFloat(cs(el, 'fontSize')) !== 15.5) return;
        var b = box(el);
        if (!prose || b.w > prose.w) prose = { w: b.w, fs: 15.5 };
      });
      if (prose) prose.chars = Math.round((prose.w / prose.fs) * 10) / 10;
      var side = null;
      if (cc.length >= 2) {
        var sb = cc[0], sbLeft = Math.round(sb.getBoundingClientRect().left);
        var rows = [], toc = [], bars = [], machine = [], heights = [];
        Array.prototype.slice.call(sb.querySelectorAll('div')).forEach(function (el) {
          var b = box(el);
          if (b.w === 2 && b.h > 8 && cs(el, 'backgroundColor') !== 'rgba(0, 0, 0, 0)') bars.push(cs(el, 'backgroundColor'));
        });
        leaves(sb).forEach(function (el) {
          var t = el.textContent.trim(), fs = parseFloat(cs(el, 'fontSize')), left = box(el).x;
          if (fs === 13.5) { rows.push(t); heights.push(box(el).h); }
          if (fs === 12.5 && left - sbLeft >= 40) toc.push(t);
          if (/^[a-z][a-z0-9-]+$/.test(t)) machine.push(t);
        });
        side = { rows: rows.length, titles: rows.slice(0, 6), machine: machine, bars: bars, heights: heights, toc: toc.length };
      }
      var railRows = cc.length >= 3 ? leaves(cc[cc.length - 1]).filter(function (el) {
        return parseFloat(cs(el, 'fontSize')) === 12.5; }).length : 0;
      var tocTree = null;
      if (side && side.toc > 0) {
        var sb1 = cc[0], left0 = Math.round(sb1.getBoundingClientRect().left);
        var leaf = leaves(sb1).filter(function (el) {
          return parseFloat(cs(el, 'fontSize')) === 12.5 && box(el).x - left0 >= 40; })[0];
        if (leaf) {
          // ⚠️ 别靠 「aria-current「 认"当前项"：壳里标的是 「data-current「，而 RNW **不一定把
          //    data-* 透传到 DOM**。用**生效的读数**认：当前项有一条**品牌色左条**（2px 的实心块），
          //    目录那一行往上爬，第一个"装着那条左条"的祖先就是它的挂载节点。
          var barEls = Array.prototype.slice.call(sb1.querySelectorAll('div')).filter(function (el) {
            var b = box(el);
            return b.w === 2 && b.h > 8 && cs(el, 'backgroundColor') !== 'rgba(0, 0, 0, 0)';
          });
          var host = leaf.parentElement, holder = null;
          while (host && host !== sb1) {
            if (barEls.some(function (b) { return host.contains(b); })) { holder = host; break; }
            host = host.parentElement;
          }
          tocTree = { rows: side.toc, underCurrent: !!holder, bars: barEls.length };
        }
      }
      var col = articleCol();
      var art = col ? leaves(col) : [];
      var byFs = function (f) { return art.filter(function (el) { return parseFloat(cs(el, 'fontSize')) === f; })
        .map(function (el) { return el.textContent.trim(); }); };
      var codeBg = null;
      if (col) Array.prototype.slice.call(col.querySelectorAll('div')).forEach(function (el) {
        var bg = cs(el, 'backgroundColor');
        if (bg === 'rgb(247, 247, 248)' && el.querySelectorAll('div,span').length > 0 && !codeBg) codeBg = bg;
      });
      var doc = col ? {
        h1: byFs(30)[0] || null,
        kicker: art.filter(function (el) { return /mono|Consolas|Menlo/i.test(cs(el, 'fontFamily')) &&
          parseFloat(cs(el, 'fontSize')) === 11.5; }).map(function (el) { return el.textContent.trim(); })[0] || null,
        crumbs: byFs(12.5),
        paras: byFs(15.5).length,
        pager: art.filter(function (el) { return /上一页|下一页/.test(el.textContent); })
          .map(function (el) { return el.textContent.trim().slice(0, 8); }),
        footer: (art.filter(function (el) { return el.textContent.trim().indexOf('源文件') === 0; })[0] || {}).textContent || null,
        codeBg: codeBg,
        overflowX: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      } : null;
      return {
        vw: innerWidth, why: '', shellBg: cs(s, 'backgroundColor'),
        topbar: { h: box(bar).h, bg: cs(bar, 'backgroundColor'),
                  labels: clickables(bar).map(function (el) { return el.textContent.trim(); }) },
        cols: cc.map(function (c) { return { w: box(c).w, oy: cs(c, 'overflowY'),
          br: parseFloat(cs(c, 'borderRightWidth') || 0), bl: parseFloat(cs(c, 'borderLeftWidth') || 0) }; }),
        pageScrolls: document.documentElement.scrollHeight > document.documentElement.clientHeight + 1,
        overflowX: document.documentElement.scrollWidth - document.documentElement.clientWidth,
        prose: prose, side: side, tocRail: { rows: railRows }, tocTree: tocTree, doc: doc,
        sheet: (function () { var p = panel(); return p ? { h: box(p).h, x: box(p).x, y: box(p).y } : null; })(),
        fabs: absBoxes().filter(function (el) { return /导航|书架|目录/.test(el.textContent || ''); })
          .map(function (el) { return { label: el.textContent.trim(), x: center(el).x, y: center(el).y,
            left: Math.round(el.getBoundingClientRect().left), bg: cs(el, 'backgroundColor') }; }),
        bodyText: document.body.innerText.trim().slice(0, 60),
      };
    },

    /** 侧栏里第一条**条目标题**（字号 13.5）的坐标 —— 点它应当进文档页。 */
    sidebarTitle: function () {
      var c = cols(); if (c.length < 2) return null;
      var t = leaves(c[0]).filter(function (el) {
        var s2 = el.textContent.trim();
        return parseFloat(cs(el, 'fontSize')) === 13.5 && s2.length > 6 && !/^[▸▾·–]/.test(s2); })[0];
      return reveal(t);
    },
    /** sheet 面板里可点的条目的坐标列表。 */
    sheetRows: function () {
      var p = panel(); if (!p) return [];
      return leaves(p).filter(function (el) {
        var s2 = el.textContent.trim();
        return s2.length > 6 && parseFloat(cs(el, 'fontSize')) >= 12 && !/^[▸▾·–≡▤☰]/.test(s2); })
        .map(function (el) { var p2 = reveal(el); return p2 ? { t: el.textContent.trim().slice(0, 14), x: p2.x, y: p2.y } : null; })
        .filter(function (x) { return !!x; });
    },
    /** 贴边按钮的坐标（按文字找：三个标签分别是 "≡ 导航" / "▤ 书架" / "☰ 目录"）。 */
    fab: function (label) { var e = fabBox(label); return e ? center(e) : null; },
    /** 顶栏第一个可点（站名 = 回首页）/ 最后一个（主题开关）。 */
    brand: function () { var b = clickables(topbar()); return b.length ? center(b[0]) : null; },
    theme: function () { var b = clickables(topbar()); return b.length ? center(b[b.length - 1]) : null; },
    /** "下一页"那一格的坐标（算不出给 null）。 */
    nextPage: function () {
      var col = articleCol(); if (!col) return null;
      // ⚠️ 取**最近的那个 button**（可点的是 Pressable 那一层）。早先"往上走 3 层"的取法
      //    会落到两个格子之间的缝里 —— 点在那儿什么都不会发生（真输入下当场暴露）。
      var el = leaves(col).filter(function (e) { return e.textContent.trim().indexOf('下一页') === 0; })[0];
      if (!el) return null;
      var host = el;
      while (host && host !== col && host.tagName !== 'BUTTON') host = host.parentElement;
      if (!host || host === col) host = el;
      return reveal(host);
    },
  };
})();
true
`;
