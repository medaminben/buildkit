#!/usr/bin/env python3
"""Regenerates tiny.zip byte for byte (fixed timestamp, mode and order).

tiny.zip is the FETCH_URL fixture of tests/dependency/fetch_url: one
CMakeLists.txt in a top-level folder that defines the INTERFACE target `tiny`.
Its content is tiny-src/CMakeLists.txt (also used unzipped by the
source_dir_override fixture).
Run: python3 make_tiny_zip.py   (writes tiny.zip next to this script)
"""
import pathlib
import zipfile


here = pathlib.Path(__file__).parent
out = here / "tiny.zip"
cmakelists = (here / "tiny-src" / "CMakeLists.txt").read_bytes()
info = zipfile.ZipInfo("tiny/CMakeLists.txt", date_time=(2026, 1, 1, 0, 0, 0))
info.external_attr = 0o644 << 16
info.compress_type = zipfile.ZIP_DEFLATED
with zipfile.ZipFile(out, "w") as z:
    z.writestr(info, cmakelists)
