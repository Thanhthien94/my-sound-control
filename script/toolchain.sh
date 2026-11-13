#!/usr/bin/env bash
# Prefer existing CLT without changing system-wide xcode-select or accepting licenses.
if [[ -n "${MSC_DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR="$MSC_DEVELOPER_DIR"
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Library/Developer/CommandLineTools ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
MSC_SWIFT_ARGS=()
if [[ -n "${MSC_SDK_PATH:-}" ]]; then
  MSC_SWIFT_ARGS+=(--sdk "$MSC_SDK_PATH")
elif [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  # Installed CLT 27.2 SDK is missing its SwiftUI macro plugin. Same fallback as my-fan-control.
  MSC_SWIFT_ARGS+=(--sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk)
fi
