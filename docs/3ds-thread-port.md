# SoLoud 3DS Thread Port

`vendor/soloud/` includes the birbparty SoLoud fork commit
`412011ec5c950ebf85f717b57722bb9298329686`, pushed on branch
`feat/3ds-support`.

That fork line includes the earlier thread-port commit, which adds a `__3DS__`
branch to `src/core/soloud_thread.cpp` so SoLoud's core thread and mutex helpers
no longer fall through to pthreads when building with devkitARM/libctru.

## Implemented Mapping

- `createMutex`, `lockMutex`, and `unlockMutex` use libctru `LightLock`.
- `destroyMutex` deletes the allocated `LightLock`; libctru light locks do not
  expose a separate destroy call.
- `createThread` uses `threadCreate` with a 32 KiB stack, priority `0x30`,
  default core `-2`, and attached lifetime management.
- `wait` uses `threadJoin(..., U64_MAX)`.
- `release` uses `threadFree` after the joined thread is no longer needed.
- `sleep` uses `svcSleepThread` with millisecond-to-nanosecond conversion.
- `getTimeMillis` uses `osGetTime`.

## Verification

The fork source was compiled directly on the host path:

```sh
c++ -Iinclude -c src/core/soloud_thread.cpp -o /tmp/soloud_thread_host.o
```

The 3DS branch was compiled with devkitARM and libctru headers:

```sh
/opt/devkitpro/devkitARM/bin/arm-none-eabi-g++ \
  -D__3DS__ \
  -Iinclude \
  -I/opt/devkitpro/libctru/include \
  -c src/core/soloud_thread.cpp \
  -o /tmp/soloud_thread_3ds.o
```

The vendored snapshot was refreshed from the fork with `git archive`, and the
fork tracked-file list was compared against `vendor/soloud/`.
