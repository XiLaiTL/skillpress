# template —— 站点实例模板（`skillpress attach` 的真源）

**这里是模板的唯一真源。** `attach` 生成的每一个站点实例都是从这里来的：
把 `template/instance/**` 逐个文件写出，替换掉里面的 `{{占位符}}`，再生成 `content/`。

⚠️ 别在别处再摆一份工程文件 —— 两份手写的同类文件**必然漂移**（这条是量出来的教训，
不是洁癖：另一处仓库的模板与它生成出来的工程，装门那天当场核出 3 处漏登、1 处多登）。

## 占位符（全部，别偷偷加）

| 占位符 | 值从哪来 | 出现在 |
|---|---|---|
| `{{MODULE}}` | 目标仓目录名 + `-site`（清洗成合法标识符） | `moon.mod` 的 `name`、`moon.pkg` 的 import、`package.json` 的 `name` |
| `{{ENGINE_REL}}` | **实例目录 → 程序根**的相对路径（正斜杠） | `moon.work`、`package.json`、`verify.mjs` |
| `{{HOST_DEP}}` | 宿主包 `moobile-host` 的依赖值（默认 registry 的 `^<版本>`） | `package.json` 的 dependencies |
| `{{SITE_TITLE}}` | 站名（来自首页源的 H1；没有就用仓目录名） | `index.html` 的 `<title>` |

生成器**必须断言"产物里一个占位符都不剩"**：替换漏了不会报错，只会静静编不过。

## 三条不成文的规矩（都吃过亏）

- **目录名不能以点开头**：实测 `template/.skillpress/` 会被 `moon package` **整个跳过**
  （同一份内容改叫 `template/instance/` 就一条不落）—— 而"包里缺模板"在生成器那侧是
  "找不到模板目录"（明确的报错），在包里却是一条**没人会去看**的静默差异。
  所以模板目录叫 `instance`，**生成出来的**那个目录才叫 `.skillpress`（按 SPEC 的约定）。

- **文件名映射**：模板里的 `gitignore`（没有点）写出时叫 `.gitignore` ——
  `npm pack` **永远不打 `.gitignore`**（即使单独列进 `files` 白名单），所以真源里不能带那个点。
- **不复制产物**：`node_modules/` `_build/` `dist/` `moobile.js` `content/content.generated.mbt`
  都不在模板里。最后那份由生成器**自己跑一遍内容管线**写出来（生成失败就退 2，不留半成品）。
