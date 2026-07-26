#!/usr/bin/env python3
"""Generate the deterministic AceleraChat public visual package."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BLUE = "#2563EB"
CYAN = "#06B6D4"
DARK = "#0F172A"
LIGHT = "#F8FAFC"
WHITE = "#FFFFFF"
RUBY = "#F43F5E"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    windows_font = Path("C:/Windows/Fonts/seguisb.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf")
    if windows_font.exists():
        return ImageFont.truetype(str(windows_font), size=size)
    return ImageFont.load_default(size=size)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    ensure_parent(path)
    path.write_text(content.strip() + "\n", encoding="utf-8", newline="\n")


def save_png(path: Path, image: Image.Image) -> None:
    ensure_parent(path)
    image.save(path, format="PNG", optimize=True)


def symbol_svg() -> str:
    return f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="title">
  <title id="title">AceleraChat</title>
  <path fill="{BLUE}" d="M72 64h296c44 0 80 36 80 80v176c0 44-36 80-80 80h-66l-91 65c-14 10-33 0-31-17l8-48H144c-44 0-80-36-80-80V144c0-44 36-80 80-80Z"/>
  <path fill="{WHITE}" d="M171 299c-9 0-15-10-10-18l79-134c7-12 25-12 32 0l78 134c5 8-1 18-10 18h-42l-40-72-43 72h-44Z"/>
  <path fill="{CYAN}" d="M128 192h62l-22 38h-62c-11 0-18-12-12-21l10-16c5-8 14-13 24-13v12Zm-24 73h64l-22 38H82c-11 0-18-12-12-21l10-16c5-8 14-13 24-13v12Z"/>
  <rect width="84" height="24" x="214" y="297" fill="{CYAN}" rx="12"/>
</svg>
"""


def logo_svg(dark: bool = False) -> str:
    word = WHITE if dark else DARK
    return f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 168" role="img" aria-labelledby="title">
  <title id="title">AceleraChat</title>
  <g transform="translate(8 4) scale(.3125)">{symbol_svg().split('>', 1)[1].rsplit('</svg>', 1)[0]}</g>
  <text x="184" y="108" fill="{word}" font-family="Inter, Segoe UI, Arial, sans-serif" font-size="70" font-weight="700" letter-spacing="-2">Acelera<tspan fill="{BLUE}">Chat</tspan></text>
