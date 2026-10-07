// shell/buildstamp.mbt —— **构建时间戳：宿主侧注入，不进内容包**（DESIGN-site.md §5 页脚那一行）。
//
// ## 为什么不在内容包里（这一条是实测出来的，不是洁癖）
//
// 内容包必须**逐字节可复现**：`node tools/press.mjs --check` 拿同一份内容重跑一遍，
// 产物与磁盘上那份**逐行比对**，不一样就红。而"生成那一刻"每次都不一样 ⇒ 时间戳一进内容包，
// 这条门**每跑必红**，然后人就会去关掉它。所以真源只能是**构建那一刻的宿主**：
//
//     实例的 `build-web.mjs` → 往 `dist/index.html` 注入 `globalThis.__skillpress_build`
//         ↓
//     这里读一次（读不到就是空串 ⇒ 页脚那一项**不画**，不猜、不写死）
//
// ⚠️ 与 `engine/highlight/ts_shim.mbt` 同一条互操作形状（`extern "js"` + `#|`），
//    但**不共用那个全局**：`__skillpress_ts` 是引擎的语法资产，这个是站点的构建信息。

///|
extern "js" fn build_stamp_raw() -> String =
  #|() => {
  #|  const b = globalThis.__skillpress_build;
  #|  return (b && typeof b.generatedAt === "string") ? b.generatedAt : "";
  #| }

///|
/// 构建时间（宿主给的**本地**短形态，如 `2026-10-07 13:52`；空串 = 没注入）。
pub fn build_stamp() -> String {
  build_stamp_raw()
}
