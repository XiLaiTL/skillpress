// ts.c —— 原生（native）高亮垫片的 C 桩。
//
// 形状：MoonBit 把 **UTF-8 字节**交给这里，这里跑 parse + query（含**谓词**），
//      把 capture 压成「名字\t起点字节\t终点字节」三列 ASCII 文本交回去。
//      「字节 → UTF-16 码元」的折算在 MoonBit 侧做（那才是引擎消费的坐标）。
//
// 谓词**照 web-tree-sitter 的口径**（`vendor/web-tree-sitter/web-tree-sitter.js` 里那几段是唯一参照）：
//   · `#eq?` 等：capture **不在** match 里 ⇒ `nodes.every(...)` 的空集语义 = **真**；
//   · `#match?` / `#any-of?`：capture **不在** match 里 ⇒ 显式返回 **假**（这是它们与 `#eq?` 的唯一差别）；
//   · `any-` 前缀 ⇒ 把 every 换成 some；
//   · `#is?` / `#is-not?` / `#set!`：web-tree-sitter 只把它们**记成属性**、不参与过滤 ⇒ 这里是**空操作**
//     （我们五份 query 里一条 `#set!` 都没有 ⇒ 这个口径足够）；
//   · 未知算子 ⇒ 不参与过滤（与上游 default 分支一致：只记不筛）。
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// 头文件按**相对本文件**的路径找（stub 是就地编译的）：vendor 那份保持原样不动
#include "../../vendor/tree-sitter/lib/include/tree_sitter/api.h"

const TSLanguage *tree_sitter_json(void);
const TSLanguage *tree_sitter_moonbit(void);
const TSLanguage *tree_sitter_bash(void);
const TSLanguage *tree_sitter_javascript(void);
const TSLanguage *tree_sitter_toml(void);

/* 单体 C 库（与 tree-sitter 上游自己的构建方式一致：一份文件编成一个目标文件） */
#include "../../vendor/tree-sitter/lib/src/lib.c"

static const TSLanguage *lang_by_id(int32_t id) {
  switch (id) {
    case 0: return tree_sitter_json();
    case 1: return tree_sitter_moonbit();
    case 2: return tree_sitter_bash();
    case 3: return tree_sitter_javascript();
    case 4: return tree_sitter_toml();
    default: return NULL;
  }
}

static char *grow(char *buf, size_t *cap, size_t need) {
  if (*cap >= need) return buf;
  size_t ncap = *cap ? *cap * 2 : 1024;
  while (ncap < need) ncap *= 2;
  char *nb = realloc(buf, ncap);
  if (!nb) {
    free(buf);
    return NULL;
  }
  *cap = ncap;
  return nb;
}

/* ── 极小的正则：只覆盖我们 query 实际用到的那几条模式 ─────────────────────────────
   用到的模式：^- ｜ ^[A-Z] ｜ ^[A-Z_][A-Z\d_]+$ ｜ ^(arguments|module|console|window|document)$
                ｜ ^[A-Z][A-Z_]+$ ｜ ^\.[A-Z][A-Z_]+$ ｜ ^#deprecated\(.*\)
   ⇒ 需要：^ $、字面、转义、字符类（含区间与 \d）、分组择一、量词 * +、`.`。
   语义与 JS `new RegExp(p).test(t)` 一致：**不带 ^ 时是"串内任意位置"匹配**，只有 `^` 才锚开头。 */

static const char *re_here(const char *p, const char *t, const char *end);

/* 解析一个"原子"（字符类 / 转义 / 字面 / `.`），返回下一个模式指针；命中与否写进 hit。
   分组不在这里处理（见 re_here）—— 因为分组要带上"剩下的模式"一起匹配。 */
static const char *re_atom(const char *p, const char *t, const char *end, int *hit) {
  *hit = 0;
  if (*p == '\\') {
    char c = p[1];
    if (c == 0) return NULL;
    if (c == 'd') {
      *hit = (t < end && *t >= '0' && *t <= '9');
      return p + 2;
    }
    *hit = (t < end && *t == c);
    return p + 2;
  }
  if (*p == '.') {
    *hit = (t < end);
    return p + 1;
  }
  if (*p == '[') {
    const char *q = p + 1;
    int neg = 0;
    if (*q == '^') {
      neg = 1;
      q++;
    }
    int m = 0;
    char ch = (t < end) ? *t : 0;
    while (*q && *q != ']') {
      if (*q == '\\' && q[1] == 'd') {
        if (ch >= '0' && ch <= '9') m = 1;
        q += 2;
        continue;
      }
      char lo;
      if (*q == '\\') {
        lo = q[1];
        q += 2;
      } else {
        lo = *q;
        q++;
      }
      if (*q == '-' && q[1] != ']' && q[1] != 0) {
        char hi = q[1];
        q += 2;
        if (t < end && ch >= lo && ch <= hi) m = 1;
      } else if (t < end && ch == lo) {
        m = 1;
      }
    }
    if (*q == ']') q++;
    *hit = neg ? (t < end && !m) : m;
    return q;
  }
  *hit = (t < end && *t == *p);
  return p + 1;
}

