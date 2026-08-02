# VR-reversal (unvr-mpv)

Uses mpv and a Lua plugin to play a 3D side-by-side VR video as a flat 2D
video: look around and zoom within the video with the mouse or keyboard, and
optionally log the "head" motions to a file for later rendering out to a
regular 2D video with ffmpeg.

Fork of [dfaker/VR-reversal](https://github.com/dfaker/VR-reversal) with
Linux launcher support, optional GPU decode acceleration, and portability
fixes.

![Example output](https://github.com/dfaker/VR-reversal/blob/master/example.gif?raw=true)

# Requirements

- [mpv](https://mpv.io/) built against a reasonably recent FFmpeg. The plugin
  needs the `v360` filter with the `reset_rot` option (FFmpeg >= 4.4). If mpv
  reports `AVOption 'reset_rot' not found`, your mpv/FFmpeg is too old.
- [ffmpeg](https://ffmpeg.org/) on PATH - only needed to render the recorded
  sessions to 2D video files, not for viewing.

# Installation

## Linux

Install mpv and ffmpeg from your distribution, then clone this repo:

```sh
# Debian/Ubuntu
sudo apt install mpv ffmpeg
# Fedora (RPM Fusion enabled)
sudo dnf install mpv ffmpeg
# Arch
sudo pacman -S mpv ffmpeg

git clone https://github.com/llucis/unvr-mpv.git
cd unvr-mpv
```

Play a video through the wrapper script:

```sh
./vr-reversal.sh videoFile.mp4
```

The wrapper:

- launches mpv with the plugin enabled (no mpv config changes needed);
- auto-detects a GPU (NVIDIA or a `/dev/dri` render node) and enables
  hardware *decoding* (`hwdec=auto-copy`) when one is present - pass
  `--no-hwdec` to disable, or `--hwdec MODE` to force a specific mode;
- accepts an alternative player binary with `-p /path/to/mpv` or the
  `MPV_BIN` environment variable (useful for flatpak or custom builds);
- passes all other arguments straight to mpv, so multiple files, playlists
  and extra mpv options work as usual;
- with no file arguments, opens an idle mpv window you can drag videos onto.

Run `./vr-reversal.sh --help` for the full usage text.

Note: motion logs and the conversion script are written to the directory you
launch from, so run the wrapper from a writable directory (ideally the one
holding your videos).

Alternatively, to enable the plugin inside your regular mpv setup, copy
`360plugin.lua` into `~/.config/mpv/scripts/` and
`script-opts/360plugin.conf` into `~/.config/mpv/script-opts/`, then press
`v` in any mpv session to toggle it (or set `enabled=yes` in the conf to
always start active).

## Windows

- `vr-reversal.bat` looks for mpv in this order: the `MPV_BIN` environment
  variable (full path to `mpv.exe`), an `mpv.exe` next to the .bat, then
  `mpv.exe` on PATH. If mpv is installed elsewhere, point `MPV_BIN` at it
  once with e.g. `setx MPV_BIN "D:\video\mpv\mpv.exe"`.
- If mpv cannot be found, the console window stays open with an error
  message instead of closing silently.
- Run `vr-reversal.bat` and drag videos onto the mpv window, or drop a video
  file directly onto the .bat.

To get a Desktop shortcut you can drop videos onto:

```powershell
powershell -ExecutionPolicy Bypass -File create-windows-shortcut.ps1
```

This creates "VR Reversal.lnk" on your Desktop pointing at
`vr-reversal.bat` (a ready-made .lnk cannot ship in the repo because
shortcuts embed absolute local paths). Dropping a video file on the shortcut
starts a session with the plugin enabled.

To enable GPU decode acceleration on Windows, set the `VR_HWDEC`
environment variable before launching, e.g. `set VR_HWDEC=auto-copy` (or
`d3d11va-copy`, `nvdec-copy`).

# GPU acceleration - what it does and does not cover

The v360 reprojection is a CPU libavfilter filter; mpv has no GPU
implementation of it, so the projection math always runs on the CPU. What
*can* be offloaded is video decoding (the other big CPU consumer,
especially for 4K+ VR sources), using mpv's copy-back hardware decoding
modes (`auto-copy`, `nvdec-copy`, `vaapi-copy`, `d3d11va-copy`, ...).
Copy-back is required: non-copy modes keep frames in GPU memory where the
CPU filter cannot reach them and playback fails with a filter format error.
For that reason the plugin normalizes `hwdec=yes/auto` to `auto-copy`, and
defaults to `hwdec=no` (the historic safe behavior) unless you or the
launcher scripts opt in.

This also works in headless or remote sessions (VNC, X forwarding):
NVDEC/VAAPI decode does not need the display, so GPU decode acceleration is
available even when the video output itself falls back to software
rendering.

The plugin option is exposed like any other script opt:

```sh
mpv --script=360plugin.lua --script-opts=360plugin-enabled=yes,360plugin-hwdec=auto-copy videoFile.mp4
```

# Controls

You can press `?` to show all of the keyboard controls on screen at any time.

When the player is started, if the script is automatically enabled, you'll be
looking straight forwards. If not type:

- `v` to toggle the main feature on or off.

The preview starts near 480p (768x432; configurable via the `start_height`
option, snapped to 108px steps). Press `y` to increase the preview quality,
`h` to reduce it again. This only affects the live preview - recorded
sections always export at 1080p height.

- `y` increase resolution
- `h` decrease resolution

Control where you're looking with the mouse:

- MouseLook: click anywhere in the video and your mouse position will control
  the camera, click again to stop mouse control
- MouseScroll: zoom in and out

or alternately look around with these keys:

- `i`,`j`,`k`,`l` look around
- `u`,`o` roll head
- `=`,`-` zoom
- `TAB` center view

Additional controls:

- `t` switch the eye you're looking through between left and right
- `e` switch the video scaler
- `x` cycle vertical (portrait) crop: off -> 9:16 -> 2:3 -> 3:4 -> 1:1 -> off
- `g` toggle mouse smoothing
- `n` start / stop logging head motions to file (for later rendering)
- `?` display reminder of keyboard and mouse controls

Advanced projection controls:

90% of modern VR releases work perfectly with the defaults of 180 degree
'hequirect' projection so you shouldn't need these unless playing older or
unusually formatted content:

- `r` toggle stereo mode between top/bottom and side-by-side
- `b` cycle input fov bounds between 180, 360 and 90
- `1` cycle through input projections
- `2` cycle through output projections: flat -> sg -> pannini ->
  cylindrical (see "Zoom, FOV and distortion" below for the trade-offs)
- `p` cycle through 2D output modes including flat 2D, reprojected side by
  side and anaglyph modes

Most of the standard default mpv controls are maintained:

- `Arrow keys` seek through video
- `SPACE` pause
- `f` fullscreen toggle
- `9`,`0` or `/`,`*` volume up and down
- `m` mute
- `q` quit

You can configure the default keybindings in the `script-opts/360plugin.conf`
file, or override them in your `input.conf` file as usual.

# Zoom, FOV and distortion

Zooming (`=`/`-` or the mouse wheel) is a field-of-view change: it adjusts
the output `d_fov` (30-150 degrees), exactly like changing lens focal
length on a camera that never moves. There is no separate "move closer"
operation - the source is a video from a fixed camera position with no
depth information, so getting "closer" always means narrowing the FOV.

If people look warped, the distortion has two independent sources:

1. Projection distortion - tweakable. The default output projection is
   `flat` (rectilinear): straight lines stay straight, but radial
   stretching grows steeply with FOV, smearing objects near the frame
   edges. At the default `d_fov=110` this is visible; at 130+ it is
   severe; below about 70-80 it is nearly gone. Counterintuitively,
   zooming *in* reduces distortion and zooming *out* adds it, and a
   subject looks most natural centered, worst in a corner at wide FOV.
2. Baked-in capture distortion - not tweakable. VR content is shot with
   fisheye lenses at close range and mastered for headset viewing; a
   subject very close to the camera has real close-range perspective
   exaggeration recorded in the pixels, which no reprojection can undo.

To compensate for (1):

- Keep `d_fov` in the 70-100 range and keep the subject centered.
- Cycle the output projection with `2`:
  - `flat` (rectilinear) - straight architecture, worst for people at
    wide FOV.
  - `sg` (stereographic) - keeps face and body proportions natural even
    at wide FOV; straight lines bow outward (mild barrel look). Often the
    most "realistic" for people-centric framing.
  - `pannini` - the classic wide-angle compromise: verticals stay
    straight, much less edge stretching than `flat`, faces stay close to
    natural. A good default when both people and interiors are in frame.
  - `cylindrical` - no horizontal stretching at any FOV and verticals stay
    straight, but horizontal lines curve away from the center line. Best
    for very wide panoramic framing; people keep natural width but can
    look slightly compressed vertically off-center.

The active output projection is recorded into the export command, so a
section recorded in `sg` or `pannini` mode renders with the same look.
Note that mouse-look panning at wide FOV always shows some "swimming" at
the frame edges regardless of projection - that is inherent to
reprojecting a sphere onto a flat frame.

# Vertical (portrait) crop

Press `x` (configurable as `vertical_crop`) to crop the projected 2D view to
a portrait aspect - a centered cut of the normal 16:9 projection, useful for
producing vertical clips. The key cycles through the aspect list from
`vertical_aspects` in the config (default `9:16,2:3,3:4,1:1`) and back to
off. Recording honors the crop: sections recorded with a crop active export
as vertical video at 1080p height (9:16 -> 608x1080, 2:3 -> 720x1080,
3:4 -> 810x1080, 1:1 -> 1080x1080) - exactly the view you saw.

Notes:

- The export frame size is fixed when a recording section starts (video
  streams cannot change size mid-file), so changing the crop while a section
  is recording does not affect that section; press `n` twice to start a new
  section with the new crop.
- The crop only applies in the flat 2D output mode, not in the side-by-side
  or anaglyph output modes.
- When setting `vertical_aspects` on the mpv command line, note that commas
  separate script opts; use the config file for multiple aspects, or pass a
  single one, e.g. `--script-opts=...,360plugin-vertical_aspects=9:16`.

# Recording a session and rendering it to 2D with ffmpeg

The workflow to capture a "virtual camera" pass through a VR video and bake
it into a normal 2D clip:

1. Start the video with the plugin enabled (wrapper script, .bat/shortcut,
   or the `--script=...` command line above).
2. Frame your view (look around, zoom, pick the eye) and press `n` to start
   recording. An OSD timer shows `Recording:HH:MM:SS` while active.
3. Keep watching and moving the view; every head movement is logged with
   timestamps.
4. Press `n` again to stop the section (or just quit - the log is closed
   automatically on exit). You can press `n` repeatedly to record several
   independent sections of the same video.
5. Quit mpv. For each recorded section you get a motion log named
   `{videoFilename}_3dViewHistory_{N}.txt` - a list of timestamped ffmpeg
   `sendcmd` commands that replay your view animation - plus one combined
   conversion script:
   - `convert_3dViewHistory.sh` on Linux/macOS (already executable)
   - `convert_3dViewHistory.bat` on Windows
6. Run that script from the same directory to render the 2D clips:

   ```sh
   ./convert_3dViewHistory.sh        # Linux
   convert_3dViewHistory.bat         # Windows
   ```

   Each section renders (CRF 17, preset slower, 1920x1080) to
   `{videoFilename}_2d_{NNN}.mp4`.

The exact ffmpeg command for each section is also embedded as a comment at
the end of its motion log file, so you can tweak quality settings or re-run
sections individually.

Caveats:

- Run the conversion from the same directory where the logs were written
  (the ffmpeg command references the log file by relative name).
- Video filenames containing `'`, `:` or `,` will break the generated ffmpeg
  filter arguments; rename such files before recording.

# License

See [LICENSE](LICENSE). Original work by [dfaker](https://github.com/dfaker).
