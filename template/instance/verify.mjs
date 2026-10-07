#!/usr/bin/env node
// verify.mjs —— 本实例的**判据入口**：**委托**给 skillpress 引擎里那份，不在这里重写一套。
//
// 为什么委托（而不是另写一份断言）：站点的判据有一半是"**渲染出来的内容与内容源逐字一致**"，
// 那要以内容根里的 `SKILL.md` 为准；在这里重写等于又造一份会漂的实现。
//
//   node verify.mjs          # = 引擎的 `skillpress-native verify`（真 Chrome 无头 + 进程内静态服务）
//
// ⚠️ **判据本体在 native 那份 CLI 里**（`skillpress-native verify`）：站点判据要 async 的
//    http server / websocket / process，而它们在 `moonbitlang/async` 的 **js 目标上没有实现**
//    ⇒ 这条路**要一次 native 编译**（C 工具链）。这个 wrapper 自己**不需要** Node 跑判据逻辑，
//    它只是把"引擎在哪"与"本实例在哪"接上去。
//
// 引擎在哪：环境变量 `SKILLPRESS_ENGINE` 优先；否则按生成时算好的那条
// "实例 → 程序根"路径找。找不到、或者引擎还没编过 ⇒ **SKIP 并说清怎么办**（要大声说出来）——
// 这个实例可以被单独拿走，但那时它自己没有判据，真门在 skillpress 那边。
//
// ⚠️ 这个文件是 **ESM**（`.mjs`）：**不能写 `require`**。踩过一次，症状是
//    `ReferenceError: require is not defined in ES module scope` —— 而那行报错看着像
//    "文件写错了"，其实是"整份判据**根本跑不起来**"（入口脚本坏掉时，很容易被当成"这条判据没过"）。
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
/**
 * 往上找"程序根"：带 `moon.mod` **且**带 `cmd/skillpress-native` 的那一级。
 *
 * ⚠️ 为什么不能只认 `{{ENGINE_REL}}`：**自举那份实例**（引擎自己仓里的
 * `skills/skillpress/scripts/.skillpress`）里生成时那个占位符是**空串**
 * （它是从仓内跑的，不需要"往上几层"这个提示）⇒ 只认占位符会在自举上直接 SKIP。
 * 往上走几层是稳的：实例永远住在程序里（或旁边的兄弟仓里）。
 */
function findEngine() {
  const seen = [];
  const explicit = process.env.SKILLPRESS_ENGINE && path.resolve(process.env.SKILLPRESS_ENGINE);
  if (explicit) seen.push(explicit);
  seen.push(path.resolve(HERE, '{{ENGINE_REL}}'));
  let up = HERE;
  for (let i = 0; i < 6; i++) {
    seen.push(up);
    up = path.dirname(up);
  }
  return seen.find(
    (p) => p && fs.existsSync(path.join(p, 'moon.mod')) && fs.existsSync(path.join(p, 'cmd', 'skillpress-native')),
  );
}

const ENGINE = findEngine();

/** 编出来的 native CLI（`moon build cmd/skillpress-native --target native` 的产物）。 */
const CLI = ENGINE
  ? [
      path.join(ENGINE, '_build/native/debug/build/cmd/skillpress-native/skillpress-native.exe'),
      path.join(ENGINE, '_build/native/debug/build/cmd/skillpress-native/skillpress-native'),
      path.join(ENGINE, '_build/install-bin/skillpress-native.exe'),
    ].find((p) => fs.existsSync(p))
  : null;

if (!ENGINE || !CLI) {
  console.log('SKIP：还跑不了站点判据 —— 先把引擎编出来（判据本体在 native 那份 CLI 里）：');
  if (ENGINE) {
    console.log(`      moon -C "${ENGINE}" build cmd/skillpress-native --target native`);
    console.log(`      node "${CLI ?? path.join(ENGINE, '_build/native/debug/build/cmd/skillpress-native/skillpress-native.exe')}" verify --app "${HERE}"`);
    console.log('      ⚠️ 它**只有 native 那份有**：js 那条路上 moonbitlang/async 没有 http server / websocket / process。');
  } else {
    console.log('      找不到 skillpress 引擎 —— 站点判据在 skillpress 那边跑：');
    console.log(`      SKILLPRESS_ENGINE=<程序根> node "${HERE}/verify.mjs"`);
  }
  console.log(`      找过：${ENGINE ?? '(没找到带 moon.mod 的程序根)'}`);
  process.exit(0);
}

// 实例住在**内容根**里：`<内容根>/skillpress/scripts/.skillpress` ⇒ 往上三层就是它。
// ⚠️ 必须**显式传**：CLI 的默认值是"程序根的兄弟 moobile/skills"，而这个实例的内容根
//    可能完全不叫那个名字（换一个内容仓时就是）—— 默认值不是"这一个实例"的答案。
const CONTENT = path.resolve(HERE, '..', '..', '..');
const REPO = path.dirname(CONTENT);
const args = ['verify', '--app', HERE];
if (!process.argv.includes('--skills') && fs.existsSync(path.join(CONTENT, 'skillpress'))) {
  args.push('--skills', CONTENT, '--repo', REPO);
}
args.push(...process.argv.slice(2));

// 让 CLI 知道"程序根在哪"（native 没有引导层，这条提示由环境变量给 —— 与 SKILLPRESS_PROGRAM 同一口径）。
const r = spawnSync(CLI, args, {
  stdio: 'inherit',
  cwd: HERE,
  env: { ...process.env, SKILLPRESS_PROGRAM: ENGINE },
});
process.exit(r.status ?? 2);