</svg>
"""


def draw_symbol(size: int, background: str | None = None, badge: bool = False) -> Image.Image:
    scale = 4
    canvas = Image.new("RGBA", (size * scale, size * scale), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    s = size * scale
    pad = int(s * 0.09)
    bubble = (pad, pad, s - pad, int(s * 0.79))
    radius = int(s * 0.18)
    draw.rounded_rectangle(bubble, radius=radius, fill=BLUE)
    draw.polygon(
        [(int(s * 0.51), int(s * 0.76)), (int(s * 0.72), int(s * 0.93)), (int(s * 0.68), int(s * 0.70))],
        fill=BLUE,
    )
    draw.polygon(
        [
            (int(s * 0.34), int(s * 0.60)),
            (int(s * 0.49), int(s * 0.29)),
            (int(s * 0.65), int(s * 0.60)),
            (int(s * 0.57), int(s * 0.60)),
            (int(s * 0.49), int(s * 0.43)),
            (int(s * 0.41), int(s * 0.60)),
        ],
        fill=WHITE,
    )
    line_width = max(2, int(s * 0.035))
    draw.line((int(s * 0.18), int(s * 0.38), int(s * 0.34), int(s * 0.38)), fill=CYAN, width=line_width)
    draw.line((int(s * 0.14), int(s * 0.52), int(s * 0.31), int(s * 0.52)), fill=CYAN, width=line_width)
    draw.line((int(s * 0.42), int(s * 0.61), int(s * 0.57), int(s * 0.61)), fill=CYAN, width=line_width)
    if badge:
        badge_radius = int(s * 0.16)
        center = (s - badge_radius, badge_radius)
        draw.ellipse(
            (center[0] - badge_radius, center[1] - badge_radius, center[0] + badge_radius, center[1] + badge_radius),
            fill=RUBY,
            outline=WHITE,
            width=max(2, int(s * 0.025)),
        )
        dot = max(2, int(s * 0.035))
        draw.ellipse((center[0] - dot, center[1] - dot, center[0] + dot, center[1] + dot), fill=WHITE)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def draw_nemmo(size: int, dark: bool = False) -> Image.Image:
    scale = 3
    canvas = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    s = size * scale
    shell = DARK if dark else BLUE
    draw.ellipse((int(s * 0.08), int(s * 0.08), int(s * 0.92), int(s * 0.92)), fill=CYAN)
    draw.rounded_rectangle(
        (int(s * 0.18), int(s * 0.21), int(s * 0.82), int(s * 0.76)),
        radius=int(s * 0.17),
        fill=shell,
    )
    draw.polygon(
        [(int(s * 0.58), int(s * 0.72)), (int(s * 0.73), int(s * 0.88)), (int(s * 0.70), int(s * 0.69))],
        fill=shell,
    )
    eye = int(s * 0.055)
    for x in (0.39, 0.61):
        draw.ellipse((int(s * x) - eye, int(s * 0.46) - eye, int(s * x) + eye, int(s * 0.46) + eye), fill=WHITE)
        pupil = int(eye * 0.45)
        draw.ellipse((int(s * x) - pupil, int(s * 0.46) - pupil, int(s * x) + pupil, int(s * 0.46) + pupil), fill=CYAN)
    draw.arc((int(s * 0.38), int(s * 0.48), int(s * 0.62), int(s * 0.67)), start=15, end=165, fill=WHITE, width=max(2, int(s * 0.025)))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def illustration_svg(kind: str, dark: bool, popover: bool = False) -> str:
    bg = DARK if dark else LIGHT
    panel = "#1E293B" if dark else WHITE
    foreground = WHITE if dark else DARK
    icon = {
        "assistant": "M258 158c47 0 86 34 86 76s-39 76-86 76c-13 0-26-3-37-8l-50 31 12-51c-8-13-12-30-12-48 0-42 39-76 87-76Zm-33 65a12 12 0 1 0 0 24 12 12 0 0 0 0-24Zm66 0a12 12 0 1 0 0 24 12 12 0 0 0 0-24Z",
        "document": "M198 126h92l48 48v170H198V126Zm92 12v48h48M226 226h84M226 262h84M226 298h58",
        "faqs": "M256 135c57 0 103 37 103 83 0 47-46 84-103 84-13 0-27-2-39-6l-55 34 15-56c-15-15-24-35-24-56 0-46 46-83 103-83Zm0 119v12m-25-69c4-20 20-31 42-29 20 2 34 14 34 31 0 25-27 28-43 44",
    }[kind]
    stroke = f'fill="none" stroke="{foreground}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"' if kind != "assistant" else f'fill="{BLUE}"'
    panel_width = 360 if popover else 416
    panel_x = (512 - panel_width) // 2
    return f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="title">
  <title id="title">Nemmo {kind}</title>
  <rect width="512" height="512" rx="64" fill="{bg}"/>
  <rect x="{panel_x}" y="72" width="{panel_width}" height="368" rx="44" fill="{panel}" stroke="{CYAN}" stroke-opacity=".35" stroke-width="4"/>
  <circle cx="120" cy="116" r="32" fill="{BLUE}"/>
  <path d="M104 120h33l-10-18m10 18-10 18" fill="none" stroke="{WHITE}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="{icon}" {stroke}/>
  <rect x="160" y="374" width="192" height="18" rx="9" fill="{CYAN}" opacity=".65"/>
</svg>
"""


def generate_logos(files: list[Path]) -> None:
    targets = {
        ROOT / "public/brand-assets/acelerachat/logo.svg": logo_svg(False),
        ROOT / "public/brand-assets/acelerachat/logo-dark.svg": logo_svg(True),
        ROOT / "public/brand-assets/acelerachat/symbol.svg": symbol_svg(),
        ROOT / "app/javascript/widget/assets/images/acelerachat-symbol.svg": symbol_svg(),
        ROOT / "app/javascript/dashboard/assets/images/acelerachat-bubble-logo.svg": symbol_svg(),
        ROOT / "app/javascript/design-system/images/acelerachat-symbol.svg": symbol_svg(),
    }
    for path, content in targets.items():
        write_text(path, content)
        files.append(path)


def generate_pwa(files: list[Path]) -> None:
    base = ROOT / "public/brand-assets/acelerachat/pwa"
    families = {
        "favicon": [16, 32, 96, 512],
        "android-icon": [36, 48, 72, 96, 144, 192],
        "apple-icon": [57, 60, 72, 76, 114, 120, 144, 152, 180],
        "ms-icon": [70, 144, 150, 310],
    }
    for prefix, sizes in families.items():
        for size in sizes:
            path = base / f"{prefix}-{size}x{size}.png"
            save_png(path, draw_symbol(size, background=WHITE if prefix in {"apple-icon", "ms-icon"} else None))
            files.append(path)
    for size in [16, 32, 96]:
        path = base / f"favicon-badge-{size}x{size}.png"
        save_png(path, draw_symbol(size, badge=True))
        files.append(path)
    for name, size in {
        "apple-icon.png": 192,
        "apple-icon-precomposed.png": 192,
        "apple-touch-icon.png": 180,
        "apple-touch-icon-precomposed.png": 180,
    }.items():
        path = base / name
        save_png(path, draw_symbol(size, background=WHITE))
        files.append(path)


