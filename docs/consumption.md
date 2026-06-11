# Consuming play from Nimble

`play` can be used by an external Nim project through a Nimble URL pin:

```nim
requires "https://github.com/birbparty/play#<commit-sha>"
```

Local development can use a path dependency:

```nim
requires "file:///absolute/path/to/play"
```

Consumer code only imports the public facade:

```nim
import play

discard init(initOptions(backend = nullBackend))
shutdown()
```

The package installs its public import root and vendored SoLoud snapshot under
`play.nim`, `play/`, and `vendor/`. The binding source closure resolves SoLoud
from either the source-tree layout (`src/play/private`) or Nimble's installed
package layout (`play/private`). The consumer smoke test verifies a path
dependency and a real local Nimble install; a pushed commit can also be checked
with:

```sh
PLAY_CONSUMER_URL="https://github.com/birbparty/play#<commit-sha>" sh tests/consumer/verify_consumer.sh
```

The smoke script treats compiler output containing `Error:` or a missing
consumer binary as a failure because Nimble 0.22.2 can report a successful
process exit after some dependency graph or compiler failures.

## Consuming play with `--path`

Console-style build systems can also consume `play` without Nimble dependency
resolution by injecting the source directory into the consumer compile:

```sh
nim c --path:/absolute/path/to/play/src src/my_game.nim
```

The consumer code still imports only the public facade:

```nim
import play

discard init(initOptions(backend = nullBackend))
shutdown()
```

For clckr-style console builds, put the injected path and platform runtime
settings in the consumer's target config:

```text
--path:"/absolute/path/to/play/src"
--threads:off
--mm:arc
--define:useMalloc
--define:nimAllocPagesViaMalloc
--define:noSignalHandler
--opt:size
```

The vendored SoLoud source closure is still resolved from `play`'s own source
location, not from the consumer working directory. `scripts/test_path_consumer.sh`
verifies that a bare consumer outside this repository can compile through
`nim c` with only `--path` injection, including a console-style config profile,
and that compiler output uses `play/vendor/soloud/...` even when the consumer
contains its own `vendor/soloud` directory.
