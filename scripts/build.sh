#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p build output
/usr/bin/swiftc -O -whole-module-optimization src/*.swift \
  -framework Foundation -framework AppKit -framework AVFoundation \
  -framework CoreGraphics -framework CoreVideo \
  -o build/impedance-video
printf 'Built %s/build/impedance-video\n' "$project_root"
