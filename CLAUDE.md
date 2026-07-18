# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A single-file mpv Lua plugin (`360plugin.lua`) that plays 3D SBS/TB VR video
as flat 2D by driving FFmpeg's `v360` filter inside mpv, and records "head
motion" sessions as ffmpeg `sendcmd` scripts for later offline 2D rendering.
Fork of dfaker/VR-reversal (upstream issues/PRs live there).

## Layout

- `360plugin.lua` - the entire plugin. No modules, no dependencies beyond
  mpv's bundled Lua API (`mp`, `mp.options`).
- `script-opts/360plugin.conf` - default key bindings and options; every key
  in the `opts` table at the top of the Lua file can be overridden here or
  via `--script-opts=360plugin-KEY=VALUE`.
- `vr-reversal.sh` - Linux launcher (player override via `-p`/`MPV_BIN`,
  GPU auto-detection -> `360plugin-hwdec=auto-copy`).
- `vr-reversal.bat` - Windows launcher (GPU opt-in via `VR_HWDEC` env var).
- `create-windows-shortcut.ps1` - generates a Desktop .lnk to the .bat
  (shortcuts embed absolute paths, so the .lnk itself is not committed).

## Architecture notes

- View state (yaw/pitch/roll/dfov/res/projections) lives in file-local vars;
  every change goes through `updateFilters()`, which rebuilds one mpv video
  filter chain labeled `@vrrev` (`v360=...` + `setsar` + optional
  `stereo3d`) via `vf add`/`vf set`.
- Recording: `startNewLogSession()` (key `n`) opens
  `{filename}_3dViewHistory_{N}.txt` in the *current working directory*;
  `writeHeadPositionChange()` appends timestamped `[expr] v360 ... lerp()`
  sendcmd lines on every view change. `closeCurrentLog()` appends the
  suggested ffmpeg command as comments; `onExit()` writes the combined
  `convert_3dViewHistory.sh` (POSIX) or `.bat` (Windows, detected via
  `package.config`).
- `onExit` is registered for both `end-file` and `shutdown` and may run
  twice; `closeCurrentLog` is idempotent, keep it that way.
- Key bindings are forced (`add_forced_key_binding`) from the `bindings`
  table when the plugin is toggled on and removed on toggle off, except the
  `toggle_vr360` key which is always bound.

## Hard constraints

- Portability: everything must keep working on both Linux and Windows.
  OS-specific behavior in the Lua code branches on
  `package.config:sub(1,1) == '\\'`.
- `v360` is a CPU libavfilter filter. Hardware decoding must use copy-back
  modes only (`auto-copy`, `nvdec-copy`, `vaapi-copy`, `d3d11va-copy`);
  non-copy hwdec leaves frames in GPU memory and breaks the filter chain.
  The `hwdec` script opt defaults to `no`; `yes`/`auto` are normalized to
  `auto-copy` in `requestedHwdec()`.
- The motion log format is consumed by ffmpeg's `sendcmd` filter - do not
  change the line format without verifying an actual ffmpeg render.
- Requires FFmpeg >= 4.4 in mpv for `v360`'s `reset_rot` option.
- ASCII only in code and docs; the Lua file uses tabs for indentation.

## Testing

No test suite. Smoke-test headlessly (works over VNC/ssh, no window):

```sh
mpv --no-config --vo=null --ao=null --end=3 \
    --script=360plugin.lua \
    --script-opts=360plugin-enabled=yes,360plugin-hwdec=no \
    someVideo.mp4
```

Check: no Lua errors, `vf` chain contains `@vrrev`. To exercise recording,
drive keypresses over `--input-ipc-server` (send `keypress n`, move view,
`keypress n`, `quit`), then run the generated `convert_3dViewHistory.sh` and
ffprobe the output. For hwdec, verify `hwdec-current` reports a `-copy` mode
and playback shows no `Impossible to convert between the formats` error.
Lua syntax check: `luac -p 360plugin.lua` (if luac installed) or just load
it in mpv as above.