/* 在文本位置 t 处匹配模式 p；成功返回"匹配到哪儿"（文本指针），失败 NULL */
static const char *re_here(const char *p, const char *t, const char *end) {
  if (*p == 0) return t;
  if (*p == '$' && p[1] == 0) return (t == end) ? t : NULL;
  if (*p == '(') {
    int depth = 0;
    const char *q = p;
    while (*q) {
      if (*q == '\\') {
        q += 2;
        continue;
      }
      if (*q == '[') {
        while (*q && *q != ']') q++;
        if (*q) q++;
        continue;
      }
      if (*q == '(') {
        depth++;
      } else if (*q == ')') {
        depth--;
        if (depth == 0) break;
      }
      q++;
    }
    if (*q != ')') return NULL;
    const char *close = q;
    const char *rest = close + 1;
    const char *a = p + 1;
    for (;;) {
      const char *b = a;
      int d = 0;
      while (b < close) {
        if (*b == '\\') {
          b += 2;
          continue;
        }
        if (*b == '[') {
          while (b < close && *b != ']') b++;
          if (b < close) b++;
          continue;
        }
        if (*b == '(') {
          d++;
        } else if (*b == ')') {
          d--;
        } else if (*b == '|' && d == 0) {
          break;
        }
        b++;
      }
      /* 把 [a,b) 这段择一取出来，拼上 rest 一起匹配 */
      size_t n = (size_t)(b - a);
      char *sub = malloc(n + strlen(rest) + 1);
      if (!sub) return NULL;
      memcpy(sub, a, n);
      strcpy(sub + n, rest);
      const char *r = re_here(sub, t, end);
      free(sub);
      if (r) return r;
      if (b >= close) break;
      a = b + 1;
    }
    return NULL;
  }
  int hit = 0;
  const char *after = re_atom(p, t, end, &hit);
  if (!after) return NULL;
  char quant = (*after == '*' || *after == '+') ? *after : 0;
  const char *rest = quant ? after + 1 : after;
  if (!quant) {
    if (!hit) return NULL;
    return re_here(rest, t + 1, end);
  }
  const char *cur = t;
  if (quant == '+') {
    if (!hit) return NULL;
    cur = t + 1;
  }
  const char *positions[256];
  int n = 0;
  positions[n++] = cur;
  while (n < 256) {
    int h2 = 0;
    const char *nx = re_atom(p, cur, end, &h2);
    if (!nx || !h2) break;
    cur = cur + 1;
    positions[n++] = cur;
  }
  for (int i = n - 1; i >= 0; i--) {
    const char *r = re_here(rest, positions[i], end);
    if (r) return r;
  }
  return NULL;
}

static int re_test(const char *pat, const char *text, uint32_t len) {
  const char *end = text + len;
  if (*pat == '^') return re_here(pat + 1, text, end) != NULL;
  for (const char *t = text; t <= end; t++) {
    if (re_here(pat, t, end)) return 1;
  }
  return 0;
}

/* ── 谓词 ─────────────────────────────────────────────────────────────────────── */

typedef struct {
  const TSQuery *query;
  const char *src;
} Ctx;

static const char *cap_text(const Ctx *c, TSNode n, uint32_t *out_len) {
  uint32_t s = ts_node_start_byte(n);
  uint32_t e = ts_node_end_byte(n);
  *out_len = e - s;
  return c->src + s;
}

static int text_eq(const char *a, uint32_t alen, const char *b, uint32_t blen) {
  return alen == blen && memcmp(a, b, alen) == 0;
}

