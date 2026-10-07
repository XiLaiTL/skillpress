#!/usr/bin/env node
// cdp.mjs —— **真输入**那一层：起无头 Chrome、连 CDP、发真鼠标/真按键。
//
// ## 为什么非要它（不是洁癖，是判据的可信度）
//
// 2026-10-07 实测（`tools/ui-probe*.mjs` 的窄屏那条红）：**合成事件在这套宿主上会静默失效** ——
// 页面里 `el.dispatchEvent(new MouseEvent('click', …))` 有时**根本到不了处理器**：
// 按钮既不高亮、面板也不出，而 `window.onerror` 与 `console.error` **各 0 条**。
// 既然"点没点着"连报错都不给，那么**所有靠合成点击得出的绿都可能是假的** ——
// 这正是本仓最忌讳的形状（"看起来点了、其实没点"）。
// ⇒ 交互一律走 CDP 的 `Input.dispatchMouseEvent`（真鼠标）与 `Input.dispatchKeyEvent`（真按键）。
//
// ## ⚠️ 零 npm 依赖
//
// 用 **Node 22+ 自带的 `globalThis.WebSocket`**（本机 Node 24）直连 CDP，**不引 `ws` 包** ——
// 这个仓"拿到包的人不用装依赖"是卖点，探针也不该破它。
//
// ## 用法
//
// ```js
// const cdp = await connect(await launch({ width: 900, height: 900 }));
// await cdp.viewport(1440, 900);          // 真 CSS 视口（不是拖窗口、不是 iframe）
// await cdp.call("Page.navigate", { url });
// const v = await cdp.eval("document.title");
// await cdp.click(120, 300);              // 真鼠标：mousePressed + mouseReleased
// await cdp.key("Escape");                // 真按键：keyDown + keyUp
// cdp.close();                            // 关页面与 Chrome
// ```
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/// 找一个空闲端口（问内核要一个，再放开 —— 比写死 9222 稳）。
async function freePort() {
  return new Promise((done) => {
    const srv = createServer();
    srv.listen(0, "127.0.0.1", () => {
      const p = srv.address().port;
      srv.close(() => done(p));
    });
  });
}

export const CHROME = [process.env.CHROME,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].filter(Boolean).find((p) => existsSync(p));

