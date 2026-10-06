#!/usr/bin/env node
/**
 * dom-dump.mjs —— 把站点实例**渲染出来的 DOM** 存一份（P6 搬界面的对账证据）。
 *
 * ## 为什么要它
 *
 * P6 把实例里的界面（`app.mbt`，1000+ 行）搬进了包的 `shell/`。搬完之后两边都**编译得过**
 * 这件事**不构成**证据：少画一个块、少一个下拉菜单、顺序换一条，编译器一声不响。
 * 真正能证明"搬过去没搬坏"的，是**同一个 bundle 在真浏览器里渲出来的 DOM 逐字节相同**。
 *
 * ## 用法
 *
 *   node tools/dom-dump.mjs --app <实例目录> [--out <文件>] [--budget 20000] [--port 8123]
 *
 * 打印：bundle 的 sha256（**这份快照到底是谁的产物**）+ 落盘路径。
 * 对账：
 *   node tools/dom-dump.mjs --app <实例> --out /tmp/dom-a.html     # 搬之前
 *   node tools/dom-dump.mjs --app <实例> --out /tmp/dom-b.html     # 搬之后
 *   diff /tmp/dom-a.html /tmp/dom-b.html
 *
 * ## ⚠️ 两个"仪器本身"的坑（都实测过）
 *
 * 1. **`--dump-dom` 默认在 load 事件就抓**，而这个站点的内容是 wasm/JS 起来之后**异步**渲的 ——
 *    不加 `--virtual-time-budget` 会抓到一具空壳（`<div id="root"></div>`），
 *    然后"两次快照一模一样"就成了假绿。所以预算默认给 20 秒。
 * 2. **仪器要先自证**：同一份 bundle 连抓两次必须逐字节相同，否则它证明不了任何东西。
 *    先 `--app <实例> --out a --repeat 2`（两次结果直接比），绿了再去比"搬之前/之后"。
 *
 * ## 为什么复用实例自己的静态服务
 *
 * `serve-web.mjs` 导出 `createStaticServer()` —— 用它就不用在这里再写一份静态服务
 * （也就不会出现"判据读的是另一个目录"这种最难查的错）。
 */
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

/** `--key value` 取值。 */
function argOf(name, dflt = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}

/** Chrome 的位置（与 `lib/verify-site.mjs` 同一套候选；`CHROME` 可以覆盖）。 */
function findChrome() {
  const win = process.env.SystemRoot ? join(process.env.SystemRoot, "..") : "C:/";
  const cands = [
    process.env.CHROME,
    join(process.env.ProgramFiles || join(win, "Program Files"), "Google/Chrome/Application/chrome.exe"),
    join(process.env["ProgramFiles(x86)"] || join(win, "Program Files (x86)"), "Google/Chrome/Application/chrome.exe"),
    join(process.env.LOCALAPPDATA || "", "Google/Chrome/Application/chrome.exe"),
    "/usr/bin/google-chrome",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ].filter(Boolean);
  return cands.find((p) => existsSync(p)) || null;
}

/** 抓一次 DOM（返回 HTML 字符串）。 */
async function dumpOnce(app, port, budget) {
  const { createStaticServer } = await import(pathToFileURL(join(app, "serve-web.mjs")).href);
  const server = createStaticServer(join(app, "dist"));
  await new Promise((ok, no) => server.listen(port, "127.0.0.1", ok).on("error", no));
  const chrome = findChrome();
  if (!chrome) {
    server.close();
    throw new Error("找不到 Chrome（用 CHROME=<chrome.exe 路径> 指定）");
  }
  const profile = mkdtempSync(join(tmpdir(), "skillpress-dom-"));
  const args = [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    `--user-data-dir=${profile}`,
    `--virtual-time-budget=${budget}`,
    "--dump-dom",
    `http://127.0.0.1:${port}/`,
  ];
  try {
    // ⚠️ **必须异步 spawn，不能用 spawnSync / execFileSync**：同步版会把 Node 的事件循环
    //    **整个堵住**，于是**同一个进程里**那个静态服务永远答不上 Chrome 的请求 ——
    //    Chrome 就在那儿等到超时（实测症状：`exit=null`；把服务换成另一个进程、命令行手跑
    //    同一个 Chrome 却是好的 ⇒ 真因是"同步子进程 + 同进程服务"死锁，**与 Chrome 无关**）。
    const r = await new Promise((ok, no) => {
      const child = spawn(chrome, args);
      let out = "";
      let err = "";
      const timer = setTimeout(() => {
        child.kill();
        no(new Error(`Chrome 超过 ${(budget + 60000) / 1000}s 没退出`));
      }, budget + 60000);
      child.stdout.on("data", (d) => (out += d));
      child.stderr.on("data", (d) => (err += d));
      child.on("error", (e) => {
        clearTimeout(timer);
        no(e);
      });
      child.on("close", (code) => {
        clearTimeout(timer);
        ok({ code, out, err });
      });
    });
    // Chrome 在 Windows 上**经常**非零退出（`update_service_dialer` / GPU 一堆噪声），
    // 但 stdout 里那份 DOM 是好的 —— 所以判据是"stdout 里有没有 `<html`"，不是退出码。
    // （反过来说：拿退出码当判据，这台仪器会**永远红**。）
    if (!/<html/i.test(r.out)) {
      const cand = r.err.split("\n").filter((l) => /ERROR|FATAL/i.test(l)).slice(0, 3).join("\n  ");
      throw new Error(`Chrome 没吐出 DOM（exit=${r.code}）${cand ? "\n  真因候选（stderr 里的 ERROR 行）：\n  " + cand : ""}`);
    }
    return r.out;
  } finally {
    server.close();
  }
}

const APP = resolve(argOf("--app", process.cwd()));
const OUT = argOf("--out");
const BUDGET = Number(argOf("--budget", "20000"));
const PORT = Number(argOf("--port", "8123"));
const REPEAT = Number(argOf("--repeat", "1"));

if (!existsSync(join(APP, "dist/index.html"))) {
  console.error(`dom-dump: ${APP}/dist/index.html 不存在 —— 先在该目录跑 \`npm run build\``);
  process.exit(2);
}
const bundle = join(APP, "dist/bundle.js");
const sha = existsSync(bundle) ? createHash("sha256").update(readFileSync(bundle)).digest("hex") : "（没有 bundle.js）";
console.log(`bundle.js sha256 = ${sha}`);

const dumps = [];
for (let i = 0; i < REPEAT; i++) {
  dumps.push(await dumpOnce(APP, PORT, BUDGET));
}
if (REPEAT > 1) {
  const same = dumps.every((d) => d === dumps[0]);
  console.log(same ? `✓ 仪器自证：连抓 ${REPEAT} 次逐字节相同（${dumps[0].length} 字节）` : `✗ 仪器不稳：${REPEAT} 次快照不一致 —— 别用它当证据`);
  if (!same) process.exit(1);
}
if (OUT) {
  writeFileSync(OUT, dumps[0]);
  console.log(`✓ 快照落盘：${OUT}（${dumps[0].length} 字节）`);
} else {
  process.stdout.write(dumps[0]);
}
