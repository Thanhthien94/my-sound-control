# My Sound Control icon

An original waveform and fader mark using the SkyTruong palette, visually related
to the dark tile and sculpted forms of My Fan Control. Five orange/gold bars
represent audio; the green center fader represents control. The artwork has no
lettering so it remains recognizable at small sizes.

Palette references: orange `#FF5A00`, gold `#FFC400`, fresh green `#80F23E`,
black `#030303`, white `#FFFFFF`. Gradients and highlights introduce additional
shades; these are reference colors, not a claim that every pixel matches a token.

## Assets

- `AppIcon.png`: 1024 × 1024 RGBA with transparent padding.
- `AppIcon.icns`: macOS icon bundle used by the app packaging script.
- `AppIcon.iconset/`: ten standard macOS PNG representations, 16–1024 pixels.
- `logo-preview.png`: 512 × 512 transparent preview.
- `icon-preview.png`: size and light/dark background review board.

This is raster artwork, not a vector master. The source was generated with the
SkyTruong Responses image tool on 2026-11-13 using the configured main model,
with the SkyTruong symbol and My Fan Control icon as palette/style references.
The generated 1254 × 1254 source was visually inspected, then resized and given
a clean rounded-tile alpha mask locally. Generated originals and metadata are
retained locally and excluded from Git. This version has not yet been approved
by the user.

To prepare exports from a preserved source on macOS (Python with Pillow):

```sh
python3 script/prepare_icon.py /path/to/preserved-square-source.png
```

Normal app builds use the checked-in ICNS and do not require Python or Pillow.
