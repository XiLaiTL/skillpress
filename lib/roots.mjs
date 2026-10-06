#!/usr/bin/env node
/**
 * roots.mjs —— **四个根**的唯一算法（程序 / 仓库 / 内容 / 实例）。
 *
 * 为什么要有这个文件：这四条路径的算法原先在 **5 个文件**里各写了一遍
 * （`gen-content` / `check` / `docfacts` / `highlight` / `verify-site`），
 * 而它们共用同一套约定 —— 家规改一次就要改五处，漏一处就是"某个门在查别的目录"
 * 这种最难查的错（症状：门绿着，但查的不是你以为的那份东西）。
 *
 * ## 形状（2026-10-06 搬家后）
 *
 * ```
 * interest/
 * ├── skillpress/                     ★ **程序**（本文件住在它的 `lib/`）
 * │   ├── bin/ lib/ grammars/ …
 * │   └── （将来：moon.mod + 界面包 —— 见 PLAN.md 的 P6）
 * └── moobile/                        ★ **仓库**（内容住在它的 `skills/` 里）
 *     └── skills/                     ★ **内容**（内容根搬过一次：`.agents/skills` → `skills`）
 *         └── skillpress/scripts/.skillpress/   ★ **实例**
 * ```
 *
 * ⚠️ **程序与仓库是兄弟，不是包含关系**。搬家前程序住在 `<仓库>/examples/apps/skillpress/`，
 * 往上三层就是仓库根；搬家后往上三层会跑到 `D:\` —— 而**门不会报错**，
 * 它会安安静静地去查一个空目录（实测：`check` 报「moobile 根：D:\」、遍历整个盘、
 * 然后说"skills/ 下还没有 skill"）。所以这里**先找兄弟里的 moobile**，找不到才退回老约定。
 *
 * ## 覆盖顺序（每一个都能被显式指定 —— 「不猜」是刻意的）
 *
 * | 根 | 命令行 | 环境变量 | 默认 |
 * |---|---|---|---|
 * | 程序 | （本文件的位置） | — | `lib/` 的上一层 |
 * | 仓库 | `--repo` | `SKILLPRESS_REPO` | 兄弟 `moobile/`，退回往上三层 |
 * | 内容 | `--skills` | `SKILLPRESS_SKILLS` | `<仓库>/skills`（老仓库退回 `<仓库>/.agents/skills`） |
 * | 实例 | `--app` | `SKILLPRESS_APP_DIR` | `<内容>/skillpress/scripts/.skillpress` |
 *
 * （`docfacts` 另有 `MOOBILE_ROOT`：它查的是 moobile 的文档，与 `SKILLPRESS_REPO` 同义。）
 */
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** 程序根：本文件在 `<程序>/lib/`，往上走一层。 */
export const PROGRAM = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** `--name <值>`（没给就给 null）。 */
export function argOf(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : null;
}

/** 默认仓库根：优先"程序旁边的 moobile"，否则退回"程序往上三层"（搬家前的布局）。 */
export function defaultRepo() {
  const sibling = resolve(PROGRAM, "..", "moobile");
  if (existsSync(join(sibling, "skills")) || existsSync(join(sibling, ".agents", "skills"))) return sibling;
  return resolve(PROGRAM, "..", "..", "..");
}

/**
 * 默认内容根：**`<仓库>/skills`**；只有"这个仓库还是老约定"时才退回 `<仓库>/.agents/skills`。
 *
 * 为什么给一条规则而不是直接猜：
 *   · `skills/` 是**现在的**约定（2026-10-06 搬过去）：它是仓库里看得见的一级目录，
 *     会跟着发布包走（`.moonignore` 放行即可），也是"用这个仓库的人"会去翻的地方。
 *   · `.agents/skills/` 是**老约定**，也是 harness 的项目扫描根（rank 200）——
 *     退役是因为"给别人看的内容"和"仓库自己的门面"混在同一个点目录里，谁也说不清它是给谁的。
 * 两个都真实存在过，所以按存在性判一次；**跑的时候头一行会打印用的是哪个根**（不猜的落点在这儿）。
 */
export function defaultSkills(repo) {
  const plain = join(repo, "skills");
  if (existsSync(plain)) return plain;
  const legacy = join(repo, ".agents", "skills");
  if (existsSync(legacy)) return legacy;
  return plain; // 两个都没有：报错信息里给**现在的**约定那条
}

/** 仓库根（moobile 的根 —— 事实的家就是它）。 */
export const REPO = resolve(process.env.SKILLPRESS_REPO || argOf("--repo") || defaultRepo());

/** 内容根：7 份 skill 住在这儿。 */
export const SKILLS = resolve(
  process.env.SKILLPRESS_SKILLS || argOf("--skills") || defaultSkills(REPO),
);

/** 站点实例：一个"用程序"的 MoonBit 工程，生成物写进它的 `content/`。 */
export const APP = resolve(
  argOf("--app") || process.env.SKILLPRESS_APP_DIR || join(SKILLS, "skillpress", "scripts", ".skillpress"),
);

/** 相对**仓库根**的可读路径（报错信息里用；Windows 反斜杠统一成正斜杠）。 */
export const relRepo = (p) => p.split("\\").join("/").replace(REPO.split("\\").join("/") + "/", "");
