#!/usr/bin/env bash

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"

examples=(
  "examples/phase1_public_api.nim"
  "examples/bus_volume_demo.nim"
  "examples/music_fades.nim"
  "examples/sfx_keypress.nim"
)

example_name() {
  local path="$1"
  local base
  base="$(basename "$path")"
  printf '%s\n' "${base%.nim}"
}

require_cmd() {
  local cmd="$1"
  local hint="${2:-Install the required tool and ensure it is in PATH.}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found." >&2
    echo "  $hint" >&2
    exit 1
  fi
}

require_file() {
  local file="$1"
  local hint="${2:-Required file is missing.}"
  if [ ! -f "$file" ]; then
    echo "Error: missing $file." >&2
    echo "  $hint" >&2
    exit 1
  fi
}

nim_cfg_backup=""

restore_nim_cfg() {
  if [ -n "$nim_cfg_backup" ]; then
    cp "$nim_cfg_backup" "$repo_root/nim.cfg"
    rm -f "$nim_cfg_backup"
  else
    rm -f "$repo_root/nim.cfg"
  fi
}

install_platform_nim_cfg() {
  local platform_cfg="$1"
  require_file "$platform_cfg" "Platform cfgs are expected at the repository root."

  if [ -f "$repo_root/nim.cfg" ]; then
    nim_cfg_backup="$(mktemp -t play-nim-cfg.XXXXXX)"
    cp "$repo_root/nim.cfg" "$nim_cfg_backup"
  fi

  trap restore_nim_cfg EXIT HUP INT TERM
  cp "$platform_cfg" "$repo_root/nim.cfg"
}

replace_in_nim_cfg() {
  local needle="$1"
  local replacement="$2"
  local escaped_replacement
  local tmp
  escaped_replacement="$(printf '%s' "$replacement" | sed 's/[&|\\]/\\&/g')"
  tmp="$(mktemp -t play-nim-cfg-edit.XXXXXX)"
  sed "s|$needle|$escaped_replacement|g" "$repo_root/nim.cfg" > "$tmp"
  mv "$tmp" "$repo_root/nim.cfg"
}
