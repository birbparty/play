# Thin Make bridge over the canonical Nimble tasks.
#
# Why this exists: the /ralph autonomous loop auto-detects a project's test
# command by build system (Go/Node/Python/Rust/Make). This is a Nim project, so
# without a Makefile ralph falls back to "verify manually" and loses its VERIFY
# gate. The `test` target maps ralph's `make test` onto the real suite defined
# in play.nimble (`task test`). Humans can use it too.

.PHONY: test build

# Canonical full suite (host + Vita/3DS nim check guards). See play.nimble.
test:
	nimble test

# Compile smoke for the SoLoud C/C++ closure against the generated C API.
build:
	nim c --path:src tests/test_soloud_compile.nim
