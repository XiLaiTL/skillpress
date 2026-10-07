// host.c —— **native（本机）宿主的 C 桩**：只补 MoonBit 侧拿不到的三件事。
//
//   · `sp_cwd()`       当前工作目录（`Host.cwd` 的最后兜底要用它）
//   · `sp_is_tty()`    stdin 是不是终端
//   · `sp_read_line()` 问一句、读一行 —— 与 js 宿主**同一套语义**：
//                      TTY 上逐字节读到换行；管道上把 stdin **整个读一次**再逐行弹出
//                      （只认终端的话，交互逻辑永远测不到；这条在 js 侧已经踩过一遍）
//
// ⚠️ MoonBit 的字符串在 C ABI 上是 **UTF-16**（`moonbit_string_t = uint16_t*`），
//    而文件系统/终端那一侧吃 **UTF-8** 字节 ⇒ 这里自带两个小转换函数（纯 C，不依赖平台 API，
//    免得在 Windows 上用 `WideCharToMultiByte`、到 POSIX 又要换一套）。
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mbstr.h"

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#define SP_GETCWD _getcwd
#define SP_ISATTY _isatty
#define SP_FILENO _fileno
#include <fcntl.h>
#else
#include <unistd.h>
#define SP_GETCWD getcwd
#define SP_ISATTY isatty
#define SP_FILENO fileno
#endif

/* ── 入口 ───────────────────────────────────────────────────────────────────── */

MOONBIT_FFI_EXPORT
moonbit_string_t sp_cwd(void) {
  char buf[4096];
  if (SP_GETCWD(buf, sizeof buf) == NULL) return moonbit_make_string(0, 0);
  int32_t n = 0;
  uint16_t *w = utf8_to_utf16(buf, (int32_t)strlen(buf), &n);
  moonbit_string_t out = moonbit_make_string(n, 0);
  memcpy(out, w, (size_t)n * sizeof(uint16_t));
  free(w);
  return out;
}

MOONBIT_FFI_EXPORT
int32_t sp_is_tty(void) {
  return SP_ISATTY(SP_FILENO(stdin)) ? 1 : 0;
}

/* 管道那条路：把 stdin 读一次、按行切，之后逐次弹出（与 js 宿主同一套） */
static char *sp_pipe = NULL;
static int32_t sp_pipe_len = 0;
static int32_t sp_pipe_pos = 0;
static int sp_pipe_ready = 0;

static void sp_load_pipe(void) {
  sp_pipe_ready = 1;
  size_t cap = 4096;
  size_t n = 0;
  char *buf = malloc(cap);
  for (;;) {
    if (n + 1 >= cap) {
      cap *= 2;
      buf = realloc(buf, cap);
    }
    int c = fgetc(stdin);
    if (c == EOF) break;
    buf[n++] = (char)c;
  }
  buf[n] = 0;
  sp_pipe = buf;
  sp_pipe_len = (int32_t)n;
  sp_pipe_pos = 0;
}

MOONBIT_FFI_EXPORT
moonbit_string_t sp_read_line(moonbit_string_t prompt) {
  /* 提问走 stderr（stdout 是产物，别污染） */
  int32_t plen = Moonbit_array_length(prompt);
  int32_t pbytes = 0;
  char *p = utf16_to_utf8(prompt, plen, &pbytes);
  fputs(p, stderr);
  fflush(stderr);
  free(p);

  char line[4096];
  int32_t n = 0;
  if (SP_ISATTY(SP_FILENO(stdin))) {
    for (;;) {
      int c = fgetc(stdin);
      if (c == EOF || c == '\n') break;
      if (c == '\r') continue;
      if (n < (int32_t)sizeof line - 1) line[n++] = (char)c;
    }
  } else {
    if (!sp_pipe_ready) sp_load_pipe();
    while (sp_pipe_pos < sp_pipe_len && n < (int32_t)sizeof line - 1) {
      char c = sp_pipe[sp_pipe_pos++];
      if (c == '\n') break;
      if (c == '\r') continue;
      line[n++] = c;
    }
  }
  line[n] = 0;
  int32_t wlen = 0;
  uint16_t *w = utf8_to_utf16(line, n, &wlen);
  moonbit_string_t out = moonbit_make_string(wlen, 0);
  memcpy(out, w, (size_t)wlen * sizeof(uint16_t));
  free(w);
  return out;
}

// ── 把 stdout/stderr 切到二进制模式 ────────────────────────────────────────────
// Windows 上文本模式会把换行符翻成 CRLF，而生成物要逐字节等于 js 那条（Node 输出的就是单个换行），
// 也要满足仓里 G2 那条「文件一律 LF」。实测踩到：native 的 gen-file 产物整份都是 CRLF。
MOONBIT_FFI_EXPORT
void sp_set_binary_stdio(void) {
#ifdef _WIN32
  _setmode(_fileno(stdout), _O_BINARY);
  _setmode(_fileno(stderr), _O_BINARY);
#endif
}
