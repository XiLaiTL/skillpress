@echo off
REM native-build.bat -- build for the native target on THIS machine.
REM
REM Why it exists (measured in P8.0): the Windows native backend needs an MSVC
REM cl-compatible driver (cl.exe / clang-cl.exe) and it calls link.exe directly.
REM Without the MSVC environment, `moon build --target native` fails with
REM "LNK1120: N unresolved externals" -- which looks like a missing toolchain
REM but is really "INCLUDE/LIB not set". This box has VS 2022 Build Tools, so:
REM
REM Keep this file ASCII-only: cmd.exe reads .bat as the OEM codepage (GBK here),
REM and UTF-8 comments decode into bytes that contain & | > " -- which cmd then
REM runs as commands (measured: 356k lines of garbage, and the build never ran).
REM
REM Usage: native-build.bat [args for moon...]   (default: build cmd/main --target native)
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio‚2\BuildTools\VC\Auxiliary\Buildcvars64.bat" >nul
cd /d "%~dp0"
if "%~1"=="" (
  moon build cmd/main --target native
) else (
  moon %*
)
endlocal
