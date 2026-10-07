// 由 `skillpress` 生成（P6 起是 MoonBit 引擎：`cmd/skillpress gen-file`）—— **别手改**。
//
// 类型**不在这里**：它们在包 `XiLaiTL/skillpress/shell`（`Span` / `Block` / `Kid` / `Doc` /
// `NavItem` / `Section` / `Home`）。这份文件只**填值**，所以每个构造器都带 `@shell.` 前缀 ——
// 为什么必须带，见 `engine/content/emit.mbt` 里 `REC` 的注释。
//
// 内容源：`skills/skillpress/WEBSITE.md`（首页）+ `skills/<name>/{SKILL.md,references/*.md,scripts/*}`。
// 为什么在构建期解析 markdown：见 `tools/gen-content.mjs` 的文件头（映射的**参照实现**还在那边）。

///| 首页（来自 `skills/skillpress/WEBSITE.md`）。
pub fn home() -> @shell.Home {
  {
    title: "skillpress —— 改它的人和用它的人",
    lede: [
      @shell.P([@shell.Txt("我们相信"), @shell.Bold("文档的形态会变成 skill"), @shell.Txt("（agent 拿来即用的那种），而不再另有一份给人看的 docs —— 所以这个站点的意义就是那批 skill 的"), @shell.Bold("人读侧"), @shell.Txt("：同一份内容，机器读原文，人读这里。")]),
      @shell.P([@shell.Txt("这一份语料是"), @shell.Bold("程序自己"), @shell.Txt("的 skill：两份，一份给"), @shell.Bold("改这套程序的人"), @shell.Txt("，一份给"), @shell.Bold("用它做站点的人"), @shell.Txt("。 它同时是站点的"), @shell.Bold("首页源"), @shell.Txt("，也是"), @shell.Bold("站点的家"), @shell.Txt("（站点工程就住在它的 "), @shell.Code("scripts/.skillpress/"), @shell.Txt(" 里）。")]),
    ],
    sections: [
      { title: [@shell.Txt("先读哪一份")], link: "skillpress-user", nav: ([] : Array[@shell.NavItem]), blocks: [
        @shell.P([@shell.Txt("要用这套工具做站点就看 "), @shell.Code("skillpress-user"), @shell.Txt("（首页怎么写、配色改哪儿、加一块新构造、怎么验收）； 要改这套程序就看 "), @shell.Code("skillpress-dev"), @shell.Txt("（三个根、改什么跑哪条门、怎么加判据与诱饵）。 两份的边界只有一条："), @shell.Bold("写内容的不改引擎，改引擎的不写内容"), @shell.Txt("。")]),
      ] },
      { title: [@shell.Txt("怎么改这套程序")], link: "skillpress-dev", nav: ([] : Array[@shell.NavItem]), blocks: [
      ] },
    ],
  }
}