/* 一条谓词是否通过。`steps` 指向它的第一步（steps[0] = 算子），`nsteps` 是它的步数（不含 Done）。 */
static int pred_passes(const Ctx *ctx, const TSQueryMatch *m, const TSQueryPredicateStep *steps,
                       uint32_t nsteps) {
  if (nsteps < 1 || steps[0].type != TSQueryPredicateStepTypeString) return 1;
  uint32_t op_len = 0;
  const char *op = ts_query_string_value_for_id(ctx->query, steps[0].value_id, &op_len);
  char oper[32];
  if (op_len >= sizeof oper) op_len = sizeof oper - 1;
  memcpy(oper, op, op_len);
  oper[op_len] = 0;

  int is_eq = !strcmp(oper, "eq?") || !strcmp(oper, "any-eq?") || !strcmp(oper, "not-eq?") ||
              !strcmp(oper, "any-not-eq?");
  int is_match = !strcmp(oper, "match?") || !strcmp(oper, "any-match?") ||
                 !strcmp(oper, "not-match?") || !strcmp(oper, "any-not-match?");
  int is_anyof = !strcmp(oper, "any-of?") || !strcmp(oper, "not-any-of?");
  if (!is_eq && !is_match && !is_anyof) return 1; /* is?/is-not?/set!/未知 ⇒ 不参与过滤 */

  int positive = !strcmp(oper, "eq?") || !strcmp(oper, "any-eq?") || !strcmp(oper, "match?") ||
                 !strcmp(oper, "any-match?") || !strcmp(oper, "any-of?");
  int match_all = strncmp(oper, "any-", 4) != 0;

  if (nsteps < 2 || steps[1].type != TSQueryPredicateStepTypeCapture) return 1;
  uint32_t name_len = 0;
  const char *cname = ts_query_capture_name_for_id(ctx->query, steps[1].value_id, &name_len);

  const char *texts[64];
  uint32_t lens[64];
  int n = 0;
  for (uint32_t i = 0; i < m->capture_count && n < 64; i++) {
    uint32_t nl = 0;
    const char *nm = ts_query_capture_name_for_id(ctx->query, m->captures[i].index, &nl);
    if (nl == name_len && memcmp(nm, cname, nl) == 0) {
      texts[n] = cap_text(ctx, m->captures[i].node, &lens[n]);
      n++;
    }
  }

  if (is_eq) {
    if (nsteps >= 3 && steps[2].type == TSQueryPredicateStepTypeCapture) {
      uint32_t n2len = 0;
      const char *cname2 = ts_query_capture_name_for_id(ctx->query, steps[2].value_id, &n2len);
      const char *texts2[64];
      uint32_t lens2[64];
      int n2 = 0;
      for (uint32_t i = 0; i < m->capture_count && n2 < 64; i++) {
        uint32_t nl = 0;
        const char *nm = ts_query_capture_name_for_id(ctx->query, m->captures[i].index, &nl);
        if (nl == n2len && memcmp(nm, cname2, nl) == 0) {
          texts2[n2] = cap_text(ctx, m->captures[i].node, &lens2[n2]);
          n2++;
        }
      }
      int all = 1;
      int some = 0;
      for (int i = 0; i < n; i++) {
        int any = 0;
        for (int j = 0; j < n2; j++) {
          int eq = text_eq(texts[i], lens[i], texts2[j], lens2[j]);
          if (positive ? eq : !eq) any = 1;
        }
        if (!any) all = 0;
        if (any) some = 1;
      }
      return match_all ? all : some;
    }
    if (nsteps >= 3 && steps[2].type == TSQueryPredicateStepTypeString) {
      uint32_t vlen = 0;
      const char *v = ts_query_string_value_for_id(ctx->query, steps[2].value_id, &vlen);
      int all = 1;
      int some = 0;
      for (int i = 0; i < n; i++) {
        int eq = text_eq(texts[i], lens[i], v, vlen);
        int ok = positive ? eq : !eq;
        if (!ok) all = 0;
        if (ok) some = 1;
      }
      return match_all ? all : some;
    }
    return 1;
  }

  if (is_match) {
    if (n < 1) return 0; /* 上游：capture 不在 match 里 ⇒ 假 */
    if (nsteps < 3 || steps[2].type != TSQueryPredicateStepTypeString) return 1;
    uint32_t plen = 0;
    const char *pat = ts_query_string_value_for_id(ctx->query, steps[2].value_id, &plen);
    char pbuf[512];
    if (plen >= sizeof pbuf) plen = sizeof pbuf - 1;
    memcpy(pbuf, pat, plen);
    pbuf[plen] = 0;
    int all = 1;
    int some = 0;
    for (int i = 0; i < n; i++) {
      int mt = re_test(pbuf, texts[i], lens[i]);
      int ok = positive ? mt : !mt;
      if (!ok) all = 0;
      if (ok) some = 1;
    }
    return match_all ? all : some;
  }

  /* any-of? / not-any-of? */
  if (n < 1) return 0; /* 上游：同上 */
  int all = 1;
  int some = 0;
  for (int i = 0; i < n; i++) {
    int found = 0;
    for (uint32_t s = 2; s < nsteps; s++) {
      if (steps[s].type != TSQueryPredicateStepTypeString) continue;
      uint32_t vlen = 0;
      const char *v = ts_query_string_value_for_id(ctx->query, steps[s].value_id, &vlen);
      if (text_eq(texts[i], lens[i], v, vlen)) {
        found = 1;
        break;
      }
    }
    int ok = (found == positive);
    if (!ok) all = 0;
    if (ok) some = 1;
  }
  return match_all ? all : some;
}

