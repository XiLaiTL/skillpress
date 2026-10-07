#!/usr/bin/env node
/**
 * agent-http.mjs —— **Agent 出口真的取得回来吗**（真静态服务 + 真 HTTP）。
 *
 * "产物生成好了"与"浏览器能拿到"是两件事：产物在**实例根**，而站点只服务 `dist/`
 * ⇒ 没拷进 `dist/` 就永远 404，而且**不报错**（这正是要单独量一次的理由）。
 *
 * ⚠️ 静态服务用 `file.startsWith(dist)` 挡路径穿越 ⇒ 传进去的 dist 必须与 `path.resolve` 同形
 *    （Windows 反斜杠）。传正斜杠会被判成越界、一律 404 —— 我第一次就踩了，读数是**假红**。
 *
 * 用法：node tools/agent-http.mjs [--app <实例目录>]
 */
import path from "node:path";
import { pathToFileURL } from "node:url";

function argOf(n, d) { const i = process.argv.indexOf(n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
const APP = path.resolve(argOf("--app", "skills/skillpress/scripts/.skillpress"));
const DIST = path.join(APP, "dist");
const { createStaticServer } = await import(pathToFileURL(path.join(APP, "serve-web.mjs")).href);

const s = createStaticServer(DIST);
await new Promise((r) => s.listen(0, "127.0.0.1", r));
const base = `http://127.0.0.1:${s.address().port}`;
let bad = 0;
for (const p of ["/llms.txt", "/md/moobile-app-development/SKILL.md", "/md/moobile-app-development/references/events-and-subs.md"]) {
  const r = await fetch(base + p);
  const t = await r.text();
  const ok = r.ok && t.length > 0;
  if (!ok) bad++;
  console.log(`${ok ? "✓" : "✗"} ${p} → ${r.status} ${t.length}B 首行=${JSON.stringify(t.split("\n")[0].slice(0, 44))}`);
}
s.close();
setTimeout(() => process.exit(bad ? 1 : 0), 50);
