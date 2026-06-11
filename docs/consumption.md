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
