---
name: skillpress
description: 这套工具是什么、站点住哪儿、三个根怎么分、跑哪三条命令 —— 站点的门口那一份（读者从这儿决定去看「用它的人」那侧还是「改它的人」那侧）。
whenToUse: 你刚进这个仓库、想知道 skillpress 能干什么、站点为什么长这样、该跑哪几条命令；已经确定要动手改引擎或写内容的人不必停在这儿（那两侧各有一份更专的 skill）。
---

# skillpress —— 一套内容，投影成站点

**一句话**：把仓库里那批 skill（`skills/<名字>/SKILL.md` 与它同目录下的参考资料）印成一个能读的
**站点**；内容只有一份，站点是它的投影 —— 而**首页也是这份语料里的一份 skill**。

这个站点就是它自己的样板：内容根 `skills/`，实例在 `skills/skillpress/scripts/.skillpress/`。

## 一、三个根（别混）

| 根 | 在哪 | 是什么 |
|---|---|---|
| **程序** | 本仓库根 | 引擎（`engine/`）+ 站点界面包（`shell/`）+ 门 + 语法资产 |
| **内容** | `skills/` | 这份语料：`skillpress`（门口与首页源）、`skillpress-dev`、`skillpress-user` |
| **实例** | `skills/skillpress/scripts/.skillpress/` | 一个"**用**程序"的 MoonBit 工程：界面不在它里面，它只接线 |

界面抽成包是刻意的：实例的 `app.mbt` 只把生成物交给 `@shell.site`，
所以**换皮改的是程序里的 `shell/theme.mbt`** —— 用这份程序的每个站点一起变。

## 二、三条命令

```bash
node tools/press.mjs                                   # 内容源 → 实例的 content 包
node tools/press.mjs --check                           # 门：生成物与内容源一致吗
node tools/run-js.mjs check --repo . --skills skills   # 门：skill 自己（G1–G8）
```

看效果（实例目录里）：`npm run build` → `npm run serve` → `http://127.0.0.1:8123/`。

⚠️ `check` 那条 `--repo` 要**显式给**：默认的仓库根是"程序旁边的 `moobile/`"，
而这份语料住在程序仓自己里 —— 不指定的话，门会去查另一个仓（它不报错，只是查错了东西）。

## 三、还没做（别当成已支持）

- **`pack`**：把一组 skill 打成便携目录 —— 还没做（命令存在，但会明说"还没做"）。
  （`attach` **已落地**：`node tools/run-js.mjs attach --repo <仓根> --skills <内容根>` ——
  扫语料 → 选哪几份不上书架（要理由）→ 首页来自 `<仓根>/README.md` → 写整套 `skills/skillpress/**`。
  **本仓这份实例就是它生成的**；模板真源在 `template/instance/`。）
- **锚点 / 目录 / 搜索**：语法树已经在手上，功能还没做；窄屏也还没折叠菜单。
- **打的还是 dev 模式 bundle**（约 6 MB，大头是 react-native-web）；上生产要换 `NODE_ENV=production` + minify。

## 四、往哪儿走

| 你要干的事 | 读那份 |
|---|---|
| 用它做站点（写首页、换配色与字号、加一块构造、验收） | `skillpress-user` |
| 改这套程序（引擎、三道门、上色、加判据与诱饵、落锁） | `skillpress-dev` |
