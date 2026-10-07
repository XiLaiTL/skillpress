# 站点实例 —— 一个「用 skillpress」的 MoonBit 工程

这个目录是**这个内容根里那批 skill 的站点**：顶栏来自首页源（`skillpress/WEBSITE.md`），
右侧那条「文档 / SKILL」切进带侧栏树的文档区，书架上是内容根里没被忽略的那些 skill。

⚠️ **界面不在这里**：顶栏 / 分栏下拉 / 侧栏树 / 正文渲染整套住在包
`XiLaiTL/skillpress/shell` 里。本目录的 `app.mbt` 只剩**接线**（把 `content` 包交给 `@shell.site`）。
想换配色与字号，改程序里的 `shell/theme.mbt` —— 用这份程序的每个站点一起变。

## 四条命令

```bash
npm install          # esbuild / react / react-dom / react-native-web / moobile-host
npm run press        # 内容源 → content/（引擎的 `tools/press.mjs`；`press:check` 是门）
npm run build        # moon build --target js → moobile-host build → esbuild → dist/
npm run serve        # 零依赖静态服务 → http://127.0.0.1:8123/
```

`node verify.mjs` 是判据入口（真 Chrome 无头，自起服务）—— 它**委托**给程序里那份，
找得到程序才跑，找不到就明说 SKIP。

## 目录

| 路径 | 是什么 |
|---|---|
| `app.mbt` | **接线**：把 `@content` 交给 `@shell.site`（≤20 行；抄界面会让它立刻变长） |
| `content/` | **生成物**：内容的值（类型在 `@shell` 里），别手改 —— 下次 `press` 就把手改抹掉 |
| `moon.work` | 工作区：让本工程吃**本地源码**而不是已发布的包（未发布时才需要） |
| `index.html` / `index.js` / `App.js` | 静态宿主三件（`#root` + `AppRegistry`） |
| `build-web.mjs` / `serve-web.mjs` | esbuild 打包（一行 `alias`：`react-native` → `react-native-web`）／零依赖服务 |

## 诚实清单

1. 打的是 **dev 模式** bundle；上生产要换 `NODE_ENV=production` + minify。
2. 产物（`node_modules/`、`_build/`、`dist/`、`moobile.js`）都不进版本库；
   只有 `content/content.generated.mbt` **要进仓库**（本工程得能独立编译）。
3. 改了内容源就必须重跑 `press`，否则站点还是旧内容 —— `press --check` 会红并指出第一处差异。
