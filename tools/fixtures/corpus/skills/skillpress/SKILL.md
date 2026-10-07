---
name: skillpress
description: 夹具语料的首页源：这份语料里有什么、从哪一份开始读。
---

# 夹具语料（parity fixture）

这是**逐字节对账**用的一小份**冻结**语料：它自己住在程序仓里
（`tools/fixtures/corpus/`），不随内容仓变化 —— 拿它当基准的判据**不会腐**。

## 一、这份语料里有什么

- `alpha-skill`：有子页（含一层更深的子目录）、有 `scripts/`
- `beta-skill`：有表格，以及多种语言的代码块
- `gamma-skill`：有跨 skill 的链接与行内标记

## 二、从哪一份开始

[intro](references/intro.md)

## 三、一段带行内标记的正文

读的时候先看 **加粗的那个结论**，再回头看 `行内代码` 里的参数 —— 它们描述的是同一件事，
只是一个是结论、一个是证据。这一段刻意够长，好让"探针句子"有东西可选。

## 四、去哪看

| 想做什么 | 去哪 |
|---|---|
| 建一个应用 | [alpha](alpha-skill/references/notes.md) |
| 看多种语言的例子 | `beta-skill` |
