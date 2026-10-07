#!/usr/bin/env python3
"""make-fixture-png.py —— 生成夹具语料里那张图（**可复现**，别手工丢一张图进来）。

    python3 tools/fixtures/make-fixture-png.py

产物：`tools/fixtures/corpus/skills/assets/fixture.png`（160×90）。

## 为什么要"生成"而不是"随便放一张图"

那张图是 `#10 图片` 这条判据的**输入**之一：`gamma-skill/SKILL.md` 里写着
`![一张夹具图](../assets/fixture.png)`，而站点侧要读到"浏览器**真的解码了**它"
（`naturalWidth > 0`）。所以这张图必须：

  · **真的能被解码**（不是空文件、不是改名成 .png 的文本）—— 判据正是靠这一点把"空壳 `<img>`"筛掉；
  · **尺寸已知**（160×90）—— 好让判据顺手核一下"排出来的宽高不是 0"；
  · **可复现** —— 语料是冻结的，配一张"谁也不知道怎么来的"二进制，将来没人能重建它。

不依赖 Pillow：PNG 的那点容器格式手写（IHDR + IDAT(zlib) + IEND）比装一个图形库省事得多。
"""

import os
import struct
import zlib

W, H = 160, 90
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "corpus", "skills", "assets", "fixture.png")


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def pixel(x: int, y: int):
    """一张"看得出是张图"的图案：蓝底 + 斜向亮带 + 四周一圈深色边框。

    ⚠️ 刻意**不用纯色**：纯色图上"图没画出来"和"图画出来了"在肉眼与截图里分不清，
       而斜带让"图被拉伸/裁切/错位"一眼可见（它是给**人**看的夹具，不只给机器）。
    """
    edge = 3
    if x < edge or y < edge or x >= W - edge or y >= H - edge:
        return (24, 32, 48, 255)
    band = (x + y) % 40 < 12
    t = x / (W - 1)
    base = (int(40 + 60 * t), int(90 + 70 * t), int(200 - 40 * t), 255)
    return (235, 240, 255, 255) if band else base


def main() -> None:
    raw = bytearray()
    for y in range(H):
        raw.append(0)  # 每行的 filter 字节（0 = None；夹具不追求压缩率）
        for x in range(W):
            raw.extend(pixel(x, y))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))  # 8bit RGBA
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(png)
    print(f"写出 {OUT}（{len(png)} 字节，{W}×{H}）")


if __name__ == "__main__":
    main()
