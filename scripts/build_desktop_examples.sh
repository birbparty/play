#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
usage: scripts/build_desktop_examples.sh [--smoke] [--audio]

Build all desktop examples. --smoke runs the headless null-backend path used by
CI. --audio requests the default non-null backend compiled for this host.
USAGE
}

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

run_smoke=0
run_audio=0

if [ "$#" -eq 0 ]; then
  run_smoke=1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --smoke)
      run_smoke=1
      ;;
    --audio)
      run_audio=1
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

build_example() {
  nim c --path:src --path:examples "$1"
}

run_example() {
  echo "$ $*"
  "$@"
}

build_example examples/phase1_public_api.nim
build_example examples/bus_volume_demo.nim
build_example examples/music_fades.nim
build_example examples/sfx_keypress.nim

if [ "$run_smoke" -eq 1 ]; then
  run_example examples/phase1_public_api
  run_example examples/bus_volume_demo --quiet
  run_example examples/music_fades --quiet
  run_example examples/sfx_keypress --keys=sq --quiet
fi

if [ "$run_audio" -eq 1 ]; then
  run_example examples/phase1_public_api
  run_example examples/bus_volume_demo --audio --quiet
  run_example examples/music_fades --audio --quiet
  run_example examples/sfx_keypress --audio --keys=sq --quiet
fi
