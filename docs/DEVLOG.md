# Development log

Engineering journal for unvr-mpv. Newest entries first. Terse, user-facing
release notes belong in a CHANGELOG, not here; this records what was done,
why, and how it was verified.

## 2026-07-18 - Configurable starting preview resolution (default ~480p)

The preview previously started at res=1 (a 192x108 render upscaled by mpv,
hence the very soft default image). New `start_height` opt (default 480)
sets the initial preview height in pixels, snapped to the 108px grid the
`y`/`h` keys step through and clamped to res 1..20: 480 -> res 4 (768x432),
540 -> res 5 (960x540). Exact 480p is not on the 192x108 grid, so 480
snaps to 432p. Preview only - exports remain 1080p. Verified over IPC:
default gives w=4*192, start_height=540 gives 5, 90 clamps to 1, invalid
values fall back to the default.

## 2026-07-17 - Vertical (portrait) crop mode

Cropping to a portrait view of the projected 2D image, with matching
vertical-video export.

Design decisions:

- Crop, not re-project: the request was a portrait cut of the usual
  projection, so a centered `crop` filter is appended after the existing
  chain rather than changing the v360 output geometry. What you see is
  exactly what exports.
- Hotkey (`x`, opt `vertical_crop`) cycles off -> each aspect in the
  `vertical_aspects` opt (default `9:16,2:3,3:4,1:1`) -> off. Invalid
  aspect tokens are skipped with a console warning.
- 2d output mode only: cropping a side-by-side or anaglyph frame is
  ill-defined (and 1:1 would exceed the halved anaglyph frame width), so
  `cropClause()` returns nothing unless `outputMode == '2d'`; the OSD says
  so when toggling in other modes.
- Export crop is captured at recording-section start (`init_cropFilter`,
  alongside the existing `init_*` values) because an encoder cannot change
  frame size mid-stream. Toggling crop during a section shows an OSD note
  and applies from the next section on. Export sizes at 1080p height:
  9:16 -> 608x1080, 2:3 -> 720x1080, 3:4 -> 810x1080, 1:1 -> 1080x1080
  (widths rounded to even for yuv420).
- Refactored `updateFilters` to build the filter string once instead of
  duplicating it in the vf add / vf set branches.

Verified headlessly over IPC: crop cycles at res=3 gave 182/216/244/324
widths on the 576x324 preview and cleanly removed when off; recorded two
sections (one started under 9:16, one under 2:3) with a mid-section aspect
change in the first; the generated commands contained crop=608:1080 and
crop=720:1080 respectively, and running convert_3dViewHistory.sh produced
valid 608x1080 and 720x1080 mp4s.

## 2026-07-17 - Code review, GPU decode support, Linux launcher, docs

Commits: 41be8fe (plugin fixes + hwdec), 41525cb (launchers), 4e988d4 (docs).

### Code review findings in 360plugin.lua

Fixed:

- Projection cycling crash: the `1`/`2` key handlers advanced the table
  index with `% (#table + 1)`, so every full cycle the index hit 0, which
  is nil in a Lua table, and `string.format` crashed. Same fix as upstream
  dfaker/VR-reversal PR #33 (confirmed independently, then merged).
- OSD message for `y`/`h` reported the output height (`res*108`) labeled
  "Out-Width"; now shows the real `WxH`.
- Zero-duration motion intervals emitted `lerp(...)/0.000` (division by
  zero) into the ffmpeg sendcmd expressions - visible on the first line of
  every recording. Duration is now clamped to 0.001.
- `onExit` always wrote a Windows-only `convert_3dViewHistory.bat` with
  commands joined by `&`. On Linux/macOS it now writes an executable
  `convert_3dViewHistory.sh` (one command per line); Windows behavior is
  unchanged. OS detection via `package.config:sub(1,1)`.

Noted but deliberately left alone (pre-existing, harmless):

- `onExit` runs twice on quit (registered for both `end-file` and
  `shutdown`); `closeCurrentLog` is idempotent so this is safe.
- First log file is numbered `_1` instead of `_0` because the recording
  status timer mutates `lasttimePos` before the first session starts.
- `closeCurrentLog` leaks a few globals (`commandForFinalLog`,
  `finalTimeStamp`); cosmetic.
