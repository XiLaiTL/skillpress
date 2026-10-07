// mbstr.h —— MoonBit 字符串（C ABI 上是 **UTF-16**）与 **UTF-8** 之间的两个小转换。
//
// 为什么放在头里、用 `static inline`：`native-stub` 是**按包**编的（每个包的 C 桩各编一次），
// 两个包都要用同一套转换 ⇒ 共用一个头最省事，而且 `static` 不会在链接期撞符号。
// （不依赖平台 API：Windows 上是 `WideCharToMultiByte`、POSIX 又是另一套，纯 C 一份就到处都对。）
#ifndef SKILLPRESS_MBSTR_H
#define SKILLPRESS_MBSTR_H

#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ── UTF-8 → UTF-16（返回 malloc 出来的 uint16 数组，长度写进 *out_len）──────────── */
static inline uint16_t *utf8_to_utf16(const char *s, int32_t len, int32_t *out_len) {
  uint16_t *out = malloc(((size_t)len + 1) * 2 * sizeof(uint16_t));
  int32_t n = 0;
  for (int32_t i = 0; i < len;) {
    unsigned char c = (unsigned char)s[i];
    uint32_t cp;
    int adv;
    if (c < 0x80) {
      cp = c;
      adv = 1;
    } else if ((c & 0xE0) == 0xC0) {
      cp = c & 0x1F;
      adv = 2;
    } else if ((c & 0xF0) == 0xE0) {
      cp = c & 0x0F;
      adv = 3;
    } else if ((c & 0xF8) == 0xF0) {
      cp = c & 0x07;
      adv = 4;
    } else {
      cp = 0xFFFD;
      adv = 1;
    }
    for (int k = 1; k < adv && i + k < len; k++) {
      cp = (cp << 6) | ((unsigned char)s[i + k] & 0x3F);
    }
    i += adv;
    if (cp >= 0x10000) {
      cp -= 0x10000;
      out[n++] = (uint16_t)(0xD800 + (cp >> 10));
      out[n++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
    } else {
      out[n++] = (uint16_t)cp;
    }
  }
  *out_len = n;
  return out;
}

/* ── UTF-16 → UTF-8（返回 malloc 出来的字节，长度写进 *out_len）──────────────────── */
static inline char *utf16_to_utf8(const uint16_t *s, int32_t len, int32_t *out_len) {
  char *out = malloc((size_t)len * 4 + 1);
  int32_t n = 0;
  for (int32_t i = 0; i < len; i++) {
    uint32_t cp = s[i];
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < len && s[i + 1] >= 0xDC00 && s[i + 1] <= 0xDFFF) {
      cp = 0x10000 + ((cp - 0xD800) << 10) + (s[i + 1] - 0xDC00);
      i++;
    }
    if (cp < 0x80) {
      out[n++] = (char)cp;
    } else if (cp < 0x800) {
      out[n++] = (char)(0xC0 | (cp >> 6));
      out[n++] = (char)(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
      out[n++] = (char)(0xE0 | (cp >> 12));
      out[n++] = (char)(0x80 | ((cp >> 6) & 0x3F));
      out[n++] = (char)(0x80 | (cp & 0x3F));
    } else {
      out[n++] = (char)(0xF0 | (cp >> 18));
      out[n++] = (char)(0x80 | ((cp >> 12) & 0x3F));
      out[n++] = (char)(0x80 | ((cp >> 6) & 0x3F));
      out[n++] = (char)(0x80 | (cp & 0x3F));
    }
  }
  out[n] = 0;
  *out_len = n;
  return out;
}


#endif
