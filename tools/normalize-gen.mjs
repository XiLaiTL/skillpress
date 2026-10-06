#!/usr/bin/env node
/**
 * normalize-gen.mjs —— 把生成物的**两种形状**化到同一条基准线上（`file-parity.sh` 的判据用）。
 *
 * ## 为什么需要它
 *
 * P6 把 `Span` / `Block` / `Kid` / `Doc` / `NavItem` / `Section` / `Home` 这 7 个类型
 * 从**生成物**搬进了包 `shell` —— 于是同一个内容源印出来的文件换了"形状"：
 *
 * | | 旧形状（旧引擎 `lib/gen-content.mjs` 现印的产物） | 新形状（MoonBit 引擎 `cmd/skillpress gen-file`） |
 * |---|---|---|
 * | 文件头 | 一段 `//` 注释（说"由 gen-content.mjs 生成"） | 一段 `//` 注释（说实话：类型在包里） |
 * | 类型声明 | 7 个类型都在文件里 | **没有**（唯一声明处是 `shell/types.mbt`） |
 * | 值 | 裸构造器 `Txt("x")` / `Hr` | 带包前缀 `@shell.Txt("x")` / `@shell.Hr` |
 * | 签名 | `pub fn home() -> Home` | `pub fn home() -> @shell.Home` |
 * | 结构体字面量 | 匿名 `{ slug: … }` | 匿名 `{ slug: … }`（**一样** —— 见下） |
 *
 * 裸构造器在新形状里**根本编不过**（不是风格问题）：P6 实测 —— `using @shell {type Span}`
 * 只把**类型名**引进作用域，构造器仍然 unbound；而 `@shell.NavItem { … }` 这种"限定结构体字面量"
 * 不是合法语法，好在生成物里的结构体字面量本来就是匿名的，靠字段类型推，所以不受影响。
 *
 * ## 三条规则（两边都跑；都幂等）
 *
 * ① 去掉**开头**那段 `//` 注释块（`///|` 文档注释不算 —— 它是正文的一部分）。
 * ② 去掉**类型声明块**：从 `pub fn ` 前最近的那条 `///|` 起，往上全砍（新形状里没这段，规则空转）。
 * ③ 去掉包前缀 `@shell.`。
 * 然后把连续空行压成一个、去掉首尾空行 —— ①②会把"块旁边的空行"吃掉，需要对齐。
 *
 * ## 边界（这是刻意的，也是本文件存在的风险所在）
 *
 * 只抹**形状**，不抹**内容**：值、顺序、缩进、转义、高亮 runs、正文里的空行位置，全都还在判据里。
 * 判据弱一点可以，弱到"看不出内容变了"就不行 —— `--selftest` 就是钉这条边界的：
 * 它证明"值改一个字节"会被抓到、"形状差"不会被误判。
 *
 * 用法：
 *   node tools/normalize-gen.mjs <生成物文件>     # 归一化后打到 stdout
 *   node tools/normalize-gen.mjs --selftest       # 自证：边界还在
 */
import { readFileSync } from "node:fs";

/** 形状差里唯一"值"那一侧的东西。 */
export const REC = "@shell.";

/**
 * 归一化：生成物文本 → 基准形状。
 *
 * @param {string} text
 * @returns {string}
 */
export function normalize(text) {
  let lines = text.split("\n");
  // ① 开头的 `//` 注释块（`///|` / `///` 文档注释是正文，不动）
  let i = 0;
  while (i < lines.length && /^\/\/(?![\/])/.test(lines[i])) i++;
  lines = lines.slice(i);
  // ② 类型声明块：砍到 `pub fn ` 前最近的那条 `///|` 为止
  const fnAt = lines.findIndex((l) => l.startsWith("pub fn "));
  if (fnAt >= 0) {
    let keepFrom = fnAt;
    for (let k = fnAt - 1; k >= 0; k--) {
      if (lines[k].startsWith("///|")) {
        keepFrom = k;
        break;
      }
    }
    lines = lines.slice(keepFrom);
  }
  // ③ 包前缀
  const stripped = lines.join("\n").split(REC).join("");
  // 空行：压成一个、去首尾（正文里的空行仍然保留一个）
  const kept = [];
  for (const l of stripped.split("\n")) {
    if (l.trim() === "") {
      if (kept.length > 0 && kept[kept.length - 1] !== "") kept.push("");
    } else {
      kept.push(l);
    }
  }
  while (kept.length > 0 && kept[kept.length - 1] === "") kept.pop();
  return kept.join("\n") + "\n";
}

