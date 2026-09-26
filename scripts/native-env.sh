#!/bin/bash
# Sourced by build.sh and test.sh; all compatibility files are local to this project.
SHIXU_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SHIXU_ROOT"
mkdir -p .cache/native-modules .build/direct
SHIXU_SWIFTC="$(xcrun --find swiftc)"
SHIXU_ARCH="$(uname -m)"
export SHIXU_SWIFTC SHIXU_ROOT
python3 - <<'PY'
import os, json, re
from pathlib import Path
root = Path(os.environ['SHIXU_ROOT'])
include = Path(os.environ['SHIXU_SWIFTC']).parent.parent / 'include/swift'
legacy, modern = include/'module.modulemap', include/'bridging.modulemap'
roots=[]
if legacy.is_file() and modern.is_file() and 'module SwiftBridging' in legacy.read_text() and 'module SwiftBridging' in modern.read_text():
    local = root/'.cache/legacy-modules.modulemap'
    local.write_text(re.sub(r'module SwiftBridging\s*\{[^}]*\}', '', legacy.read_text()))
    roots.append({'type':'file','name':str(legacy),'external-contents':str(local)})
(root/'.cache/toolchain-overlay.json').write_text(json.dumps({'version':0,'case-sensitive':False,'roots':roots}))
PY
SHIXU_FLAGS=(-swift-version 5 -sdk "$(xcrun --show-sdk-path)" -module-cache-path "$SHIXU_ROOT/.cache/native-modules" -vfsoverlay "$SHIXU_ROOT/.cache/toolchain-overlay.json" -target "$SHIXU_ARCH-apple-macosx14.0")
"$SHIXU_SWIFTC" "${SHIXU_FLAGS[@]}" -O -parse-as-library -emit-library -static -emit-module -module-name DeskCore Sources/DeskCore/Workspace.swift -o .build/direct/libDeskCore.a -emit-module-path .build/direct/DeskCore.swiftmodule
