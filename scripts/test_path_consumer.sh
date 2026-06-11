#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_root="${TMPDIR:-/tmp}/play-path-consumer.$$"

nim_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}

exe_path() {
  if [ -x "$1" ]; then
    printf '%s\n' "$1"
  elif [ -x "$1.exe" ]; then
    printf '%s\n' "$1.exe"
  else
    return 1
  fi
}

grep_path() {
  local path
  path=$(nim_path "$1")
  grep -F -q "$path" "$2" || grep -F -q "${path//\//\\}" "$2"
}

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT INT TERM

run_and_check() {
  local name="$1"
  shift

  local log="$tmp_root/$name.log"
  if ! "$@" > "$log" 2>&1; then
    cat "$log"
    exit 1
  fi

  if grep -q "Error:" "$log"; then
    cat "$log"
    exit 1
  fi

  if grep_path "$tmp_root/consumer-host/vendor/soloud" "$log" ||
      grep_path "$tmp_root/consumer-console/vendor/soloud" "$log"; then
    cat "$log"
    echo "Consumer-local vendor/soloud was used unexpectedly" >&2
    exit 1
  fi

  if ! grep_path "$repo_root/vendor/soloud/src/c_api/soloud_c.cpp" "$log"; then
    cat "$log"
    echo "Expected play's vendored SoLoud source path in compiler output" >&2
    exit 1
  fi
}

rm -rf "$tmp_root"
mkdir -p \
  "$tmp_root/consumer-host/src" \
  "$tmp_root/consumer-host/vendor/soloud/src/c_api" \
  "$tmp_root/consumer-console/src" \
  "$tmp_root/consumer-console/vendor/soloud/src/c_api" \
  "$tmp_root/nimcache-host" \
  "$tmp_root/nimcache-console"

cp "$repo_root/tests/consumer_path/path_consumer.nim" "$tmp_root/consumer-host/src/path_consumer.nim"
cp "$repo_root/tests/consumer_path/console_style_consumer.nim" "$tmp_root/consumer-console/src/console_style_consumer.nim"

cat > "$tmp_root/consumer-host/vendor/soloud/src/c_api/soloud_c.cpp" <<'EOF'
#error play path consumer test must not compile consumer-local SoLoud sources
EOF
cat > "$tmp_root/consumer-console/vendor/soloud/src/c_api/soloud_c.cpp" <<'EOF'
#error play path consumer test must not compile consumer-local SoLoud sources
EOF

cat > "$tmp_root/consumer-console/nim.cfg" <<EOF
--path:"$(nim_path "$repo_root/src")"
--threads:off
--mm:arc
--define:useMalloc
--define:nimAllocPagesViaMalloc
--define:noSignalHandler
--opt:size
EOF

(
  cd "$tmp_root/consumer-host"
  run_and_check host \
    nim c --verbosity:1 --listCmd --nimcache:"$(nim_path "$tmp_root/nimcache-host")" \
      --path:"$(nim_path "$repo_root/src")" --mm:orc \
      --out:"$(nim_path "$tmp_root/consumer-host/path_consumer")" src/path_consumer.nim
)

host_binary=$(exe_path "$tmp_root/consumer-host/path_consumer")
"$host_binary"

(
  cd "$tmp_root/consumer-console"
  run_and_check console-style \
    nim c --verbosity:1 --listCmd --nimcache:"$(nim_path "$tmp_root/nimcache-console")" \
      --out:"$(nim_path "$tmp_root/consumer-console/console_style_consumer")" \
      src/console_style_consumer.nim
)

console_binary=$(exe_path "$tmp_root/consumer-console/console_style_consumer")
"$console_binary"
