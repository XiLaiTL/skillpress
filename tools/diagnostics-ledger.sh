#!/usr/bin/env bash
# diagnostics-ledger.sh —— **诊断口径账本**：旧实现（冻结规格 `lib/*.mjs`）里每一条"给人看的诊断"，
# 在新实现里**要么有对应物（句子被钉住），要么明确记成一笔欠账**。**不许无声蒸发**。
#
#   bash tools/diagnostics-ledger.sh              # 站岗
#   bash tools/diagnostics-ledger.sh --selftest   # 诱饵：把一条锚点改坏 ⇒ 必须红
#
# ── 为什么要有它（2026-10-06 那场只读静态审计的产物：76 条）──────────────────────
#
# 四条对账判据盯的都是**产物**（生成物 / 块 / 上色），而"诊断"是另一条线：一句话没了、退出码反了、
# 该走 stderr 的走了 stdout —— **产物照样逐字节一致，判据全绿**。审计实测逮到的（都不是推测）：
#   · 🔴 **未知子命令：新实现 `rc=0`**（旧 `rc=2` 且点名）。`cmd && next` 会把拼错的子命令当成功。
#   · 🔴 **`#20`「（N/M 个代码块没配语法或为空，按原文渲染）」今天就在触发却已静默丢** ——
#        旧引擎在**真实语料**上打 `（3/38 个代码块没配语法或为空，按原文渲染）`。
#   · 🔴 **首页两条问题新实现丢了 `${where}：` 定位前缀**；下拉菜单那条连尾注一起丢。
#   · 🟠 **`acceptance.sh` 的 A3 跑的是旧 CLI**（已由 P6 改成"旧引擎现场重印基线 + 新引擎逐字节对账"）。
#   · 🟠 `dump-blocks` / `hl` / `batch` 的参数错与失败路径**打 stdout 且 rc=0**（失败看着像成功）。
#
# ── 判据形状（三档，两个方向都锁住）─────────────────────────────────────────────
#
# | 档 | 断言 | 防的是 |
# |---|---|---|
# | `ok`  | **新源码里有** `新锚` 这句 | 句子被无声删掉/改写（措辞漂了没人管） |
# | `dev` | **新源码里有** `新锚` 这句，**且** PLAN 里记着这笔偏差（`dev` 列给的编号） | 以"新设计下旧句不成立"为名**偷偷**改口径 |
# | `ow`  | **新源码里没有** `老关键句` 这句，**且** PLAN 里记着这笔欠账（`dev` 列的编号） | 两件事：① 欠账不许只躺在判据里、文档里查不到；② **谁把它补上了，这一行就红** —— 逼我把 `ow` 改成 `ok` 并钉住新句子（**自销账**，账本不会烂） |
#
# ✅ **自销账已经真的响过一次**（2026-10-06，P8.2 通用门落地）：账本里 10 行 `ow`（G1–G4 / G7 / G8）
#    当场翻红说"已经补上了"，我按子代理报告里**逐字可 grep 的原文**把它们改成 `ok` 并钉住 ——
#    这就是这套设计的意义：补上了就必须改账本，而不是悄悄多出一批"没人盯着的绿"。
#
# ⚠️ 这一条判据**故意不检查"旧句子还在不在 lib/ 里"**：`lib/` 是冻结规格，不在判据范围。
set -u
cd "$(dirname "$0")/.."

SELFTEST=0
[ "${1:-}" = "--selftest" ] && SELFTEST=1

