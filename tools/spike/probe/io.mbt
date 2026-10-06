///|
/// `Document.frontmatter` 的原文（没有就返回空串）。探针关心的是：
/// **它能不能替掉我们手写的那段 frontmatter 解析**。
pub fn frontmatter_raw(doc : @markdown.Document) -> String {
  match doc.frontmatter {
    Some(fm) => fm.raw
    None => ""
  }
}
