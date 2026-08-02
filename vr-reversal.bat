@ECHO OFF
REM Launch mpv with the VR-reversal 360plugin enabled.
REM Drop one or more videos onto this file (or its shortcut), or run it with
REM no arguments and drag videos onto the mpv window.
REM mpv is located in this order: MPV_BIN env var (full path to mpv.exe),
REM mpv.exe next to this file, then mpv.exe on PATH.
REM Set VR_HWDEC=auto-copy (or nvdec-copy / d3d11va-copy) to enable GPU
REM decode acceleration; only copy-back modes work with the v360 filter.
pushd %~dp0
SET "MPV="
IF DEFINED MPV_BIN IF EXIST "%MPV_BIN%" SET "MPV=%MPV_BIN%"
IF NOT DEFINED MPV IF EXIST "%~dp0mpv.exe" SET "MPV=%~dp0mpv.exe"
IF NOT DEFINED MPV (
	where mpv.exe >NUL 2>NUL
	IF NOT ERRORLEVEL 1 SET "MPV=mpv.exe"
)
IF NOT DEFINED MPV (
	ECHO mpv.exe was not found.
	ECHO Either set the MPV_BIN environment variable to the full path of
	ECHO mpv.exe, add its folder to PATH, or copy mpv.exe next to this file.
	ECHO Example:  setx MPV_BIN "D:\video\mpv\mpv.exe"
	PAUSE
	popd
	EXIT /B 1
)
SET HWOPT=
IF DEFINED VR_HWDEC SET HWOPT=,360plugin-hwdec=%VR_HWDEC%
IF "%~1"=="" (
	"%MPV%" --script=360plugin.lua --script-opts=360plugin-enabled=yes%HWOPT% --force-window --idle=once
) ELSE (
	"%MPV%" --script=360plugin.lua --script-opts=360plugin-enabled=yes%HWOPT% %*
)
popd
