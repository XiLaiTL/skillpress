// win_compat.c —— 只补**一个**东西：`GetTempPath2W`。
//
// ## 为什么需要它（2026-10-07 实测，不是猜）
//
// `moonbitlang/async` 的 **native fs 桩**引用了 `GetTempPath2W`，而那是
// **Windows 10 2004+ 的 SDK（10.0.20348 起）** 才提供的导入符号。
// 本机只装了 SDK **10.0.19041.0**（`ls "Program Files (x86)/Windows Kits/10/Lib"` 只有这一个目录，
// 且 `strings kernel32.lib | grep GetTempPath2W` 命中 **0**）⇒ 链接期直接红：
//
//   libfs.lib(stub.obj) : error LNK2019: unresolved external symbol GetTempPath2W
//                        referenced in function moonbitlang_async_get_tmp_path
//   site.exe : fatal error LNK1120: 1 unresolved externals
//
// ⚠️ **绕不开**：`@process` 依赖 `@async/fs`，而站点判据（P8.3）要起 Chrome 就得用 `@process`
//    ⇒ 只要走 async 那条路，这个符号就跑不掉。
//
// ## 语义上这一版够用
//
// `GetTempPath2W` 与 `GetTempPathW` 的差别只有一条：**系统进程**调用时前者返回**系统** temp、
// 后者返回用户 temp。我们是普通用户进程 ⇒ 两者同值。所以直接转发。
//
// ⚠️ 装了新 SDK 的机器上这段会与 SDK 的导入库并存：链接器会先用这里的**本地定义**
//    （导入库只在"符号仍未定义"时才被取用）⇒ 不会重复定义报错，新机器上也不受影响。
#include <windows.h>

DWORD __stdcall GetTempPath2W(DWORD nBufferLength, LPWSTR lpBuffer) {
  return GetTempPathW(nBufferLength, lpBuffer);
}
