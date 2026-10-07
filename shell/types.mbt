// shell/types.mbt —— **公开契约**：站点数据 + 渲染入口要的那几样东西。
//
// 这几个类型原先声明在**生成物**里（`content/content.generated.mbt`），P6 把它们搬进包：
// 从此它们是 skillpress 的对外契约，生成物只**填值**，不再声明类型。
//
// ⚠️ 为什么生成物里的构造要写 `@shell.P(...)` 而不是裸 `P(...)`：
// **实测**（P6 的语言实验）`using @shell {type Span, type Block}` 只把**类型名**引进作用域，
// **构造器仍然 unbound** —— 所以"值"那一侧必须带包前缀。
//
// ⚠️ 为什么是 `pub(all)` 而不是 `pub`：**实测**（P6 的 `_scratch` 探针）裸 `pub enum` / `pub struct`
// 对**别的包**是**只读**的 —— 消费者写 `@shell.Txt("x")` 得到
// `Cannot create values of the read-only type: Txt`，写 `@shell.NavItem { … }` 得到
// `Value NavItem not found in package shell`。生成物在**另一个包**（实例的 `content`）里填值，
// 所以这几个类型必须 `pub(all)`（构造器与字段一起公开）。

///| 一段行内内容。
pub(all) enum Span {
  Txt(String)
  Code(String)
  Bold(String)
  /// **链接**：`(标签, 目标, 标签看起来是不是个路径)` —— 第三个字段由**引擎**判（`wordy`），
  /// 站点照着排（路径标签用 mono），**别在站点再判一次**。
  Link(String, String, Bool)
}

///| 正文里的一个块。
pub(all) enum Block {
  Hr
  H2(Array[Span])
  H3(Array[Span])
  H4(Array[Span])
  P(Array[Span])
  Quote(Array[Span])
  Code(String, String, Array[(String, Int)]) // 语言, 正文, 高亮片段（文本, 色号）
  Ul(Array[(Int, String, Array[Span])]) // 缩进, 序号前缀(有序列表用), 内容
  Table(Array[Array[Span]], Array[Array[Array[Span]]]) // 表头, 行
}

///| 一个子页：skill 的 references/（深水区）或 scripts/（随 skill 发的脚本）。
pub(all) struct Kid {
  kind : String // "ref" | "script"
  name : String
  title : String
  desc : String
  blocks : Array[Block]
}

///| 一页 = 一个 skill。
pub(all) struct Doc {
  slug : String        // 目录名（= skill 名）；**只在 kicker / 面包屑末位 / Agent 面板 / URL 出现**
  title : String       // **中文人话的名字**（frontmatter `title` → 正文 H1 → 回退 slug）—— 界面上一律用它
  desc : String        // 一行摘要（给 Agent 读的，不是侧栏标签）
  full_desc : String   // frontmatter 的完整 description
  when : String        // frontmatter 的 whenToUse
  blocks : Array[Block]
  kids : Array[Kid]
}

///| 分栏下拉菜单里的一条（来自那一节的第一个链接列表）。
pub(all) struct NavItem {
  label : String  // 显示的名字
  key : String    // 页面键（给 `find_page` 换成第几页）
}

///| 官网首页的一个**分栏** = 首页那份 skill 里的一个 `##`（顶部栏的一条）。
pub(all) struct Section {
  title : Array[Span]  // 分栏名（就是那个 `##` 的标题文本）
  blocks : Array[Block]
  link : String        // 纯链接节：这一节指向的**页面键**（空 = 普通分栏，点了只换正文）
  nav : Array[NavItem] // 这一节的下拉菜单（空 = 没有）；有它时点一下先展开
}

///| 首页（来自首页那份 skill：H1 + 首个 `##` 之前 = 首屏）。
pub(all) struct Home {
  title : String       // H1 —— 页眉的站名
  lede : Array[Block]  // 首屏正文
  sections : Array[Section]
}

///|
/// 内容侧交给界面的四样东西（首页 / 全部 skill / 页面键换算 / 页脚出处）。
///
/// ⚠️ 为什么是**参数**而不是 import：包不该知道内容从哪来（实例里是生成物 `content` 包，
/// 将来也可能来自别处）。这三样是界面**唯一**需要的"外面的事"。
pub(all) struct Ctx {
  home : Home
  docs : Array[Doc]
  /// 页面键 → `(kind, skill 下标, 子页下标)`；认不出给 `(0, -1, -1)`。
  find_page : (String) -> (Int, Int, Int)
  /// 页脚要交代的出处（许可 / 生成时间 / 内容根指纹）—— 见下面的 `Footer`。
  footer : Footer
}

// ── 页脚（DESIGN-site.md §5 页脚那一行） ──────────────────────────────────────

///|
/// 页脚要交代的**出处**：许可 / 生成时间 / 内容根指纹。
///
/// ⚠️ 三个字段都可能**是空串**，而且**空就是空**：渲染时那一项**直接不画**，
///    不写「许可 —」这种占位（§1 反面验收：不画假东西）。空的原因各不相同，写在这儿免得下次又猜：
///
/// | 字段 | 真源 | 今天为什么可能是空 |
/// |---|---|---|
/// | `license` | **站点配置**的 `footer.license`（§7） | 那份配置还不存在；过渡期由 `press` 从**实例自己的 `moon.mod` 声明**里取（真实可读的值，不是编的） |
/// | `generated_at` | **构建那一刻**（宿主侧） | **不进内容包**：内容包要逐字节可复现（`press --check` 拿同一份内容重跑必须一致），时间戳进去会让它每次都红 ⇒ 由实例的构建脚本注入 `globalThis.__skillpress_build`，运行期读它 |
/// | `root_fingerprint` | 生成期算的**真值**（复用 G8 那套结构指纹 + sha256 归拢） | 应当总有值；空 = 生成器没算（那是 bug，不是"没数据"） |
pub(all) struct Footer {
  license : String
  generated_at : String
  root_fingerprint : String
}
