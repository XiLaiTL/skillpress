---
name: beta-skill
description: 夹具里的第二份 skill：表格与多种语言的代码块。
whenToUse: 你要验"表格渲染"或"多语言上色"时用这一份。
---

# beta-skill

这一份用来验**表格**与**多种语言的代码块**（上色那条判据要按语言分别读数）。
代码块刻意写得**有东西可上色**（关键字 / 字符串 / 注释 / 数字）—— 都是同一段空壳代码的话，
"上色退步"这件事在读数上看不出来。

## 表格

| 语言 | 用途 | 备注 |
|---|---|---|
| bash | 脚本 | 判据脚本自己就是 bash |
| json | 数据 | 注册表与锁 |
| toml | 配置 | 语法资产 |
| moonbit | 引擎 | 引擎与界面都是它 |

## JSON

```json
{
  "name": "beta-skill",
  "version": "1.0.0",
  "keywords": ["fixture", "parity"],
  "count": 42,
  "enabled": true
}
```

## TOML

```toml
[package]
name = "fixture"
version = "0.1.0"
license = "Apache-2.0"

[deps]
engine = "1.2.3"
```

## MoonBit

```moonbit
///|
/// 一段有函数、有匹配、有字符串的 MoonBit。
pub fn classify(n : Int) -> String {
  match n {
    0 => "zero"
    x if x > 0 => "positive"
    _ => "negative"
  }
}

///|
pub fn main {
  println(classify(42))
}
```

## JavaScript

```javascript
// 一段有注释、模板串与函数的 JS
export function greet(name) {
  const who = String(name ?? "world");
  return `hello, ${who}!`;
}
```

## Bash

```bash
# 一段有变量、有函数、有条件的 bash
set -euo pipefail
root="${1:-.}"
if [ -d "$root/skills" ]; then
  echo "skills root: $root/skills"
fi
```
