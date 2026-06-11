#!/usr/bin/env bash
set -euo pipefail

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
usage: scripts/build_3ds_examples.sh [--out-dir DIR]

Build all examples for Nintendo 3DS with bare `nim c` and nim_3ds.cfg.

Prerequisites:
  DEVKITPRO must point at a devkitPro install, usually /opt/devkitpro.
  DEVKITARM defaults to $DEVKITPRO/devkitARM.
  nim, arm-none-eabi-gcc, arm-none-eabi-g++, arm-none-eabi-ar, and 3dsxtool
  must be in PATH.
USAGE
}

out_dir="build/3ds"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out-dir)
      if [ "$#" -lt 2 ]; then
        echo "Error: --out-dir requires a value." >&2
        exit 2
      fi
      out_dir="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$repo_root"

if [ -z "${DEVKITPRO:-}" ]; then
  echo "Error: DEVKITPRO is not set." >&2
  echo "  Set it to your devkitPro root, for example: export DEVKITPRO=/opt/devkitpro" >&2
  exit 1
fi

export DEVKITARM="${DEVKITARM:-$DEVKITPRO/devkitARM}"
export PATH="$DEVKITPRO/tools/bin:$DEVKITARM/bin:$PATH"

require_cmd nim "Install Nim and ensure it is in PATH."
require_cmd arm-none-eabi-gcc "Install devkitARM, set DEVKITPRO/DEVKITARM, and ensure the toolchain is in PATH."
require_cmd arm-none-eabi-g++ "Install devkitARM, set DEVKITPRO/DEVKITARM, and ensure the toolchain is in PATH."
require_cmd arm-none-eabi-ar "Install devkitARM, set DEVKITPRO/DEVKITARM, and ensure the toolchain is in PATH."
require_cmd 3dsxtool "Install devkitPro tools and ensure $DEVKITPRO/tools/bin is in PATH."

install_platform_nim_cfg "$repo_root/nim_3ds.cfg"
replace_in_nim_cfg "/opt/devkitpro/devkitARM" "$DEVKITARM"
replace_in_nim_cfg "/opt/devkitpro/libctru" "$DEVKITPRO/libctru"
scripts/ensure_3ds_link_stubs.sh
mkdir -p "$out_dir"
mkdir -p "$out_dir/sdroot/tests/fixtures"
rm -rf "$out_dir/sdroot/tests/fixtures/generated"
cp -R "$repo_root/tests/fixtures/generated" "$out_dir/sdroot/tests/fixtures/generated"

for example in "${examples[@]}"; do
  name="$(example_name "$example")"
  elf="$out_dir/$name.elf"
  three_dsx="$out_dir/$name.3dsx"
  echo "Building $example -> $elf"
  nim c -d:ds3 --path:examples --out:"$elf" "$example"
  echo "Packaging $elf -> $three_dsx"
  3dsxtool "$elf" "$three_dsx"
done
