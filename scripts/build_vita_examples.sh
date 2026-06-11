#!/usr/bin/env bash
set -euo pipefail

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
usage: scripts/build_vita_examples.sh [--out-dir DIR]

Build all examples for PS Vita with bare `nim c` and nim_vita.cfg.

Prerequisites:
  VITASDK defaults to /usr/local/vitasdk.
  nim, arm-vita-eabi-gcc, arm-vita-eabi-ar, vita-elf-create,
  vita-make-fself, vita-mksfoex, and zip must be in PATH.
USAGE
}

out_dir="build/vita"

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

export VITASDK="${VITASDK:-/usr/local/vitasdk}"
export PATH="$VITASDK/bin:$PATH"

if [ ! -d "$VITASDK" ]; then
  echo "Error: VITASDK does not exist at $VITASDK." >&2
  echo "  Install VitaSDK or set VITASDK to the installed SDK root." >&2
  exit 1
fi

require_cmd nim "Install Nim and ensure it is in PATH."
require_cmd arm-vita-eabi-gcc "Install VitaSDK and ensure $VITASDK/bin is in PATH."
require_cmd arm-vita-eabi-g++ "Install VitaSDK and ensure $VITASDK/bin is in PATH."
require_cmd arm-vita-eabi-ar "Install VitaSDK and ensure $VITASDK/bin is in PATH."
require_cmd vita-elf-create "Install VitaSDK and ensure $VITASDK/bin is in PATH."
require_cmd vita-make-fself "Install VitaSDK and ensure $VITASDK/bin is in PATH."
require_cmd vita-mksfoex "Install VitaSDK and ensure $VITASDK/bin is in PATH."
require_cmd zip "Install zip and ensure it is in PATH."

install_platform_nim_cfg "$repo_root/nim_vita.cfg"
replace_in_nim_cfg "/usr/local/vitasdk" "$VITASDK"
mkdir -p "$out_dir"

created_librt=0
cleanup_vita_stubs() {
  restore_nim_cfg
  if [ "$created_librt" -eq 1 ]; then
    rm -f "$repo_root/librt.a"
  fi
}
trap cleanup_vita_stubs EXIT HUP INT TERM

if [ -e "$repo_root/librt.a" ]; then
  echo "Error: refusing to overwrite existing $repo_root/librt.a." >&2
  echo "  Remove or move it before running the Vita example build." >&2
  exit 1
fi
arm-vita-eabi-ar rcs "$repo_root/librt.a"
created_librt=1

title_id_for() {
  local raw="$1"
  local prefix
  prefix="$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9' | cut -c1-5)"
  while [ "${#prefix}" -lt 5 ]; do
    prefix="${prefix}X"
  done
  printf '%s0001\n' "$prefix"
}

for example in "${examples[@]}"; do
  name="$(example_name "$example")"
  elf="$out_dir/$name"
  velf="$out_dir/$name.velf"
  eboot="$out_dir/$name-eboot.bin"
  sfo="$out_dir/$name-param.sfo"
  stage="$out_dir/$name-vpk-stage"
  title_id="$(title_id_for "$name")"
  vpk="$out_dir/$name.vpk"

  echo "Building $example -> $elf"
  nim c -d:vita --path:examples --out:"$elf" "$example"

  echo "Packaging $elf -> $vpk"
  vita-elf-create "$elf" "$velf"
  vita-make-fself "$velf" "$eboot"
  vita-mksfoex -s "TITLE_ID=$title_id" "$name" "$sfo"

  rm -rf "$stage"
  mkdir -p "$stage/sce_sys"
  mkdir -p "$stage/tests/fixtures"
  cp "$eboot" "$stage/eboot.bin"
  cp "$sfo" "$stage/sce_sys/param.sfo"
  cp -R "$repo_root/tests/fixtures/generated" "$stage/tests/fixtures/generated"
  rm -f "$vpk"
  ( cd "$stage" && zip -qr "../$name.vpk" . )
  rm -rf "$stage"
done