///| 全部 skill（按 slug 排序，保证生成物稳定）。
pub fn skills() -> Array[@shell.Doc] {
  [
    {
      slug: "skillpress-dev",
      title: "skillpress 开发者 —— 改这套程序",
      desc: "改 skillpress 程序本身（引擎 / 三道门 / 上色 / 站点判据 / 规范与账本）：四个根在哪、改了什么跑…",
      full_desc: "改 skillpress 程序本身（引擎 / 三道门 / 上色 / 站点判据 / 规范与账本）：四个根在哪、改了什么跑哪条门、怎么加一条判据和它的诱饵、落锁的规矩、以及那些会安静咬人的坑。",
      when: "你要动引擎（`engine/**` 的 MoonBit（内容管线 / 门 / 上色）与 `engine/site/`（站点判据））、要加或改一道门的判据、动语法资产与 SPEC/SKILLS/DRIFT，或者遇到「门绿着，但它查的不是我以为的那份东西」这类症状。",
      blocks: [
        @shell.P([@shell.Bold("一句话"), @shell.Txt("：这台程序只守一条 —— "), @shell.Bold("一个说谎的 skill 比没有 skill 更糟"), @shell.Txt("。 门、规范、账本、判据全都是为这一条服务的；判断任何改动，先问\"它让谎更难撒，还是更容易\"。")]),
        @shell.H2([@shell.Txt("一、先认清四个根（不认清就会改错文件）")]),
        @shell.Table([[@shell.Txt("根")], [@shell.Txt("在哪")], [@shell.Txt("谁说了算")]], [[[@shell.Bold("程序")], [@shell.Txt("本仓库根（"), @shell.Code("interest/skillpress"), @shell.Txt("）")], [@shell.Code("cmd/skillpress/cli/args.mbt"), @shell.Txt("（门与 CLI）+ "), @shell.Code("engine/site/entry.mbt"), @shell.Txt("（站点判据）—— "), @shell.Bold("唯一算法")]], [[@shell.Bold("仓库"), @shell.Txt("（内容仓）")], [@shell.Bold("旁边的"), @shell.Txt(" "), @shell.Code("../moobile/"), @shell.Txt("；找不到才退回\"程序往上 3 层\"")], [@shell.Txt("同上："), @shell.Code("--repo"), @shell.Txt(" / "), @shell.Code("SKILLPRESS_REPO")]], [[@shell.Bold("内容")], [@shell.Code("<内容仓>/skills")], [@shell.Txt("同上："), @shell.Code("--skills"), @shell.Txt(" / "), @shell.Code("SKILLPRESS_SKILLS")]], [[@shell.Bold("实例")], [@shell.Code("<内容>/skillpress/scripts/.skillpress")], [@shell.Txt("同上："), @shell.Code("--app"), @shell.Txt(" / "), @shell.Code("SKILLPRESS_APP_DIR")]]]),
        @shell.P([@shell.Txt("⚠️ "), @shell.Bold("不猜是刻意的"), @shell.Txt("：猜错的表现是\"站点没更新\"—— 页面照常渲染，只是旧内容，最难查的一类症状。 别再手写\"往上几层\"：那四条路径原先在 5 个文件里各写一遍，家规改一次要改五处。")]),
        @shell.H2([@shell.Txt("二、改了什么 → 跑什么（都在"), @shell.Bold("程序根"), @shell.Txt("跑）")]),
        @shell.Code("bash", "node tools/run-js.mjs check               # 门：skill 自己（G1–G8）\nmoon test engine/gates                   # 证伪：22 条 wbtest，诱饵必须全被点名\nnode tools/press.mjs --check              # 生成物与源一致吗\n# facts（事实来源对账）按 D18 住在**内容仓**：moobile/tools/skillpress-gates.mjs --gate facts\nnode tools/run-js.mjs audit               # 上色的回归闸门（召回率 / 漏色比例）\nbash tools/verify.sh                     # 站点判据（23 条；**要一次 native 编译**）", [("node", 6), (" tools/run-js.mjs check               ", 0), ("# 门：skill 自己（G1–G8）", 3), ("\n", 0), ("moon", 6), (" test engine/gates                   ", 0), ("# 证伪：22 条 wbtest，诱饵必须全被点名", 3), ("\n", 0), ("node", 6), (" tools/press.mjs ", 0), ("--check", 4), ("              ", 0), ("# 生成物与源一致吗", 3), ("\n", 0), ("# facts（事实来源对账）按 D18 住在**内容仓**：moobile/tools/skillpress-gates.mjs --gate facts", 3), ("\n", 0), ("node", 6), (" tools/run-js.mjs audit               ", 0), ("# 上色的回归闸门（召回率 / 漏色比例）", 3), ("\n", 0), ("bash", 6), (" tools/verify.sh                     ", 0), ("# 站点判据（23 条；**要一次 native 编译**）", 3)]),
        @shell.P([@shell.Txt("站点判据的"), @shell.Bold("现役"), @shell.Txt("那一份在 native CLI 里（要 C 工具链；js 那条路上 "), @shell.Code("moonbitlang/async"), @shell.Txt(" 没有 http server / websocket / process）：")]),
        @shell.Code("bash", "moon build cmd/skillpress-native --target native\n_build/native/debug/build/cmd/skillpress-native/skillpress-native verify [--skills <内容根>] [--app <实例>]", [("moon", 6), (" build cmd/skillpress-native ", 0), ("--target", 4), (" native\n", 0), ("_build/native/debug/build/cmd/skillpress-native/skillpress-native", 6), (" verify [--skills ", 0), ("<", 9), ("内容根", 0), (">", 9), ("] [--app ", 0), ("<", 9), ("实例", 0), (">", 9), ("]", 0)]),
        @shell.Quote([@shell.Txt("在"), @shell.Bold("内容仓根"), @shell.Txt("跑同一份程序就多一层："), @shell.Code("node ../skillpress/tools/run-js.mjs …"), @shell.Txt("。")]),
        @shell.Table([[@shell.Txt("动了什么")], [@shell.Txt("必须跟着跑")]], [[[@shell.Code("engine/gates/"), @shell.Txt(" 的判据")], [@shell.Code("moon test engine/gates"), @shell.Txt("（22 条 wbtest）—— "), @shell.Bold("新判据必须配诱饵"), @shell.Txt("，否则等于没加")]], [[@shell.Code("engine/content/"), @shell.Txt(" / "), @shell.Code("engine/highlight/")], [@shell.Code("bash tools/engine-fixtures.sh"), @shell.Txt("（四份读数 vs 入库 golden；有意的变化就 "), @shell.Code("--capture"), @shell.Txt(" 重采）；上色的改动还要 "), @shell.Code("node tools/run-js.mjs audit")]], [[@shell.Code("engine/site/**"), @shell.Txt("（站点判据"), @shell.Bold("本体"), @shell.Txt("）")], [@shell.Code("bash tools/verify.sh"), @shell.Txt("（23 条，真 Chrome）；加断言照 "), @shell.Code("engine/site/checks.mbt"), @shell.Txt(" 里那张表写（每条抓哪个失败模式），加完跑 "), @shell.Code("bash tools/engine-fixtures.sh")]], [[@shell.Code("cmd/skillpress-native/**"), @shell.Txt("（站点判据的"), @shell.Bold("入口"), @shell.Txt("）")], [@shell.Txt("同上（"), @shell.Code("verify"), @shell.Txt(" 只有 native 那份有）")]], [[@shell.Code("facts"), @shell.Txt("（按 D18 住在"), @shell.Bold("内容仓"), @shell.Txt("）")], [@shell.Code("moobile/tools/skillpress-gates.mjs --gate facts")]], [[@shell.Code("grammars/**")], [@shell.Code("audit"), @shell.Txt(" + 更新 "), @shell.Code("grammars/PROVENANCE.md"), @shell.Txt(" 的 sha256")]], [[@shell.Bold("native 那一侧"), @shell.Txt("（"), @shell.Code("engine/gates/native/**"), @shell.Txt("、"), @shell.Code("engine/content/io.native.mbt"), @shell.Txt("、"), @shell.Code("engine/highlight/{ts_shim.native.mbt,ts.c,gram-*.c}"), @shell.Txt("、"), @shell.Code("cmd/skillpress-native/**"), @shell.Txt("、"), @shell.Code("vendor/tree-sitter{,-grammars}/**"), @shell.Txt("）")], [@shell.Code("bash tools/native-parity.sh"), @shell.Txt("（+ "), @shell.Code("--selftest"), @shell.Txt("）—— 同一份语料上 "), @shell.Bold("native 与 js 的产物逐字节一致"), @shell.Txt("。改 "), @shell.Code("vendor/web-tree-sitter/**"), @shell.Txt(" 或 "), @shell.Code("vendor/tree-sitter/**"), @shell.Txt(" 时先读两份 "), @shell.Code("PROVENANCE.md"), @shell.Txt("："), @shell.Bold("两个 runtime 必须同版本"), @shell.Txt("（版本不齐会差几行、而两边看上去都还绿），脚本自己会把版本号与 sha256 对一遍")]], [[@shell.Code("engine/scaffold/**"), @shell.Txt(" / "), @shell.Code("template/instance/**"), @shell.Txt(" / "), @shell.Code("cmd/skillpress/cli/attach.mbt")], [@shell.Code("bash tools/attach-check.sh"), @shell.Txt("（+ "), @shell.Code("--selftest"), @shell.Txt("）；"), @shell.Bold("模板动了要重生成自举那份实例"), @shell.Txt("："), @shell.Code("node tools/run-js.mjs attach --repo . --skills skills --force"), @shell.Txt("（它写的是"), @shell.Bold("别人的仓库"), @shell.Txt(" ⇒ 判据盯的是\"幂等 / 不覆盖 / 坏输入不落盘\"）；改完想确认\"生成出来真能跑\"就加 "), @shell.Code("--build"), @shell.Txt("（拷依赖 + 真编一次，慢）")]], [[@shell.Txt("内容源（在"), @shell.Bold("内容仓"), @shell.Txt("）")], [@shell.Code("check"), @shell.Txt(" → 复核体量 → "), @shell.Code("check --update-lock <名字>"), @shell.Txt(" → "), @shell.Code("press")]], [[@shell.Code("SPEC.md"), @shell.Txt(" / "), @shell.Code("SKILLS.md"), @shell.Txt(" / "), @shell.Code("DRIFT.md")], [@shell.Txt("查有没有被引用的路径与 "), @shell.Code("§"), @shell.Txt(" 号（G3 / G6）—— "), @shell.Bold("改引用，别改判据")]]]),
        @shell.H2([@shell.Txt("三、三条不许破的规矩")]),
        @shell.Ul([(0, "1. ", [@shell.Bold("不许为了让谁变绿而放宽断言"), @shell.Txt("。放宽 = 把 bug 藏起来；非放宽不可，注释里要写清为什么。")]), (0, "2. ", [@shell.Bold("落锁不是让门变绿的手段"), @shell.Txt("。"), @shell.Code("--update-lock"), @shell.Txt(" 的含义是\"我"), @shell.Bold("看过"), @shell.Txt("这次体量变化\"；")])]),
        @shell.P([@shell.Txt("而且只锁一个（"), @shell.Code("--update-lock <名字>"), @shell.Txt("）—— 整文件重写会把别人正在改的那份指纹一起锁掉。")]),
        @shell.Ul([(0, "3. ", [@shell.Bold("空集合不算通过"), @shell.Txt("。一个块都没数到时 "), @shell.Code("NaN < 阈值"), @shell.Txt(" 是 false ⇒ 会假绿；")])]),
        @shell.P([@shell.Txt("出口一律 "), @shell.Code("process.exitCode"), @shell.Txt("，别调 "), @shell.Code("process.exit()"), @shell.Txt("。")]),
        @shell.P([@shell.Txt("判据逐条（G1–G8）、怎么加一条新规则、诱饵的形状 —— 见 "), @shell.Code("references/gates.md"), @shell.Txt("。")]),
        @shell.H2([@shell.Txt("四、坑（都是踩出来的）")]),
        @shell.Table([[@shell.Txt("现象")], [@shell.Txt("真因")], [@shell.Txt("处置")]], [[[@shell.Txt("门绿着，但它查的不是那份东西")], [@shell.Txt("除 "), @shell.Code("roots.mjs"), @shell.Txt(" 外的\"往上几层\"都是漂移点（曾实测 "), @shell.Code("check"), @shell.Txt(" 报「moobile 根："), @shell.Code("D:\\"), @shell.Txt("」、遍历整个盘）")], [@shell.Txt("只用 "), @shell.Code("roots.mjs")]], [[@shell.Txt("内容里讲程序的指针\"查过了\"")], [@shell.Txt("其实是"), @shell.Bold("静默不查"), @shell.Txt("：第二个根曾与第一个重复，且 "), @shell.Code("bin"), @shell.Txt("/"), @shell.Code("lib"), @shell.Txt("/"), @shell.Code("grammars"), @shell.Txt(" 不在 G3 白名单")], [@shell.Txt("现已修：第二个根 = 程序根 + 三个目录进白名单 + 诱饵 "), @shell.Code("bad-program-path")]], [[@shell.Txt("某条判据\"永远绿\"")], [@shell.Txt("口径太松（整页子串 / 合成 "), @shell.Code("click()"), @shell.Txt(" / 写死端口）")], [@shell.Txt("与同一次运行里的另一处口径对齐；"), @shell.Bold("总数也是读数"), @shell.Txt("（少验了长得像验过了）")]], [[@shell.Txt("判据\"绿着\"但其实是假绿（第二种形态）")], [@shell.Txt("`if diff -u a b \\")], [@shell.Txt("head -40; then"), @shell.Code(" —— **管道把退出码吃掉了**，取到的是 "), @shell.Txt("head` 的 0 ⇒ 明明有差异也走\"通过\"")], [@shell.Txt("先重定向再判退出码（"), @shell.Code("diff … > out"), @shell.Txt("），或干脆 "), @shell.Code("cmp"), @shell.Txt("；"), @shell.Bold("对账脚本"), @shell.Txt("上最容易犯")]], [[@shell.Txt("某个语言上色突然少一大片")], [@shell.Txt("tree-sitter 的 "), @shell.Code("Parser"), @shell.Txt(" "), @shell.Bold("有状态"), @shell.Txt("：最后装载的语言污染之后所有解析")], [@shell.Txt("每种语言一个 "), @shell.Code("Parser")]], [[@shell.Code("press"), @shell.Txt(" 跑完站点还是旧的")], [@shell.Txt("生成物没重跑，或者 "), @shell.Code("dist/"), @shell.Txt(" 是缓存")], [@shell.Code("press --check"), @shell.Txt("；实在怪就删 "), @shell.Code("dist/"), @shell.Txt(" 重编")]], [[@shell.Txt("frontmatter 静默失效")], [@shell.Txt("文件是 CRLF（"), @shell.Code("(.*)$"), @shell.Txt(" 匹配不到行尾 "), @shell.Code("\\r"), @shell.Txt("）")], [@shell.Txt("一律 LF（"), @shell.Code(".gitattributes"), @shell.Txt(" 钉着，G2 也拦）")]], [[@shell.Txt("改完程序，内容侧报\"某路径不存在\"")], [@shell.Txt("G3 的候选根只有三个（内容仓根 / 程序根 / 那个 skill 自己的目录）")], [@shell.Txt("指针写清是相对哪个根")]]]),
        @shell.H2([@shell.Txt("五、程序自己的 skill 住哪儿（这份就在这儿）")]),
        @shell.P([@shell.Txt("程序自己的 skill 住在 "), @shell.Bold("本仓库的 `skills/`"), @shell.Txt(" —— 给"), @shell.Bold("用这个仓库的人"), @shell.Txt("看的那份（用它的人 + 改它的人）。")]),
        @shell.P([@shell.Txt("⚠️ "), @shell.Bold("两个 `skills/`，别混"), @shell.Txt("：内容仓（"), @shell.Code("../moobile/"), @shell.Txt("）里那个也在同一个位置、同一个名字， 但它是"), @shell.Bold("内容"), @shell.Txt("（会被印成站点、给别人看的那份）。分得清它们的只有"), @shell.Bold("仓库"), @shell.Txt("，不是目录名 —— 所以指向内容的地方一律写全 "), @shell.Code("<内容仓>/skills/…"), @shell.Txt("，别只写 "), @shell.Code("skills/…"), @shell.Txt("。")]),
        @shell.P([@shell.Txt("⚠️ 与老约定的一处差别：内容根原先是 "), @shell.Bold("`.agents` 下的 `skills`"), @shell.Txt("（"), @shell.Bold("harness 的项目扫描根"), @shell.Txt("，rank 200）， 搬到 "), @shell.Code("skills/"), @shell.Txt(" 之后 harness "), @shell.Bold("不再自动加载"), @shell.Txt("它们（"), @shell.Code("skills/"), @shell.Txt(" 不在 DSH 的扫描根里）。 要恢复\"agent 一进仓库就带 7 份 skill\"，得配 DSH 的 "), @shell.Code("customSkillDirs"), @shell.Txt("（本机全局设置）—— "), @shell.Bold("别两边各放一份"), @shell.Txt("：两份内容就是两份会漂的真相。")]),
        @shell.P([@shell.Txt("⚠️ 这不是风格问题："), @shell.Code("skills/"), @shell.Txt(" 的形状和内容根"), @shell.Bold("一模一样"), @shell.Txt("（"), @shell.Code("skills/<名字>/SKILL.md"), @shell.Txt("）， 所以将来把程序自己的 skill 印成站点（自举）时，它天然就是那个内容根。")]),
        @shell.P([@shell.Txt("跑门时"), @shell.Bold("显式指这个根"), @shell.Txt("（默认那个根是内容仓的）：")]),
        @shell.Code("bash", "node tools/run-js.mjs check --skills skills", [("node", 6), (" tools/run-js.mjs check ", 0), ("--skills", 4), (" skills", 0)]),
        @shell.P([@shell.Txt("落锁同样认这个根，而且 "), @shell.Code("--update-lock"), @shell.Txt(" "), @shell.Bold("出现在哪儿都认"), @shell.Txt("（曾经它必须正好是第一个参数， 于是 "), @shell.Code("check --skills <根> --update-lock"), @shell.Txt(" 会"), @shell.Bold("静默变成一次普通检查"), @shell.Txt(" —— 你以为落了锁， 其实什么都没发生）：")]),
        @shell.Code("bash", "node tools/run-js.mjs check --skills skills --update-lock", [("node", 6), (" tools/run-js.mjs check ", 0), ("--skills", 4), (" skills ", 0), ("--update-lock", 4)]),
        @shell.P([@shell.Code("skills.lock.json"), @shell.Txt(" 仍然"), @shell.Bold("只有一份"), @shell.Txt("（跟着程序走 = 它是机制的契约），但每条指纹都记着 "), @shell.Bold("它属于哪个内容根"), @shell.Txt(" ⇒ 查 A 根不会把 B 根的条目报成\"已删除的 skill\"。")]),
        @shell.P([@shell.Txt("✅ "), @shell.Bold("已经自举"), @shell.Txt("：程序仓的 "), @shell.Code("skills/"), @shell.Txt(" 自己就是一份语料，实例在 "), @shell.Code("skills/skillpress/scripts/.skillpress/"), @shell.Txt(" —— 由脚手架生成（"), @shell.Code("node tools/run-js.mjs attach --repo . --skills skills"), @shell.Txt("；"), @shell.Code("--repo"), @shell.Txt(" 要显式给）。")]),
        @shell.H2([@shell.Txt("六、诚实清单（现状，别写成\"已支持\"）")]),
        @shell.Ul([(0, "", [@shell.Bold("引擎已经是 MoonBit"), @shell.Txt("（"), @shell.Code("engine/**"), @shell.Txt("）—— 残余的 "), @shell.Code(".mjs"), @shell.Txt(" 只有三个跨进程的工具（"), @shell.Code("press"), @shell.Txt(" / "), @shell.Code("dom-dump"), @shell.Txt(" / 引导层）。")])]),
        @shell.P([@shell.Txt("迁移的阶段与读数在 "), @shell.Code("PLAN.md"), @shell.Txt(" 的 P8。"), @shell.Bold("不单独发 npm 包了。")]),
        @shell.Ul([(0, "", [@shell.Bold("已发布"), @shell.Txt("：registry 上这一版是 "), @shell.Code("XiLaiTL/skillpress@0.1.1"), @shell.Txt("（"), @shell.Code("tools/published-check.sh"), @shell.Txt(" 验过：装得下来、在别的工程里编得过）；本仓开发期仍走源码路径（"), @shell.Code("node tools/run-js.mjs …"), @shell.Txt(" / "), @shell.Code("bash tools/verify.sh"), @shell.Txt("）。")]), (0, "", [@shell.Code("pack"), @shell.Txt(" "), @shell.Bold("还没做"), @shell.Txt("：命令存在，但会明说\"还没做\"并非零退出（不做\"看着像跑了\"的假动作）。")])]),
        @shell.P([@shell.Txt("（"), @shell.Code("attach"), @shell.Txt(" "), @shell.Bold("已落地"), @shell.Txt("，见 "), @shell.Code("PLAN.md"), @shell.Txt(" 的 P9 与 "), @shell.Code("engine/scaffold/"), @shell.Txt("。）")]),
        @shell.Ul([(0, "", [@shell.Txt("界面"), @shell.Bold("已经抽成 `shell` 包"), @shell.Txt("（P6）：实例的 "), @shell.Code("app.mbt"), @shell.Txt(" 只剩接线。")]), (0, "", [@shell.Txt("⚠️ 引擎迁移的"), @shell.Bold("进度"), @shell.Txt("只有一处答案："), @shell.Code("PLAN.md"), @shell.Txt(" 的 P8（这份清单里原先那句\"引擎今天还是 Node\"")])]),
        @shell.P([@shell.Txt("已经过期 —— 内容管线、通用门、上色与站点判据都已经是 MoonBit，"), @shell.Bold("`lib` 与 `bin` 两个旧目录已经整体退役"), @shell.Txt("（D43））。")]),
        @shell.H2([@shell.Txt("七、指针")]),
        @shell.Table([[@shell.Txt("要什么")], [@shell.Txt("去哪")]], [[[@shell.Txt("判据逐条（G1–G8）、加一条规则的形状、诱饵怎么写")], [@shell.Code("references/gates.md")]], [[@shell.Txt("内容管线内部（数据形状、解析边界、两种模式、上色、站点判据）")], [@shell.Code("references/pipeline.md")]], [[@shell.Txt("四个根的算法、两种布局、程序为什么在仓库外")], [@shell.Code("references/roots.md")]], [[@shell.Txt("投影规范（收录判据 / 结构 / 预算 / 站点边界）")], [@shell.Code("SPEC.md"), @shell.Txt("（§2 / §3 / §6 / §8）")]], [[@shell.Txt("集合划分、产出顺序")], [@shell.Code("SKILLS.md")]], [[@shell.Txt("漂移账本的方法、政策与已知边界")], [@shell.Code("DRIFT.md")]], [[@shell.Txt("禁语表 / 已落地台账 / 体量指纹")], [@shell.Code("claims.txt"), @shell.Txt(" ｜ "), @shell.Code("done-claims.txt"), @shell.Txt(" ｜ "), @shell.Code("skills.lock.json")]], [[@shell.Txt("计划与未做（会变，别当契约）")], [@shell.Code("PLAN.md")]], [[@shell.Txt("用"), @shell.Bold("这套工具"), @shell.Txt("做站点那一侧")], [@shell.Txt("另一份 skill："), @shell.Code("skillpress-user")]], [[@shell.Txt("内容仓的现状与已踩的坑（"), @shell.Bold("唯一来源"), @shell.Txt("，别抄数字）")], [@shell.Code("../moobile/docs/STATUS.md"), @shell.Txt(" ｜ "), @shell.Code("../moobile/docs/FINDINGS.md")]]]),
      ],
      kids: [
        {
          kind: "ref",
          name: "gates",
          title: "门：判据逐条、怎么加一条新规则、诱饵怎么写",
          desc: "G1–G8 每条判据抓的失败模式、判据背后的三条设计原则、加一条新规则的固定四步（判据+诱…",
          blocks: [
            @shell.P([@shell.Bold("什么时候读它"), @shell.Txt("：你要改 "), @shell.Code("engine/gates/"), @shell.Txt("（门的实现）的判据、要"), @shell.Bold("加"), @shell.Txt("一条新规则、 或者某条判据红了而你怀疑是判据自己的问题。")]),
            @shell.P([@shell.Txt("判据的实现只有一处："), @shell.Code("engine/gates/judge.mbt"), @shell.Txt(" 的 "), @shell.Code("judge()"), @shell.Txt("（正文 → 失败清单）。 规范侧的家是 "), @shell.Code("SPEC.md"), @shell.Txt(" §6 —— "), @shell.Bold("两边必须一起改"), @shell.Txt("（改判据 = 改规范）。")]),
            @shell.H2([@shell.Txt("一、G1–G8：每条抓什么失败模式")]),
            @shell.Table([[@shell.Txt("#")], [@shell.Txt("判据")], [@shell.Txt("它抓的失败模式")]], [[[@shell.Bold("G1")], [@shell.Txt("frontmatter 三字段齐全；"), @shell.Code("name"), @shell.Txt(" == 目录名；都是单行标量")], [@shell.Txt("skill 加载不到（harness 只认这三个字段）")]], [[@shell.Bold("G2")], [@shell.Txt("体量预算（400 行 / 20 KB / 代码块 ≤15 行 / 表 ≤12 行）+ "), @shell.Bold("行尾必须 LF")], [@shell.Txt("一次塞太多 → token 成本；CRLF → frontmatter "), @shell.Bold("静默失效")]], [[@shell.Bold("G3")], [@shell.Txt("正文"), @shell.Bold("行内代码"), @shell.Txt("里的路径必须存在（按三个根查，见 "), @shell.Code("references/roots.md"), @shell.Txt("）")], [@shell.Txt("死链：读者点过去一片茫然，而写的人以为它还在")]], [[@shell.Bold("G4")], [@shell.Txt("命令里引用的脚本路径必须存在（一级目录须是 "), @shell.Code("tools"), @shell.Txt(" / "), @shell.Code("npm"), @shell.Txt(" / "), @shell.Code("examples"), @shell.Txt(" / "), @shell.Code("docs"), @shell.Txt(" / "), @shell.Code("vendor"), @shell.Txt(" 之一）")], [@shell.Txt("命令复制过去跑不了 —— \"确切命令\"是收录判据之一")]], [[@shell.Bold("G5")], [@shell.Code("@html."), @shell.Txt(" / "), @shell.Code("@style."), @shell.Txt(" / "), @shell.Code("@cmd."), @shell.Txt(" / "), @shell.Code("@sub."), @shell.Txt(" 的 API 名必须在源码里存在")], [@shell.Txt("编出来的 API（AI 最容易犯）：读者照抄 → 编译错")]], [[@shell.Bold("G6")], [@shell.Txt("文档链接的 "), @shell.Code("§N"), @shell.Txt(" 节号必须真的存在")], [@shell.Txt("指向一个不存在的节 —— 静默，而且会让人以为整份文档都相关")]], [[@shell.Bold("G7")], [@shell.Txt("禁语表（"), @shell.Code("claims.txt"), @shell.Txt("）出现即红")], [@shell.Bold("把\"未做\"写成\"已支持\""), @shell.Txt(" —— 这条是这套东西存在的理由")]], [[@shell.Bold("G8")], [@shell.Txt("体量 / 条目数指纹变了就红（"), @shell.Code("skills.lock.json"), @shell.Txt("）")], [@shell.Txt("悄悄膨胀：200 行变 380 行没人看过")]]]),
            @shell.H2([@shell.Txt("二、判据背后的三条设计原则")]),
            @shell.Ul([(0, "1. ", [@shell.Bold("宽进严出（G3 有\"行文残留\"那条）"), @shell.Txt("：反引号里的路径"), @shell.Bold("尾部粘了中文"), @shell.Txt("（比如写成")])]),
            @shell.P([@shell.Code("skills/skillpress/SKILL.md的补记"), @shell.Txt("）允许 —— 去掉尾部的非路径字符后再查一次， 过了就只记一条提示。因为"), @shell.Bold("误杀比漏报更伤"), @shell.Txt("：人看到红的处置通常是\"把真引用删掉\"， 那正是最坏的结果。")]),
            @shell.Ul([(0, "2. ", [@shell.Bold("三个候选根都认"), @shell.Txt("：内容仓根 / 程序根 / 那个 skill 自己的目录。")])]),
            @shell.P([@shell.Txt("只认一个根会让另两边全红（见 G3 的实现注释）。")]),
            @shell.Ul([(0, "3. ", [@shell.Bold("不许有\"静默不查\""), @shell.Txt("：判据白名单之外的东西等于没判据。")])]),
            @shell.P([@shell.Txt("曾经的洞："), @shell.Code("bin"), @shell.Txt(" / "), @shell.Code("lib"), @shell.Txt(" / "), @shell.Code("grammars"), @shell.Txt(" 不在白名单 ⇒ 内容里讲程序的指针"), @shell.Bold("一个都没查过"), @shell.Txt(" （不是\"查了但错了\"，是\"根本没查\"）—— 现在有诱饵 "), @shell.Code("bad-program-path"), @shell.Txt(" 守着。")]),
            @shell.H2([@shell.Txt("三、加一条新规则：固定四步")]),
            @shell.Ul([(0, "1. ", [@shell.Bold("写判据"), @shell.Txt("：加进 "), @shell.Code("judge()"), @shell.Txt("（或像 "), @shell.Code("docfacts"), @shell.Txt(" / "), @shell.Code("verify-site"), @shell.Txt(" 那样独立成门）。")])]),
            @shell.P([@shell.Txt("出口一律 "), @shell.Code("process.exitCode"), @shell.Txt("，"), @shell.Bold("别调 `process.exit()`"), @shell.Txt("（会被上游吞掉）。")]),
            @shell.Ul([(0, "2. ", [@shell.Bold("配诱饵"), @shell.Txt("：在 "), @shell.Code("--selftest"), @shell.Txt(" 的 "), @shell.Code("cases"), @shell.Txt(" 里加一条"), @shell.Bold("必须被点名"), @shell.Txt("的假样本。")])]),
            @shell.P([@shell.Txt("⚠️ 判据没诱饵 = 没加：没人能证明它真的会红。")]),
            @shell.Ul([(0, "3. ", [@shell.Bold("改规范"), @shell.Txt("："), @shell.Code("SPEC.md"), @shell.Txt(" §6 的表加一行（判据 + 抓什么），与实现同一次提交。")]), (0, "4. ", [@shell.Bold("落指纹"), @shell.Txt("：如果判据让某些 skill 的体量/结构变化，跑 "), @shell.Code("--update-lock <名字>"), @shell.Txt(" 复核落锁。")])]),
            @shell.P([@shell.Txt("加完两边都要过："), @shell.Code("check --selftest"), @shell.Txt("（诱饵全被点名、正例不许被误杀） "), @shell.Bold("和"), @shell.Txt(" "), @shell.Code("check"), @shell.Txt("（真实内容不许被误杀）。")]),
            @shell.H2([@shell.Txt("四、诱饵清单（"), @shell.Code("check --selftest"), @shell.Txt("）")]),
            @shell.P([@shell.Txt("现在的诱饵按\"每条判据一个\"摆：名字不匹配 ｜ 缺字段 ｜ 没有 frontmatter ｜ 体量超限 ｜ 代码块超长 ｜ 假路径（内容仓侧）｜ 假路径（程序侧 "), @shell.Code("bin/…"), @shell.Txt("）｜ 假脚本（G4）｜ 编造的 API（G5）｜ 不存在的节号（G6）｜ CRLF ｜ 禁语（G7）。")]),
            @shell.P([@shell.Txt("最后还有一个"), @shell.Bold("正例"), @shell.Txt("：它必须"), @shell.Bold("一条都不红"), @shell.Txt(" —— 只有诱饵全中、正例全过，才说明门是\"能分辨\"的， 而不是\"见谁都红\"。")]),
            @shell.H2([@shell.Txt("五、落锁（G8）的政策")]),
            @shell.Ul([(0, "", [@shell.Txt("指纹算的是 "), @shell.Code("SKILL.md"), @shell.Txt(" / "), @shell.Code("references/**"), @shell.Txt(" / "), @shell.Code("FAQ.md"), @shell.Txt("（"), @shell.Bold("`scripts` 子目录不进指纹"), @shell.Txt("）：")])]),
            @shell.P([@shell.Txt("随 skill 一起发的工具天天改，不该天天触发\"人复核\"。")]),
            @shell.Ul([(0, "", [@shell.Txt("指纹变了 → "), @shell.Bold("硬红"), @shell.Txt("（不是提示）：提示会被淹没，而这条门的全部意义就是\"不许悄悄膨胀\"。")]), (0, "", [@shell.Code("--update-lock <名字>"), @shell.Txt(" 的语义是\"我"), @shell.Bold("看过"), @shell.Txt("这次变化\"；"), @shell.Bold("不是"), @shell.Txt("让门变绿的手段。")]), (0, "", [@shell.Bold("只锁一个"), @shell.Txt("：整文件重写会把别人正在改的那份的指纹一起锁掉，他改完 G8 就无辜地红。")]), (0, "", [@shell.Bold("锁是一份，但记根"), @shell.Txt("：程序可以面对多个内容根（内容仓的 "), @shell.Code("skills"), @shell.Txt(" 与程序自己的")])]),
            @shell.P([@shell.Code("skills/"), @shell.Txt("），锁跟着程序走；每条指纹记着"), @shell.Bold("它属于哪个内容根"), @shell.Txt("， 于是查 A 根不会把 B 根报成\"已删除的 skill\"（提示一多，真提示就被淹了）。")]),
            @shell.Ul([(0, "", [@shell.Txt("落锁时顺手"), @shell.Bold("清掉\"根已经不在磁盘上\"的条目"), @shell.Txt("（比如程序自己的 skill 换了根）：留着只会越攒越旧。")]), (0, "", [@shell.Code("--update-lock"), @shell.Txt(" "), @shell.Bold("出现在参数里任何位置都认"), @shell.Txt("：曾经它必须是第一个参数，")])]),
            @shell.P([@shell.Txt("于是 "), @shell.Code("check --skills <根> --update-lock"), @shell.Txt(" 静默退化成一次普通检查 —— 以为落了锁，其实没落。")]),
            @shell.H2([@shell.Txt("六、另外两道门（形状不同，别混）")]),
            @shell.Table([[@shell.Txt("门")], [@shell.Txt("它查什么")], [@shell.Txt("它的\"真值\"从哪来")]], [[[@shell.Code("docfacts"), @shell.Txt("（"), @shell.Code("facts"), @shell.Txt("）")], [@shell.Txt("内容仓的文档有没有撒谎（版本号、状态、\"未做\"清单…）")], [@shell.Bold("只查能从代码算出来的"), @shell.Txt("事实；分"), @shell.Bold("硬 / 软"), @shell.Txt("两档；豁免必须写在文档里")]], [[@shell.Code("audit"), @shell.Txt("（"), @shell.Code("highlight.mjs --audit"), @shell.Txt("）")], [@shell.Txt("代码上色坏没坏（召回率 / 漏色比例）")], [@shell.Txt("纯正则数出的\"必须上色的词法元素\"（关键字 / 字符串 / 注释 / 数字）")]], [[@shell.Code("verify"), @shell.Txt("（"), @shell.Code("verify-site.mjs"), @shell.Txt("）")], [@shell.Txt("站点真的是那样吗（真 Chrome + CDP 真鼠标）")], [@shell.Txt("从"), @shell.Bold("内容源现取"), @shell.Txt("探针（不写死在脚本里）")]]]),
            @shell.P([@shell.Code("docfacts"), @shell.Txt(" 的设计与已知边界在 "), @shell.Code("DRIFT.md"), @shell.Txt("；"), @shell.Code("verify"), @shell.Txt(" 的判据清单的家是"), @shell.Bold("它自己的文件头"), @shell.Txt(" （一张表：每条断言抓哪个失败模式）。")]),
          ],
        },
        {
          kind: "ref",
          name: "pipeline",
          title: "站点管线内部：数据形状、解析边界、两种模式、上色、站点判据",
          desc: "gen-content 编出来的类型化数据、markdown 的解析边界与三条会咬人的规矩…",
          blocks: [
            @shell.P([@shell.Bold("什么时候读它"), @shell.Txt("：你要动内容管线（"), @shell.Code("engine/content/"), @shell.Txt("）、动上色（"), @shell.Code("engine/highlight/"), @shell.Txt("）、 加一条站点判据（"), @shell.Code("engine/site/checks.mbt"), @shell.Txt("），或者遇到「改了内容源但站点没变」。")]),
            @shell.H2([@shell.Txt("一、数据形状（内容包只有数据，渲染在应用里）")]),
            @shell.P([@shell.Code("gen-content.mjs"), @shell.Txt(" 把 markdown 编成"), @shell.Bold("站点应用"), @shell.Txt("的 "), @shell.Code("content/content.generated.mbt"), @shell.Txt("（"), @shell.Bold("生成物，别手改"), @shell.Txt("）：")]),
            @shell.Table([[@shell.Txt("类型")], [@shell.Txt("是什么")]], [[[@shell.Code("Span")], [@shell.Txt("一段行内内容："), @shell.Code("Txt"), @shell.Txt(" / "), @shell.Code("Code"), @shell.Txt(" / "), @shell.Code("Bold"), @shell.Txt("（行内只认这三种写法）")]], [[@shell.Code("Block")], [@shell.Txt("正文里的一块：标题 / 段落 / 列表 / 表格 / 代码块 / 引用 / 分隔线")]], [[@shell.Code("Code(lang, text, runs)")], [@shell.Txt("代码块 + "), @shell.Bold("高亮片段"), @shell.Txt("；"), @shell.Code("runs"), @shell.Txt(" 拼回去要"), @shell.Bold("逐字节等于"), @shell.Txt(" "), @shell.Code("text")]], [[@shell.Code("Section")], [@shell.Txt("首页的一个"), @shell.Bold("分栏"), @shell.Txt(" = 首页那份 skill 的一个 "), @shell.Code("##"), @shell.Txt("（"), @shell.Code("title"), @shell.Txt(" + "), @shell.Code("blocks"), @shell.Txt(" + "), @shell.Code("link"), @shell.Txt("）")]], [[@shell.Code("Home")], [@shell.Txt("首页："), @shell.Code("title"), @shell.Txt("（H1）+ "), @shell.Code("lede"), @shell.Txt("（首个 "), @shell.Code("##"), @shell.Txt(" 之前）+ "), @shell.Code("sections")]], [[@shell.Code("Kid")], [@shell.Txt("子页：某份 skill 的 "), @shell.Code("references/**"), @shell.Txt("、"), @shell.Code("FAQ.md"), @shell.Txt("、或它的脚本文件")]], [[@shell.Code("Doc")], [@shell.Txt("一份 skill："), @shell.Code("slug"), @shell.Txt(" / "), @shell.Code("desc"), @shell.Txt(" / "), @shell.Code("when"), @shell.Txt(" / "), @shell.Code("blocks"), @shell.Txt(" / "), @shell.Code("kids")]]]),
            @shell.P([@shell.Txt("三个入口："), @shell.Code("home()"), @shell.Txt("（首页）、"), @shell.Code("skills()"), @shell.Txt("（文档区，按 slug 排序 ⇒ 生成物稳定）、 "), @shell.Code("find_page(key)"), @shell.Txt("（页面键 → 位置，给纯链接节用；认不出给\"没有\"）。")]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Bold("页面键的形状在生成器与生成物两侧各写一次"), @shell.Txt("（主文档 = "), @shell.Code("<slug>"), @shell.Txt("、子页 = "), @shell.Code("<slug>/<kind>/<name>"), @shell.Txt("）， 改一边必须改另一边 —— 它们靠那段注释对账。")]),
            @shell.H2([@shell.Txt("二、markdown 的解析边界（刻意的窄）")]),
            @shell.P([@shell.Txt("只支持内容源里"), @shell.Bold("实际用到的"), @shell.Txt("构造；遇到不认识的（图片、原始 HTML…）"), @shell.Bold("逐条点名报错"), @shell.Txt("， 不静默丢内容。三条会咬人的：")]),
            @shell.Ul([(0, "", [@shell.Bold("`#` 不进正文"), @shell.Txt("：H1 被抽成 "), @shell.Code("title"), @shell.Txt("（站名 + 首屏大标题）。")]), (0, "", [@shell.Bold("`##` 就是分栏边界"), @shell.Txt("：顶栏有几条完全由首页那份 skill 决定 ⇒ 它的 "), @shell.Code("##"), @shell.Txt(" 必须写"), @shell.Bold("短名"), @shell.Txt("。")]), (0, "", [@shell.Bold("链接按\"台词\"渲染"), @shell.Txt("（没有路由）：文字与目标相同时只留一份，否则渲染成\"文字 + 路径\"。")]), (0, "", [@shell.Txt("⚠️ "), @shell.Bold("解不开的东西是硬错误，不是跳过"), @shell.Txt("：未闭合的代码块 / 图片 / 原始 HTML / 表格缺分隔行 ——")])]),
            @shell.P([@shell.Txt("生成器直接"), @shell.Bold("非零退出"), @shell.Txt("（不肯产出一份\"看着像样\"的产物）。所以那类用例"), @shell.Bold("进不了对账夹具"), @shell.Txt("； 这是"), @shell.Bold("刻意"), @shell.Txt("的，别改成静默跳过（内容写坏了要当场拦住）。")]),
            @shell.H3([@shell.Txt("纯链接节："), @shell.Code("## [名字](目标)")]),
            @shell.P([@shell.Txt("节的标题"), @shell.Bold("整条是一个链接"), @shell.Txt("时，点那一栏"), @shell.Bold("直接渲染目标文件"), @shell.Txt("： 生成期把目标按\"首页那份 skill 的目录\"解析成"), @shell.Bold("页面键"), @shell.Txt("写进 "), @shell.Code("Section.link"), @shell.Txt("， "), @shell.Bold("认不出来就报错"), @shell.Txt("（不给静默的死链）；应用侧再把键换成\"跳到那一页\"的消息， 换不出来就退回普通分栏。判定刻意严：正文里有链接"), @shell.Bold("不算"), @shell.Txt("。")]),
            @shell.H2([@shell.Txt("三、两种模式（状态机很小，两条通道别混）")]),
            @shell.P([@shell.Code("Model"), @shell.Txt(" 四个字段："), @shell.Code("mode"), @shell.Txt("（0 = 首页，1 = 文档）、"), @shell.Code("sec"), @shell.Txt("（首页选中第几栏，"), @shell.Code("-1"), @shell.Txt(" = 首屏）、 "), @shell.Code("sel"), @shell.Txt("（文档区选中的页）、"), @shell.Code("open"), @shell.Txt("（树里哪几份 skill 展开着）。消息四类： 顶栏分栏 / 换模式那条 / 文档区的页（skill、子页、纯链接节都走它）/ 树上的展开箭头。")]),
            @shell.P([@shell.Txt("⚠️ 顶栏那条"), @shell.Bold("换模式的栏位和别的分栏长得一样"), @shell.Txt("（D2：它只是最右那一栏，差一条竖细线）， 但"), @shell.Bold("标签要它自己的名字"), @shell.Txt(" —— 曾经它落进了 "), @shell.Code("i < 0 ⇒ \"首页\""), @shell.Txt(" 的兜里， 于是顶栏出现两条「首页」、"), @shell.Code("文档 / SKILL"), @shell.Txt(" 一次都没出现，而判据点了错的那条 （真因与代价见内容仓的 "), @shell.Code("../moobile/docs/FINDINGS.md"), @shell.Txt(" 第三十二轮）。")]),
            @shell.H2([@shell.Txt("四、上色（构建期，tree-sitter）")]),
            @shell.P([@shell.Txt("形状："), @shell.Code("engine/highlight/"), @shell.Txt("（引擎）+ "), @shell.Code("grammars"), @shell.Txt("（vendor 的 wasm 与 "), @shell.Code("highlights.scm"), @shell.Txt("， 出处与 sha256 见那份 "), @shell.Code("PROVENANCE.md"), @shell.Txt("）。"), @shell.Code("web-tree-sitter"), @shell.Txt(" 是这台引擎"), @shell.Bold("唯一"), @shell.Txt("的 npm 依赖。")]),
            @shell.P([@shell.Txt("两条硬规矩：")]),
            @shell.Ul([(0, "", [@shell.Bold("色号两头对齐"), @shell.Txt("："), @shell.Code("PALETTE"), @shell.Txt(" ↔ 站点应用的 "), @shell.Code("tok_color"), @shell.Txt("，改要一起改（错位不报错，只是颜色变了）。")]), (0, "", [@shell.Bold("拼回原文"), @shell.Txt("：颜色逐字符贴，"), @shell.Code("highlight()"), @shell.Txt(" 硬断言\"拼回去逐字节等于原文\"，否则抛错。")])]),
            @shell.P([@shell.Bold("片段是常态 ⇒ 有\"包装候选\""), @shell.Txt("：文档里的代码块大多不是合法代码（顶层裸表达式最常见）， tree-sitter 会给出 ERROR 节点，而 "), @shell.Bold("ERROR 里的东西一个 capture 都拿不到"), @shell.Txt("。 解法是每种包装试一遍（函数体 / let 绑定 / 调用参数 / 数组元素 / struct 字段 / match 分支…）， 取\"未上色的非空白字符最少\"的那个。")]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Bold("一个安静得可怕的坑"), @shell.Txt("：tree-sitter 的 "), @shell.Code("Parser"), @shell.Txt(" 是"), @shell.Bold("有状态"), @shell.Txt("的 —— 按需加载语言时只 "), @shell.Code("setLanguage"), @shell.Txt(" 一次，于是\"最后装载的语言\"会污染之后所有解析（页面照常渲染，只是颜色少了）。 "), @shell.Bold("每种语言一个 `Parser`"), @shell.Txt("。")]),
            @shell.P([@shell.Txt("闸门是 "), @shell.Code("audit"), @shell.Txt("：用纯正则数出\"必须上色的词法元素\"，报召回率与漏色比例，越线即红 （要准数就跑一遍）。")]),
            @shell.H2([@shell.Txt("五、站点判据怎么加一条（"), @shell.Code("engine/site/checks.mbt"), @shell.Txt("）")]),
            @shell.P([@shell.Txt("判据清单的"), @shell.Bold("家是那个脚本的文件头"), @shell.Txt("（一张表：每条断言抓哪个失败模式）—— 加之前先读它。")]),
            @shell.P([@shell.Txt("几条硬规矩（都是踩出来的）：")]),
            @shell.Ul([(0, "", [@shell.Txt("点击一律走 "), @shell.Bold("CDP 真鼠标"), @shell.Txt("："), @shell.Code("Pressable"), @shell.Txt(" 在 web 上走 responder 事件，合成 "), @shell.Code("click()"), @shell.Txt(" 不一定触发")])]),
            @shell.P([@shell.Txt("—— 那样判据会变成"), @shell.Bold("永远绿"), @shell.Txt("。")]),
            @shell.Ul([(0, "", [@shell.Bold("端口动态挑"), @shell.Txt("：写死端口会撞上\"机器上已经有一个同端口在跑\"，于是判据测的是"), @shell.Bold("别人那个服务"), @shell.Txt("。")]), (0, "", [@shell.Bold("Chrome 的 stderr 必须留着"), @shell.Txt("：CDP 连不上时，真正的原因只在 Chrome 自己的话里。")]), (0, "", [@shell.Bold("探针文字从内容源现算"), @shell.Txt("（首页从那份 SKILL.md 取、skill 从 frontmatter 取），不写死在脚本里。")]), (0, "", [@shell.Bold("同一次运行里的两处口径必须一致"), @shell.Txt("：一处用\"整页子串\"、另一处用\"元素整条文本\"时，")])]),
            @shell.P([@shell.Txt("前者会"), @shell.Bold("假绿"), @shell.Txt("并把真 bug 藏起来（实测代价：顶栏标签写错 + 3 条判据被静默跳过）。")]),
            @shell.Ul([(0, "", [@shell.Bold("\"找不到元素\"不许退化成跳过"), @shell.Txt("："), @shell.Code("总数"), @shell.Txt("也是读数 —— 跳过的形状与通过一模一样，")])]),
            @shell.P([@shell.Txt("只有写下总数、并与上一次对，才看得见。")]),
            @shell.Ul([(0, "", [@shell.Txt("区分\"做了\"与\"没做\"：只验\"渲出来了\"抓不到\"点了没反应\"。")])]),
            @shell.H2([@shell.Txt("六、生成物的新鲜度")]),
            @shell.Ul([(0, "", [@shell.Code("press"), @shell.Txt(" 写生成物；"), @shell.Code("press --check"), @shell.Txt(" 是门（不一致即红，并指出"), @shell.Bold("第一处差异"), @shell.Txt("）。")]), (0, "", [@shell.Bold("别手改生成物"), @shell.Txt("：下一次 "), @shell.Code("press"), @shell.Txt(" 会抹掉，而你会先经历一段\"改了没反应\"。")]), (0, "", [@shell.Txt("实例要能"), @shell.Bold("独立编译"), @shell.Txt("：生成物要进仓库（它不是可以随时重造的缓存）。")])]),
            @shell.P([@shell.Txt("已知边界（别当成已覆盖）：没配语法的标记按原文渲染（"), @shell.Code("LANGS"), @shell.Txt(" 加一行即可支持）； fence 标错语言会"), @shell.Bold("染错"), @shell.Txt("而不是报错（那要改"), @shell.Bold("家"), @shell.Txt("，不是改投影）； 锚点 / 目录 / 搜索还没做（语法树已经在手上）。")]),
          ],
        },
        {
          kind: "ref",
          name: "roots",
          title: "四个根：算法、两种布局、程序为什么在仓库外",
          desc: "程序/仓库/内容/实例四个根的定位算法（cmd/skillpress/cli/args.m…",
          blocks: [
            @shell.P([@shell.Bold("什么时候读它"), @shell.Txt("：你要动任何与\"文件在哪\"有关的东西（路径、生成物落点、门的候选根）， 或者遇到\"门/管线查的不是我以为的那份目录\"。")]),
            @shell.H2([@shell.Txt("一、四个根与覆盖顺序（唯一实现在 "), @shell.Code("cmd/skillpress/cli/args.mbt"), @shell.Txt(" + "), @shell.Code("engine/site/entry.mbt"), @shell.Txt("）")]),
            @shell.Table([[@shell.Txt("根")], [@shell.Txt("命令行")], [@shell.Txt("环境变量")], [@shell.Txt("默认")]], [[[@shell.Bold("程序")], [@shell.Txt("（由文件位置决定）")], [@shell.Txt("—")], [@shell.Code("cmd/"), @shell.Txt(" 的上一层 = 本仓库根")]], [[@shell.Bold("仓库"), @shell.Txt("（内容仓）")], [@shell.Code("--repo <目录>")], [@shell.Code("SKILLPRESS_REPO")], [@shell.Bold("旁边的 `moobile/`"), @shell.Txt("；找不到才退回\"程序往上 3 层\"")]], [[@shell.Bold("内容")], [@shell.Code("--skills <目录>")], [@shell.Code("SKILLPRESS_SKILLS")], [@shell.Code("<内容仓>/skills")]], [[@shell.Bold("实例")], [@shell.Code("--app <目录>")], [@shell.Code("SKILLPRESS_APP_DIR")], [@shell.Code("<内容>/skillpress/scripts/.skillpress")]]]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Bold("这四条只有一处实现"), @shell.Txt("。它们原先在 5 个文件里各写一遍（内容管线 / 门 / 事实门 / 上色 / 站点判据），家规改一次要改五处 —— 漏一处就是\"某个门在查别的目录\"，而且"), @shell.Bold("门不会报错"), @shell.Txt("： 搬家那天实测 "), @shell.Code("check"), @shell.Txt(" 报出「moobile 根："), @shell.Code("D:\\"), @shell.Txt("」、遍历整个盘、然后说\"skills/ 下还没有 skill\"。")]),
            @shell.P([@shell.Bold("不猜是刻意的"), @shell.Txt("：猜错的表现是\"站点没更新\"—— 页面照常渲染，只是旧内容，最难查的一类症状。 所以每个根都能被显式指定，且 "), @shell.Code("press"), @shell.Txt(" / "), @shell.Code("verify"), @shell.Txt(" 都会把解析出来的根打印在开头。")]),
            @shell.H2([@shell.Txt("二、两种布局（都认，因为都真的用过）")]),
            @shell.Code("", "布局 A（现在）：兄弟                      布局 B（搬家前）：嵌套\ninterest/                                <内容仓>/  moobile/\n├── skillpress/   ★ 程序                  ├── skills/      ★ 内容\n│   ├── engine/ cmd/ grammars/            └── examples/apps/skillpress/  ★ 程序\n└── moobile/      ★ 内容仓\n    └── skills/   ★ 内容", ([] : Array[(String, Int)])),
            @shell.P([@shell.Txt("判定就一行意思："), @shell.Bold("先看\"程序旁边有没有 moobile\"（要求它下面真有 `skills`）， 没有才退回\"往上三层\""), @shell.Txt("。所以把程序挪来挪去"), @shell.Bold("不用改任何路径"), @shell.Txt("。 裸克隆到临时目录时两者都不成立（那时必须显式给 "), @shell.Code("--repo"), @shell.Txt(" 或 "), @shell.Code("SKILLPRESS_REPO"), @shell.Txt("）。")]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Bold("内容根自己也搬过一次"), @shell.Txt("（2026-10-06）：从 "), @shell.Code(".agents"), @shell.Txt(" 下的 "), @shell.Code("skills"), @shell.Txt(" 搬到仓库根的 "), @shell.Code("skills/"), @shell.Txt("。")]),
            @shell.Ul([(0, "", [@shell.Bold("为什么"), @shell.Txt("：普通目录"), @shell.Bold("看得见"), @shell.Txt("（翻仓库的人一眼看到），而且"), @shell.Bold("会跟着发布包走"), @shell.Txt(" ——")])]),
            @shell.P([@shell.Txt("实测 "), @shell.Code("moon package --list"), @shell.Txt("：普通目录默认进包，点目录（"), @shell.Code(".agents"), @shell.Txt(" / "), @shell.Code(".dsh"), @shell.Txt(" / "), @shell.Code(".skillpress"), @shell.Txt("）默认不进。")]),
            @shell.Ul([(0, "", [@shell.Bold("默认值因此是"), @shell.Txt("："), @shell.Code("<仓库>/skills"), @shell.Txt(" 优先，老仓库退回 "), @shell.Code(".agents"), @shell.Txt(" 下的 "), @shell.Code("skills"), @shell.Txt("（见 "), @shell.Code("cmd/skillpress/cli/args.mbt"), @shell.Txt(" 的 "), @shell.Code("default_skills"), @shell.Txt("）。")]), (0, "", [@shell.Bold("代价"), @shell.Txt("："), @shell.Code("skills/"), @shell.Txt(" 不在 harness 的扫描根里（扫描根只有 "), @shell.Code(".dsh"), @shell.Txt(" 下的 "), @shell.Code("skills"), @shell.Txt(" 与 "), @shell.Code(".agents"), @shell.Txt(" 下的 "), @shell.Code("skills"), @shell.Txt(" 这两个），")])]),
            @shell.P([@shell.Txt("所以搬过去之后 agent "), @shell.Bold("不会自动加载"), @shell.Txt("它们。要两者都要，只有配 DSH 的 "), @shell.Code("customSkillDirs"), @shell.Txt("； "), @shell.Bold("别两边各放一份"), @shell.Txt(" —— 两份内容就是两份会漂的真相。")]),
            @shell.H2([@shell.Txt("三、这条路走过两遍，第二次的理由不一样")]),
            @shell.Ul([(0, "", [@shell.Txt("一度搬出去（与仓库平级）又搬回来，理由是\"平级带来的是一整套毫无收益的相对路径改写\"。")]), (0, "", [@shell.Bold("2026-10-06 再搬出去"), @shell.Txt("：这次要的是程序"), @shell.Bold("独立成一个 git 仓库"), @shell.Txt("（自己的版本、发布与协作），")])]),
            @shell.P([@shell.Txt("那是\"待在内容仓里\"给不了的。代价写在明处：内容里的命令多一层 "), @shell.Code("../skillpress/"), @shell.Txt("。")]),
            @shell.H2([@shell.Txt("四、G3 的三个候选根（判据按什么根查）")]),
            @shell.Table([[@shell.Txt("候选根")], [@shell.Txt("谁用它")]], [[[@shell.Bold("内容仓根")], [@shell.Txt("多数内容讲的是内容仓自己（"), @shell.Code("docs/**"), @shell.Txt("、"), @shell.Code("examples/**"), @shell.Txt("…）")]], [[@shell.Bold("程序根")], [@shell.Txt("内容里「这套工具在哪儿」的指针（"), @shell.Code("cmd/skillpress"), @shell.Txt("、"), @shell.Code("engine/gates/"), @shell.Txt("、"), @shell.Code("grammars/PROVENANCE.md"), @shell.Txt("）")]], [[@shell.Bold("那个 skill 自己的目录")], [@shell.Txt("随 skill 一起发的工具（它自己的 "), @shell.Code("scripts"), @shell.Txt(" 子目录、"), @shell.Code("references/**"), @shell.Txt("）")]]]),
            @shell.P([@shell.Txt("⚠️ 程序根这一条是搬家时才补的：在那之前 "), @shell.Code("check.mjs"), @shell.Txt(" 里的\"第二个根\"写的是"), @shell.Bold("内容仓根"), @shell.Txt(" （与第一个重复），而 "), @shell.Code("bin"), @shell.Txt(" / "), @shell.Code("lib"), @shell.Txt(" / "), @shell.Code("grammars"), @shell.Txt(" 又不在 G3 的一级目录白名单里 ⇒ 讲程序的指针是"), @shell.Bold("静默不查"), @shell.Txt("（门绿着，死链没人管）。现在两处都补上，诱饵 "), @shell.Code("bad-program-path"), @shell.Txt(" 守着。")]),
            @shell.H2([@shell.Txt("五、实例怎么找到程序")]),
            @shell.P([@shell.Txt("实例的 "), @shell.Code("package.json"), @shell.Txt(" 里那句 "), @shell.Code("SKILLPRESS_ENGINE"), @shell.Txt(" 默认是 "), @shell.Code("../../../../../skillpress"), @shell.Txt(" （从实例目录往上 5 层再进 "), @shell.Code("skillpress/"), @shell.Txt("）—— 正好是"), @shell.Bold("兄弟布局"), @shell.Txt("下的程序根。 实例对宿主用 "), @shell.Code("file:"), @shell.Txt(" 依赖（这套东西的老规矩）：改了宿主之后要刷新 "), @shell.Code("node_modules"), @shell.Txt(" 里那份副本，否则"), @shell.Bold("验证脚本会悄悄测旧代码"), @shell.Txt("。")]),
          ],
        },
      ],
    },
    {
      slug: "skillpress-user",
      title: "skillpress 用户 —— 把 skill 印成站点",
      desc: "用 skillpress 把一份或多份 skill 印成一个站点：起站点、写主页、改配色与字号、加一块新内容构造、预览…",
      full_desc: "用 skillpress 把一份或多份 skill 印成一个站点：起站点、写主页、改配色与字号、加一块新内容构造、预览与验收。这是「用这套工具的人」那一侧。",
      when: "你要**用** skillpress 做站点（一份 skill 变网站 / 多份 skill 变网站、写首页、换配色与字体、加一块新构造或新页面、跑起来看效果、验收改完的站点），而不是改 skillpress 本身（那一侧是另一份 skill：`skillpress-dev`）。",
      blocks: [
        @shell.P([@shell.Bold("一句话"), @shell.Txt("：内容只有一份（一堆 "), @shell.Code("SKILL.md"), @shell.Txt("），站点是它的投影 —— 而"), @shell.Bold("首页也是其中一份 skill"), @shell.Txt("。")]),
        @shell.P([@shell.Txt("三条命令（在"), @shell.Bold("内容仓根"), @shell.Txt("跑；程序是它旁边的兄弟 "), @shell.Code("../skillpress/"), @shell.Txt("）：")]),
        @shell.Code("bash", "node ../skillpress/tools/press.mjs press              # 内容源 → 站点的内容包（生成物）\nnode ../skillpress/tools/press.mjs --check            # 门：生成物与源一致吗\nbash ../skillpress/tools/verify.sh                   # 判据：23 条（真 Chrome；要一次 native 编译）", [("node", 6), (" ../skillpress/tools/press.mjs press              ", 0), ("# 内容源 → 站点的内容包（生成物）", 3), ("\n", 0), ("node", 6), (" ../skillpress/tools/press.mjs ", 0), ("--check", 4), ("            ", 0), ("# 门：生成物与源一致吗", 3), ("\n", 0), ("bash", 6), (" ../skillpress/tools/verify.sh                   ", 0), ("# 判据：23 条（真 Chrome；要一次 native 编译）", 3)]),
        @shell.P([@shell.Txt("站点判据的"), @shell.Bold("现役"), @shell.Txt("那一份是 "), @shell.Code("skillpress-native verify"), @shell.Txt("（真 Chrome 无头 + CDP，23 条）—— ⚠️ "), @shell.Bold("只有 native 那份有"), @shell.Txt("（要一次 C 工具链）：站点判据要 async 的 http server / websocket / process，而它们在 "), @shell.Code("moonbitlang/async"), @shell.Txt(" 的 js 目标上没有实现。"), @shell.Bold("实例里最省事的是 `npm run verify`"), @shell.Txt(" （实例的 "), @shell.Code("verify.mjs"), @shell.Txt(" 会把\"引擎在哪、本实例在哪\"接上去，找不到就明说 SKIP）。")]),
        @shell.Quote([@shell.Txt("在"), @shell.Bold("程序仓根"), @shell.Txt("跑同一份程序就是 "), @shell.Code("node tools/run-js.mjs …"), @shell.Txt(" / "), @shell.Code("bash tools/verify.sh"), @shell.Txt("。内容仓不在兄弟位置时， 用 "), @shell.Code("--repo <内容仓根>"), @shell.Txt(" 或 "), @shell.Code("SKILLPRESS_REPO"), @shell.Txt(" 显式指定 —— "), @shell.Bold("它不猜"), @shell.Txt("（猜错的表现是\"站点没更新\"）。")]),
        @shell.P([@shell.Txt("⚠️ "), @shell.Bold("今天要不要 Node"), @shell.Txt("：日常要 —— 上面这三条走的是"), @shell.Bold("源码路径 + Node 启动器"), @shell.Txt("。 native 那一侧"), @shell.Bold("已经验过"), @shell.Txt("："), @shell.Code("moon install ./cmd/skillpress-native"), @shell.Txt(" 装出来的是"), @shell.Bold("本机可执行件（零 Node）"), @shell.Txt("， 装出来的那支 release 二进制跑 "), @shell.Code("gen-file"), @shell.Txt("，产物与 js "), @shell.Bold("逐字节一致"), @shell.Txt("（判据 "), @shell.Code("bash tools/native-parity.sh"), @shell.Txt(" 钉着）。 ⚠️ 但它有"), @shell.Bold("两处必须显式给的东西"), @shell.Txt("：吃到 "), @shell.Code("check"), @shell.Txt(" / "), @shell.Code("attach"), @shell.Txt(" 时"), @shell.Bold("要给程序根"), @shell.Txt(" （"), @shell.Code("--program <程序根>"), @shell.Txt(" 或 "), @shell.Code("SKILLPRESS_PROGRAM=<程序根>"), @shell.Txt("）—— "), @shell.Code("moon install"), @shell.Txt(" 把可执行件放进 "), @shell.Code("~/.moon/bin/"), @shell.Txt("， 程序数据（"), @shell.Code("claims.txt"), @shell.Txt(" / "), @shell.Code("skills.lock.json"), @shell.Txt(" / "), @shell.Code("template/"), @shell.Txt("）不在它旁边，而 "), @shell.Bold("native 不猜"), @shell.Txt("； 不给会先说一句「程序根没给（native 不猜）」再照常跑门。两条路今天都能走，日常仍以 Node 这条为准 （"), @shell.Code("moon install"), @shell.Txt(" 走的是 release 构建，慢一档）。")]),
        @shell.H2([@shell.Txt("一、怎么落一个站点")]),
        @shell.P([@shell.Bold("一条命令"), @shell.Txt("（脚手架，P9 已落地）：")]),
        @shell.Code("bash", "node tools/run-js.mjs attach --repo <仓根> --skills <内容根>      [--ignore \"<名字>=<理由>\"]… [--home <README 路径>] [--force] [--dry-run]", [("node", 6), (" tools/run-js.mjs attach ", 0), ("--repo", 4), (" ", 0), ("<", 9), ("仓根", 0), (">", 9), (" --skills ", 0), ("<", 9), ("内容根", 0), (">", 9), ("      [--ignore ", 0), ("\"<名字>=<理由>\"", 2), ("]… [--home ", 0), ("<", 9), ("README 路径", 0), (">", 9), ("] [--force] [--dry-run]", 0)]),
        @shell.P([@shell.Txt("它扫内容根 → 问（或按 "), @shell.Code("--ignore"), @shell.Txt(" 收）哪几份"), @shell.Bold("不上书架"), @shell.Txt("（每条都要"), @shell.Bold("理由"), @shell.Txt("）→ 首页源取 "), @shell.Code("<仓根>/README.md"), @shell.Txt("（复制 + 改写）→ 写整套 "), @shell.Code("skills/skillpress/{SKILL.md, WEBSITE.md, scripts/.skillpress/**}"), @shell.Txt("。 "), @shell.Bold("幂等"), @shell.Txt("、"), @shell.Bold("不覆盖人写的东西"), @shell.Txt("（要覆盖加 "), @shell.Code("--force"), @shell.Txt("）、"), @shell.Bold("算不出来就一个字节都不写"), @shell.Txt("。 ⚠️ "), @shell.Code("pack"), @shell.Txt("（打成便携目录）"), @shell.Bold("还没做"), @shell.Txt("。")]),
        @shell.P([@shell.Txt("要"), @shell.Bold("特化"), @shell.Txt("那个实例（换模块名、加能力包）时才手工改下面这些 —— 它们都由脚手架生成，别再抄一份：")]),
        @shell.Table([[@shell.Txt("实例里的东西")], [@shell.Txt("是什么")], [@shell.Txt("你要动它吗")]], [[[@shell.Code("app.mbt")], [@shell.Bold("只剩接线"), @shell.Txt("（界面 P6 起住在程序包的 "), @shell.Code("shell/"), @shell.Txt(" 里）")], [@shell.Txt("基本不用动；改外观看 "), @shell.Code("shell/theme.mbt")]], [[@shell.Code("content/")], [@shell.Bold("生成物"), @shell.Txt("（"), @shell.Code("press"), @shell.Txt(" 写的），别手改")], [@shell.Txt("不动")]], [[@shell.Code("index.html"), @shell.Txt(" / "), @shell.Code("index.js"), @shell.Txt(" / "), @shell.Code("App.js")], [@shell.Txt("静态宿主三件")], [@shell.Txt("一般不动")]], [[@shell.Code("build-web.mjs"), @shell.Txt(" / "), @shell.Code("serve-web.mjs")], [@shell.Txt("esbuild 打包 / 零依赖静态服务")], [@shell.Txt("一般不动")]], [[@shell.Code("moon.mod"), @shell.Txt(" / "), @shell.Code("moon.pkg")], [@shell.Txt("独立 MoonBit 模块（依赖 "), @shell.Code("XiLaiTL/moobile"), @shell.Txt("）")], [@shell.Txt("换依赖时动")]], [[@shell.Code("package.json")], [@shell.Code("file:"), @shell.Txt(" 依赖宿主 + "), @shell.Code("SKILLPRESS_ENGINE"), @shell.Txt(" 指向程序")], [@shell.Txt("换机器/换路径时动")]]]),
        @shell.P([@shell.Txt("现成的一份在："), @shell.Code("<内容仓>/skills/skillpress/scripts/.skillpress/"), @shell.Txt("。 一个 skill / 多个 skill 各自要动什么、哪些名字写死 —— 见 "), @shell.Code("references/make-a-site.md"), @shell.Txt("。")]),
        @shell.H2([@shell.Txt("二、内容怎么组织（站点结构 = 目录结构）")]),
        @shell.Table([[@shell.Txt("你放什么")], [@shell.Txt("站点上变成什么")]], [[[@shell.Code("<内容根>/skillpress/SKILL.md")], [@shell.Bold("首页"), @shell.Txt("（"), @shell.Bold("回退"), @shell.Txt("那一档）：H1 = 站名与大标题，首个 "), @shell.Code("##"), @shell.Txt(" 之前 = 首屏引言。✅ R2 已落地：首页源"), @shell.Bold("优先"), @shell.Txt(" "), @shell.Code("<内容根>/skillpress/WEBSITE.md"), @shell.Txt("，没有它才回退到 "), @shell.Code("SKILL.md"), @shell.Txt("（"), @shell.Code("--home"), @shell.Txt(" 可显式指一份；判据 "), @shell.Code("tools/site-source.sh"), @shell.Txt("）。首页那份 "), @shell.Code("SKILL.md"), @shell.Txt(" 讲工具本身。")]], [[@shell.Txt("首页里 "), @shell.Bold("`## [名字](目标)`"), @shell.Txt("（整条是链接）")], [@shell.Txt("顶栏的"), @shell.Bold("一条导航"), @shell.Txt("：点了"), @shell.Bold("跳页"), @shell.Txt("，直接渲染目标那一份（认不出目标就报错）")]], [[@shell.Txt("首页里"), @shell.Bold("普通 `##`"), @shell.Txt("（不是链接）")], [@shell.Txt("⚠️ "), @shell.Bold("不进顶栏"), @shell.Txt("，正文今天"), @shell.Bold("也不上首页"), @shell.Txt("：想让人看到就写进首屏（首个 "), @shell.Code("##"), @shell.Txt(" 之前），或做成一页再用链接节指过去")]], [[@shell.Code("<内容根>/<别的名字>/SKILL.md")], [@shell.Txt("文档区里的"), @shell.Bold("一份 skill"), @shell.Txt("（侧栏按名字排序）")]], [[@shell.Code("references/*.md"), @shell.Txt(" ｜ "), @shell.Code("FAQ.md"), @shell.Txt(" ｜ "), @shell.Code("scripts/*")], [@shell.Txt("那份 skill 的"), @shell.Bold("子页"), @shell.Txt("（树上展开）")]]]),
        @shell.P([@shell.Txt("三条会咬人的：")]),
        @shell.Ul([(0, "", [@shell.Bold("顶栏只有\"点了真会到某处\"的才画"), @shell.Txt("：结构性三条（首页 / 书架 / 搜索）+ 首页里"), @shell.Bold("带目标"), @shell.Txt("的那些 "), @shell.Code("##")])]),
        @shell.P([@shell.Txt("⇒ 栏名要"), @shell.Bold("短"), @shell.Txt("（序号会被剥掉；细则放正文第一句），长标题会把顶栏挤爆。")]),
        @shell.Ul([(0, "", [@shell.Code("#"), @shell.Txt("（H1）"), @shell.Bold("不进正文"), @shell.Txt("：它被抽成站名与首屏大标题。")])]),
        @shell.H2([@shell.Txt("三、改外观：改哪儿、别改哪儿")]),
        @shell.Table([[@shell.Txt("想改")], [@shell.Txt("去哪")]], [[[@shell.Txt("配色 / 字号 / 间距")], [@shell.Txt("程序的 "), @shell.Code("shell/tokens.mbt"), @shell.Txt("（"), @shell.Bold("设计 token 的唯一来源"), @shell.Txt("：调色板 "), @shell.Code("Palette"), @shell.Txt(" + 字号/行高）与 "), @shell.Code("shell/theme.mbt"), @shell.Txt("（明暗 × 三态偏好 → "), @shell.Code("Theme"), @shell.Txt(" 值）。⚠️ "), @shell.Bold("不是实例的 `app.mbt`"), @shell.Txt(" —— 那里只剩接线，以前那组 "), @shell.Code("c_bg"), @shell.Txt(" / "), @shell.Code("c_ink"), @shell.Txt(" / "), @shell.Code("c_head"), @shell.Txt(" 常量"), @shell.Bold("已经不存在了")]], [[@shell.Txt("代码块"), @shell.Bold("颜色")], [@shell.Txt("程序 "), @shell.Code("engine/highlight/hl.mbt"), @shell.Txt(" 产的色号 ↔ "), @shell.Code("shell/theme.mbt"), @shell.Txt(" 的 "), @shell.Code("Theme::tok_color"), @shell.Txt("："), @shell.Bold("索引两边对齐，改要一起改")]], [[@shell.Txt("页面骨架（顶栏 / 侧栏 / 正文）")], [@shell.Txt("程序的 "), @shell.Code("shell/"), @shell.Txt("（"), @shell.Code("site.mbt"), @shell.Txt(" 的 "), @shell.Code("view()"), @shell.Txt("、"), @shell.Code("article.mbt"), @shell.Txt("、"), @shell.Code("sidebar.mbt"), @shell.Txt("…）；⚠️ 实例的 "), @shell.Code("app.mbt"), @shell.Txt(" 只剩 19 行接线（判据 A2 钉着\"≤20 行\"）。顶栏栏位由内容决定，"), @shell.Bold("别写死")]], [[@shell.Txt("一块"), @shell.Bold("新构造"), @shell.Txt("（图片 / 折叠…）")], [@shell.Txt("两边一起改："), @shell.Code("engine/content/blocks.mbt"), @shell.Txt(" 解析 + "), @shell.Code("shell/"), @shell.Txt(" 渲染（解析边界刻意窄，见 refs）")]]]),
        @shell.P([@shell.Txt("⚠️ "), @shell.Bold("不许手改 `content/content.generated.mbt`"), @shell.Txt("（生成物）。改了内容源就重跑 "), @shell.Code("press"), @shell.Txt("； 生成物与源不一致时 "), @shell.Code("press --check"), @shell.Txt(" 会红，并指出"), @shell.Bold("第一处差异"), @shell.Txt("。")]),
        @shell.H2([@shell.Txt("四、验收（改完做什么）")]),
        @shell.Table([[@shell.Txt("改了什么")], [@shell.Txt("跑什么")], [@shell.Txt("红了怎么办")]], [[[@shell.Txt("任何内容源（"), @shell.Code("SKILL.md"), @shell.Txt(" / "), @shell.Code("references/**"), @shell.Txt("）")], [@shell.Code("press"), @shell.Txt(" → "), @shell.Code("press --check")], [@shell.Txt("别手改生成物")]], [[@shell.Txt("内容源（体量 / 条目数变了）")], [@shell.Code("check"), @shell.Txt("（G8 要你复核体量 → "), @shell.Code("check --update-lock <名字>"), @shell.Txt("）")], [@shell.Txt("复核，不是\"让门变绿\"")]], [[@shell.Txt("站点界面（"), @shell.Code("app.mbt"), @shell.Txt("）")], [@shell.Code("npm run build"), @shell.Txt(" → "), @shell.Code("verify")], [@shell.Bold("先修应用"), @shell.Txt("，不许放宽判据")]], [[@shell.Txt("代码块多了 / 改了")], [@shell.Code("audit"), @shell.Txt("（召回率与漏色比例越线即红）")], [@shell.Txt("别把阈值调松")]]]),
        @shell.P([@shell.Txt("看效果（实例目录里）："), @shell.Code("npm install && npm run build && npm run serve"), @shell.Txt(" → "), @shell.Code("http://127.0.0.1:8123/"), @shell.Txt("。")]),
        @shell.H2([@shell.Txt("五、坑（都是踩出来的）")]),
        @shell.Table([[@shell.Txt("现象")], [@shell.Txt("真因")], [@shell.Txt("处置")]], [[[@shell.Txt("frontmatter 三字段\"突然全没了\"")], [@shell.Txt("文件是 CRLF，"), @shell.Code("(.*)$"), @shell.Txt(" 匹配不到行尾的 "), @shell.Code("\\r")], [@shell.Txt("一律 LF（程序的 G2 会拦）")]], [[@shell.Txt("改了内容源，站点没变")], [@shell.Txt("忘了重跑 "), @shell.Code("press")], [@shell.Txt("跑 "), @shell.Code("press --check"), @shell.Txt("，它指出第一处差异")]], [[@shell.Txt("点那一栏\"没反应\"")], [@shell.Txt("合成 "), @shell.Code("click()"), @shell.Txt(" 在 web 上不触发 "), @shell.Code("Pressable"), @shell.Txt("（它走 responder）")], [@shell.Txt("判据要用真鼠标事件（"), @shell.Code("verify"), @shell.Txt(" 已这么干）")]], [[@shell.Txt("顶栏挤成两行 / 有条栏位跑到屏幕外")], [@shell.Txt("首页 "), @shell.Code("##"), @shell.Txt(" 名字太长、条数太多（顶栏是"), @shell.Bold("一行"), @shell.Txt("，靠横向滚动）")], [@shell.Txt("栏名写短；栏位别无限加")]], [[@shell.Txt("一大片代码块上不了色")], [@shell.Txt("片段不是合法代码，tree-sitter 落在 ERROR 区（里面拿不到 capture）")], [@shell.Txt("程序会自动试几种"), @shell.Bold("包装"), @shell.Txt("；仍不行见 "), @shell.Code("../skillpress-dev/references/pipeline.md")]], [[@shell.Txt("内容里写图片 / 原始 HTML 直接报错")], [@shell.Txt("解析边界"), @shell.Bold("刻意窄"), @shell.Txt("（只收实际用到的构造，不静默丢内容）")], [@shell.Txt("换写法，或按 §三 两边一起加构造")]], [[@shell.Txt("窄屏上顶栏挤")], [@shell.Txt("折叠菜单还没做")], [@shell.Txt("现状：宽屏优先")]]]),
        @shell.H2([@shell.Txt("六、还没做（别当成已支持）")]),
        @shell.P([@shell.Code("pack"), @shell.Txt("（一组 skill → 便携目录）｜ 首页里 "), @shell.Code("##"), @shell.Txt(" 的正文不上首页 ｜ 页内锚点的深链（"), @shell.Code("#section"), @shell.Txt("）｜ 窄屏顶栏的折叠菜单 ｜ 预渲染（整站客户端渲染，"), @shell.Code("#root"), @shell.Txt(" 是空壳；搜索索引也在渲染期现算）。 （本页目录 / 站内搜索 / 书架树 / "), @shell.Code("attach"), @shell.Txt(" / \"界面抽成 "), @shell.Code("shell"), @shell.Txt(" 包\""), @shell.Bold("都已经落地"), @shell.Txt(" —— 别再把它们列进\"还没做\"。）")]),
        @shell.P([@shell.Txt("这些会变，"), @shell.Bold("别当契约"), @shell.Txt(" —— 去程序的 "), @shell.Code("PLAN.md"), @shell.Txt(" 看。")]),
        @shell.H2([@shell.Txt("七、指针")]),
        @shell.Table([[@shell.Txt("要什么")], [@shell.Txt("去哪")]], [[[@shell.Txt("一份 / 多份 skill 到站点的完整步骤、哪些名字写死")], [@shell.Code("references/make-a-site.md")]], [[@shell.Txt("主页怎么写、样式与构造怎么改")], [@shell.Code("references/home-and-styles.md")]], [[@shell.Txt("投影规范：收录判据 / 结构 / 预算 / 站点边界")], [@shell.Txt("程序 "), @shell.Code("SPEC.md"), @shell.Txt("（§2 / §3 / §8）")]], [[@shell.Txt("集合划分、产出顺序")], [@shell.Txt("程序 "), @shell.Code("SKILLS.md")]], [[@shell.Txt("计划与未做")], [@shell.Txt("程序 "), @shell.Code("PLAN.md")]], [[@shell.Txt("目录形状（程序 / 内容 / 实例四个根、两种布局）")], [@shell.Txt("另一份 skill "), @shell.Code("skillpress-dev"), @shell.Txt("（程序侧）："), @shell.Code("skills/skillpress-dev/references/roots.md")]], [[@shell.Txt("站点管线内部（数据形状、两种模式、上色细则）")], [@shell.Txt("同上（程序侧）："), @shell.Code("skills/skillpress-dev/references/pipeline.md")]], [[@shell.Txt("改"), @shell.Bold("程序本身"), @shell.Txt("（引擎 / 门 / 判据）")], [@shell.Txt("另一份 skill："), @shell.Code("skillpress-dev")]]]),
      ],
      kids: [
        {
          kind: "ref",
          name: "home-and-styles",
          title: "首页怎么写、样式与构造怎么改",
          desc: "首页（那份叫 skillpress 的 skill）的写作规矩、markdown 的解析边…",
          blocks: [
            @shell.Quote([@shell.Txt("⚠️ "), @shell.Bold("已定要改（D19/D20，还没落地）"), @shell.Txt("：首页的内容源要改成 "), @shell.Code("skillpress/WEBSITE.md"), @shell.Txt("，"), @shell.Code("SKILL.md"), @shell.Txt(" 只讲工具本身 —— 今天仍读 "), @shell.Code("SKILL.md"), @shell.Txt("。")]),
            @shell.P([@shell.Bold("什么时候读它"), @shell.Txt("：你在排首页（顶栏栏位、下拉菜单、纯链接节）， 或者要把站点换成自己的配色 / 字号，要加一块"), @shell.Bold("新构造"), @shell.Txt("（图片、折叠、卡片…）。")]),
            @shell.H2([@shell.Txt("一、首页就是一份 skill（有它自己的规矩）")]),
            @shell.Table([[@shell.Txt("你写的")], [@shell.Txt("站点上变成")]], [[[@shell.Txt("H1（"), @shell.Code("# 标题"), @shell.Txt("）")], [@shell.Bold("站名"), @shell.Txt("（顶栏左边）+ 首屏大标题；它"), @shell.Bold("不进正文")]], [[@shell.Txt("首个 "), @shell.Code("##"), @shell.Txt(" 之前的段落")], [@shell.Txt("首屏引言（"), @shell.Code("lede"), @shell.Txt("）")]], [[@shell.Code("## [名字](目标)"), @shell.Txt("（"), @shell.Bold("整条"), @shell.Txt("是链接）")], [@shell.Txt("顶栏"), @shell.Bold("一条导航"), @shell.Txt(" —— 点了"), @shell.Bold("跳页"), @shell.Txt("，直接渲染目标那一份")]], [[@shell.Txt("普通 "), @shell.Code("##"), @shell.Txt("（不是链接）")], [@shell.Txt("⚠️ "), @shell.Bold("不进顶栏"), @shell.Txt("；正文今天"), @shell.Bold("也不上首页"), @shell.Txt("（缺口）：写进首屏，或做成一页再用链接节指过去")]], [[@shell.Code("###"), @shell.Txt(" / "), @shell.Code("####")], [@shell.Txt("正文里的章节标题；只有 "), @shell.Code("##"), @shell.Txt(" / "), @shell.Code("###"), @shell.Txt(" 进"), @shell.Bold("右栏本页目录")]]]),
            @shell.P([@shell.Txt("三条会咬人的（都吃过）：")]),
            @shell.Ul([(0, "", [@shell.Bold("顶栏只画\"点了真会到某处\"的"), @shell.Txt("：结构性三条（首页 / 书架 / 搜索）+ 首页里"), @shell.Bold("带目标"), @shell.Txt("的那些 "), @shell.Code("##"), @shell.Txt("。")])]),
            @shell.P([@shell.Txt("顶栏是"), @shell.Bold("一行"), @shell.Txt("，栏名要短（序号会被剥掉），7 个长标题会把它挤爆 —— 细则放正文第一句，别写进标题。")]),
            @shell.Ul([(0, "", [@shell.Bold("纯链接节的判定很严"), @shell.Txt("：只有 "), @shell.Code("[名字](目标)"), @shell.Txt(" 占满"), @shell.Bold("整条标题"), @shell.Txt("才算；正文里有链接"), @shell.Bold("不算"), @shell.Txt("。")])]),
            @shell.P([@shell.Txt("目标是相对"), @shell.Bold("首页那份 skill 的目录"), @shell.Txt("解析的，"), @shell.Bold("认不出来就报错"), @shell.Txt("（不给你一个静默的死链）。")]),
            @shell.Ul([(0, "", [@shell.Txt("纯链接节如果"), @shell.Bold("还带着正文"), @shell.Txt("，生成器会提示\"点它会跳到 X\"—— 那条正文只在\"不跳\"时才看得到，")])]),
            @shell.P([@shell.Txt("想让它真的显示就别把标题写成链接。")]),
            @shell.H2([@shell.Txt("二、markdown 支持的构造（刻意窄）")]),
            @shell.P([@shell.Txt("正文块：标题（"), @shell.Code("##"), @shell.Txt("–"), @shell.Code("####"), @shell.Txt("）、段落、列表、表格、围栏代码块、引用、分隔线， 以及"), @shell.Bold("独占一行的图片"), @shell.Txt("（"), @shell.Code("![alt](x.png)"), @shell.Txt(" 单独占一行 ⇒ 收成真 "), @shell.Code("<img>"), @shell.Txt("；"), @shell.Code("press"), @shell.Txt(" 会把图拷进 "), @shell.Code("img/"), @shell.Txt("）。 行内只认三样：`"), @shell.Code(" "), @shell.Txt("code"), @shell.Code(" "), @shell.Code("、"), @shell.Bold("bold"), @shell.Txt("`、链接。")]),
            @shell.P([@shell.Txt("两条刻意的边界：")]),
            @shell.Ul([(0, "", [@shell.Bold("不认识的构造逐条点名报错"), @shell.Txt("（行首原始 HTML、表格缺分隔行、围栏没闭合…），"), @shell.Bold("不静默丢内容"), @shell.Txt(" ——")])]),
            @shell.P([@shell.Txt("\"解不开的必须看得见\"；生成器报错时 "), @shell.Code("--check"), @shell.Txt(" 也一起红。")]),
            @shell.Ul([(0, "", [@shell.Bold("链接按\"台词\"渲染"), @shell.Txt("（这是静态阅读页，没有路由）：文字与目标相同时只留一份；")])]),
            @shell.P([@shell.Txt("否则渲染成\"文字 + 代码样式的路径\"。")]),
            @shell.P([@shell.Txt("要加"), @shell.Bold("折叠 / 卡片"), @shell.Txt("这类新构造：解析边界与渲染是"), @shell.Bold("两边"), @shell.Txt("的事，见第四节。")]),
            @shell.H2([@shell.Txt("三、改外观：配色、字号、代码颜色")]),
            @shell.P([@shell.Txt("配色与字号"), @shell.Bold("都在程序包里"), @shell.Txt("（⚠️ "), @shell.Bold("不在"), @shell.Txt("实例的 "), @shell.Code("app.mbt"), @shell.Txt(" —— 那里只剩接线）：")]),
            @shell.Table([[@shell.Txt("文件")], [@shell.Txt("管什么")]], [[[@shell.Txt("程序的 "), @shell.Code("shell/tokens.mbt")], [@shell.Bold("设计 token 的唯一来源"), @shell.Txt("：色值只在最底层的\"原语\"里写死；上面是语义色（"), @shell.Code("Palette"), @shell.Txt("：一个用途一个名字，如 "), @shell.Code("indigo_light"), @shell.Txt(" / "), @shell.Code("paper_light"), @shell.Txt("）、再上面是明暗不变量（间距 / 字号 / 行高 / 圆角，如 "), @shell.Code("fs_base"), @shell.Txt(" 15.5、"), @shell.Code("fs_h1"), @shell.Txt(" 30.0）")]], [[@shell.Txt("程序的 "), @shell.Code("shell/theme.mbt")], [@shell.Txt("把 "), @shell.Code("Palette"), @shell.Txt(" 按明暗（"), @shell.Code("Scheme"), @shell.Txt("）与三态偏好（"), @shell.Code("Pref"), @shell.Txt("）组装成 "), @shell.Code("Theme"), @shell.Txt(" "), @shell.Bold("值"), @shell.Txt("，跟着 Model 走；上色色号的翻译在 "), @shell.Code("Theme::tok_color")]]]),
            @shell.P([@shell.Txt("铁律是\""), @shell.Bold("渲染代码里不许出现字面色号"), @shell.Txt("\"：组件只引用语义名，换皮才只改一处。 （⚠️ 以前那份\"在 "), @shell.Code("app.mbt"), @shell.Txt(" 顶部改一组 "), @shell.Code("c_bg"), @shell.Txt(" / "), @shell.Code("c_ink"), @shell.Txt(" / "), @shell.Code("c_head"), @shell.Txt(" 常量\"的写法"), @shell.Bold("已经过期"), @shell.Txt("： 那些常量不存在了。）")]),
            @shell.P([@shell.Bold("代码块的颜色是另一条链"), @shell.Txt("：色号（调色板的索引）由程序 "), @shell.Code("engine/highlight/hl.mbt"), @shell.Txt(" 决定， 而\"这个色号长什么样\"由 "), @shell.Code("app.mbt"), @shell.Txt(" 的 "), @shell.Code("tok_color"), @shell.Txt(" 决定 —— "), @shell.Bold("索引两边对齐，改要一起改"), @shell.Txt("， 错位不会报错，只是颜色悄悄变了。")]),
            @shell.P([@shell.Txt("⚠️ 样式层的坑（改样式前值得知道）：这套界面是 moobile 的样式系统， RN 上有几条\"写了不报错但没效果\"的陷阱（按下一类、"), @shell.Code("transform"), @shell.Txt(" 每项只读第一个键、 "), @shell.Code("position: sticky"), @shell.Txt(" 连构造器都没有、"), @shell.Code("View"), @shell.Txt(" 不滚动）。这些的家是内容仓 moobile 那份讲坑的 "), @shell.Code("moobile-pitfalls"), @shell.Txt(" skill，别在这儿重抄。")]),
            @shell.H2([@shell.Txt("四、加一块新构造 = 两边一起改")]),
            @shell.Table([[@shell.Txt("这边")], [@shell.Txt("改什么")]], [[[@shell.Txt("程序侧 "), @shell.Code("engine/content/blocks.mbt")], [@shell.Txt("解析：把 markdown 里的新写法变成类型化数据（"), @shell.Code("Block"), @shell.Txt(" / "), @shell.Code("Span"), @shell.Txt(" 的新分支）")]], [[@shell.Txt("实例侧 "), @shell.Code("app.mbt")], [@shell.Txt("渲染："), @shell.Code("block_view"), @shell.Txt(" 里给新分支写画法（现成 8 种：标题三档 / 段落 / 引用 / 代码块 / 列表 / 表格 / 分隔线）")]]]),
            @shell.P([@shell.Txt("只改一边的症状：解析出来了但页面不显示（"), @shell.Code("match"), @shell.Txt(" 穷尽性会提醒 app 侧）， 或者渲染没数据可渲。"), @shell.Bold("生成物是两边共用的契约"), @shell.Txt("（"), @shell.Code("content/content.generated.mbt"), @shell.Txt("）， 所以改完必须 "), @shell.Code("press"), @shell.Txt(" 重生成，然后 "), @shell.Code("verify"), @shell.Txt(" —— 站点判据里\"渲染出来的与内容源逐字一致\"那条会盯着。")]),
            @shell.H2([@shell.Txt("五、改完的验收")]),
            @shell.Code("bash", "node ../skillpress/tools/press.mjs --check             # 内容源与生成物一致\nnode ../skillpress/tools/run-js.mjs audit             # 上色的闸门（改配色/色号后必跑）", [("node", 6), (" ../skillpress/tools/press.mjs ", 0), ("--check", 4), ("             ", 0), ("# 内容源与生成物一致", 3), ("\n", 0), ("node", 6), (" ../skillpress/tools/run-js.mjs audit             ", 0), ("# 上色的闸门（改配色/色号后必跑）", 3)]),
            @shell.P([@shell.Txt("实例里 "), @shell.Code("npm run build"), @shell.Txt(" → "), @shell.Code("npm run serve"), @shell.Txt(" 看效果；要机器判据就跑 "), @shell.Code("verify"), @shell.Txt(" （它要求 "), @shell.Code("dist/bundle.js"), @shell.Txt(" 已经在，见 "), @shell.Code("references/make-a-site.md"), @shell.Txt("）。")]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Bold("别手改生成物"), @shell.Txt("（"), @shell.Code("content/content.generated.mbt"), @shell.Txt("）：它的新鲜度由 "), @shell.Code("press --check"), @shell.Txt(" 保证， 手改之后下一次 "), @shell.Code("press"), @shell.Txt(" 就把你那次改动抹掉，而你会先经历一段\"改了没反应\"的困惑。")]),
          ],
        },
        {
          kind: "ref",
          name: "make-a-site",
          title: "从一份 / 多份 skill 到一个站点",
          desc: "站点怎么从内容源长出来：一个 skill 的最小站点、多份 skill 的侧栏树、子页的收…",
          blocks: [
            @shell.P([@shell.Bold("什么时候读它"), @shell.Txt("：你要"), @shell.Bold("新建"), @shell.Txt("一个站点（自己的 skill 目录 → 一个能打开的网站）， 或者想知道\"我把第 2 份 skill 放上去会变成什么\"。")]),
            @shell.H2([@shell.Txt("一、站点 = 一个实例 + 三个根")]),
            @shell.Table([[@shell.Txt("根")], [@shell.Txt("在哪")], [@shell.Txt("谁提供")]], [[[@shell.Bold("程序")], [@shell.Txt("旁边的 "), @shell.Code("skillpress/"), @shell.Txt("（"), @shell.Code("cmd/skillpress"), @shell.Txt("）")], [@shell.Txt("这套工具本身")]], [[@shell.Bold("内容")], [@shell.Code("<内容仓>/skills/"), @shell.Txt("（可以换成任何目录："), @shell.Code("--skills"), @shell.Txt("）")], [@shell.Bold("你写的 skill")]], [[@shell.Bold("实例")], [@shell.Txt("一个 MoonBit 工程（现成的在 "), @shell.Code("skills/skillpress/scripts/.skillpress/"), @shell.Txt("）")], [@shell.Txt("界面 + 宿主 + 生成物")]]]),
            @shell.P([@shell.Code("press"), @shell.Txt(" 把"), @shell.Bold("内容"), @shell.Txt("读出来、写进"), @shell.Bold("实例"), @shell.Txt("的 "), @shell.Code("content/content.generated.mbt"), @shell.Txt("；界面住在"), @shell.Bold("程序包的 `shell/`"), @shell.Txt(" 里（P6 起），实例的 "), @shell.Code("app.mbt"), @shell.Txt(" 只剩接线。 四个根怎么定位（"), @shell.Code("--repo"), @shell.Txt(" / "), @shell.Code("--skills"), @shell.Txt(" / "), @shell.Code("--app"), @shell.Txt(" 与环境变量、两种布局）见另一份 skill "), @shell.Code("skillpress-dev"), @shell.Txt("（程序侧）："), @shell.Code("skills/skillpress-dev/references/roots.md"), @shell.Txt("。")]),
            @shell.H2([@shell.Txt("二、一份 skill 的最小站点")]),
            @shell.Ul([(0, "1. ", [@shell.Txt("内容根里建 "), @shell.Code("<内容根>/skillpress/SKILL.md"), @shell.Txt(" —— ⚠️ "), @shell.Bold("首页那份的目录名写死是 `skillpress`"), @shell.Txt("（✅ "), @shell.Bold("已落地（D19/D20）"), @shell.Txt("：首页源优先 "), @shell.Code("<内容根>/skillpress/WEBSITE.md"), @shell.Txt("，没有它才回退 "), @shell.Code("SKILL.md"), @shell.Txt("；"), @shell.Code("--home"), @shell.Txt(" 可显式指一份）：")])]),
            @shell.P([@shell.Txt("生成器直接取 "), @shell.Code("join(SKILLS, \"skillpress\", \"SKILL.md\")"), @shell.Txt("，名字不对"), @shell.Bold("报错"), @shell.Txt("，不会静默给你一个空首页。")]),
            @shell.Ul([(0, "2. ", [@shell.Txt("写它 —— H1 = 站名与首屏大标题，首个 "), @shell.Code("##"), @shell.Txt(" 之前 = 首屏引言，每个 "), @shell.Code("##"), @shell.Txt(" = 顶栏一条栏位。")]), (0, "3. ", [@shell.Code("press"), @shell.Txt(" → "), @shell.Code("press --check"), @shell.Txt("。")]), (0, "4. ", [@shell.Txt("实例里 "), @shell.Code("npm install && npm run build && npm run serve"), @shell.Txt(" → 打开 "), @shell.Code("http://127.0.0.1:8123/"), @shell.Txt("。")])]),
            @shell.Code("", "<内容根>/\n└── skillpress/\n    └── SKILL.md        ← 首页：H1 + 引言 + 每个 ## 一栏", ([] : Array[(String, Int)])),
            @shell.H2([@shell.Txt("三、多份 skill：文档区自己长出来")]),
            @shell.P([@shell.Txt("再加一份 = "), @shell.Bold("再加一个目录"), @shell.Txt("，不需要任何配置：")]),
            @shell.Code("", "<内容根>/\n├── skillpress/SKILL.md          ← 首页（名字写死）\n├── my-thing/SKILL.md            ← 文档区里的第 1 份（侧栏按名字排序）\n└── other-thing/\n    ├── SKILL.md\n    ├── references/gates.md      ← 它的子页\n    └── notes/deep.md            ← 也是子页（位置不限）", ([] : Array[(String, Int)])),
            @shell.P([@shell.Txt("侧栏树 = skill → 它的子页；顶栏那条「文档 / SKILL」切过去就是文档区（它换的是"), @shell.Bold("整个模式"), @shell.Txt("）。")]),
            @shell.P([@shell.Bold("子页怎么来的"), @shell.Txt("（规矩在 "), @shell.Code("engine/content/kids.mbt"), @shell.Txt("，生成器 / 门 / 判据三处共用）：")]),
            @shell.Ul([(0, "", [@shell.Txt("那个 skill 目录下"), @shell.Bold("任何子目录里的 `.md`"), @shell.Txt(" 都收（"), @shell.Code("references/"), @shell.Txt(" 只是"), @shell.Bold("推荐"), @shell.Txt("位置，不是硬性位置）；")]), (0, "", [@shell.Code("scripts"), @shell.Txt(" 子目录里"), @shell.Bold("直接放着的非 md 文件"), @shell.Txt("按可跑脚本收（站点上以代码块展示）；")]), (0, "", [@shell.Bold("产物目录与点开头的目录一律跳过"), @shell.Txt("（依赖目录、构建产物、任何以 "), @shell.Code("."), @shell.Txt(" 开头的）；")]), (0, "", [@shell.Txt("侧栏上的名字："), @shell.Code("references/"), @shell.Txt(" 下的文件去掉前缀与扩展名（"), @shell.Code("references/"), @shell.Txt(" 里的 gates.md → "), @shell.Code("gates"), @shell.Txt("）；")])]),
            @shell.P([@shell.Txt("其余按相对路径去掉扩展名；"), @shell.Bold("名字撞了就都退回全路径"), @shell.Txt("（宁可长一点，也不要两个同名的子页）。")]),
            @shell.H2([@shell.Txt("四、实例：怎么准备一个")]),
            @shell.P([@shell.Bold("先跑脚手架"), @shell.Txt("（它把整套实例写出来，含首页源与忽略清单）：")]),
            @shell.Code("bash", "node tools/run-js.mjs attach --repo <仓根> --skills <内容根>", [("node", 6), (" tools/run-js.mjs attach ", 0), ("--repo", 4), (" ", 0), ("<", 9), ("仓根", 0), (">", 9), (" --skills ", 0), ("<", 9), ("内容根", 0), (">", 9)]),
            @shell.P([@shell.Txt("只有要"), @shell.Bold("特化"), @shell.Txt("它时才手工改这几处（改的都是"), @shell.Bold("生成出来的"), @shell.Txt("那份，不是另抄一份）：")]),
            @shell.Table([[@shell.Txt("要改的")], [@shell.Txt("改成什么")]], [[[@shell.Code("package.json"), @shell.Txt(" 的 "), @shell.Code("name")], [@shell.Txt("你的站点名")]], [[@shell.Code("package.json"), @shell.Txt(" 里的宿主依赖")], [@shell.Txt("指向你本机的宿主（"), @shell.Code("file:"), @shell.Txt(" 路径）")]], [[@shell.Code("package.json"), @shell.Txt(" 的 "), @shell.Code("SKILLPRESS_ENGINE")], [@shell.Txt("指向程序（默认值 "), @shell.Code("../../../../../skillpress"), @shell.Txt(" 正是\"兄弟\"布局）")]], [[@shell.Code("moon.mod"), @shell.Txt(" 的模块名与依赖版本")], [@shell.Txt("你的模块名 / 你要的库版本")]], [[@shell.Code("index.html"), @shell.Txt(" 的标题")], [@shell.Txt("浏览器标签上的标题（首屏 H1 来自"), @shell.Bold("内容"), @shell.Txt("，不是这里）")]], [[@shell.Code("app.mbt")], [@shell.Txt("想改外观才动 —— 见 "), @shell.Code("references/home-and-styles.md")]]]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Bold("宿主是 `file:` 依赖"), @shell.Txt("（这套东西的老规矩）：改了宿主之后，"), @shell.Code("node_modules"), @shell.Txt(" 里那份副本要刷新， 否则"), @shell.Bold("验证脚本会悄悄测旧代码"), @shell.Txt("（症状是\"两次跑出来的结果一模一样\"）。")]),
            @shell.H2([@shell.Txt("五、验收")]),
            @shell.Table([[@shell.Txt("命令")], [@shell.Txt("在哪跑")], [@shell.Txt("它证明什么")]], [[[@shell.Code("press --check")], [@shell.Txt("内容仓根")], [@shell.Txt("生成物与内容源一致（\"改了内容忘了 press\"会被抓，并指出第一处差异）")]], [[@shell.Code("npm run build")], [@shell.Txt("实例目录")], [@shell.Txt("内容包能编译、界面能打包出 "), @shell.Code("dist/bundle.js")]], [[@shell.Code("verify")], [@shell.Txt("内容仓根（或实例里那份薄壳 "), @shell.Code("verify.mjs"), @shell.Txt("）")], [@shell.Txt("真 Chrome 无头：顶栏 / 两种模式 / 点击切换 / 上色 / 吸顶 / 无 console error")]], [[@shell.Code("check")], [@shell.Txt("内容仓根")], [@shell.Txt("skill 自己合格（G1–G8）：frontmatter、LF、路径、预算、体量指纹")]]]),
            @shell.P([@shell.Txt("⚠️ "), @shell.Code("verify"), @shell.Txt(" "), @shell.Bold("要求实例里先有 `dist/bundle.js`"), @shell.Txt("：没有它会直接说\"先在 site/ 里跑 "), @shell.Code("npm run build"), @shell.Txt("\" （它不猜、也不替你构建）。")]),
            @shell.H2([@shell.Txt("六、还没做（别当成已支持）")]),
            @shell.Ul([(0, "", [@shell.Code("pack"), @shell.Txt("：把一个 / 一组 skill 打成"), @shell.Bold("便携目录"), @shell.Txt("（自带程序副本 + 生成的首页 skill）。")]), (0, "", [@shell.Txt("锚点 / 目录 / 搜索；窄屏折叠菜单；生产 bundle（现在是 dev 模式，大头是 react-native-web）。")])]),
            @shell.P([@shell.Txt("这些会变，"), @shell.Bold("别当契约"), @shell.Txt("：去程序的 "), @shell.Code("PLAN.md"), @shell.Txt(" 看。")]),
          ],
        },
      ],
    },
  ]
}

