#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_root="${TMPDIR:-/tmp}/play-consumer-smoke.$$"

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT INT TERM

rm -rf "$tmp_root"
mkdir -p "$tmp_root/path-consumer/src" "$tmp_root/installed-consumer/src"

cat > "$tmp_root/path-consumer/play_consumer_smoke.nimble" <<EOF
version = "0.1.0"
author = "play"
description = "Throwaway play consumer"
license = "Zlib"
srcDir = "src"
bin = @["play_consumer_smoke"]

requires "nim >= 2.0.0"
requires "file://$repo_root"
EOF

cat > "$tmp_root/path-consumer/src/play_consumer_smoke.nim" <<'EOF'
import play

discard init(initOptions(backend = nullBackend))
shutdown()
EOF

path_log="$tmp_root/path-consumer/build.log"
(
  cd "$tmp_root/path-consumer"
  nimble --nimbleDir:"$tmp_root/path-consumer/nimble" --noColor --verbose build -y
) > "$path_log" 2>&1

if grep -q "Error:" "$path_log"; then
  cat "$path_log"
  exit 1
fi

if [ ! -x "$tmp_root/path-consumer/play_consumer_smoke" ]; then
  cat "$path_log"
  echo "Expected path dependency consumer binary was not created" >&2
  exit 1
fi

"$tmp_root/path-consumer/play_consumer_smoke"

install_log="$tmp_root/install.log"
(
  cd "$repo_root"
  nimble --nimbleDir:"$tmp_root/installed-nimble" --noColor --verbose install -y
) > "$install_log" 2>&1

if grep -q "Error:" "$install_log"; then
  cat "$install_log"
  exit 1
fi

pkg_root=$(find "$tmp_root/installed-nimble/pkgs2" -maxdepth 1 -type d -name 'play-*' | head -n 1)

if [ "$pkg_root" = "" ]; then
  cat "$install_log"
  echo "Expected Nimble-installed play package was not created" >&2
  exit 1
fi

if [ ! -f "$pkg_root/play.nim" ] || [ ! -f "$pkg_root/play/private/soloud_sources.nim" ]; then
  find "$pkg_root" -maxdepth 3 -print
  echo "Expected Nimble-installed play sources were not copied" >&2
  exit 1
fi

if [ ! -f "$pkg_root/vendor/soloud/src/c_api/soloud_c.cpp" ]; then
  find "$pkg_root" -maxdepth 3 -print
  echo "Expected Nimble-installed vendored SoLoud sources were not copied" >&2
  exit 1
fi

cat > "$tmp_root/installed-consumer/src/play_consumer_smoke.nim" <<'EOF'
import play

discard init(initOptions(backend = nullBackend))
shutdown()
EOF

installed_log="$tmp_root/installed-consumer/build.log"
nim c --path:"$pkg_root" --out:"$tmp_root/installed-consumer/play_consumer_smoke" \
  "$tmp_root/installed-consumer/src/play_consumer_smoke.nim" > "$installed_log" 2>&1

if grep -q "Error:" "$installed_log"; then
  cat "$installed_log"
  exit 1
fi

if [ ! -x "$tmp_root/installed-consumer/play_consumer_smoke" ]; then
  cat "$installed_log"
  echo "Expected installed-layout consumer binary was not created" >&2
  exit 1
fi

"$tmp_root/installed-consumer/play_consumer_smoke"

if [ "${PLAY_CONSUMER_URL:-}" != "" ]; then
  mkdir -p "$tmp_root/url-consumer/src"
  cat > "$tmp_root/url-consumer/play_consumer_smoke.nimble" <<EOF
version = "0.1.0"
author = "play"
description = "Throwaway play consumer"
license = "Zlib"
srcDir = "src"
bin = @["play_consumer_smoke"]

requires "nim >= 2.0.0"
requires "$PLAY_CONSUMER_URL"
EOF

  cat > "$tmp_root/url-consumer/src/play_consumer_smoke.nim" <<'EOF'
import play

discard init(initOptions(backend = nullBackend))
shutdown()
EOF

  url_log="$tmp_root/url-consumer/build.log"
  (
    cd "$tmp_root/url-consumer"
    nimble --nimbleDir:"$tmp_root/url-consumer/nimble" --noColor --verbose build -y
  ) > "$url_log" 2>&1

  if grep -q "Error:" "$url_log"; then
    cat "$url_log"
    exit 1
  fi

  if [ ! -x "$tmp_root/url-consumer/play_consumer_smoke" ]; then
    cat "$url_log"
    echo "Expected URL dependency consumer binary was not created" >&2
    exit 1
  fi

  "$tmp_root/url-consumer/play_consumer_smoke"
fi