def generate_nemmo(files: list[Path]) -> None:
    dashboard_source = ROOT / "app/javascript/dashboard/assets/images/nemmo_bot.png"
    dashboard_public = ROOT / "public/assets/images/nemmo_bot.png"
    brand_avatar = ROOT / "public/brand-assets/acelerachat/nemmo-avatar.png"
    avatar = draw_nemmo(512)
    for path in (dashboard_source, dashboard_public, brand_avatar):
        save_png(path, avatar)
        files.append(path)

    base = ROOT / "public/assets/images/dashboard/nemmo"
    targets = {"logo.svg": symbol_svg()}
    for kind in ("assistant", "document", "faqs"):
        for mode in ("light", "dark"):
            targets[f"{kind}-{mode}.svg"] = illustration_svg(kind, mode == "dark")
            targets[f"{kind}-popover-{mode}.svg"] = illustration_svg(kind, mode == "dark", popover=True)
    for name, content in targets.items():
        path = base / name
        write_text(path, content)
        files.append(path)

    for dark in (False, True):
        path = ROOT / f"public/dashboard/images/integrations/nemmo{'-dark' if dark else ''}.png"
        canvas = Image.new("RGBA", (512, 512), DARK if dark else LIGHT)
        avatar = draw_nemmo(340, dark=dark)
        canvas.alpha_composite(avatar, (86, 48))
        draw = ImageDraw.Draw(canvas)
        label = "Nemmo"
        label_font = font(54, bold=True)
        bbox = draw.textbbox((0, 0), label, font=label_font)
        draw.text(((512 - (bbox[2] - bbox[0])) / 2, 405), label, font=label_font, fill=WHITE if dark else DARK)
        save_png(path, canvas)
        files.append(path)


def generate_design_system(files: list[Path]) -> None:
    for dark in (False, True):
        path = ROOT / f"app/javascript/design-system/images/acelerachat-logo{'-dark' if dark else ''}.png"
        canvas = Image.new("RGBA", (720, 180), DARK if dark else WHITE)
        canvas.alpha_composite(draw_symbol(128), (24, 26))
        draw = ImageDraw.Draw(canvas)
        draw.text((178, 42), "AceleraChat", font=font(54, bold=True), fill=WHITE if dark else DARK)
        draw.text((180, 108), "Design System", font=font(28), fill=CYAN if dark else BLUE)
        save_png(path, canvas)
        files.append(path)


def generate_public_metadata(files: list[Path]) -> None:
    base = ROOT / "public/brand-assets/acelerachat"
    manifest = {
        "name": "AceleraChat",
        "short_name": "AceleraChat",
        "start_url": "/app/",
        "display": "standalone",
        "background_color": LIGHT,
        "theme_color": BLUE,
        "icons": [
            {"src": "/brand-assets/acelerachat/pwa/android-icon-192x192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "/brand-assets/acelerachat/pwa/favicon-512x512.png", "sizes": "512x512", "type": "image/png"},
        ],
    }
    manifest_path = base / "manifest.json"
    write_text(manifest_path, json.dumps(manifest, ensure_ascii=False, indent=2))
    files.append(manifest_path)
    browserconfig = f"""
<?xml version="1.0" encoding="utf-8"?>
<browserconfig><msapplication><tile>
  <square70x70logo src="/brand-assets/acelerachat/pwa/ms-icon-70x70.png"/>
  <square150x150logo src="/brand-assets/acelerachat/pwa/ms-icon-150x150.png"/>
  <square310x310logo src="/brand-assets/acelerachat/pwa/ms-icon-310x310.png"/>
  <TileColor>{BLUE}</TileColor>
</tile></msapplication></browserconfig>
"""
    browser_path = base / "browserconfig.xml"
    write_text(browser_path, browserconfig)
    files.append(browser_path)

    og = Image.new("RGB", (1200, 630), LIGHT)
    draw = ImageDraw.Draw(og)
    draw.rounded_rectangle((55, 55, 1145, 575), radius=64, fill=WHITE, outline="#DBEAFE", width=4)
    og.paste(draw_symbol(260), (100, 180), draw_symbol(260))
    draw.text((405, 178), "AceleraChat", font=font(88, bold=True), fill=DARK)
    draw.text((410, 292), "Atendimento que ganha velocidade", font=font(42, bold=True), fill=BLUE)
    draw.text((410, 362), "Conversa, colaboração e automação em um só lugar.", font=font(30), fill="#475569")
    og_path = base / "open-graph.png"
    save_png(og_path, og)
    files.append(og_path)


def write_inventory(files: list[Path]) -> None:
    records = []
    for path in sorted(set(files)):
        payload = path.read_bytes()
        records.append(
            {
                "path": path.relative_to(ROOT).as_posix(),
                "bytes": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
        )
    inventory_path = ROOT / "public/brand-assets/acelerachat/assets.sha256.json"
    write_text(
        inventory_path,
        json.dumps(
            {
                "generator": "scripts/generate_acelerachat_assets.py",
                "audited_visual_assets": 55,
                "generated_files": records,
            },
            ensure_ascii=False,
            indent=2,
        ),
    )


def main() -> None:
    files: list[Path] = []
    generate_logos(files)
    generate_pwa(files)
    generate_nemmo(files)
    generate_design_system(files)
    generate_public_metadata(files)
    write_inventory(files)
    print(f"Generated {len(files)} AceleraChat files")


if __name__ == "__main__":
    main()