///| 页面键 → `(kind, skill 下标, 子页下标)`；认不出来给 `(-1, -1, -1)`。
///
/// 键的形状与生成器里的 `docKey` / `kidKey` **必须对账**：
/// 主文档 = `<slug>`，子页 = `<slug>/<kind>/<name>`（kind 是 `ref` / `script`）。
/// 站在**生成物**这一侧做这个查找，是为了让「第几页」这个编号只有一处定义（`skills()` 的顺序）。
pub fn find_page(key : String) -> (Int, Int, Int) {
  let ks = skills()
  for i = 0; i < ks.length(); i = i + 1 {
    let d = ks[i]
    if key == d.slug {
      return (1, i, 0)
    }
    for j = 0; j < d.kids.length(); j = j + 1 {
      let k = d.kids[j]
      if key == "\{d.slug}/\{k.kind}/\{k.name}" {
        return (2, i, j)
      }
    }
  }
  (-1, -1, -1)
}

///| 页脚要交代的出处（DESIGN-site.md §5）：许可 / 生成时间 / 内容根指纹。
///
/// ⚠️ 空串 = 拿不到 ⇒ 页脚那一项**不画**（不写「许可 —」这种占位）。
///    三个字段各自为什么可能空，写在 `shell/types.mbt` 的 `Footer` 里（一处定义）。
pub fn footer() -> @shell.Footer {
  {
    license: "Apache-2.0",
    generated_at: "",   // 由宿主构建脚本注入（内容包必须逐字节可复现）
    root_fingerprint: "01db55d8d93e6d717aa397100a1ad3d83bc8e53e7772a4656145f31322eda12d",
  }
}

