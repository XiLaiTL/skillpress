// note.c —— native 上的**诊断输出**（走 stderr）。
//
// 为什么要有它：`gen-file` 的 **stdout 是那份产物本身**（判据对它逐字节 diff），
// 所以诊断必须走 stderr —— 而 MoonBit 的 `println` 只往 stdout 写，`moonbitlang/x` 也没有 stderr。
// 于是这 20 行 C：MoonBit 字符串（UTF-16）→ UTF-8 → `fputs(stderr)`。
//
// 转换函数与 `engine/gates/native/host.c` **共用同一个头**（`mbstr.h`，`static inline`，
// 免得在两个包里各抄一份、将来只改一处）。
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "../gates/native/mbstr.h"

MOONBIT_FFI_EXPORT
void sp_eprintln(moonbit_string_t msg) {
  int32_t len = Moonbit_array_length(msg);
  int32_t n = 0;
  char *utf8 = utf16_to_utf8(msg, len, &n);
  fputs(utf8, stderr);
  fputc('\n', stderr);
  fflush(stderr);
  free(utf8);
}
