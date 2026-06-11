# Link Stubs

3DS builds use `--os:linux` so Nim's devkitARM/newlib target can emit POSIX
library references such as `-ldl`, and future imports may emit `-lrt`.

Run `scripts/ensure_3ds_link_stubs.sh` before full 3DS links. It creates empty
GNU `ar` archives here:

- `libdl.a`
- `librt.a`

The archives are local build products and are ignored by git. Do not call
`dlopen`, `clock_gettime`, or related unavailable APIs at runtime on 3DS.
