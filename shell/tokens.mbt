// shell/tokens.mbt —— **设计 token 的唯一来源**（DESIGN-site.md §3）。
//
// 两层结构，铁律是"渲染代码里不许出现字面色号"：
//
//     原语 primitive（色值只在这里写死）
//         ↓
//     语义 semantic（Palette：一个用途一个名字）
//         ↓  组件只准引用语义名
//     尺度 scale（明暗不变量：间距 / 字号 / 行高 / 圆角 / 宽度）
//
// ⚠️ moobile 里没有 CSS 变量：**主题就是值**（PLAN-ui §6.3）⇒ 这一层产出的是
//    `Palette` 结构体（值），由 `theme.mbt` 组装成 `Theme` 跟着 Model 走。
//    所以"换主题"= 换一个值 + 重渲，不依赖任何浏览器特性。
//
// ⚠️ 两套色（浅/深）**成对给全**：漏一个字段编不过（这是刻意的——比"深色下少画一条线"强）。
//
// ⚠️ 对比度是**判据**，不是审美（DESIGN §1 A4 / §3.2 第 4 条）：
//    · 可读文字一律 ≥4.5（含"次要文字"）；
//    · `fg3` 只给**机器串与装饰**（指纹、分隔点）——它落在 surface2 上只有 2.97；
//    · 深色下品牌色必须比浅色**更亮**，否则在深底上读不出。

// ══ 尺度（明暗不变量） ═══════════════════════════════════════════════════════
//
// 间距**只用这 7 档**（DESIGN §3.3）。写死别处出现的 7 / 9 / 14 这类值都是"混用"，会毁掉节奏。

///| 4px —— 紧邻的两样东西（图标与文字）
let sp1 : Double = 4.0
///| 8px —— 一行的内上下、两行之间
let sp2 : Double = 8.0
///| 12px —— 行内左右
let sp3 : Double = 12.0
///| 16px —— 块内、缩进的一档
let sp4 : Double = 16.0
///| 24px —— 块与块
let sp5 : Double = 24.0
///| 32px —— 栏的内边距
let sp6 : Double = 32.0
///| 48px —— 大段落之间
let sp7 : Double = 48.0

///| meta / 机器串 11.5
let fs_meta : Double = 11.5
///| 辅助 / 目录行 / 小标签 12.5
let fs_aux : Double = 12.5
///| 小正文 / 侧栏行 13.5
let fs_sm : Double = 13.5
///| **正文 15.5**（14px 的中文在桌面偏小）
let fs_base : Double = 15.5
///| h3 17
let fs_h3 : Double = 17.0
///| h2 22
let fs_h2 : Double = 22.0
///| h1 30
let fs_h1 : Double = 30.0

///| 标题行高 1.45
let lh_tight : Double = 1.45
///| 辅助行高 1.6
let lh_aux : Double = 1.6
///| **正文行高 1.75**（中文比拉丁文需要更宽）
let lh_base : Double = 1.75

///| 圆角 4
let r1 : Double = 4.0
///| 圆角 6
let r2 : Double = 6.0
///| 圆角 10
let r3 : Double = 10.0
///| 圆角 14
let r4 : Double = 14.0

///| 侧栏宽（DESIGN §3.3）
let w_side : Double = 272.0
///| 右栏目录轨宽
let w_toc : Double = 220.0
///| 正文宽 720（≈46 个字）
let w_prose : Double = 720.0
///| 顶栏高
let h_top : Double = 56.0
///| 站点最大宽
let w_max : Double = 1440.0
///| 阶梯：三栏能同时放下的最小宽（272+64+720+220 = 1276）
let w_rail3 : Double = 1280.0
///| 阶梯：两栏（侧栏 + 正文）能放下的最小宽
let w_rail2 : Double = 1024.0
///| 顶栏那一排排不下的宽（导航进 sheet、搜索收成图标）
let w_narrow : Double = 700.0

// ══ 语义色（一套 = 一个 Palette） ════════════════════════════════════════════

///|
/// 一套语义色。字段名 = 用途，不是色名（换主题时"色名"会撒谎，用途不会）。
pub(all) struct Palette {
  name : String
  // 面
  canvas : String      // 页面底
  surface : String     // 正文卡片
  surface2 : String    // 侧栏 / 次级面
  inset : String       // 行内码、kbd 的底（半透明，跟着底走）
  overlay : String     // 浮层（下拉 / 搜索 / sheet）
  scrim : String       // 遮罩
  // 字
  fg1 : String         // 正文
  fg2 : String         // 次要文字（可读的一切次要文字都用它）
  fg3 : String         // **只给机器串与装饰**（在 surface2 上只有 2.97）
  // 线
  line1 : String       // 分隔线
  line2 : String       // 需要被看见的边界
  // 品牌
  brand : String
  /// **压在品牌色上的前景色**（站名那个方块里的字、实心按钮的字）。
  /// ⚠️ 为什么必须是独立一格、而不是就地写 `#ffffff`：**深色的品牌色是亮的**
  ///    （`#a5b4fc`），白字压上去只有 ~1.9:1 ⇒ 深色主题下那个字直接读不出来。
  ///    浅色/暖纸的品牌色深 ⇒ `on_brand` 近白；深色的品牌色亮 ⇒ `on_brand` 必须**深**。
  on_brand : String
  brand_hover : String
  brand_soft : String  // 选中底（淡底一律半透明 ⇒ 进深色天然成立）
  brand_ring : String
  // 状态
  state_hover : String      // 落在 canvas 上
  state_hover_side : String // 落在 surface2 上（同一叠色在灰底上会被吃掉）
  // 代码
  code_bg : String
  code_line : String
  // 语义
  note : String
  tip : String
  warn : String
  danger : String
  // 上色（引擎产出的色号 → 颜色；见 theme.mbt 的 `tok_color`）
  tok_kw : String
  tok_ty : String
  tok_st : String
  tok_num : String
  tok_fn : String
  tok_mod : String
  tok_var : String
  tok_cm : String
  tok_op : String
}

