#!/bin/bash

set -euo pipefail

APP="${1:?usage: try-hook.sh <app> <executable>}"
EXECUTABLE_NAME="${2:?missing executable name}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GCODE="$ROOT/build/sample-plate.gcode"

cp "$ROOT/Scripts/Fixtures/sample-plate.gcode" "$GCODE"
echo "==> Running $EXECUTABLE_NAME as Bambu Studio's post-processing script on $GCODE"
SLIC3R_PP_OUTPUT_NAME="Sample_plate_1.gcode.3mf" "$APP/Contents/MacOS/$EXECUTABLE_NAME" "$GCODE"

echo "==> Post-processed G-code start:"
head -n 20 "$GCODE"
