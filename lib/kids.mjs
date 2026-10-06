#!/usr/bin/env node
/**
 * kids.mjs —— **一个 skill 目录里有哪些"子页"**（三处共用：`gen-content` / `check` / `verify-site`）。
 *
 * ## 规矩：位置不限，扩展名决定形态
 *
 * - **任何子目录里的 `.md`** 都是子页（`SKILL.md` 除外 —— 那是主文档）；
 *   `references/` 只是**推荐**放深水区的地方，不是硬性位置。放 `docs/`、`notes/`… 一样收。
 * - `scripts/` 下的**非 md 文件**按可跑脚本收（在站点上以代码块展示）。
 * - **产物目录与点开头的目录一律跳过**：`node_modules/`、`_build/`、`dist/`、`.mooncakes/`、
 *   以及任何以 `.` 开头的目录（站点实例就住在 `scripts/.skillpress/` 里 —— 不跳过的话，
 *   它的 `README.md` 和 `node_modules/**` 的几千个 md 会被当成子页收进来）。
 *
 * ## 名字怎么起（站点侧栏上显示的那个）
 *
 * `references/x.md` → `x`（约定目录，去掉前缀更清爽）；其余按**相对路径**去掉扩展名
 * （`docs/gates.md` → `docs/gates`）。名字撞了（`references/x.md` 与 `x.md`）就都退回全路径 ——
 * 宁可长一点，也不要两个同名的子页。
 */
import { readdirSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

/** 一律跳过的目录名（产物 / 依赖 / 版本库元数据）。 */
export const SKIP_DIRS = new Set([
  "node_modules",
  "_build",
  "dist",
  "target",
  ".mooncakes",
  ".git",
  ".scratch",
]);

const skip = (name) => SKIP_DIRS.has(name) || name.startsWith(".");

/** 一个 skill 目录下所有 md（除 `SKILL.md`），按相对路径排序 —— 生成物才稳定。 */
export function mdFiles(skillDir) {
  const out = [];
  const walk = (dir, prefix) => {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries.sort((a, b) => a.name.localeCompare(b.name))) {
      if (skip(e.name)) continue;
      const abs = join(dir, e.name);
      const rel = prefix ? `${prefix}/${e.name}` : e.name;
      if (e.isDirectory()) walk(abs, rel);
      else if (e.name.endsWith(".md") && rel !== "SKILL.md") out.push({ rel, abs });
    }
  };
  walk(skillDir, "");
  return out;
}

/** `scripts/` 下**直接**放着的非 md 文件（脚本按代码块展示）。 */
export function scriptFiles(skillDir) {
  const dir = join(skillDir, "scripts");
  try {
    return readdirSync(dir)
      .filter((f) => !skip(f) && !f.endsWith(".md") && statSync(join(dir, f)).isFile())
      .sort()
      .map((f) => ({ rel: `scripts/${f}`, abs: join(dir, f) }));
  } catch {
    return [];
  }
}

/** 相对路径 → 侧栏上显示的名字（去掉 `.md`；`references/` 前缀不显示）。 */
export function kidName(rel) {
  const noExt = rel.replace(/\.md$/, "");
  return noExt.startsWith("references/") ? noExt.slice("references/".length) : noExt;
}

/**
 * 把一组文件映射成"名字 → 文件"，并在**名字撞车**时全部退回相对路径。
 * 返回 `Array<{ name, rel, abs }>`（顺序保持传入顺序）。
 */
export function nameKids(files) {
  const names = files.map((f) => kidName(f.rel));
  const dup = new Set(names.filter((n, i) => names.indexOf(n) !== i));
  return files.map((f, i) => ({ ...f, name: dup.has(names[i]) ? f.rel.replace(/\.md$/, "") : names[i] }));
}

/** 便于别处打印：相对内容根的可读路径（Windows 反斜杠统一成正斜杠）。 */
export const posix = (p) => p.split(sep).join("/");

export { relative };
