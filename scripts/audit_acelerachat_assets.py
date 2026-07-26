#!/usr/bin/env python3
"""Validate AceleraChat assets, dimensions, alpha, SVGs, manifests, and contrast."""

from __future__ import annotations

import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "public/brand-assets/acelerachat"
INVENTORY = ASSET_ROOT / "assets.sha256.json"
SIZE_PATTERN = re.compile(r"-(\d+)x(\d+)\.png$")


def relative_luminance(hex_color: str) -> float:
    channels = [int(hex_color[index : index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(first: str, second: str) -> float:
    high, low = sorted((relative_luminance(first), relative_luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def main() -> None:
    manifest = json.loads(INVENTORY.read_text(encoding="utf-8"))
    errors: list[str] = []
    png_count = 0
    svg_count = 0

    for record in manifest["generated_files"]:
        path = ROOT / record["path"]
        if not path.is_file() or path.stat().st_size == 0:
            errors.append(f"missing-or-empty:{record['path']}")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != record["sha256"]:
            errors.append(f"digest:{record['path']}")
        if path.suffix == ".svg":
            svg_count += 1
            try:
                root = ET.parse(path).getroot()
                if "viewBox" not in root.attrib:
                    errors.append(f"svg-viewbox:{record['path']}")
            except ET.ParseError:
                errors.append(f"svg-invalid:{record['path']}")
        elif path.suffix == ".png":
            png_count += 1
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                match = SIZE_PATTERN.search(path.name)
                if match and image.size != (int(match.group(1)), int(match.group(2))):
                    errors.append(f"dimension:{record['path']}:{image.size}")
                if "favicon" in path.name and "badge" not in path.name and image.mode != "RGBA":
                    errors.append(f"alpha:{record['path']}:{image.mode}")

    public_manifest = json.loads((ASSET_ROOT / "manifest.json").read_text(encoding="utf-8"))
    if public_manifest.get("name") != "AceleraChat" or public_manifest.get("theme_color") != "#2563EB":
        errors.append("manifest-brand")
    for icon in public_manifest.get("icons", []):
        icon_path = ROOT / "public" / icon["src"].lstrip("/")
        if not icon_path.is_file():
            errors.append(f"manifest-icon:{icon['src']}")

    contrast_checks = {
        "blue-on-white": contrast("#2563EB", "#FFFFFF"),
        "light-on-dark": contrast("#F8FAFC", "#0F172A"),
        "cyan-on-dark": contrast("#06B6D4", "#0F172A"),
    }
    errors.extend(f"contrast:{name}:{ratio:.2f}" for name, ratio in contrast_checks.items() if ratio < 4.5)

    result = {
        "audited_visual_assets": manifest["audited_visual_assets"],
        "generated_files": len(manifest["generated_files"]),
        "png_files": png_count,
        "svg_files": svg_count,
        "contrast": {key: round(value, 2) for key, value in contrast_checks.items()},
        "errors": errors,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(1 if errors else 0)


if __name__ == "__main__":
    main()