/// 起一个无头 Chrome，返回它的 CDP WebSocket 地址。
///
/// `width/height` 是**初始窗口**（随后用 `Emulation.setDeviceMetricsOverride` 改视口）。
export async function launch({ width = 1200, height = 900, chrome = CHROME, extra = [] } = {}) {
  if (!chrome) throw new Error("找不到 Chrome/Edge（设 CHROME 环境变量）");
  const port = await freePort();
  const profile = mkdtempSync(join(tmpdir(), "ui-probe-cdp-"));
  const proc = spawn(chrome, [
    "--headless=new", "--disable-gpu", "--no-first-run", "--no-sandbox",
    "--hide-scrollbars", "--disable-extensions",
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
    `--window-size=${width},${height}`,
    ...extra, "about:blank",
  ], { stdio: ["ignore", "pipe", "pipe"] });
  proc.stdout.on("data", () => {});
  proc.stderr.on("data", () => {});          // ⚠️ 必须排空：管道不读会被写满 ⇒ Chrome 卡死
  // 等调试端口起来（最多 20s）：`/json/list` 里出现一个 page target
  const deadline = Date.now() + 20000;
  let wsUrl = null;
  while (Date.now() < deadline && !wsUrl) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/list`);
      const list = await r.json();
      const page = list.find((t) => t.type === "page" && t.webSocketDebuggerUrl);
      if (page) wsUrl = page.webSocketDebuggerUrl;
    } catch { /* 还没起来 */ }
    if (!wsUrl) await new Promise((r) => setTimeout(r, 150));
  }
  if (!wsUrl) { try { proc.kill(); } catch {} throw new Error("等不到 Chrome 的调试端口"); }
  return { proc, wsUrl, port };
}

/// 一条 CDP 会话（请求/响应 + 事件）。
export class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.seq = 0;
    this.pending = new Map();
    this.events = [];                       // 事件全收着（控制台报错从这儿读）
    ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id !== undefined && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(msg.method + " → " + JSON.stringify(msg.error))) : resolve(msg.result);
      } else if (msg.method) {
        this.events.push(msg);
      }
    });
  }

  static async connect(wsUrl) {
    const ws = new WebSocket(wsUrl);            // ⚠️ Node 自带的 WebSocket，零依赖
    await new Promise((ok, no) => {
      ws.addEventListener("open", ok, { once: true });
      ws.addEventListener("error", () => no(new Error("CDP WebSocket 连不上：" + wsUrl)), { once: true });
    });
    return new Cdp(ws);
  }

  call(method, params = {}) {
    const id = ++this.seq;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (this.pending.has(id)) { this.pending.delete(id); reject(new Error("CDP 超时：" + method)); }
      }, 30000);
    });
  }

  /// 在页面里求一个表达式（`returnByValue`）——**读数**都走这儿。
  async eval(expr) {
    const r = await this.call("Runtime.evaluate", {
      expression: expr, returnByValue: true, awaitPromise: true,
    });
    if (r.exceptionDetails) throw new Error("页面里抛了：" + (r.exceptionDetails.text || "") + " " + JSON.stringify(r.exceptionDetails.exception || {}).slice(0, 200));
    return r.result.value;
  }

  /// **真鼠标点击**（按下 + 抬起，坐标是 CSS 像素、视口左上角为原点）。
  async click(x, y) {
    const base = { x: Math.round(x), y: Math.round(y), button: "left", clickCount: 1 };
    await this.call("Input.dispatchMouseEvent", { type: "mouseMoved", ...base });
    await this.call("Input.dispatchMouseEvent", { type: "mousePressed", ...base });
    await this.call("Input.dispatchMouseEvent", { type: "mouseReleased", ...base });
  }

  /// **真按键**（如 `Escape`）。`code` 缺省时按 `key` 推一个。
  async key(key, code = null) {
    const map = { Escape: "Escape", Enter: "Enter", ArrowDown: "ArrowDown", ArrowUp: "ArrowUp" };
    const c = code || map[key] || key;
    for (const type of ["keyDown", "keyUp"]) {
      await this.call("Input.dispatchKeyEvent", { type, key, code: c, windowsVirtualKeyCode: key === "Escape" ? 27 : 0 });
    }
  }

  /// 真 CSS 视口（**不是** iframe、**不是**拖窗口 —— 无头 Chrome 的窗口有最小宽）。
  async viewport(width, height) {
    await this.call("Emulation.setDeviceMetricsOverride", {
      width, height, deviceScaleFactor: 1, mobile: false,
    });
    await new Promise((r) => setTimeout(r, 400));
  }

  /// 控制台里的 error（`Runtime.consoleAPICalled`）。favicon 的 404 由调用方过滤。
  consoleErrors() {
    const out = [];
    for (const e of this.events) {
      if (e.method === "Runtime.consoleAPICalled" && e.params.type === "error") {
        out.push((e.params.args || []).map((a) => a.value ?? a.description ?? a.type).join(" "));
      }
    }
    return out;
  }

  /// 页面自己抛的异常（`Runtime.exceptionThrown`）。
  pageErrors() {
    return this.events.filter((e) => e.method === "Runtime.exceptionThrown")
      .map((e) => e.params.exceptionDetails.text + " " + (e.params.exceptionDetails.exception?.description || ""));
  }

  async close() {
    try { this.ws.close(); } catch {}
  }
}

/// 起 Chrome + 连 CDP + 打开必需的域（一步到位，省得每条判据都记三行）。
export async function open(opts = {}) {
  const { proc, wsUrl } = await launch(opts);
  const cdp = await Cdp.connect(wsUrl);
  await cdp.call("Page.enable");
  await cdp.call("Runtime.enable");
  await cdp.call("Log.enable");
  cdp.proc = proc;
  cdp.kill = () => { try { proc.kill(); } catch {} };
  return cdp;
}
