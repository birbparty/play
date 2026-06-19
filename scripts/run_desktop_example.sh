#!/usr/bin/env bash
set -euo pipefail

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
usage: scripts/run_desktop_example.sh [example] [options] [-- example-args...]

Build and run ONE desktop example on the host (macOS/Linux/Windows) through the
real default audio backend (miniaudio -> CoreAudio on macOS, ALSA/Pulse on
Linux, WASAPI on Windows) so you can actually hear it. This is the convenience
runner for the manual audible-verification tasks (e.g. play-apf on macOS).

Arguments:
  example         One of:
                    music_fades       (default) streamed OGG with fade in/out
                    bus_volume_demo   per-bus volume mix
                    sfx_keypress      one-shot SFX (auto-plays keys "sq")
                    phase1_public_api smoke only -- device-free by design (silent)

Options:
  --release       Build with -d:release (recommended for clean, glitch-free audio).
  --no-audio      Run the device-free path (null/nosound backend) instead of audio.
  --build-only    Compile the example but do not run it.
  -h, --help      Show this help.

Anything after a literal `--` is forwarded verbatim to the example and REPLACES
this script's default per-example arguments (e.g. to drive sfx_keypress
interactively: `... sfx_keypress -- --audio`).

What you should hear (fixtures are >=440Hz so handheld/laptop speakers reproduce
them; see tests/fixtures/generated/README.md):
  * music_fades / bus_volume_demo : a ~440 Hz musical tone, fading in and out.
  * sfx_keypress                  : short ~880 Hz blips, one per key.
If a real output device cannot be opened (headless / sandboxed shells, no audio
permission), the AUTO backend falls back to NoSound and the run is SILENT but
still exits 0 -- that is expected, not a failure. Run from a normal desktop
session to actually hear sound.

Examples:
  scripts/run_desktop_example.sh                       # music_fades, audible
  scripts/run_desktop_example.sh bus_volume_demo --release
  scripts/run_desktop_example.sh sfx_keypress          # auto-plays "sq"
  scripts/run_desktop_example.sh sfx_keypress -- --audio   # interactive keys
USAGE
}

cd "$repo_root"

example="music_fades"
release=0
build_only=0
no_audio=0
forwarded=()
have_forwarded=0

# Parse leading flags / example name until `--`, then collect forwarded args.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --)
      shift
      have_forwarded=1
      forwarded=("$@")
      break
      ;;
    --release)    release=1 ;;
    --no-audio)   no_audio=1 ;;
    --build-only) build_only=1 ;;
    -h|--help)    usage; exit 0 ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      example="$1"
      ;;
  esac
  shift
done

# Validate the example against the known desktop set.
case "$example" in
  music_fades|bus_volume_demo|sfx_keypress|phase1_public_api) ;;
  *)
    echo "unknown example: $example" >&2
    echo "valid: music_fades, bus_volume_demo, sfx_keypress, phase1_public_api" >&2
    exit 2
    ;;
esac

src="examples/${example}.nim"
require_file "$src" "Expected the example source at $src."
require_cmd nim "Install Nim 2.2.x (see .github/workflows/ci.yml for the pinned version)."

# Pick default per-example arguments so each run is audible AND non-blocking.
# phase1_public_api is always device-free; the others take --audio. sfx_keypress
# needs --keys to stay non-interactive (without it, --audio waits on getch()).
default_args=()
if [ "$have_forwarded" -eq 0 ]; then
  if [ "$no_audio" -eq 1 ]; then
    case "$example" in
      sfx_keypress) default_args=(--keys=sq) ;;   # default null backend, scripted keys
      *)            default_args=() ;;             # default config is already device-free
    esac
  else
    case "$example" in
      music_fades|bus_volume_demo) default_args=(--audio) ;;
      sfx_keypress)                default_args=(--audio --keys=sq) ;;
      phase1_public_api)           default_args=() ;;  # device-free by design
    esac
  fi
  run_args=("${default_args[@]}")
else
  run_args=("${forwarded[@]}")
fi

build_cmd=(nim c --path:src --path:examples)
[ "$release" -eq 1 ] && build_cmd+=(-d:release)
build_cmd+=("$src")

echo "==> Building $example"
echo "\$ ${build_cmd[*]}"
"${build_cmd[@]}"

if [ "$build_only" -eq 1 ]; then
  echo "==> Build only; not running."
  exit 0
fi

bin="examples/${example}"
require_file "$bin" "Build did not produce $bin."

if [ "$example" = "phase1_public_api" ] && [ "$no_audio" -eq 0 ]; then
  echo "note: phase1_public_api is device-free by design (nullBackend) -- it"
  echo "      validates the API headlessly and produces NO sound. Use"
  echo "      music_fades / bus_volume_demo / sfx_keypress to hear the backend."
fi

echo "==> Running $example"
if [ "${#run_args[@]}" -gt 0 ]; then
  echo "\$ $bin ${run_args[*]}"
  "$bin" "${run_args[@]}"
else
  echo "\$ $bin"
  "$bin"
fi
echo "==> $example exited 0"
