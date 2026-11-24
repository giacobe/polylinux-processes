#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 BUILDROOT_OUTPUT" >&2
    echo "Example: $0 /home/nxg13/buildroot-builder2/work/build/basic" >&2
    exit 2
fi

BUILD_OUTPUT=$(cd -- "$1" && pwd)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

TARGET_CC=$(find "$BUILD_OUTPUT/host/bin" \
    -maxdepth 1 \
    -name '*-buildroot-linux-gnu-gcc' \
    -print \
    -quit)

if [ -z "$TARGET_CC" ] || [ ! -x "$TARGET_CC" ]; then
    echo "Target GCC wrapper not found under $BUILD_OUTPUT/host/bin." >&2
    exit 1
fi

if [ ! -x "$BUILD_OUTPUT/target/lib/ld-linux.so.2" ]; then
    echo "The selected Buildroot target lacks the 32-bit glibc loader." >&2
    exit 1
fi

echo "Cross-compiling with $TARGET_CC"

"$TARGET_CC" \
    -Os \
    -Wall \
    -Wextra \
    -o "$SCRIPT_DIR/process-helper" \
    "$SCRIPT_DIR/process-helper.c"

chmod 755 "$SCRIPT_DIR/process-helper"

file "$SCRIPT_DIR/process-helper"
echo "Wrote $SCRIPT_DIR/process-helper"
