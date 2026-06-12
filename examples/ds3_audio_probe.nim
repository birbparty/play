## Nintendo 3DS hardware diagnostic probe.
##
## The standard examples are short headless smoke programs: on hardware they
## show a black screen briefly and exit even when they succeed (confirmed on
## PS Vita via examples/vita_audio_probe.nim). This probe is the observable
## replacement for 3DS hardware verification. It:
##
## - prints live status text to the top screen via the libctru console,
## - writes a flushed line-by-line log to `sdmc:/play-3ds-probe.log`,
## - plays a repeated SFX beep pattern and several seconds of streamed music,
## - holds the screen long enough to read the final state before exiting
##   (START skips the current hold early).
##
## Every phase and failure is announced as a console banner, so a hardware
## tester only needs to read the top screen and report the last banner plus
## whether beeps and music were audible. If the screen shows nothing at all,
## the app died before console init; check whether the log file was created.
##
## On non-3DS hosts the console procs are no-ops and the default config uses
## the null backend with zero holds, so the shared logic stays testable in the
## regular host suite.

import std/[monotimes, os, strutils, times]

import play
import common/assets

when defined(playPlatform3ds):
  const
    gfxTopScreen = 0'i32 # gfxScreen_t GFX_TOP
    keyStart = 0x8'u32   # KEY_START (BIT(3))

  proc gfxInitDefault() {.importc, header: "<3ds.h>".}
  proc gfxExit() {.importc, header: "<3ds.h>".}
  proc consoleInit(
    screen: cint, console: pointer
  ): pointer {.importc, header: "<3ds.h>".}
  proc gfxFlushBuffers() {.importc, header: "<3ds.h>".}
  proc gfxSwapBuffers() {.importc, header: "<3ds.h>".}
  proc gspWaitForVBlank() {.importc, header: "<3ds.h>".}
  proc aptMainLoop(): bool {.importc, header: "<3ds.h>".}
  proc hidScanInput() {.importc, header: "<3ds.h>".}
  proc hidKeysDown(): cuint {.importc, header: "<3ds.h>".}

  var consoleReady = false

  proc probeDisplayInit(): bool =
    if not consoleReady:
      gfxInitDefault()
      discard consoleInit(gfxTopScreen, nil)
      consoleReady = true
    consoleReady

  proc probeDisplayShutdown() =
    if consoleReady:
      gfxExit()
      consoleReady = false

  proc probeHold(durationMs: int): bool =
    ## Pumps frames at ~60 Hz so the app stays responsive while holding.
    ## START skips the current hold. Returns false when the OS asked the app
    ## to quit (HOME menu close), so callers can abort the remaining phases.
    result = true
    var remainingMs = durationMs
    while remainingMs > 0:
      if not aptMainLoop():
        return false
      hidScanInput()
      if (hidKeysDown() and keyStart) != 0'u32:
        return true
      gfxFlushBuffers()
      gfxSwapBuffers()
      gspWaitForVBlank()
      remainingMs -= 17
else:
  proc probeDisplayInit(): bool = false
  proc probeDisplayShutdown() = discard
  proc probeHold(durationMs: int): bool =
    if durationMs > 0:
      sleep(durationMs)
    true

type
  ProbeConfig* = object
    options*: InitOptions
    logPath*: string
    beepCount*: int
    beepMs*: int
    beepGapMs*: int
    musicMs*: int
    successHoldMs*: int
    failureHoldMs*: int
    verbose*: bool

  ProbeResult* = object
    ok*: bool
    displayReady*: bool
    logOpened*: bool
    initOk*: bool
    sfxLoaded*: bool
    musicLoaded*: bool
    sfxPlayed*: bool
    musicPlayed*: bool
    failure*: string

  ProbeContext = object
    config: ProbeConfig
    logFile: File
    logOpen: bool
    startTime: MonoTime
    clockOk: bool
    aborted: bool

