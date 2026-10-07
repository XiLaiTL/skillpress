# VitePress 能力边界调研（以官网 docs 为准）

**版本口径（重要）**：`vitepress.dev` 当前官方 docs 对应 **2.0.0-alpha.20**（npm dist-tags: `latest=1.6.4`, `next=2.0.0-alpha.20`，见 `curl https://registry.npmjs.org/-/package/vitepress/dist-tags`）。下文结论以官网 docs（2.0 线）为准；标注「实测」的条目由本地探针验证：`vitepress@1.6.4` 构建于 `D:\ai_project\interest\vp-probe`，同时对照 main 分支源码。
**取证方式**：官网文档页 + main 分支源码（src/、docs/）+ 本地构建产物 grep。凡未查实一律写「未查实」。

## A. Markdown 扩展（内容里能写什么）

### A1 内置 Markdown 扩展

- 自定义容器内置 5 类：`info` / `tip` / `warning` / `danger` / `details`，写法 `::: tip`，可自定义标题 `::: danger STOP`、可嵌套（外层 fence 需比内层长，如 `::::`）——[guide/markdown#custom-containers](https://vitepress.dev/guide/markdown#custom-containers)。
- 容器默认标题可全局改：`markdown.container.tipLabel / warningLabel / dangerLabel / infoLabel / detailsLabel`，并可注册新容器 `markdown.container.customContainers: { success: 'SUCCESS' }`（新容器不带样式，需自己写 `.custom-block.success`）——[guide/markdown#registering-new-containers](https://vitepress.dev/guide/markdown#registering-new-containers)。
- 容器可加任意属性（由 `@mdit/plugin-attrs` 提供）：`::: details Click {open}`、`::: tip {no-title}`——[guide/markdown#additional-attributes](https://vitepress.dev/guide/markdown#additional-attributes)。
- `::: raw` 容器把内容包进 `<div class="vp-raw">`，用于避免与 VitePress 样式/路由冲突（文档化组件库时常用）——[guide/markdown#raw](https://vitepress.dev/guide/markdown#raw)。
- GitHub 风格 alerts 也支持：`> [!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]`，另有 VitePress 扩展的 `[!DANGER]`；`themeConfig.gradedContainers: true` 改为分级配色——[guide/markdown#github-flavored-alerts](https://vitepress.dev/guide/markdown#github-flavored-alerts)。
- 代码高亮用 Shiki，语言别名写在 ``` 后；可配 `markdown.theme`（支持 `{ light, dark }` 双主题）、`languages`、`languageAlias`、`languageLabel`、`defaultHighlightLang`、`codeTransformers`、`colorReplacements`、`shikiSetup`——[reference/site-config#markdown](https://vitepress.dev/reference/site-config#markdown) + [src/node/markdown/markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)。
- 行高亮语法：```js{4}、```js{1,4,6-8}（范围/多行/混合都支持）；行内注释写法 `// [!code highlight]`——[guide/markdown#line-highlighting-in-code-blocks](https://vitepress.dev/guide/markdown#line-highlighting-in-code-blocks)。
- focus：`// [!code focus]` 或 `// [!code focus:<lines>]`——[guide/markdown#focus-in-code-blocks](https://vitepress.dev/guide/markdown#focus-in-code-blocks)。
- diff：`// [!code --]` / `// [!code ++]`；另有 `// [!code error]` / `// [!code warning]` 行着色——[guide/markdown#colored-diffs-in-code-blocks](https://vitepress.dev/guide/markdown#colored-diffs-in-code-blocks)。
- 行号：全局 `markdown.lineNumbers: true`，逐块覆盖用 ```ts:line-numbers / :no-line-numbers / :line-numbers=2——[guide/markdown#line-numbers](https://vitepress.dev/guide/markdown#line-numbers)。
- 代码组：`::: code-group` 包多个围栏块，块名 ` ```js [config.js] ` 即标签名——[guide/markdown#code-groups](https://vitepress.dev/guide/markdown#code-groups)。
- 从文件导入代码片段：`<<< @/filepath{1,2,4-6 ts:line-numbers}`，支持 VS Code region `#region`，`@` = 源根（`srcDir`）；不存在文件默认报构建错误，`markdown.snippet.silent: true` 改为警告——[guide/markdown#import-code-snippets](https://vitepress.dev/guide/markdown#import-code-snippets)。
- Markdown 文件内联：`<!--@@include: ./parts/basics.md{3,}-->`，支持行范围、region、heading 锚点、在围栏内包含代码文件；`markdown.include.silent`、`markdown.include.rebaseRelativeUrls` 控制例外——[guide/markdown#markdown-file-inclusion](https://vitepress.dev/guide/markdown#markdown-file-inclusion)。
- 数学公式是**opt-in**：需 `npm add -D markdown-it-mathjax3@^4` 且 `markdown: { math: true }`，行内 `$...$`、块级 `$$...$$`（含表格单元格）；不装则原样输出（实测）——[guide/markdown#math-equations](https://vitepress.dev/guide/markdown#math-equations)。
- 图片懒加载：`markdown: { image: { lazyLoad: true } }`（默认关）——[guide/markdown#image-lazy-loading](https://vitepress.dev/guide/markdown#image-lazy-loading)。
- emoji：`:tada:` `:100:` 直接写（`markdown.emoji: false` 可关）；除 emoji 外还有 GFM 表格、任务列表 `- [ ]`、脚注 `[^1]` 与行内 `^[note]`、`[[toc]]`——[guide/markdown](https://vitepress.dev/guide/markdown)。
- 锚点规则：标题自动加锚点链接（`markdown.anchor` 控制，`false` 则连 id 都不加，默认主题 outline 依赖它），自定义锚点写 `# Title {#my-anchor}`；标题里的 `html_inline` 与 emoji token 不参与 slug 计算——[guide/markdown#header-anchors](https://vitepress.dev/guide/markdown#header-anchors) + [markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)。
- slug 具体算法（`@mdit-vue/shared` 的 `slugify`）：NFKD 归一 → 去组合音标 → 去控制字符 → 空白与 ``~`!@#$%^&*()\-_+=[]{}|\;:"'“”‘’<>,.?/`` 全部替换为 `-` → 合并连续 `-` → 去首尾 `-` → **以数字开头则前缀 `_`** → 全小写；中文因不在特殊字符集里会被原样保留——[mdit-vue slugify.ts](https://github.com/mdit-vue/mdit-vue/blob/main/packages/shared/src/slugify.ts)。
- 内部链接会被转成 router link（SPA 导航），外链自动加 `target="_blank" rel="noreferrer"`（可用 `markdown.externalLinks` 改）——[guide/markdown#links](https://vitepress.dev/guide/markdown#links)。

### A2 在 Markdown 里写 Vue（MDX 那一路）

- 机制：每个 `.md` 先编译成 HTML，再**当作 Vue SFC 处理**，因此可直接用插值 `{{ 1 + 1 }}`、指令（`<span v-for="i in 3">{{ i }}</span>`）与任意 Vue 组件——[guide/using-vue](https://vitepress.dev/guide/using-vue)。
- `<script>` / `<style>`：根级 `<script>`、`<script setup>`、`<style module>` 与 SFC 一致，**没有 `<template>`**，其余根级内容都是 Markdown；标签必须放在 frontmatter 之后；官方建议避免 `<style scoped>`（会让页面体积膨胀），本地样式用 `<style module>`——[guide/using-vue#script-and-style](https://vitepress.dev/guide/using-vue#script-and-style)。
- 组件注册有两种，**不是"必须全局注册"**：少量页面用就在该页 `<script setup>` 里 `import CustomComponent from '../components/CustomComponent.vue'`（可被 code-split）；大多数页面用才建议全局注册 `enhanceApp({ app }) { app.component('MyGlobalComponent', ...) }`——[guide/using-vue#using-components](https://vitepress.dev/guide/using-vue#using-components) + [guide/extending-default-theme#registering-global-components](https://vitepress.dev/guide/extending-default-theme#registering-global-components)。
- 硬约束：组件名必须带连字符或 PascalCase，否则会被当行内元素包进 `<p>`，导致 hydration mismatch——[guide/using-vue#registering-components-globally](https://vitepress.dev/guide/using-vue#registering-components-globally)。
- SSR 约束：所有 Vue 用法都必须 SSR 兼容（只在 `beforeMount`/`mounted` 里碰 DOM）；不兼容组件用内置 `<ClientOnly>` 包住，或 `defineClientComponent(() => import(...))`、`import.meta.env.SSR` 条件导入——[guide/ssr-compat](https://vitepress.dev/guide/ssr-compat) + [reference/runtime-api#clientonly](https://vitepress.dev/reference/runtime-api#clientonly)。
- 标题里可以用组件，但 `` # text `<Tag/>` `` 会被当代码原样显示、只有**不**被 `<code>` 包裹的才会被 Vue 解析（解析出的纯文本用于侧栏与文档标题）——[guide/using-vue#using-components-in-headers](https://vitepress.dev/guide/using-vue#using-components-in-headers)。
- 转义：`<span v-pre>{{ ... }}</span>` 或 `::: v-pre` 容器；围栏代码块默认整体包 `v-pre`，要开插值需给语言加 `-vue` 后缀（如 ```js-vue）——[guide/using-vue#escaping](https://vitepress.dev/guide/using-vue#escaping)。
- 其他代价：CSS 预处理器（scss/less/stylus）需自行安装对应包；`<Teleport>` 官方只支持 target=body，其余目标要配 `<ClientOnly>` 或 `postRender` 钩子——[guide/using-vue](https://vitepress.dev/guide/using-vue)。

### A3 哪些构造会被原样透传 / 相关开关

- 原始 HTML **默认原样透传**：渲染器以 `new MarkdownItAsync({ html: true, linkify: true, ...options })` 构造，传 `markdown: { html: false }` 可改为转义——[markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)（实测：默认 `<div class="x">raw</div>` 原样输出；`{ html: false }` 输出 `&lt;div ...&gt;`）。
- `<script>`：根级会被 plugin-sfc 抽成 SFC 的 script；MPA 模式下改用 VitePress 专有的 `<script client>` 给单页挂客户端 JS（**不是** Vue 组件代码，按普通 JS module 处理）——[guide/using-vue](https://vitepress.dev/guide/using-vue) + [guide/mpa-mode](https://vitepress.dev/guide/mpa-mode)。
- HTML 注释：markdown-it 层是保留的（实测渲染结果含 `<!-- hello comment -->`），但**Vue 编译器会把注释从产物里抹掉**（实测：`dist/guide/one.html` 与编译出的页面 JS 里都 grep 不到该注释）；同时注释对 Vue **有意义**——官方明确警告别在托管平台开 HTML Auto Minify，注释被删会导致 hydration mismatch——[guide/deploy](https://vitepress.dev/guide/deploy)。
- 开关清单（`markdown` 下可逐个关掉的键）：`anchor` `toc` `emoji` `tasklist` `footnote` `attrs` `snippet` `include` `image` `container` `gfmAlerts` `tableTabIndex` `component` `frontmatter` `sfc` `headers` `lineNumbers` `preWrapper` `cjkFriendlyEmphasis` `eagerFrontmatterInterpolation`，以及 `preConfig`（内置插件之前）、`config`（全部内置插件之后）、`cache`、`locales`——[markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)。
- `markdown.headers`（默认关）决定 `useData().page.headers` 是否有数据；默认主题的 outline 不走它、直接读渲染后的标题——[reference/site-config#markdown](https://vitepress.dev/reference/site-config#markdown) + [reference/runtime-api](https://vitepress.dev/reference/runtime-api)。

## B. 主题系统与黑夜 / 白天

### B1 默认主题 `themeConfig` 全貌（主要键）

- 站点骨架类：`logo`（`string | ThemeableImage`，可 `{ light, dark }` 分开）、`siteTitle`（`string | false`）、`nav`（`NavItem[]`，支持 dropdown / `activeMatch` / `component`）、`sidebar`（`SidebarItem[] | SidebarMulti`，item 支持 `items/collapsed/base/docFooterText`）、`aside`（`boolean | 'left'`）、`outline`（`{ level: number|[n,n]|'deep', label } | false`）——[reference/default-theme-config](https://vitepress.dev/reference/default-theme-config)。
- 页面块类：`footer`（`{ message, copyright }`，无侧栏时才显示）、`editLink`（`{ pattern, text }`）、`lastUpdated`（`{ text, formatOptions }`）、`docFooter`（`{ prev, next }`，设 `false` 全局关上下页）、`carbonAds`——[reference/default-theme-config](https://vitepress.dev/reference/default-theme-config)。
- 社交与搜索：`socialLinks`（simple-icons 名 / iconify `collection:name` / 内联 SVG）、`search`（`{ provider: 'local' | 'algolia', options }`，见 D3）——[reference/default-theme-config#sociallinks](https://vitepress.dev/reference/default-theme-config#sociallinks) + [reference/default-theme-search](https://vitepress.dev/reference/default-theme-search)。
- 文案 / a11y 类：`darkModeSwitchLabel`、`lightModeSwitchTitle`、`darkModeSwitchTitle`、`sidebarMenuLabel`、`returnToTopLabel`、`langMenuLabel`、`navMenuLabel`、`mobileMenuLabel`、`extraMenuLabel`、`skipToContentLabel`、`externalLinkIcon`、`gradedContainers`、`i18nRouting`——[reference/default-theme-config](https://vitepress.dev/reference/default-theme-config)。
- 类型定义里还有两个 docs 页面未列出的键：`logoLink?: string | {...}` 与 `notFound?: NotFoundOptions`（可自定义 "PAGE NOT FOUND" 文案）——[types/default-theme.d.ts](https://github.com/vuejs/vitepress/blob/main/types/default-theme.d.ts)（**未查实**它们在文档中的正式说明与否，我 grep `docs/en/reference/*.md` 无命中）。
- 前端 composable：`useLayout()`（`isHome/sidebar/hasSidebar/hasAside/headers/hasLocalNav`），从 `vitepress/theme` 导入——[reference/default-theme-config#uselayout](https://vitepress.dev/reference/default-theme-config#uselayout)。

### B2 暗色模式实现（含防闪烁）

- 配置键 `appearance`：`boolean | 'dark' | 'force-dark' | 'force-auto' | UseDarkOptions`，默认 `true`；`true`=跟随系统且可切换，`'dark'`=默认暗但可切，`false`=不可切且亮，`'force-dark'`/`'force-auto'`=锁定（`initialValue` 仅允许 `'dark' | undefined`）——[reference/site-config#appearance](https://vitepress.dev/reference/site-config#appearance)。
- DOM 表现：在 `<html>` 上加 `.dark` 类（官方原文 "by adding the `.dark` class to the `<html>` element"）；实测产物静态 HTML 是 `<html lang="en-US" dir="ltr">`（不带 dark），dark 由脚本运行时加上——[reference/site-config#appearance](https://vitepress.dev/reference/site-config#appearance)。
- 跟随系统：走 `@vueuse/core` 的 `useDark`/`usePreferredDark`，并用 `window.matchMedia('(prefers-color-scheme: dark)')` 判定——[src/client/app/data.ts](https://github.com/vuejs/vitepress/blob/main/src/client/app/data.ts)。
- 用户选择的存储位置：`localStorage` 键名 **`vitepress-theme-appearance`**（常量 `APPEARANCE_KEY`）——[src/shared/shared.ts](https://github.com/vuejs/vitepress/blob/main/src/shared/shared.ts) + [reference/site-config#appearance](https://vitepress.dev/reference/site-config#appearance)。
- 防闪烁：构建期注入 `<head>` 内联脚本，`id="check-dark-mode"`（实测产物：读 localStorage → 否则 `prefers-color-scheme` → `document.documentElement.classList.add('dark')`）；另有 `id="check-mac-os"` 脚本加 `.mac` 类；**MPA 模式下这两个脚本都不注入**（`if (userConfig?.mpa) return head`）——[src/node/config.ts](https://github.com/vuejs/vitepress/blob/main/src/node/config.ts)。
- 运行时读取：`useData().isDark`（`Ref<boolean>`，可直接改以切换主题）——[reference/runtime-api#usedata](https://vitepress.dev/reference/runtime-api#usedata)；官方还给了基于 View Transitions API 的切换动画示例（`provide('toggle-appearance', ...)`）——[guide/extending-default-theme#on-appearance-toggle](https://vitepress.dev/guide/extending-default-theme#on-appearance-toggle)。

### B3 CSS 变量体系

- 命名前缀 `--vp-`，**浅色值写在 `:root`，深色值写在 `.dark`**，两组同名单变量成对出现——[src/client/theme-default/styles/vars.css](https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/styles/vars.css)。
- 量级：`vars.css` 内共 294 处 `--vp-` 出现、**238 个唯一变量名**；整个 `theme-default` 目录唯一变量名 247 个；实测构建出的 `assets/style.*.css` 里 228 个唯一 `--vp-*`——（本地实测 + vars.css）。
- 分组（约 24 组）：Solid、Palette、Background、Borders、Text、Function、Typography、Shadows、Z-Index、Direction、Layouts、Header Anchor、Code、Button、Custom Block、Input、Nav、Local Nav、Sidebar、Backdrop、Home、Badge、Carbon Ads、Local Search——[vars.css](https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/styles/vars.css)。
- 调色板规律：每个色系四档 `-1`（实心文字色）/`-2`（hover）/`-3`（实心背景）/`-soft`（半透明底色），色系有 `gray/indigo/purple/green/yellow/orange/red` + `--vp-c-sponsor`；功能色再映射过去：`--vp-c-default-*`、`--vp-c-brand-*`、`--vp-c-tip-*`、`--vp-c-note-*`、`--vp-c-success-*`、`--vp-c-important-*`、`--vp-c-warning-*`、`--vp-c-danger-*`、`--vp-c-caution-*`（`--vp-c-brand` 已废弃，用 `--vp-c-brand-1`）——[vars.css](https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/styles/vars.css)。
- 覆盖方式：在 `.vitepress/theme/custom.css` 里于 `:root` 覆盖并在 theme 入口 `import './custom.css'`；例如 `--vp-c-brand-1: #646cff`；深色差异值写 `.dark { ... }`；另有 `gradedContainers` 生效时用 `:root:where(:has(.vp-graded-containers))` 重映射 warning/caution——[guide/extending-default-theme#customizing-css](https://vitepress.dev/guide/extending-default-theme#customizing-css) + [vars.css](https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/styles/vars.css)。
- 换字体：从 `vitepress/theme-without-fonts` 导入默认主题以去掉 Inter（可选组件也要从该路径导入），再覆盖 `--vp-font-family-base` / `--vp-font-family-mono`——[guide/extending-default-theme#using-different-fonts](https://vitepress.dev/guide/extending-default-theme#using-different-fonts)。

### B4 自定义主题与运行时 API

- 主题入口：`.vitepress/theme/index.{js,ts}`（存在即接管默认主题），默认导出 `Theme = { Layout（唯一必需）, enhanceApp?, setup?, extends? }`——[guide/custom-theme#theme-interface](https://vitepress.dev/guide/custom-theme#theme-interface)。
- `extends: DefaultTheme`（`import DefaultTheme from 'vitepress/theme'`）可只加 CSS、全局组件或 Layout 插槽而不重写整个主题——[guide/extending-default-theme](https://vitepress.dev/guide/extending-default-theme)。
- `enhanceApp(ctx)` 拿到 `{ app, router, siteData }`，可 `app.component/app.use`；`router.onBeforeRouteChange / onBeforePageLoad / onAfterPageLoad / onAfterRouteChange` 挂路由钩子（返回 `false` 可取消导航）；`setup()` 在根组件 setup 内运行（SSR 时也会跑，浏览器逻辑要放 `onMounted`）——[guide/custom-theme](https://vitepress.dev/guide/custom-theme)。
- Layout 取值：frontmatter `layout: 'doc' | 'home' | 'page' | false`，默认 `doc`；`false` 表示完全不要布局（无侧栏/导航/页脚），用于全自定义落地页——[reference/frontmatter-config#layout](https://vitepress.dev/reference/frontmatter-config#layout) + [reference/default-theme-layout](https://vitepress.dev/reference/default-theme-layout)（源码判定即 `v-if="frontmatter.layout !== false"`，[Layout.vue](https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/Layout.vue)）。
- Layout slots 全量（默认主题，用 `extends` + `Layout: MyLayout` 或 render 函数注入）：`layout: 'doc'` 时 `doc-top` `doc-bottom` `doc-footer-before` `doc-before` `doc-after` `sidebar-nav-before` `sidebar-nav-after` `aside-top` `aside-bottom` `aside-outline-before` `aside-outline-after` `aside-ads-before` `aside-ads-after`；`layout: 'home'` 时 `home-hero-before` `home-hero-info-before` `home-hero-info` `home-hero-info-after` `home-hero-actions-before-actions` `home-hero-actions-after` `home-hero-image` `home-hero-after` `home-features-before` `home-features-after`；`layout: 'page'` 时 `page-top` `page-bottom`；404 页 `not-found`；**始终可用**：`layout-top` `layout-bottom` `nav-bar-title-before` `nav-bar-title-after` `nav-bar-content-before` `nav-bar-content-after` `nav-screen-content-before` `nav-screen-content-after`——[guide/extending-default-theme#layout-slots](https://vitepress.dev/guide/extending-default-theme#layout-slots)。
- 运行时 API：`useData()`（`site/theme/page/frontmatter/params/title/description/lang/isDark/dir/localeIndex/hash`）、`useRoute()`（`{ path, data, component }`）、`useRouter()`（`route/go/onBefore*`）、`useIcon()`、`withBase(path)`、组件 `<Content />`、`<ClientOnly />`、模板全局 `$frontmatter` / `$params`、`defineClientComponent()`——[reference/runtime-api](https://vitepress.dev/reference/runtime-api)。
- 覆写内部组件：用 Vite alias 替换（如 `find: /^.*\/VPNavBar\.vue$/`），但官方注明这些组件是内部的、minor 版本可能改名——[guide/extending-default-theme#overriding-internal-components](https://vitepress.dev/guide/extending-default-theme#overriding-internal-components)。

## C. 可扩展性与构建期钩子

### C1 `markdown.config` 注入 markdown-it 插件

- `markdown.preConfig(md)` 在内置插件**之前**配置实例；`markdown.config(md)` 在全部内置插件**之后**执行，可 `md.use(anyMarkdownItPlugin)`；两者都是 `MarkdownRenderer`（v2 为 `MarkdownItAsync`，渲染走 `renderAsync`）——[markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)。
- 官方示例即用 `config`：`import { headerLink } from '@mdit/plugin-anchor'` + `markdown.anchor.permalink = headerLink()`、`markdown.toc = { level: [1,2] }`、`config: (md) => md.use(markdownItFoo)`——[guide/markdown#advanced-configuration](https://vitepress.dev/guide/markdown#advanced-configuration)。
- 数学公式不是通过 `config` 手写，而是走内建键：`markdown: { math: true }` + 装 `markdown-it-mathjax3@^4`（源码里 `await import('markdown-it-mathjax3')` 并给 `mjx-container` 补 `v-pre`）；想换 KaTeX 之类则用 `config` 自行 `md.use()`——[guide/markdown#math-equations](https://vitepress.dev/guide/markdown#math-equations) + [markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)。
- 其他一行式接入点：`markdown.shikiSetup(shiki)` 配 Shiki 实例、`markdown.codeTransformers` 挂 Shiki transformer（官方示例：`<<< @/x.ts{ts twoslash}` 配合 `@shikijs/vitepress-twoslash`）——[markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts) + [guide/markdown#import-code-snippets](https://vitepress.dev/guide/markdown#import-code-snippets)。

### C2 构建期钩子各能改什么

- `head: HeadConfig[]`：静态追加 `<head>` 元素（favicon/字体/GA/service worker 注册），格式 `[tag, attrs, innerHTML?]`——[reference/site-config#head](https://vitepress.dev/reference/site-config#head)。
- `transformPageData(pageData, { siteConfig })`：改每一页的 pageData（可直接 mutate 或 return 合并对象），**dev 与客户端导航都会生效**，官方推荐优先用它加 head 项（如 `pageData.frontmatter.head.push([...])` 加 og:title / canonical）——[reference/site-config#transformpagedata](https://vitepress.dev/reference/site-config#transformpagedata)。
- `transformHead(context)`：只在 **build** 时调用，返回额外 head 项（自动与既有项合并，禁止 mutate context）；适合昂贵计算（如动态生成 og:image），产物是静态 HTML，客户端导航不会更新——[reference/site-config#transformhead](https://vitepress.dev/reference/site-config#transformhead)。
- `transformHtml(code, id, context)`：落盘前改写整页 HTML（官方警告：改 HTML 可能引入 hydration 问题；icon 样式表链接此时仍是占位符）——[reference/site-config#transformhtml](https://vitepress.dev/reference/site-config#transformhtml)。
- `postRender(context: SSGContext)`：SSG 渲染完成时调用，用于处理 teleports（`SSGContext` 含 `content/teleports/vpIcons`）——[reference/site-config#postrender](https://vitepress.dev/reference/site-config#postrender)。
- `buildEnd(siteConfig)`：SSG 构建结束、CLI 进程退出前运行（生成 sitemap/RSS/PWA 等）——[reference/site-config#buildend](https://vitepress.dev/reference/site-config#buildend)。
- `vite: UserConfig`：原始 Vite 配置直通内部 dev server / bundler（无需另建 vite.config）——[reference/site-config#vite](https://vitepress.dev/reference/site-config#vite)；`vue: Options` 直通 `@vitejs/plugin-vue`——[reference/site-config#vue](https://vitepress.dev/reference/site-config#vue)。
- 其他构建相关键：`base`（含 `'./'` 可搬迁构建）、`cleanUrls`、`rewrites`、`srcDir/srcExclude/outDir/assetsDir/assetsBase/assetsShards/cacheDir/ignoreDeadLinks/icons/mpa/lastUpdated/sitemap{hostname,transformItems}`，以及目录级覆盖文件 `config.ts`——[reference/site-config](https://vitepress.dev/reference/site-config) + [guide/sitemap-generation#transformitems-hook](https://vitepress.dev/guide/sitemap-generation#transformitems-hook)。

### C3 插件生态的形态

- 官方**没有**独立的"插件"概念/注册表/生命周期 API；官方文档把扩展点列为三类：Vite 配置（`vite.plugins`）、Vue 配置（`vue`）、Markdown 配置（`markdown.config`）——[reference/site-config#vite-vue-markdown-config](https://vitepress.dev/reference/site-config#vite-vue-markdown-config)。
- 实际生态 = 「Vite 插件 + markdown-it 插件 + 主题扩展（extends/enhanceApp/Layout slots）+ 构建钩子」四类拼装；社区插件通常就是**Vite 插件**，例如生成 llms.txt 的 `vitepress-plugin-llms` 用法是 `vite: { plugins: [llmstxt()] }` 并 `npm i -D`——[issues/4590 评论](https://github.com/vuejs/vitepress/issues/4590#issuecomment-2796382312)。
- 官方文档承认的社区搜索插件：`vitepress-plugin-pagefind`、`vitepress-plugin-typesense`、`vitepress-plugin-cloudflare-ai-search`；精选列表由社区维护（`awesome-vitepress-v1`）——[reference/default-theme-search](https://vitepress.dev/reference/default-theme-search) + [logicspark/awesome-vitepress-v1](https://github.com/logicspark/awesome-vitepress-v1)。

### C4 构建产物与部署

- 产物 = **SSR 预渲染的静态 HTML + 客户端 hydration**：首访直接吃静态 HTML（利于 SEO/首屏），随后加载 JS bundle 变成 Vue SPA，站内后续导航不再整页刷新——[guide/what-is-vitepress#performance](https://vitepress.dev/guide/what-is-vitepress#performance)。
- 实测产物结构：`index.html` / `guide/*.html` / `404.html` / `assets/app.*.js` + 每页 `<page>.md.<hash>.js` 与 `<page>.md.<hash>.lean.js` 两份 + `assets/chunks/theme.*.js`、`assets/chunks/@localSearchIndex<locale>.*.js`，以及内联 `window.__VP_HASH_MAP__` / `window.__VP_SITE_DATA__`（把 themeConfig 整个序列化进 HTML）——（本地实测，vitepress 1.6.4 构建）。
- 静态化程度可调：`mpa: true`（或 `vitepress build --mpa`）默认 **0kb JavaScript**，代价是关闭客户端导航、且要显式用 `<script client>` 才有点交互；官方定位是「只在需要极少量客户端交互时才用」——[guide/mpa-mode](https://vitepress.dev/guide/mpa-mode)。
- 「无 JS 也能用」的官方定性：`base: './'` 的可搬迁构建里，直接 `file://` 打开产物是「有样式、可完整导航的静态站点」，但「浏览器禁止 `file://` 下加载 JS 模块，因此没有 hydration——搜索等交互功能保持不激活，而所有预渲染内容与链接照常可用」——[guide/deploy#relocatable-builds-relative-base](https://vitepress.dev/guide/deploy#relocatable-builds-relative-base)。
- 部署零服务端要求：产物就是静态文件，官方给 Netlify/Vercel/Cloudflare/GitHub Pages/GitLab/Firebase/nginx 等清单；`cleanUrls` 需要托管方能 `without redirect` 地服务 `/foo` → `/foo.html`——[guide/deploy](https://vitepress.dev/guide/deploy) + [reference/site-config#cleanurls](https://vitepress.dev/reference/site-config#cleanurls)。

## D. 这个方案的代价 / 边界

### D1 是否必须是 Vue 项目、是否必须有 JS

- 不必须是「已有 Vue 项目」，但**必须是 Node 工具链**：官方前置要求 Node.js 22+（2.0 docs；deploy 页写构建环境 Node 20+），VitePress 是 **ESM-only** 包，且若要用 Vue 组件/API 定制还需显式把 `vue` 装成依赖——[guide/getting-started#prerequisites](https://vitepress.dev/guide/getting-started#prerequisites) + [guide/deploy](https://vitepress.dev/guide/deploy)。
- 构建后**产物不需要 Node**，但默认主题的完整体验需要 JS：SSR 出来的 HTML 已有正文与导航/侧栏链接（实测 `dist/guide/one.html` 里侧栏条目、`<details>` 折叠内容、代码组两个文件都在静态 HTML 中），而**搜索、客户端路由、主题切换按钮、移动端侧栏开合**都依赖 JS——[guide/deploy#relocatable-builds-relative-base](https://vitepress.dev/guide/deploy#relocatable-builds-relative-base) + 本地实测。
- 「纯静态无 JS」只有两条路：MPA 模式（0kb JS，但无 SPA 导航与交互）或接受「静态内容 + 链接可用、交互失效」的现状——[guide/mpa-mode](https://vitepress.dev/guide/mpa-mode)。

### D2 内容被 Vue 组件污染后，纯文本读者还能不能读懂

- 源 `.md` 始终是纯文本，`grep`/`cat` 没问题；问题在**渲染产物**：实测 `<ClientOnly>` 包裹的文本在 `dist/*.html` 里完全不存在（grep 计数 0），而同页普通段落与全局组件（`<Badge text="..."/>`）的文本在 HTML 里存在 ⇒ 用组件承载正文内容会让 AI/爬虫读到空洞——（本地实测 + [reference/runtime-api#clientonly](https://vitepress.dev/reference/runtime-api#clientonly)）。
- 更隐蔽的不一致：本地搜索索引基于 **markdown-it 的 HTML** 而非 SSR DOM，所以实测里 `<ClientOnly>` 内的词（`client`、`absent`）**进了搜索索引**，却永远不会出现在页面上 ⇒ 索引与可见内容可以不一致——（本地实测 + [localSearchPlugin.ts](https://github.com/vuejs/vitepress/blob/main/src/node/plugins/localSearchPlugin.ts)）。
- 官方**没有**「在 markdown 里写组件会破坏可移植性」这类提醒：我对 main 分支 `docs/` 全量检索 `llms.txt` / `llm-friendly` / `for AI` / `AI agent` / `portab` 均**无命中**（唯一的 "portable" 出现在讲 `base: './'` 的可搬迁输出）——（本地对 docs/ grep，**结论=官方无此提醒，未查实存在**）。
- 官方最接近的警告是「注释对 Vue 有意义」：部署页明确要求**不要开启 HTML Auto Minify**，否则注释被删会导致 hydration mismatch ⇒ HTML 产物与 Vue 是有耦合的，不是纯文本交付物——[guide/deploy](https://vitepress.dev/guide/deploy)。
- 官方 llms.txt 现状：**没有内建支持**（docs 无任何 llms 字样）；请求 issue [#4590「Support llms.txt generation」](https://github.com/vuejs/vitepress/issues/4590) 自 2025-03 至今仍 open，维护者 brc-dd 表态「取决于多少用户需要……在核心里生成可以复用已求值的 markdown，而 `vitepress-plugin-llms` 目前应该不支持动态路由、markdown 包含、snippet 导入」，并提到「可能会把 auto-sidebar 加回来」——[issue 4590 评论](https://github.com/vuejs/vitepress/issues/4590#issuecomment-2796346778)；相关 PR [#5313「feat(build): native LLM-friendly output (llms.txt)」](https://github.com/vuejs/vitepress/pull/5313) 仍 open，早前的 [#4692](https://github.com/vuejs/vitepress/pull/4692) 已 closed。
- 社区方案：`vitepress-plugin-llms`（406★，生成 `llms.txt`、`llms-full.txt` 以及每节独立的 `.md`）——[okineadev/vitepress-plugin-llms](https://github.com/okineadev/vitepress-plugin-llms)；另有含 AI 问答的 Algolia Ask AI / side panel 配置项与 issue [#5331「[Feature Agentic Coding] Add copy button to copy whole page」](https://github.com/vuejs/vitepress/issues/5331)（closed）显示这是活跃话题——[reference/default-theme-search#ask-ai](https://vitepress.dev/reference/default-theme-search#ask-ai)。
- 组件与 markdown 混写的解析怪癖有实证：issue [#4626「Markdown lines starting with an inline Vue component are incorrectly considered to be a whole paragraph」](https://github.com/vuejs/vitepress/issues/4626)（仅引标题，正文未逐条查实）。

### D3 本地搜索的索引粒度与依赖

- 开启方式只有一行：`themeConfig.search.provider = 'local'`，官方明说靠 in-browser 索引（minisearch），**不需要用户额外装搜索依赖**（`minisearch@^7.1.1` 本来就是 `vitepress` 的 dependencies）——[reference/default-theme-search#local-search](https://vitepress.dev/reference/default-theme-search#local-search)。
- 粒度 = **按标题切分的 section，不是整页**：`splitPageIntoSections` 用 `/ <h(\d*)> ... <a href="#..."> /` 把每页切成节，节 id 形如 `/guide/page.html#section`（不含 `base`），索引字段 `title` / `titles`（父级标题链）/ `text`（去标签后的正文）——[localSearchPlugin.ts](https://github.com/vuejs/vitepress/blob/main/src/node/plugins/localSearchPlugin.ts) + [reference/default-theme-search#document-ids](https://vitepress.dev/reference/default-theme-search#document-ids)。
- 可调项：`options.miniSearch.options`（`extractField/tokenize/processTerm`）、`options.miniSearch.searchOptions`（默认 `{ fuzzy: 0.2, prefix: true, boost: { title: 4, text: 2, titles: 1 } }`）、`options.miniSearch._splitIntoSections`、`options.locales.*.translations`（i18n 文案）、`options._render(src, env, md)`（自定义索引前渲染，函数会被剔出客户端 site data，可用 Node API）——[reference/default-theme-search#minisearch-options](https://vitepress.dev/reference/default-theme-search#minisearch-options)。
- 排除页面：frontmatter `search: false`（用自定义 `_render` 时需自己处理该判断）——[reference/default-theme-search#example-excluding-pages-from-search](https://vitepress.dev/reference/default-theme-search#example-excluding-pages-from-search)。
- 索引交付方式 = `assets/chunks/@localSearchIndex<locale>.<hash>.js`，由 `@localSearchIndex` 虚拟模块按 locale **动态 import**（实测产物中确实存在该 chunk）⇒ 搜索功能必须有 JS，无 JS 时搜索框只是壳——[localSearchPlugin.ts](https://github.com/vuejs/vitepress/blob/main/src/node/plugins/localSearchPlugin.ts) + 本地实测。
- 替代 provider：`algolia`（含 Ask AI / side panel）与社区 pagefind / typesense / cloudflare-ai-search——[reference/default-theme-search](https://vitepress.dev/reference/default-theme-search)。

## 给调研委托方的三条提醒

**最该抄的三件事**

1. **「内容源是纯 Markdown、一切增强都在构建期算成静态产物」这条主线**：容器/高亮/锚点/TOC/搜索索引全部在构建期求值，AI 读源、人读 HTML、搜索零运行时算力——理由：这正是 VitePress 的搜索索引与 markdown 插件架构的形态，且与「构建期算好一切」的项目定位同构（[guide/markdown](https://vitepress.dev/guide/markdown)、[localSearchPlugin.ts](https://github.com/vuejs/vitepress/blob/main/src/node/plugins/localSearchPlugin.ts)）。
2. **把「透传 vs 转义」做成显式可配开关（`markdown.html` / `v-pre` / 一长串可关闭的 `markdown.*` 键）**：可移植性变成用户可选的旋钮，而不是隐含行为——理由：实测 `html:false` 才让原始 HTML 变转义，否则默认透传；显式开关是 0 依赖实现里最容易漏掉、也最容易被 AI 读者感激的一环（[markdown.ts](https://github.com/vuejs/vitepress/blob/main/src/node/markdown/markdown.ts)、[site-config#markdown](https://vitepress.dev/reference/site-config#markdown)）。
3. **暗色模式那套「构建期注入 inline 脚本 + 固定 localStorage 键 + `html.dark` 类 + CSS 变量双套值」的模式**：零依赖、零闪烁、主题可整体替换——理由：它把「用户偏好 → 首屏正确渲染」压成十几行脚本 + 两份变量表，任何固定包渲染的 UI 都能直接照搬（[site-config#appearance](https://vitepress.dev/reference/site-config#appearance)、[config.ts](https://github.com/vuejs/vitepress/blob/main/src/node/config.ts)、[vars.css](https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/styles/vars.css)）。

**最不该抄的三件事**

1. **不要把内容编译进 Vue 组件树**（`<script setup>`、组件式正文、全局组件注册、`<ClientOnly>`）：这会让「内容」变成只有跑 Vue 才能看懂的东西，实测 ClientOnly 文本在 HTML 与搜索索引里表现不一致，且直接违反 0 npm 依赖的前提（[guide/using-vue](https://vitepress.dev/guide/using-vue)、[runtime-api#clientonly](https://vitepress.dev/reference/runtime-api#clientonly)）。
2. **不要抄 SPA 客户端导航 / hydration 那一层**（`app.js` + 每页 `.js`/`.lean.js` 双份 + `__VP_HASH_MAP__`）：收益是站内跳转更顺滑，代价是每页双份产物 + 「必须 JS 才完整可用」，而 MPA 模式官方自己承认 0kb JS 才是取舍后的另一头（[what-is-vitepress](https://vitepress.dev/guide/what-is-vitepress)、[guide/mpa-mode](https://vitepress.dev/guide/mpa-mode)）。
3. **不要抄「可编程主题 API 面」**（40+ layout slots + `extends`/`enhanceApp` + 用 Vite alias 覆写内部组件）：固定包渲染的站点用不上这套自由度，反而把内部组件名固化成契约——官方自己都注明内部组件名在 minor 版本间可能变动（[extending-default-theme#layout-slots](https://vitepress.dev/guide/extending-default-theme#layout-slots)、[#overriding-internal-components](https://vitepress.dev/guide/extending-default-theme#overriding-internal-components)）。
