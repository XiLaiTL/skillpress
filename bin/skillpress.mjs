#!/usr/bin/env node
// skillpress —— 程序的门面（子命令都只是转发，实现全在 `../lib/`）。
//
//   node bin/skillpress.mjs <子命令> [参数]        （在**程序根**跑；程序自己是一个仓库）
//   node ../skillpress/bin/skillpress.mjs <子命令> （在**内容仓** moobile/ 里跑时）
//
//     press    内容源 → 站点实例的内容包（`--check` 是门：生成物与源必须一致）
//     check    门：skill 自己（G1–G8；`--selftest` 造诱饵证伪门本身）
//     facts    门：**事实来源**（moobile 的 docs 有没有撒谎）
//     audit    上色的闸门（召回率 / 漏色比例；它是 `highlight.mjs --audit`）
//     verify   站点判据（真 Chrome 无头，自起静态服务）
//     pack     把一个 / 一组 skill 打成**便携目录**            —— **还没做**
//     attach   挂进一个已有项目（写 skills/ 骨架 + 实例 + npm scripts）—— **还没做**
//
// 四个根（都能用参数/环境变量改，见 `lib/gen-content.mjs` 的文件头）：
//   <程序> = 本仓库根（`interest/skillpress`）｜ <仓库> = moobile 的根（程序旁边的兄弟）
//   <内容> = `<仓库>/skills`            ｜ <实例> = `<内容>/skillpress/scripts/.skillpress`
//
// 为什么要有这层门面：`lib/` 里的文件是给人"读实现"的（名字也按实现起的），
// 而文档里该出现的是**稳定、可复制**的命令 —— 换实现不该改文档。
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const LIB = join(HERE, "..", "lib");

const CMDS = {
  press: { file: "gen-content.mjs" },
  check: { file: "check.mjs" },
  facts: { file: "docfacts.mjs" },
  audit: { file: "highlight.mjs", extra: ["--audit"] },
  verify: { file: "verify-site.mjs" },
  pack: { todo: "把一组 skill 打成便携目录（自带引擎副本 + 生成的首页 skill）" },
  attach: { todo: "挂进一个已有项目：写 skills/ 骨架 + 站点实例 + npm scripts" },
};

const USAGE = `skillpress —— 把一堆 skill 印成一个站点

用法：
  node bin/skillpress.mjs <子命令> [参数]           # 在**程序根**（本仓库）跑

  内容仓在别处时，程序与仓库是**兄弟**（interest/moobile 与 interest/skillpress），
  在内容仓里跑就是   node ../skillpress/bin/skillpress.mjs <子命令>
  仓库不在兄弟位置时，用 --repo <仓库根> 或 SKILLPRESS_REPO 显式指定（**它不猜**，
  见 lib/roots.mjs —— 猜错的表现是"站点没更新"，最难查的一类症状）。

子命令：
  press     内容源 → 站点实例的内容包（--check 是门）
  check     门：skill 自己（--selftest 是门自己的证伪）
  facts     门：事实来源（moobile 的 docs 有没有撒谎）
  audit     上色的闸门（召回率 / 漏色比例）
  verify    站点判据（真 Chrome 无头 + 自起静态服务；--shot f.png 顺手截首屏）
  pack      打便携目录                                        —— 还没做
  attach    挂进一个已有项目                                  —— 还没做

公共参数：--repo <仓库根> ｜ --skills <内容根> ｜ --app <站点实例> ｜ --root <moobile 根>
`;

const [cmd, ...rest] = process.argv.slice(2);
if (!cmd || cmd === "-h" || cmd === "--help" || cmd === "help") {
  process.stdout.write(USAGE);
  process.exit(0);
}
const spec = CMDS[cmd];
if (!spec) {
  console.error(`不认识的子命令：${cmd}\n`);
  process.stdout.write(USAGE);
  process.exit(2);
}
if (spec.todo) {
  // 诚实：没做的**说没做**，别让它看起来像"跑了但没输出"
  console.error(`✗ ${cmd} 还没做：${spec.todo}`);
  console.error("  计划与前置条件写在程序根的 SPEC.md 与内容侧的 references/layout.md。");
  process.exit(2);
}

const args = [join(LIB, spec.file), ...(spec.extra ?? []), ...rest];
const r = spawnSync(process.execPath, args, { stdio: "inherit" });
process.exit(r.status ?? 2);