- mpv 0.37 prints "Passing more than 1 argument to vf-add is deprecated";
  upstream filter-string style, cosmetic.

### GPU acceleration: analysis and implementation

The v360 reprojection is a CPU libavfilter filter; neither mpv nor mainline
FFmpeg has a GPU implementation, so the projection math cannot be
offloaded. A full GPU path would require a custom libplacebo shader or an
FFmpeg CUDA fork - judged too complex and fragile to be worth it.

What can be offloaded is decoding (the other large CPU cost on 4K VR
sources) via mpv's copy-back hwdec modes. The plugin previously
hard-disabled hwdec because non-copy modes keep frames in GPU memory where
the CPU filter cannot reach them (filter format error). Implementation:

- New `hwdec` script opt, default `no` (historic safe behavior).
- Any other value is applied while the plugin is active; `yes`/`auto`
  normalize to `auto-copy`, `auto-safe` to `auto-copy-safe`, since only
  copy-back modes work with the CPU filter chain.

Headless/VNC note: NVDEC/VAAPI decoding does not need the display, so GPU
decode works even when video output falls back to software rendering.
Verified live in a VNC framebuffer session on an RTX 4070 Ti SUPER:
`hwdec-current` reported `nvdec-copy` with the `@vrrev` filter chain
intact and no format errors.

### Launchers

- `vr-reversal.sh` (new): launches mpv with the plugin enabled. Player
  binary selectable via `-p`/`--player` or `MPV_BIN` (default `mpv`). GPU
  auto-detection (nvidia-smi, else `/dev/dri/renderD*`) enables
  `hwdec=auto-copy`; `--no-hwdec` / `--hwdec MODE` override. All other
  arguments pass through to mpv; with no file it opens an idle
  drag-and-drop window. Does not cd, so motion logs land in the caller's
  working directory and relative video paths work.
- `vr-reversal.bat` (updated): accepts multiple files (`%*`), opens an
  idle window when run bare, optional GPU decode via the `VR_HWDEC`
  environment variable.
- `create-windows-shortcut.ps1` (new): generates a Desktop "VR Reversal"
  shortcut targeting the .bat; videos can be dropped onto it. A ready-made
  .lnk cannot be committed because shortcuts embed absolute local paths.

### Verification

- Synthesized an 8 s 1920x960 test clip with ffmpeg (`testsrc2`).
- Drove mpv headlessly (`--vo=null --ao=null`) over `--input-ipc-server`:
  pressed `n`, panned/pitched, pressed `n`, quit. Confirmed the `@vrrev`
  v360 filter chain was active, the motion log contained correct
  timestamped lerp lines, and `convert_3dViewHistory.sh` was created
  executable.
- Ran the generated script: ffmpeg exited 0 and produced a valid
  1920x1080, 4.2 s 2D mp4 (checked with ffprobe).
- Repeated with `hwdec=auto-copy`: `hwdec-current` = `nvdec-copy`, no
  errors. Wrapper tested end-to-end including `--help` and GPU detection.

### Upstream triage (dfaker/VR-reversal)

- PR #33 (projection cycling fix): merged here.
- #38, #34 (GPU/CPU load): addressed by the hwdec work above.
- #30 (macOS `reset_rot` error): old FFmpeg; documented FFmpeg >= 4.4 as a
  requirement in the README.
- #27 (launch defaults): already possible via script-opts; documented.
- Plausible future work, not implemented:
  - #24/#36: 360 mono input needs an `in_stereo=2d` option (currently only
    sbs/tb cycle) - small change.
  - #35/#31: output aspect/size options instead of hardcoded 16:9
    (1920x1080 render, 192x108-based preview sizing).

### Docs

- README rewritten: Linux install (apt/dnf/pacman), wrapper and shortcut
  usage, recording-session-to-ffmpeg workflow, GPU decode-vs-projection
  explanation, caveats (run conversion from the launch directory;
  filenames with `'` `:` `,` break the generated filtergraph).
- CLAUDE.md added: architecture notes, copy-back hwdec constraint,
  portability rules, headless test recipe.

### Open question

The user mentioned a past Windows issue but the message was cut off. Most
likely candidate is the projection-cycling crash (now fixed); revisit if it
was something else.
