#!/usr/bin/env python3
"""Prepare checked-in macOS raster assets from an inspected square source (Pillow)."""
import argparse
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw


def prepare(source: Path, destination: Path) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if source == destination / "AppIcon.png":
        raise ValueError("Use the preserved generation source, not the derived app icon")
    with Image.open(source) as image:
        if image.width != image.height:
            raise ValueError("Expected a square source; do not silently crop artwork")
        artwork = image.convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)

    # Standardized sibling-app tile geometry: 896 px tile, 64 px transparent padding.
    # Flatten partially transparent AI pixels over the intended black interior, then
    # apply a clean supersampled geometric alpha mask to remove exterior speckling.
    flattened = Image.alpha_composite(Image.new("RGBA", artwork.size, "#030303"), artwork)
    scale = 4
    mask = Image.new("L", (1024 * scale, 1024 * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (64 * scale, 64 * scale, 960 * scale - 1, 960 * scale - 1),
        radius=190 * scale,
        fill=255,
    )
    mask = mask.resize((1024, 1024), Image.Resampling.LANCZOS)
    flattened.putalpha(mask)
    destination.mkdir(parents=True, exist_ok=True)
    flattened.save(destination / "AppIcon.png")
    flattened.resize((512, 512), Image.Resampling.LANCZOS).save(destination / "logo-preview.png")

    iconset = destination / "AppIcon.iconset"
    iconset.mkdir(exist_ok=True)
    for size in (16, 32, 128, 256, 512):
        for multiplier in (1, 2):
            suffix = "@2x" if multiplier == 2 else ""
            name = f"icon_{size}x{size}{suffix}.png"
            flattened.resize((size * multiplier, size * multiplier), Image.Resampling.LANCZOS).save(iconset / name)
    subprocess.run(["/usr/bin/iconutil", "-c", "icns", str(iconset), "-o", str(destination / "AppIcon.icns")], check=True)

    preview = Image.new("RGB", (1040, 460), "#202020")
    draw = ImageDraw.Draw(preview)
    draw.text((24, 16), "MY SOUND CONTROL  /  SkyTruong palette", fill="#eeeeee", font_size=21)
    x = 22
    for size in (256, 128, 64, 32, 16):
        y = 64 + (256 - size) // 2
        preview.paste(flattened.resize((size, size), Image.Resampling.LANCZOS), (x, y),
                      flattened.resize((size, size), Image.Resampling.LANCZOS))
        draw.text((x + 4, 336), f"{size}px", fill="#b0b0b0", font_size=16)
        x += size + 45
    # Confirm transparent padding on a light surface as well.
    draw.rounded_rectangle((826, 58, 1016, 362), radius=18, fill="#eeeeee")
    small = flattened.resize((168, 168), Image.Resampling.LANCZOS)
    preview.paste(small, (837, 112), small)
    colors = [("#FF5A00", "Orange"), ("#FFC400", "Gold"), ("#80F23E", "Green"), ("#030303", "Black")]
    for index, (color, title) in enumerate(colors):
        bx = 28 + index * 196
        draw.rounded_rectangle((bx, 390, bx + 28, 418), radius=5, fill=color)
        draw.text((bx + 40, 393), f"{title} {color}", fill="#cccccc", font_size=14)
    preview.save(destination / "icon-preview.png")
    print(f"Prepared AppIcon.png 1024×1024 RGBA, logo-preview.png 512×512, iconset and AppIcon.icns in {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent.parent / "assets" / "brand")
    options = parser.parse_args()
    prepare(options.source, options.output)
