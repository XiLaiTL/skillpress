# 站点实例 —— 一个「用 skillpress」的 MoonBit 工程

这个目录是**你这个内容仓里那批 skill 的站点**：首页来自首页源，顶栏有「首页 / 书架 / 搜索」，
书架页左边是那棵树（点箭头展开 `references/` 与 `scripts/`），文档页右栏是「本页目录」，
`⌘K`（Windows 上 `Ctrl+K`）开站内搜索。

⚠️ **界面不在这里**：顶栏 / 侧栏树 / 正文渲染 / 目录 / 搜索整套住在包
`XiLaiTL/skillpress/shell` 里。本目录的 `app.mbt` 只剩**接线**（把 `content` 包交给 `@shell.site`），
所以升级 skillpress = 所有站点一起升级。

## 四条命令

```bash
npm install          # esbuild / react / react-dom / react-native-web / moobile-host
npm run press        # 内容源 → content/ 内容包 + llms.txt + md/** + img/**（`press:check` 是门）
npm run build        # moon build --target js → 打宿主 → esbuild → dist/（默认 **prod 档**）
npm run serve        # 零依赖静态服务 → http://127.0.0.1:8123/
```

`node verify.mjs` 是站点判据入口（真 Chrome 无头、自起服务、23 条断言）：它**委托**给
skillpress 里那份 native CLI（`verify` 只有 native 那份有）；找不到程序就**明说 SKIP**，不假装通过。

改了内容源就必须重跑 `press`（否则站点还是旧内容）—— `npm run press:check` 会红并指出第一处差异。
`--skills` 已经在 `package.json` 里写好了（指向本仓的内容根）；换内容根就改那两行。

## 目录

| 路径 | 是什么 |
|---|---|
| `app.mbt` | **接线**：把 `@content` 交给 `@shell.site`（≤20 行；抄界面会让它立刻变长） |
| `content/` | **生成物**：内容的值（类型在 `@shell` 里），别手改 —— 下次 `press` 就把手改抹掉 |
| `engine.mjs` | 转发壳：`npm run press` 经它找程序根（`SKILLPRESS_ENGINE` 优先，其次生成时算好的相对路径） |
| `index.html` / `index.js` / `App.js` | 静态宿主三件（`#root` + `AppRegistry`） |
| `build-web.mjs` / `serve-web.mjs` | esbuild 打包（一行 `alias`：`react-native` → `react-native-web`／零依赖服务 |
| `moon.work` | 工作区：让本工程吃**本地程序源码**而不是已发布的包（程序已发布后可以删） |

## 诚实清单

1. **默认就是 prod 档**：`npm run build` 走 minify + `NODE_ENV=production`；要 dev 档用 `npm run build:dev`。
   档位是**构建期**的 —— 运行时再设 `NODE_ENV` 改不动已打好的产物（`dist/artifact.json` 的 `mode` 记着这一份是哪个档）。
2. 产物（`node_modules/`、`_build/`、`dist/`、`moobile.js`、`img/`）都不进版本库；
   只有 `content/content.generated.mbt` **要进仓库**（本工程得能独立编译）。
3. 首屏是空壳（客户端渲染、预渲染还没做）；行内图片（不独占一行的 `![alt](x.png)`）会被当成链接。
