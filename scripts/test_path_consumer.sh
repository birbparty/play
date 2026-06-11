#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_root="${TMPDIR:-/tmp}/play-path-consumer.$$"

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

  if grep -F -q "$tmp_root/consumer-host/vendor/soloud" "$log" ||
      grep -F -q "$tmp_root/consumer-console/vendor/soloud" "$log"; then
    cat "$log"
    echo "Consumer-local vendor/soloud was used unexpectedly" >&2
    exit 1
  fi

  if ! grep -q "$repo_root/vendor/soloud/src/c_api/soloud_c.cpp" "$log"; then
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
--path:"$repo_root/src"
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
    nim c --verbosity:1 --listCmd --nimcache:"$tmp_root/nimcache-host" \
      --path:"$repo_root/src" --mm:orc \
      --out:"$tmp_root/consumer-host/path_consumer" src/path_consumer.nim
)

"$tmp_root/consumer-host/path_consumer"

(
  cd "$tmp_root/consumer-console"
  run_and_check console-style \
    nim c --verbosity:1 --listCmd --nimcache:"$tmp_root/nimcache-console" \
      --out:"$tmp_root/consumer-console/console_style_consumer" \
      src/console_style_consumer.nim
)

"$tmp_root/consumer-console/console_style_consumer"