/* 该 pattern 的所有谓词是否都通过 */
static int match_passes(const Ctx *ctx, const TSQueryMatch *m) {
  uint32_t nsteps = 0;
  const TSQueryPredicateStep *steps =
      ts_query_predicates_for_pattern(ctx->query, m->pattern_index, &nsteps);
  uint32_t i = 0;
  while (i < nsteps) {
    uint32_t start = i;
    while (i < nsteps && steps[i].type != TSQueryPredicateStepTypeDone) i++;
    if (!pred_passes(ctx, m, steps + start, i - start)) return 0;
    i++; /* 跳过 Done */
  }
  return 1;
}

/* ── 主入口 ───────────────────────────────────────────────────────────────────── */

static moonbit_string_t run_captures(const TSLanguage *lang, moonbit_bytes_t src, int32_t src_len,
                                     moonbit_bytes_t q, int32_t q_len) {
  if (!lang) return moonbit_make_string(0, 0);
  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, lang)) {
    ts_parser_delete(parser);
    return moonbit_make_string(0, 0);
  }
  TSTree *tree = ts_parser_parse_string(parser, NULL, (const char *)src, (uint32_t)src_len);
  if (!tree) {
    ts_parser_delete(parser);
    return moonbit_make_string(0, 0);
  }
  TSNode root = ts_tree_root_node(tree);
  uint32_t err_off = 0;
  TSQueryError err_type = 0;
  TSQuery *query = ts_query_new(lang, (const char *)q, (uint32_t)q_len, &err_off, &err_type);
  if (!query) {
    ts_tree_delete(tree);
    ts_parser_delete(parser);
    return moonbit_make_string(0, 0);
  }
  Ctx ctx = { query, (const char *)src };
  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_exec(cursor, query, root);

  char *buf = NULL;
  size_t cap = 0, len = 0;
  TSQueryMatch m;
  uint32_t ci = 0;
  uint32_t last_id = 0xFFFFFFFFu;
  int last_ok = 1;
  /* 与 web-tree-sitter 一致：用 **captures** 迭代（顺序口径），谓词在 **match** 层面过滤；
     同一个 match 的谓词只算一次（否则每条 capture 都要重算一遍）。 */
  while (ts_query_cursor_next_capture(cursor, &m, &ci)) {
    if (m.id != last_id) {
      last_id = m.id;
      last_ok = match_passes(&ctx, &m);
    }
    if (!last_ok) continue;
    uint32_t nl = 0;
    const char *name = ts_query_capture_name_for_id(query, m.captures[ci].index, &nl);
    char line[256];
    int k = snprintf(line, sizeof line, "%.*s\t%u\t%u\n", (int)nl, name,
                       ts_node_start_byte(m.captures[ci].node), ts_node_end_byte(m.captures[ci].node));
    buf = grow(buf, &cap, len + (size_t)k + 1);
    if (!buf) break;
    memcpy(buf + len, line, (size_t)k);
    len += (size_t)k;
  }
  moonbit_string_t out = moonbit_make_string((int32_t)len, 0);
  for (size_t i = 0; i < len; i++) out[i] = (uint16_t)(unsigned char)buf[i];
  free(buf);
  ts_query_cursor_delete(cursor);
  ts_query_delete(query);
  ts_tree_delete(tree);
  ts_parser_delete(parser);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_string_t sp_captures(int32_t lang_id, moonbit_bytes_t src, int32_t src_len,
                             moonbit_bytes_t q, int32_t q_len) {
  return run_captures(lang_by_id(lang_id), src, src_len, q, q_len);
}

MOONBIT_FFI_EXPORT
moonbit_string_t sp_captures_ptr(const TSLanguage *lang, moonbit_bytes_t src, int32_t src_len,
                                 moonbit_bytes_t q, int32_t q_len) {
  return run_captures(lang, src, src_len, q, q_len);
}
