# skillpress —— 改它的人和用它的人

这一份语料是**程序自己**的 skill：两份，一份给**改这套程序的人**，一份给**用它做站点的人**。
站点实例就住在这份 skill 的 `skills/skillpress/scripts/.skillpress/` 里 ——
这份 skill 既是站点的一份内容（首页源），也是**站点的家**。

## 一、两份 skill

| skill | 给谁 | 管什么 |
|---|---|---|
| `skillpress-user` | 用这套工具做站点的人 | 一份 / 多份 skill → 站点、主页怎么写、配色与字号改哪儿、加一块新构造、验收 |
| `skillpress-dev` | 改这套程序的人 | 四个根、改什么跑哪条门、怎么加判据与诱饵、落锁、会安静咬人的坑 |

两份的边界只有一条：**写内容的不改引擎，改引擎的不写内容**。

## 二、这个站点怎么起来的

程序就是本仓库，内容根是 `skills/`，实例在内容根里那份 skill 的 `scripts/` 下：

```bash
node tools/press.mjs                      # 内容源 → 实例的 content 包（--check 是门）
cd skills/skillpress/scripts/.skillpress  # 实例：npm run build && npm run serve
```

界面**不在实例里**：顶栏 / 分栏下拉 / 侧栏树 / 正文渲染整套住在程序包的 `shell/` 目录里，
实例的 `app.mbt` 只把生成物交给 `@shell.site` —— 换皮改的是 `shell/theme.mbt`，
所有用这份程序的站点一起变（判据 A2 盯着"实例 `app.mbt` ≤20 行"）。

## [先读哪一份](skillpress-user/SKILL.md)

> 这一栏是**纯链接节**：点它不会换一栏正文，而是直接渲染那一页。
> 要**用**这套工具做站点，先看它；要**改**这套程序，看下面的 `skillpress-dev`。

## 四、两份都在下面

- [skillpress-user](skillpress-user/SKILL.md)
- [skillpress-dev](skillpress-dev/SKILL.md)

上面这个列表每一项**整条是一个链接**、目标都是已收录的页 ⇒ 它就是这一栏的**下拉菜单**
（鼠标悬停出来，触摸点一下展开）。

## 五、改完必须跑的

内容改了跑 `node tools/press.mjs --check`（生成物与内容源一致吗），
skill 自己改了跑 `node bin/skillpress.mjs check --repo . --skills skills`（G1–G8）。
⚠️ `--repo` 要显式给：默认那个根是"程序旁边的 `moobile/`"，而这份语料就住在程序仓自己里。
