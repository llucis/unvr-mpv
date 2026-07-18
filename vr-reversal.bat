@ECHO OFF
REM Launch mpv with the VR-reversal 360plugin enabled.
REM Drop one or more videos onto this file (or its shortcut), or run it with
REM no arguments and drag videos onto the mpv window.
REM Set VR_HWDEC=auto-copy (or nvdec-copy / d3d11va-copy) to enable GPU
REM decode acceleration; only copy-back modes work with the v360 filter.
pushd %~dp0
SET HWOPT=
IF DEFINED VR_HWDEC SET HWOPT=,360plugin-hwdec=%VR_HWDEC%
IF "%~1"=="" (
	mpv.exe --script=360plugin.lua --script-opts=360plugin-enabled=yes%HWOPT% --force-window --idle=once
) ELSE (
	mpv.exe --script=360plugin.lua --script-opts=360plugin-enabled=yes%HWOPT% %*
)
popd
