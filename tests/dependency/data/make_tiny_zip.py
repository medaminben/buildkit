#!/usr/bin/env python3
"""Regenerates tiny.zip byte for byte (fixed timestamp, mode and order).

tiny.zip is the FETCH_URL fixture of tests/dependency/fetch_url: one
CMakeLists.txt in a top-level folder that defines the INTERFACE target `tiny`.
Run: python3 make_tiny_zip.py   (writes tiny.zip next to this script)
"""
import pathlib
import zipfile

CMAKELISTS = """\
cmake_minimum_required(VERSION 3.29)
project(tiny LANGUAGES NONE)
add_library(tiny INTERFACE)
if(TINY_FLAG)
    set(TINY_SAW_FLAG ON CACHE INTERNAL "set when FETCH_CACHE reached this project")
endif()
"""

out = pathlib.Path(__file__).with_name("tiny.zip")
info = zipfile.ZipInfo("tiny/CMakeLists.txt", date_time=(2026, 1, 1, 0, 0, 0))
info.external_attr = 0o644 << 16
info.compress_type = zipfile.ZIP_DEFLATED
with zipfile.ZipFile(out, "w") as z:
    z.writestr(info, CMAKELISTS)