proc defaultProbeConfig*(): ProbeConfig =
  when defined(playPlatform3ds):
    ProbeConfig(
      options: initOptions(),
      logPath: "sdmc:/play-3ds-probe.log",
      beepCount: 5,
      beepMs: 250,
      beepGapMs: 750,
      musicMs: 8000,
      successHoldMs: 10000,
      failureHoldMs: 20000,
      verbose: true
    )
  else:
    ProbeConfig(
      options: initOptions(backend = nullBackend),
      logPath: getTempDir() / "play-3ds-probe.log",
      beepCount: 2,
      beepMs: 0,
      beepGapMs: 0,
      musicMs: 0,
      successHoldMs: 0,
      failureHoldMs: 0,
      verbose: false
    )

proc elapsedMs(ctx: ProbeContext): int64 =
  if not ctx.clockOk:
    return -1
  try:
    (getMonoTime() - ctx.startTime).inMilliseconds
  except CatchableError:
    -1

proc log(ctx: var ProbeContext, message: string) =
  let line = "[" & $ctx.elapsedMs() & "ms] " & message
  if ctx.config.verbose:
    try:
      echo line
    except CatchableError:
      discard
  if ctx.logOpen:
    try:
      ctx.logFile.writeLine(line)
      ctx.logFile.flushFile()
    except CatchableError:
      ctx.logOpen = false

proc banner(ctx: var ProbeContext, state: string) =
  ctx.log("==== " & state & " ====")

proc pause(ctx: var ProbeContext, durationMs: int) =
  if not ctx.aborted:
    ctx.aborted = not probeHold(durationMs)

proc fail(
  ctx: var ProbeContext,
  probe: var ProbeResult,
  state: string,
  message: string
) =
  probe.failure = message
  ctx.log("FAIL: " & message)
  ctx.banner(state & " - holding " & $ctx.config.failureHoldMs &
    "ms, press START to exit")
  discard probeHold(ctx.config.failureHoldMs)

proc assetCandidates(asset: ExampleAsset): seq[string] =
  when defined(playPlatform3ds):
    # Listed explicitly instead of via exampleAssetPath so the log records
    # every probed location, including the sdmc:/examples/assets/ primary
    # that exampleAssetPath silently falls through when absent.
    let name = extractFilename(exampleAssetPath(asset))
    result = @[
      exampleAssetRoot / name,
      fixtureAssetRoot / name,
      "tests/fixtures/generated/" & name
    ]
  else:
    result = @[exampleAssetPath(asset)]

proc resolveProbeAsset(ctx: var ProbeContext, asset: ExampleAsset): string =
  ## Logs every candidate path and returns the first one that exists, so a
  ## missing SD-root fixture copy is recorded but does not hide which paths
  ## were tried. Falls back to the default helper path.
  let candidates = assetCandidates(asset)
  result = exampleAssetPath(asset)
  var chosen = false
  for path in candidates:
    var exists = false
    try:
      exists = fileExists(path)
    except CatchableError:
      ctx.log("asset candidate: " & path & " exists=<error>")
      continue
    ctx.log("asset candidate: " & path & " exists=" & $exists)
    if exists and not chosen:
      result = path
      chosen = true
  ctx.log("asset selected: " & result)

