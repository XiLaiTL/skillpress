#!/usr/bin/env python3
"""check-links.py —— 检查仓库里所有 Markdown 的链接是否**点得动**。

    python3 tools/check-links.py            # 有问题就非零退出（发版前必跑）
    python3 tools/check-links.py --quiet    # 只打汇总

## 它判两件事（第二件是这条门存在的真正理由）

① **仓内相对链接要能在磁盘上找到**（文档一挪目录就静默失效，本地看不出来、GitHub 上 404）；
② **不许出现"跳出本仓"的相对链接**（`](../…`、`](../../…`）——
   本仓的 `README.md` **同时是 mooncakes 上的包门面**，那里没有兄弟仓：
   `../moobile/skills/…` 在 mooncakes 上（以及在**任何别的机器**上）都点不动。
   跨仓指路只有两种写法：**绝对 URL**（`https://github.com/XiLaiTL/moobile/…`）或**纯文本**。

⚠️ 第二件是从一次真实的难看里长出来的（2026-10-07）：README 重写时写了三处 `../moobile/…`，
   本机点得动（两个仓是兄弟目录），**mooncakes 上全断** —— 而当时仓里**一条链接判据都没有**
   （moobile 那边有 `tools/check_links.py`，这仓一直是空的）。判据缺了，坏法就是"只有别人点的时候才发现"。

与 moobile 那份的关系：判据①照抄（同一套口径），判据②是本仓独有的（因为本仓有"被发布的门面"）。
"""

import os
import re
import sys

try:  # Windows 上重定向输出时的编码保护（与 moobile 那份同款）
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {
    "vendor", ".git", "node_modules", "_build", ".mooncakes", "_scratch",
    "dist", "target", ".skillpress",
    # ⚠️ **冻结夹具语料**要排除：它里面的链接是**判据的输入**（刻意覆盖"相对本文件"与
    # "相对内容根"两种写法，见 `tools/fixtures/README.md`），不是给人点的文档。
    # 把它算进来会逼着人改夹具 —— 那等于改判据的输入去迎合判据。
    "fixtures",
}

# [文本](目标)；目标里可能带 "标题"
LINK_RE = re.compile(r"\[[^\]]*\]\(\s*([^)\s]+)(?:\s+\"[^\"]*\")?\s*\)")

# 必须先剥掉代码再找链接：文档里常有 ``` 里的示例链接（本文的 WEBSITE.md 示例就是），
# 不剥就会误报成断链。
FENCE_RE = re.compile(r"^```.*?^```", re.S | re.M)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")

SKIP_PREFIX = ("http://", "https://", "mailto:", "#", "data:")


def strip_code(text):
    """把围栏代码块与行内代码换成等长空白（保住行号与字符偏移）。"""

    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))

    return INLINE_CODE_RE.sub(blank, FENCE_RE.sub(blank, text))


def md_files():
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in SKIP_DIRS]
        for f in fn:
            if f.endswith(".md"):
                yield os.path.join(dp, f)


def main():
    quiet = "--quiet" in sys.argv
    files = sorted(md_files())
    broken, escaping = [], []
    checked = 0

    for path in files:
        rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
        with open(path, encoding="utf-8", errors="replace") as fh:
            scan = strip_code(fh.read())
        for m in LINK_RE.finditer(scan):
            target = m.group(1)
            if target.startswith(SKIP_PREFIX) or "://" in target:
                continue
            line = scan[: m.start()].count("\n") + 1
            t = target.split("#", 1)[0].split("?", 1)[0]
            if not t:
                continue
            checked += 1
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), t))
            # ⚠️ 判"跳出本仓"看的是**解析之后还在不在仓里**，不是"开头有没有 `../`"：
            #    `../` 往往是**对的**（`skills/skillpress/WEBSITE.md` 指
            #    `../skillpress-user/SKILL.md` 仍在仓内）—— 第一版按前缀判，把这种正确写法
            #    也点红了（判据自己制造假红，正是本仓最不想要的形状）。
            if os.path.relpath(resolved, ROOT).startswith(".."):
                escaping.append((rel, line, target))
                continue
            if not os.path.exists(resolved):
                broken.append((rel, line, target))

    print(f"检查了 {len(files)} 个 Markdown、{checked} 个仓内相对链接")
    bad = 0
    if broken:
        bad = 1
        print(f"\n断链 {len(broken)} 个：")
        for rel, line, target in broken:
            print(f"  {rel}:{line}  ->  {target}")
        if not quiet:
            print("  提示：跨文件指路要用**相对本文档**的路径，GitHub 上才点得动。")
    if escaping:
        bad = 1
        print(f"\n跳出本仓的链接 {len(escaping)} 个（**mooncakes / 别人机器上一定点不动**）：")
        for rel, line, target in escaping:
            print(f"  {rel}:{line}  ->  {target}")
        if not quiet:
            print("  改法：跨仓指路写**绝对 URL**（https://github.com/XiLaiTL/moobile/…）或纯文本。")
    if not bad:
        print("✓ 所有链接都点得动（仓内的指得到东西、没有跳出本仓的）")
    return bad


if __name__ == "__main__":
    sys.exit(main())
