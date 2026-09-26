#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/native-env.sh"
"$SHIXU_SWIFTC" "${SHIXU_FLAGS[@]}" -I .build/direct -L .build/direct -lDeskCore Tests/DeskCoreChecks/*.swift -o .build/direct/DeskCoreChecks
.build/direct/DeskCoreChecks
