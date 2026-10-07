---
name: alpha-skill
description: 夹具里的第一份 skill：有子页、有更深一层的子目录、还有 scripts/。
whenToUse: 你要在夹具里验"子页发现与侧栏树"时用这一份。
---

# alpha-skill

这一份用来验**子页发现**：`references/` 下的 md、以及 `references/deep/` 里更深一层的 md
都应当被收进来，顺序按 UTF-16 码元序。

## 一段正文

普通段落里可以有 **加粗**、`行内代码`、以及 [指向另一个 skill 的链接](../beta-skill/SKILL.md)。
段落要够长，这样探针句子才有得挑 —— 不然对账时"挑哪一句"会变成一件碰运气的事。

## 代码

```bash
# 一段 bash：验上色与"围栏切分"
set -euo pipefail
echo "hello from the fixture"
```

## 列表

- 第一条
- 第二条，带 `行内代码`
- 第三条
