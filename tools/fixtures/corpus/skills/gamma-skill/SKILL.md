---
name: gamma-skill
description: 夹具里的第三份 skill：跨 skill 的链接与行内标记。
whenToUse: 你要验"链接解析（首页目录相对 / 内容根相对两条规矩）"时用这一份。
---

# gamma-skill

这一份用来验**链接解析**：`[alpha](../alpha-skill/SKILL.md)` 是**相对本文件所在目录**的一跳，
而 `[alpha 的细则](alpha-skill/references/notes.md)` 是**相对内容根**的一跳 —— 两条都要能解开。

## 行内标记

一段话里可以有 **加粗**、`行内代码`、*斜体*、以及 [一个链到别处的链接](../alpha-skill/references/notes.md)。
行内标记剥掉之后应当与页面上 `innerText` 对得上。

## 收尾

最后一段也是正文，用来验"文件末尾的块与空行"。
