#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
./scripts/build.sh
build/impedance-video prepare
build/impedance-video preview
build/impedance-video render
build/impedance-video verify
/usr/bin/ruby scripts/metadata.rb
/usr/bin/swiftc scripts/contact-sheet.swift -framework AppKit -o build/contact-sheet
build/contact-sheet
/usr/bin/sips -s format jpeg -s formatOptions 85 output/frames/scene-05.png --out output/poster.jpg >/dev/null