proc runDs3AudioProbe*(config = defaultProbeConfig()): ProbeResult =
  var ctx = ProbeContext(config: config)
  try:
    ctx.startTime = getMonoTime()
    ctx.clockOk = true
  except CatchableError:
    ctx.clockOk = false

  result.displayReady = probeDisplayInit()

  if config.logPath.len > 0:
    try:
      ctx.logFile = open(config.logPath, fmWrite)
      ctx.logOpen = true
    except CatchableError:
      ctx.logOpen = false
  result.logOpened = ctx.logOpen

  ctx.banner("PLAY 3DS AUDIO PROBE")
  ctx.log("play version " & playVersion)
  ctx.log("console ready: " & $result.displayReady)
  ctx.log("log path: " & config.logPath &
    (if ctx.logOpen: " (open)" else: " (COULD NOT OPEN)"))
  ctx.log("requested backend id " & $cuint(config.options.backend))

  var
    sfx = SoundResult()
    music = MusicResult()
    sfxHandle = noHandle
    musicHandle = noHandle

  try:
    ctx.log("calling init (needs sdmc:/3ds/dspfirm.cdc for NDSP)")
    let initResult = init(config.options)
    if not initResult.ok:
      ctx.fail(result, "INIT FAILED",
        "init failed: " & initResult.error.message &
        " (code " & $initResult.error.code &
        "); is sdmc:/3ds/dspfirm.cdc present?")
      return
    result.initOk = true
    ctx.log("init ok, active backend id " & $cuint(activeBackend()))
    ctx.banner("INIT OK")

    try:
      ctx.log("cwd: " & getCurrentDir())
    except CatchableError:
      ctx.log("cwd: <unavailable>")

    let sfxPath = ctx.resolveProbeAsset(clickSfx)
    let musicPath = ctx.resolveProbeAsset(themeMusic)

    sfx = loadSound(sfxPath)
    if not sfx.ok:
      ctx.fail(result, "SFX LOAD FAILED",
        "load sfx failed: " & sfx.error.message)
      return
    result.sfxLoaded = true
    ctx.log("sfx loaded")

    music = loadMusic(musicPath)
    if not music.ok:
      ctx.fail(result, "MUSIC LOAD FAILED",
        "load music failed: " & music.error.message)
      return
    result.musicLoaded = true
    ctx.log("music loaded")

    ctx.banner("ASSETS OK - BEEPS STARTING")

    for beep in 1 .. config.beepCount:
      ctx.log("beep " & $beep & "/" & $config.beepCount)
      sfxHandle = play(sfx.sound, sfxBus)
      if not sfxHandle.isValid:
        result.sfxPlayed = false
        ctx.fail(result, "SFX PLAY FAILED", "sfx play returned invalid handle")
        return
      result.sfxPlayed = true
      discard setVolume(sfxHandle, 1.0'f32)
      ctx.pause(config.beepMs)
      discard stop(sfxHandle)
      sfxHandle = noHandle
      ctx.pause(config.beepGapMs)
      if ctx.aborted:
        break

    if not ctx.aborted:
      ctx.banner("MUSIC STARTING")
      ctx.log("starting streamed music for " & $config.musicMs & "ms")
      musicHandle = playMusic(music.music)
      if not musicHandle.isValid:
        ctx.fail(result, "MUSIC PLAY FAILED",
          "music play returned invalid handle")
        return
      result.musicPlayed = true
      discard setLooping(musicHandle, true)
      discard setVolume(musicHandle, 0.8'f32)
      ctx.pause(config.musicMs)
      discard stop(musicHandle)
      musicHandle = noHandle

    if ctx.aborted:
      result.failure = "aborted by user (HOME menu close)"
      ctx.log("ABORTED BY USER - probe did not run to completion")
      return

    result.ok = true
    ctx.log("probe finished successfully")
    ctx.banner("SUCCESS - holding " & $config.successHoldMs &
      "ms, press START to exit")
    discard probeHold(config.successHoldMs)
  except CatchableError as exc:
    result.ok = false
    ctx.fail(result, "UNEXPECTED ERROR", "unexpected exception: " & exc.msg)
  finally:
    if sfxHandle != noHandle:
      discard stop(sfxHandle)
    if musicHandle != noHandle:
      discard stop(musicHandle)
    if sfx.ok:
      sfx.sound.dispose()
    if music.ok:
      music.music.dispose()
    shutdown()
    ctx.log("shutdown complete, exiting")
    if ctx.logOpen:
      try:
        ctx.logFile.close()
      except CatchableError:
        discard
    probeDisplayShutdown()

proc configFromArgs*(args: seq[string]): ProbeConfig =
  result = defaultProbeConfig()
  result.verbose = true
  for arg in args:
    case arg.normalize
    of "--audio":
      result.options = initOptions()
      result.beepMs = 250
      result.beepGapMs = 500
      result.musicMs = 3000
    of "--nosound":
      result.options = initOptions(backend = noSoundBackend)
    of "--quiet":
      result.verbose = false
    else:
      discard

when isMainModule:
  let probe = runDs3AudioProbe(configFromArgs(commandLineParams()))
  if not probe.ok:
    quit 1
