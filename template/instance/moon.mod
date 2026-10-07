// 站点实例的 moon 模块 —— 名字由 `skillpress attach` 按目标仓目录名算出来（生成时替换）。
//
// 应用是**独立模块**，不是库模块里的一个包：`moon.mod` 的 import 是**模块粒度**且随包发布，
// 应用若塞进库模块，应用的依赖就变成所有使用者的下载量。
//
// ⚠️ 名字是**算出来的**，不是手抄的：生成器把模板里那个占位符换成目标仓的名字，
//    并断言"产物里一个占位符都不剩"（没断言的话，替换漏了会**静静编不过**）。
name = "{{MODULE}}"

version = "0.1.0"

license = "Apache-2.0"

description = "skillpress 站点实例：用 skillpress 把本仓的 skills/ 印成一个站点"

preferred_target = "js"

import {
  "XiLaiTL/moobile@0.6.0",
  // 站点界面就是这里来的：本工程只接线，界面（顶栏 / 侧栏树 / 正文渲染）在包 `shell` 里。
  // ⚠️ 未发布时靠 `moon.work` 指向**本地源码**；发布之后这条依赖从 registry 解析，
  //    工作区那个文件就可以删掉。
  "XiLaiTL/skillpress@0.1.0",
}