/** 自证用：一小段"旧形状"的生成物。 */
const OLD_FIXTURE = `// 由 \`tools/gen-content.mjs\` 生成 —— **别手改**（跑 \`--check\` 会红）。
//
// 内容源：\`skills/skillpress/SKILL.md\`。

///| 一段行内内容。
pub enum Span {
  Txt(String)
}

///| 正文里的一个块。
pub enum Block {
  Hr
  P(Array[Span])
}

///| 首页。
pub struct Home {
  title : String
  lede : Array[Block]
}

///| 首页（来自 \`skills/skillpress/SKILL.md\`）。
pub fn home() -> Home {
  {
    title: "skillpress",
    lede: [
      P([Txt("a"), Code("b")]),
      Hr,
    ],
  }
}

///| 全部 skill。
pub fn skills() -> Array[Doc] {
  [
    {
      slug: "s",
      blocks: [P(([] : Array[Span]))],
    },
  ]
}
`;

/** 自证用：同一份内容的"新形状"（类型不在文件里、值和签名带前缀）。 */
const NEW_FIXTURE = `// 由 \`skillpress\` 生成（P6 起是 MoonBit 引擎：\`cmd/skillpress gen-file\`）—— **别手改**。
//
// 类型**不在这里**：它们在包 \`XiLaiTL/skillpress/shell\`。

///| 首页（来自 \`skills/skillpress/SKILL.md\`）。
pub fn home() -> @shell.Home {
  {
    title: "skillpress",
    lede: [
      @shell.P([@shell.Txt("a"), @shell.Code("b")]),
      @shell.Hr,
    ],
  }
}

///| 全部 skill。
pub fn skills() -> Array[@shell.Doc] {
  [
    {
      slug: "s",
      blocks: [@shell.P(([] : Array[@shell.Span]))],
    },
  ]
}
`;

function selftest() {
  const cases = [];
  const eq = (name, a, b) => cases.push([name, a === b, a === b ? "" : "两边不相等"]);
  const ne = (name, a, b) => cases.push([name, a !== b, a !== b ? "" : "两边**居然**相等（判据看不出区别）"]);

  const base = normalize(OLD_FIXTURE);
  eq("旧形状 ↔ 新形状：归一化后相同（形状差被抹掉）", base, normalize(NEW_FIXTURE));
  // 边界 ①：值改一个字节必须被抓到
  ne("值改一个字符（\"a\" → \"b\"）必须看出来", base, normalize(NEW_FIXTURE.replace('@shell.Txt("a")', '@shell.Txt("b")')));
  // 边界 ②：块的顺序换了必须被抓到
  ne(
    "块顺序换了必须看出来",
    base,
    normalize(
      NEW_FIXTURE.replace(
        '      @shell.P([@shell.Txt("a"), @shell.Code("b")]),\n      @shell.Hr,',
        '      @shell.Hr,\n      @shell.P([@shell.Txt("a"), @shell.Code("b")]),',
      ),
    ),
  );
  // 边界 ③：正文里的空行（渲染无关，但**是产物的形状**）必须被抓到
  ne("正文里的空行多一行必须看出来", base, normalize(NEW_FIXTURE.replace('  {\n    title:', '  {\n\n    title:')));
  // 边界 ④：缩进变了必须被抓到
  ne("缩进变了必须看出来", base, normalize(NEW_FIXTURE.replace('      @shell.Hr,', '        @shell.Hr,')));
  // 边界 ⑤：只去掉前缀不算差异（证明"前缀"是唯一被规则③吃掉的东西）
  eq("只去掉前缀：仍然相同（规则③就是干这个的）", base, normalize(NEW_FIXTURE.split(REC).join("")));

  let bad = 0;
  for (const [name, ok, why] of cases) {
    if (ok) {
      console.log(`✓ ${name}`);
    } else {
      bad++;
      console.log(`✗ ${name} —— ${why}`);
    }
  }
  console.log(bad === 0 ? `\n归一化自证通过（${cases.length} 条）` : `\n归一化自证**失败**（${bad}/${cases.length} 条）`);
  process.exit(bad === 0 ? 0 : 1);
}

const arg = process.argv[2];
if (arg === "--selftest") {
  selftest();
} else if (!arg) {
  console.error("用法：node tools/normalize-gen.mjs <生成物文件> ｜ --selftest");
  process.exit(2);
} else {
  process.stdout.write(normalize(readFileSync(arg, "utf8")));
}
