#!/usr/bin/env sh
set -eu

# Nim uses --os:linux for the devkitARM/newlib target, which can add POSIX
# libraries that 3DS does not provide. These empty archives satisfy the linker;
# code must not call dlopen, clock_gettime, or related unavailable APIs on 3DS.

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
stub_dir="$repo_root/stubs"
ar_tool="${DEVKITARM:-/opt/devkitpro/devkitARM}/bin/arm-none-eabi-ar"

if [ ! -x "$ar_tool" ]; then
  if command -v arm-none-eabi-ar >/dev/null 2>&1; then
    ar_tool=$(command -v arm-none-eabi-ar)
  else
    echo "arm-none-eabi-ar not found; set DEVKITARM or install devkitARM" >&2
    exit 1
  fi
fi

mkdir -p "$stub_dir"
"$ar_tool" rcs "$stub_dir/libdl.a"
"$ar_tool" rcs "$stub_dir/librt.a"
