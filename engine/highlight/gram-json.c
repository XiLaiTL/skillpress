// gram-json.c —— 把 vendor 里的 json 语法编进来（一份文件一个目标文件；
// 文件名必须唯一：五个都叫 parser.c 会让 moon 直接 panic，见 vendor/tree-sitter-grammars/PROVENANCE.md）。
// ⚠️ 引号包含按**被包含文件自己的目录**解析 ⇒ vendor 那份的 tree_sitter/*.h 会被正确找到。
#include "../../vendor/tree-sitter-grammars/json/parser.c"
