///|
/// native target 上**不读文件**：返回一段内嵌样本。
///
/// 为什么可以偷这个懒：native 这条探针要回答的是"**tree-sitter 上色链能不能在 native 上跑**"，
/// 文件 IO 不是它要回答的问题（且 js 那边已经用真文件验过 markdown 那一半了）。
/// 样本刻意含一个 ```bash 块，好让同一段流水线（解析 → 取围栏块 → 上色）两边都跑一遍。
pub fn read_text(_path : String) -> String {
  "# 样本\n\n拿来跑通 native 这条链的小文档。\n\n```bash\nbash tools/verify_all.sh\n```\n"
}