///|
/// **靛紫**（默认）—— 浅色。
///
/// 值取自 DESIGN-site.md §3.2 的对照表（那一版是拿真浏览器量过对比度的）。
pub let indigo_light : Palette = {
  name: "indigo-light",
  canvas: "#ffffff", surface: "#ffffff", surface2: "#f7f7f8",
  inset: "rgba(120,124,150,.14)", overlay: "#ffffff", scrim: "rgba(24,24,27,.42)",
  fg1: "#35363b", fg2: "#64656c", fg3: "#8f9096",
  line1: "#e5e5e8", line2: "#c8c9ce",
  brand: "#4f46e5", on_brand: "#ffffff", brand_hover: "#4338ca",
  brand_soft: "rgba(79,70,229,.12)", brand_ring: "rgba(79,70,229,.35)",
  state_hover: "rgba(24,24,27,.045)", state_hover_side: "rgba(24,24,27,.07)",
  code_bg: "#f7f7f8", code_line: "#e5e5e8",
  note: "#2b5db8", tip: "#15803d", warn: "#9a6a10", danger: "#b3261e",
  tok_kw: "#4f46e5", tok_ty: "#0e7490", tok_st: "#15803d", tok_num: "#b45309",
  tok_fn: "#2563eb", tok_mod: "#6d28d9", tok_var: "#52525b",
  tok_cm: "#8f9096", tok_op: "#64656c",
}

///|
/// **靛紫** —— 深色。三条规则（DESIGN §3.2）：
/// ① 淡底半透明；② 海拔用更亮（overlay > canvas > surface2）；③ 品牌色比浅色更亮。
pub let indigo_dark : Palette = {
  name: "indigo-dark",
  canvas: "#18181b", surface: "#18181b", surface2: "#131316",
  inset: "rgba(113,113,122,.18)", overlay: "#1f1f23", scrim: "rgba(0,0,0,.6)",
  fg1: "#e4e4e7", fg2: "#a1a1aa", fg3: "#71717a",
  line1: "#27272a", line2: "#3f3f46",
  brand: "#a5b4fc", on_brand: "#18181b", brand_hover: "#c7d2fe",
  brand_soft: "rgba(79,70,229,.20)", brand_ring: "rgba(165,180,252,.45)",
  state_hover: "rgba(255,255,255,.055)", state_hover_side: "rgba(255,255,255,.085)",
  code_bg: "#131316", code_line: "#27272a",
  note: "#8ab4f8", tip: "#6ddba0", warn: "#e8c06a", danger: "#f2938c",
  tok_kw: "#a5b4fc", tok_ty: "#67e8f9", tok_st: "#86efac", tok_num: "#fcd34d",
  tok_fn: "#93c5fd", tok_mod: "#c4b5fd", tok_var: "#d4d4d8",
  tok_cm: "#71717a", tok_op: "#a1a1aa",
}

///|
/// **暖纸** —— 现在线上那套（P6 之前就在用），留着做"换皮"的存在性证明与回退位。
/// 它没有深色版 ⇒ 深色下**退回靛紫的深色**（见 theme.mbt 的 `theme_of`）。
/// ⚠️ 它是"旧配色"，不是"新设计的第二套"：别拿它当参照去改新界面。
pub let paper_light : Palette = {
  name: "paper-light",
  canvas: "#f2ede3", surface: "#fffdf8", surface2: "#eae3d5",
  inset: "#e6ddcb", overlay: "#fffdf8", scrim: "rgba(33,26,19,.45)",
  fg1: "#1a1410", fg2: "#5b4f3f", fg3: "#8b7c66",
  line1: "#ddd3c0", line2: "#c9bda6",
  brand: "#8a2518", on_brand: "#fffdf8", brand_hover: "#6f1d13",
  brand_soft: "rgba(138,37,24,.12)", brand_ring: "rgba(138,37,24,.35)",
  state_hover: "rgba(33,26,19,.05)", state_hover_side: "rgba(33,26,19,.07)",
  code_bg: "#f0e9da", code_line: "#ddd3c0",
  note: "#2b5db8", tip: "#15803d", warn: "#9a6a10", danger: "#b3261e",
  tok_kw: "#8a2518", tok_ty: "#0e7490", tok_st: "#15803d", tok_num: "#b45309",
  tok_fn: "#2563eb", tok_mod: "#5b3a70", tok_var: "#6b5a44",
  tok_cm: "#8b7c66", tok_op: "#5b4f3f",
}
