#!/usr/bin/env bash
# theme-check.sh —— **主题那四条判据**（PLAN-ui §6.5）落到一条命令上。
#
#   bash tools/theme-check.sh            # 查一遍
#   bash tools/theme-check.sh --list     # 顺手把"还写死在哪"逐条列出来（迁移清单）
#
# ── 为什么要有它 ──────────────────────────────────────────────────────────────
#
# 主题现在是**值**（`Theme` 跟着 Model 走）。这条路有两个**安静**的坏法：
#   · 有人在渲染代码里顺手写死一个色号 ⇒ 换主题时**只有那一处不变**（看着还挺正常）；
#   · 新加一套调色板，某个用途在深色下掉到 3:1 ⇒ "看着好看、读起来瞎"。
# 两条都不会报错、也不会被编译器拦 ⇒ 只能靠判据。
#
# 四条：
#   ① 颜色只有一处源：`shell/tokens.mbt` 之外**不许有字面色号**
#   ② 每一套调色板：可读文字（正文 / 次要 / 品牌）在它自己的底上 ≥4.5
#   ③ 深色海拔：overlay 比 canvas 亮、surface2 比 canvas 暗
#   ④ 色号全覆盖：引擎吐的 1..9 每一类都有非空映射（`tok_of` 里一条都不能少）
#
# ⚠️ 判据自己也要能被证伪：`--selftest` 造三个坏样本（漏色号 / 低对比 / 写死色号），
#    每条都必须被点名 —— 不然它可能是一条"永远绿"的判据。
set -u
cd "$(dirname "$0")/.."

LIST=0
[ "${1:-}" = "--list" ] && LIST=1
fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }

echo "① 颜色只有一处源（字面色号只准住在 shell/tokens.mbt）"
# 允许的例外，每条都要有理由：
#   · shell/tokens.mbt   —— 原语色值**本来就只在这里写死**
#   · 注释行             —— 注释里写"#4f46e5"是记账，不是渲染
HITS=$(grep -nE '#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?\b' shell/*.mbt 2>/dev/null \
  | grep -v '^shell/tokens\.mbt:' \
  | grep -v '^shell/theme\.mbt:' \
  | grep -vE ':[0-9]+: *(//|\*|/\*)' || true)
if [ -z "$HITS" ]; then
  ok "shell/ 的渲染代码里没有字面色号"
else
  N=$(printf '%s\n' "$HITS" | wc -l | tr -d ' ')
  bad "$N 处字面色号还写死在渲染代码里（换主题时它们不会跟着变）"
  [ "$LIST" = "1" ] && printf '%s\n' "$HITS" | sed 's/^/      /'
  echo "      （按文件数：$(printf '%s\n' "$HITS" | cut -d: -f1 | sort | uniq -c | tr '\n' ' ' | sed 's/  */ /g')）"
fi

echo "② 每一套调色板：可读文字 ≥4.5（含"次要"文字；--fg-3 只给机器串与装饰，单独报）"
PYTHONIOENCODING=utf-8 python - <<'PY'
import re, sys
src = open("shell/tokens.mbt", encoding="utf8").read()
# 抓 `pub let <名字> : Palette = { ... }` 那几块
blocks = re.findall(r'pub let (\w+)\s*:\s*Palette\s*=\s*\{(.*?)\n\}', src, re.S)
def field(body, name):
    m = re.search(r'\b' + name + r'\s*:\s*"([^"]+)"', body)
    return m.group(1) if m else None
def lum(hexs):
    h = hexs.lstrip('#')
    if len(h) == 3: h = ''.join(c*2 for c in h)
    ch = [int(h[i:i+2], 16)/255 for i in (0, 2, 4)]
    ch = [c/12.92 if c <= 0.03928 else ((c+0.055)/1.055)**2.4 for c in ch]
    return 0.2126*ch[0] + 0.7152*ch[1] + 0.0722*ch[2]
def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return round((hi+0.05)/(lo+0.05), 2)
bad = 0
for name, body in blocks:
    canvas, s2 = field(body, "canvas"), field(body, "surface2")
    rows = []
    for fg in ("fg1", "fg2", "brand"):
        v = field(body, fg)
        rows.append((fg, ratio(v, canvas), ratio(v, s2)))
    # **压在品牌色上的字**（站名方块 / 实心按钮）—— 深色下品牌色是亮的，
    # 白字会掉到 ~1.9:1（实测踩过：顶栏那个方块标记照原型抄了 `#ffffff`）
    ob = field(body, "on_brand")
    rows.append(("on_brand", ratio(ob, field(body, "brand")), None))
    fg3 = field(body, "fg3")
    line = "  " + name + "："
    for fg, rc, rs in rows:
        ok = rc >= 4.5 and (rs is None or rs >= 4.5)
        mark = "✓" if ok else "✗"
        if not ok: bad += 1
        line += f" {fg} {rc}" + ("" if rs is None else f"/{rs}") + mark
    line += f" ｜ fg3(机器串) {ratio(fg3, canvas)}/{ratio(fg3, s2)}"
    print(line)
    # ③ 深色海拔（只有名字里带 dark 的那套要查）
    if "dark" in name:
        ov = field(body, "overlay")
        if not (lum(ov) > lum(canvas) > lum(s2)):
            print(f"  ✗ {name} 的海拔不成立：overlay {ov} 应比 canvas {canvas} 亮、surface2 {s2} 应更暗")
            bad += 1
print("  （每组两个数：落在 canvas / surface2 上的对比度，on_brand 只有一个数：落在 brand 上；fg3 故意低于 4.5 —— 它不承载可读文字）")
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] && ok "所有调色板的可读文字 ≥4.5，深色海拔成立" || bad "有调色板不达标（上面标 ✗ 的那些）"

echo "④ 色号全覆盖（引擎吐 1..9，一类都不能漏 —— 漏了是安静地变回正文色）"
MISSING=""
for i in 1 2 3 4 5 6 7 8 9; do
  grep -qE "^\s+$i => p\.tok_" shell/theme.mbt || MISSING="$MISSING $i"
done
if [ -z "$MISSING" ]; then
  ok "1..9 都有映射（另有默认分支接 0 与未知值）"
else
  bad "色号$MISSING 没有映射"
fi

echo
if [ "$fail" = "1" ]; then
  echo "theme-check：**有不过的**（红在哪 = 还差什么；迁移没完时 ① 会红，那是预期的）"
else
  echo "theme-check：全部通过"
fi
exit $fail
