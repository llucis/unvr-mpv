# Creates a Desktop shortcut "VR Reversal.lnk" pointing to vr-reversal.bat.
# Videos can then be dragged and dropped onto the shortcut to play them with
# the 360plugin enabled.
#
# Run from this repo's directory:
#   powershell -ExecutionPolicy Bypass -File create-windows-shortcut.ps1
#
# A .lnk cannot be committed to the repo because it embeds absolute paths;
# this script generates it for the local machine instead.

$ErrorActionPreference = 'Stop'

$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target  = Join-Path $repoDir 'vr-reversal.bat'
if (-not (Test-Path $target)) {
    throw "vr-reversal.bat not found next to this script ($target)"
}

$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'VR Reversal.lnk'

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($lnkPath)
$lnk.TargetPath = $target
$lnk.WorkingDirectory = $repoDir
$lnk.Description = 'Play VR video as 2D with mpv + 360plugin (drop videos here)'
# Use the mpv icon if mpv.exe is in the repo directory
$mpvExe = Join-Path $repoDir 'mpv.exe'
if (Test-Path $mpvExe) { $lnk.IconLocation = "$mpvExe,0" }
$lnk.Save()

Write-Host "Created shortcut: $lnkPath"
Write-Host "Drag and drop video files onto it to start a session."
