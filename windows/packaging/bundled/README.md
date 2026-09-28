# Bundled binaries

This folder must contain the following files when compiling `yora_setup.iss`:

- `yt-dlp.exe`
- `ffmpeg.exe`
- `ffprobe.exe`
- `FFMPEG_LICENSE.txt`
- `vc_redist.x64.exe`

They are not tracked by Git (too large, about 295 MB in total). Download them again when needed:

## yt-dlp.exe

Latest stable release, standalone Windows build:
https://github.com/yt-dlp/yt-dlp/releases/latest → asset `yt-dlp.exe`

```
curl -L -o yt-dlp.exe "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
```

## ffmpeg.exe / ffprobe.exe

Static LGPL Windows build (BtbN/FFmpeg-Builds):
https://github.com/BtbN/FFmpeg-Builds/releases → an asset named
`ffmpeg-n*-latest-win64-lgpl-*.zip` (not `-shared`, not `-gpl`).

Take only `bin/ffmpeg.exe`, `bin/ffprobe.exe` and `LICENSE.txt` (rename it to `FFMPEG_LICENSE.txt`).

## vc_redist.x64.exe

Official Microsoft Visual C++ Redistributable (x64), required by `yora.exe`:

```
curl -L -o vc_redist.x64.exe "https://aka.ms/vs/17/release/vc_redist.x64.exe"
```