# 新实现的源码范围 = **MoonBit 源码 + 薄 Node 胶水层**（`tools/*.mjs`：press / 引导层 / 归一化 / DOM 抓取）。
# 为什么不含 `tools/*.sh`：那些是**判据自己** —— 里面必然大量引用旧诊断的原文（用来 grep 对账），
# 扫进来会把 `ow` 行误判成"已经补上了"。`tools/spike/`（探针）与 `tools/baseline/`（基线）也不扫。
NEW_SRC=$(ls engine/*/*.mbt engine/*/*/*.mbt cmd/*/*.mbt tools/*.mjs 2>/dev/null)

# ── 账本：老位置|老关键句|档|新锚（ok/dev 要钉的句子；ow 留 `-`）|dev 列：PLAN 里的编号|覆盖它的判据
#
# `|` 是分隔符，锚点里**不许出现** `|`。老关键句取**够独特的一段**（别取太短，会误命中注释）。
LEDGER=$(cat <<'ROWS'
lib/gen-content.mjs:199|代码块没闭合|ok|代码块没闭合|-|blocks-fixtures 夹具三
lib/gen-content.mjs:238|表格缺分隔行|ok|表格缺分隔行|-|blocks-fixtures 夹具三
lib/gen-content.mjs:283|不支持的构造（图片）|ok|不支持的构造（图片）|-|blocks-fixtures 夹具三
lib/gen-content.mjs:288|不支持的构造（原始 HTML）|ok|不支持的构造（原始 HTML）|-|blocks-fixtures 夹具三
lib/gen-content.mjs:795|内容里有解不开的东西|ok|内容里有解不开的东西|-|blocks-fixtures 夹具三
lib/gen-content.mjs:796|  ✗ ${p}|ok|  ✗ |-|blocks-fixtures 夹具三
lib/gen-content.mjs:379|找不到首页：|ok|找不到首页：skillpress/SKILL.md|DG-首页标签|无（夹具三刻意用干净首页）
lib/gen-content.mjs:401|里没有 `##` 标题|ok|里没有 `##` 标题|DG-首页标签|无
lib/gen-content.mjs:414|还带着|ok|还带着|DG-提示走 stderr|无
lib/gen-content.mjs:419|：纯链接节「|ow|-|DG-丢前缀|无
lib/gen-content.mjs:463|：分栏「|ow|-|DG-丢前缀|无
lib/gen-content.mjs:463|（当菜单的话它就不会渲染在正文里了）|ow|-|DG-丢前缀|无
lib/gen-content.mjs:670|skills/ 下没有 SKILL.md|dev|内容根下没有带 SKILL.md 的目录|D22|blocks-fixtures 夹具四
lib/gen-content.mjs:676|个代码块没配语法或为空，按原文渲染|ow|-|DG-20|无（**今天就在触发**）
lib/gen-content.mjs:800-814|gen-content --check：一致|dev|✓ 一致：|DG-check|tools/press.mjs --check（口径不同：只报"一致/不一致 + 第几行"）
lib/highlight.mjs:135|见程序根 grammars/PROVENANCE.md 的取法|ow|-|DG-高亮指路|无
lib/highlight.mjs:199|拼回来与原文不一致|ok|拼回来与原文不一致|-|无（参数格式与旧版不同，见审计）
lib/highlight.mjs:263|一个代码块都没数到|ow|-|DG-audit|无（audit 闸门整条未移植）
lib/highlight.mjs:322|召回率|ow|-|DG-audit|highlight-parity（更强，但依赖旧 npm 侧在场）
lib/highlight.mjs:323|未上色比例|ow|-|DG-audit|同上
lib/check.mjs:297|G1 frontmatter 缺失或未闭合|ok|G1 frontmatter 缺失或未闭合|-|engine/gates（真语料 76 行逐字节 + 22 条 wbtest）
lib/check.mjs:300|G1 frontmatter 缺 description|ok|G1 frontmatter 缺 |-|同上
lib/check.mjs:301|与目录名 "Y" 不一致|ok|与目录名 |-|同上
lib/check.mjs:304|注册表不读|ok|注册表不读（可留作打包元数据，见 SPEC §3）|-|同上
lib/check.mjs:308|G2 体量 417 行|ok|G2 体量 |-|同上
lib/check.mjs:311|skill 文件一律 LF|ok|skill 文件一律 LF|-|同上
lib/check.mjs:314|G2 代码块 17 行|ok|G2 代码块 |-|同上
lib/check.mjs:323|G2 表格 13 行|ok|G2 表格 |-|同上
lib/check.mjs:332|G3 路径不存在：|ok|G3 路径不存在：|-|同上
lib/check.mjs:336|尾部有行文残留|ok|尾部有行文残留|-|同上
lib/check.mjs:346|G4 命令引用的脚本不存在：|ok|G4 命令引用的脚本不存在：|-|同上
lib/check.mjs:365|G7 出现禁语|ok|G7 出现禁语|-|同上
lib/check.mjs:470|G8 没有 skills.lock.json|ok|G8 没有 skills.lock.json|-|同上
lib/check.mjs:492|G8 新增 skill：|ok|G8 新增 skill：|-|同上
lib/check.mjs:499|G8 指纹变了：|ok|G8 指纹变了：|-|同上
lib/check.mjs:504|G8 锁里还有已删除的 skill|ok|G8 锁里还有已删除的 skill|-|同上
lib/check.mjs:518|索引：|ok|索引：|-|同上（⚠️ 这行服务 G5，G5 按 D18 不搬 ⇒ 通用化时该由内容仓自己打）
lib/check.mjs:542|项不合格|ok|项不合格|-|同上
lib/check.mjs:557|全部通过（|ok|全部通过（|-|同上
lib/check.mjs:522|还没有 skill|ok|还没有 skill|-|同上
lib/check.mjs:610|找不到 moobile 根目录|ok|找不到 moobile 根目录|-|engine/gates/dev（库接受根参数，CLI 默认打仓库名）
lib/docfacts.mjs:564|根目录不存在：|ow|-|DG-facts|无（按 D18 搬去内容仓，不在核心里）
lib/verify-site.mjs:325|没有 site/dist/bundle.js|ow|-|DG-verify|无（P8.3 未做）
lib/verify-site.mjs:329|这条判据要真浏览器（RNW 的行为在 jsdom 里不可信）|ow|-|DG-verify|无（P8.3 未做）
lib/verify-site.mjs:769|条不过|ow|-|DG-verify|无（P8.3 未做）
bin/skillpress.mjs:67|不认识的子命令：|ow|-|DG-CLI|无（**新实现 rc=0**）
bin/skillpress.mjs:73|还没做：${spec.todo}|ow|-|DG-CLI|无
bin/skillpress.mjs:38|公共参数：--repo|ow|-|DG-CLI|无（新用法缺这三条）
ROWS
)

fail=0
n_ok=0
n_ow=0
while IFS='|' read -r old_pos old_key state anchor dev_id cover; do
  [ -z "${state:-}" ] && continue
  case "$state" in
    ok|dev)
      # 计入账本规模（与诱饵无关）：空集合守卫问的是"账本有没有被截断"，不是"锚点找没找到"
      n_ok=$((n_ok + 1))
      # 诱饵模式：把第一条 ok 行的锚点改坏 ⇒ 判据必须红（证明它真在盯句子，不是走过场）
      a="$anchor"
      if [ "$SELFTEST" = 1 ] && [ "$n_ok" = 1 ]; then a="${anchor}这句子根本不存在"; fi
      if grep -qF -- "$a" $NEW_SRC 2>/dev/null; then
        :
      else
        echo "✗ [$state] $old_pos 的对应物在新源码里**找不到**：锚点「$a」"
        echo "      要么是它被无声删了/改了措辞，要么是搬了地方 —— 无论哪种，账本得跟着改（改了才叫记账）"
        fail=1
      fi
      if [ "$state" = "dev" ]; then
        grep -qF -- "$dev_id" PLAN.md || {
          echo "✗ [dev] $old_pos 这笔**刻意偏差**没有记账：PLAN.md 里找不到「$dev_id」"
          echo "      （豁免/偏差必须写在文档里，不能只活在判据里）"
          fail=1
        }
      fi
      ;;
    ow)
      if grep -qF -- "$old_key" $NEW_SRC 2>/dev/null; then
        echo "✓→✗ [ow] 「$old_key」（$old_pos）**已经补上了** —— 这是好事，但账本必须同步："
        echo "      把这一行从 ow 改成 ok，并把「新锚」填成新实现里那句的原文，然后它才重新站岗"
        fail=1
      fi
      grep -qF -- "$dev_id" PLAN.md || {
        echo "✗ [ow] 这笔欠账（$old_pos，编号 $dev_id）在 PLAN.md 里查不到 —— 欠账必须写在文档里"
        fail=1
      }
      n_ow=$((n_ow + 1))
      ;;
    *)
      echo "✗ 账本里有一行的「档」不认识：$state（只认 ok / dev / ow）"; fail=1 ;;
  esac
done <<< "$LEDGER"

# ── 空集合守卫（同一条纪律照到自己头上）─────────────────────────────────────────
# 账本被截断、表格分隔符写坏、`while read` 一个字段都没拿到 —— 这些情况下上面会**一条都不报错**，
# 然后兴高采烈地打"✓ 没有无声蒸发的"。**判据在空集合上通过，比没有判据更糟**（旧实现的原话）。
n_rows=$((n_ok + n_ow))
if [ "$n_rows" -lt 30 ]; then
  echo "✗ 账本只读到 $n_rows 行 —— 太少（真实账本 47 行）⇒ 表格写坏/被截断了？（这条判据不允许在空集合上通过）"
  fail=1
fi
if [ "$n_ok" -lt 5 ]; then
  echo "✗ 「已对上」的行只有 $n_ok 条 —— 全被改成欠账了？（守卫：ok/dev 档至少 5 条）"
  fail=1
fi

echo
if [ "$fail" = 0 ]; then
  if [ "$SELFTEST" = 1 ]; then
    echo "✗ 诱饵没生效：锚点都改坏了判据还绿 ⇒ 这条判据不可信"; exit 1
  fi
  echo "✓ 诊断口径账本：$n_ok 条已对上（句子钉住）+ $n_ow 条已记账的欠账 —— 没有无声蒸发的"
  echo "  ⚠️ 欠账清单见 PLAN 的「诊断欠账」一节；补上一条就要把账本里那行改成 ok（自销账）"
else
  if [ "$SELFTEST" = 1 ]; then
    echo "✓ 诱饵生效：锚点被改坏后判据确实红了"; exit 0
  fi
  echo "✗ 诊断口径账本：上面有红 —— 修完再看一遍"
  exit 1
fi
