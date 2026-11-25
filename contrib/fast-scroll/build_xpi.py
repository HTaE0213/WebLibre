#!/usr/bin/env python3
"""Produce a deterministic, unsigned Firefox/Gecko WebExtension XPI."""
from __future__ import annotations

import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parent
SOURCES = ("manifest.json", "background.js", "content.js")


def build() -> Path:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    if manifest["manifest_version"] != 2:
        raise ValueError("Expected MV2 manifest for GeckoView compatibility")
    if manifest["browser_specific_settings"]["gecko"]["id"] != "weblibre-fast-scroll@local":
        raise ValueError("Gecko extension ID unexpectedly changed")
    if manifest["background"]["scripts"] != ["background.js"]:
        raise ValueError("Background script list unexpectedly changed")
    if manifest["content_scripts"][0]["js"] != ["content.js"]:
        raise ValueError("Content script list unexpectedly changed")

    output = ROOT / "dist" / f"weblibre-fast-scroll-{manifest['version']}.xpi"
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name in SOURCES:
            entry = ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            archive.writestr(entry, (ROOT / name).read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
    with ZipFile(output) as archive:
        if archive.namelist() != list(SOURCES):
            raise ValueError("Unexpected files in XPI")
        if archive.testzip() is not None:
            raise ValueError("XPI contains a corrupt entry")
    return output


if __name__ == "__main__":
    print(build())
