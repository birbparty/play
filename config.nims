# Auto-loaded NimScript build logic.
#
# Keep desktop as the default target. Console toolchain settings live in
# nim_3ds.cfg and nim_vita.cfg; this file only records platform defines that
# should apply whenever a developer runs `nim c -d:ds3` or `nim c -d:vita`.

when defined(ds3):
  switch("define", "playPlatform3ds")
elif defined(vita):
  switch("define", "playPlatformVita")
else:
  switch("define", "playPlatformDesktop")
