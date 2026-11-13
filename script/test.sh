#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source script/toolchain.sh
if [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools ]]; then
  MSC_SWIFT_ARGS+=(-Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib)
fi
swift test --disable-xctest --enable-swift-testing ${MSC_SWIFT_ARGS[@]+"${MSC_SWIFT_ARGS[@]}"}
