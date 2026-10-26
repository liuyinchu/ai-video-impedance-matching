#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
./scripts/build.sh
build/impedance-video prepare
build/impedance-video preview
build/impedance-video render
build/impedance-video verify | tee output/verification.txt
/usr/bin/ruby scripts/metadata.rb
/usr/bin/swiftc scripts/contact-sheet.swift -framework AppKit -o build/contact-sheet
build/contact-sheet
/usr/bin/sips -s format jpeg -s formatOptions 85 output/frames/scene-05.png --out output/poster.jpg >/dev/null
LC_ALL=C /usr/bin/shasum -a 256 output/impedance-matching.mp4 output/impedance-matching.zh-CN.srt > output/SHA256SUMS
