## Import-only module that proves the vendored SoLoud C API can compile through
## Nim's C backend. Binding and wrapper modules should import this before using
## symbols from `soloud_c.h`.

import play/private/soloud_sources

export soloud_sources
