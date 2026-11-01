#!/usr/bin/env bash
# Captures the screenshots of a manual from a running application.
#
# Usage: capture.sh <capture-command> <output-dir> [args...]
#
# <capture-command> is the product's own executable (or script) that renders
# the application and writes its screenshots as
#   <output-dir>/shots/<lang>/<name>.png   (referenced as ![caption](shot:name))
# for every language of the manual. It is called as
#   <capture-command> <output-dir> [args...]
# The kit knows nothing about the application: building the capture binary is
# the product's job. <output-dir> is normally <manual root>/assets.
# Environment: MANUAL_CAPTURE_QPA (set as QT_QPA_PLATFORM, default "offscreen",
# for Qt applications; ignored by others). Afterwards run build_manual.py.
set -euo pipefail
if [ "$#" -lt 2 ]; then
    sed -n '2,13p' "$0" >&2
    exit 2
fi
command="$1"
output="$2"
shift 2
mkdir -p "$output"
QT_QPA_PLATFORM="${MANUAL_CAPTURE_QPA:-offscreen}" "$command" "$output" "$@"
