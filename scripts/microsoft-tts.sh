#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p build
if [[ ! -x build/microsoft-tts || scripts/microsoft-tts.swift -nt build/microsoft-tts ]]; then
 /usr/bin/swiftc -O -parse-as-library scripts/microsoft-tts.swift -framework Foundation -framework AVFoundation -o build/microsoft-tts
fi
exec build/microsoft-tts "$@"
