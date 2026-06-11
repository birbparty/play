## PS Vita hardware diagnostic probe.
##
## The standard examples are short headless smoke programs: on hardware they
## show a black screen briefly and exit even when they succeed. This probe is
## the observable replacement for Vita hardware verification. It:
##
## - paints the whole screen with a distinct solid color per phase,
## - writes a flushed line-by-line log to `ux0:/data/play-vita-probe.log`,
## - plays a repeated SFX beep pattern and several seconds of streamed music,
## - holds the screen long enough to read the final state before exiting.
##
## Screen color legend:
##
## - dark blue: probe started, engine init in progress
## - dark gray (brief flash): log file could not be opened, continuing
## - dark green (brief): engine init succeeded
## - cyan: assets loaded, beep pattern starting
## - white flashes: each SFX beep
## - yellow: streamed music playing
## - bright green (final hold): probe finished successfully
## - red: engine init failed
## - magenta: asset load failed
## - orange: playback failed (handle invalid)
## - pink: unexpected error (exception), details in the log
##
## On non-Vita hosts the display procs are no-ops and the default config uses
## the null backend with zero holds, so the shared logic stays testable in the
## regular host suite.

import std/[monotimes, os, strutils, times]

import play
import common/assets

const
  colorBoot = 0xFF801000'u32      # dark blue (A8B8G8R8: 0xAABBGGRR)
  colorLogWarn = 0xFF404040'u32   # dark gray
  colorInitOk = 0xFF006000'u32    # dark green
  colorAssetsOk = 0xFFC0C000'u32  # cyan
  colorBeep = 0xFFFFFFFF'u32      # white
  colorMusic = 0xFF00C0C0'u32     # yellow
  colorSuccess = 0xFF00C000'u32   # bright green
  colorInitFail = 0xFF0000C0'u32  # red
  colorLoadFail = 0xFFC000C0'u32  # magenta
  colorPlayFail = 0xFF0060C0'u32  # orange
  colorException = 0xFF8080FF'u32 # pink

when defined(playPlatformVita):
  const
    screenWidth = 960
    screenHeight = 544
    # CDRAM memblocks are allocated in 256 KiB units; 960*544*4 rounded up.
    framebufferSize = 0x200000'u32
    # SCE_KERNEL_MEMBLOCK_TYPE_USER_CDRAM_RW
    memblockTypeCdramRw = 0x09408060'i32
    # SCE_DISPLAY_SETBUF_NEXTFRAME
    setBufNextFrame = 1'i32

  type
    SceDisplayFrameBuf {.importc: "SceDisplayFrameBuf",
        header: "<psp2/display.h>".} = object
      size: cuint
      base: pointer
      pitch: cuint
      pixelformat: cuint
      width: cuint
      height: cuint

  proc sceKernelAllocMemBlock(
    name: cstring, kind: cint, size: cuint, optp: pointer
  ): cint {.importc, header: "<psp2/kernel/sysmem.h>".}

  proc sceKernelGetMemBlockBase(
    uid: cint, base: ptr pointer
  ): cint {.importc, header: "<psp2/kernel/sysmem.h>".}

  proc sceKernelFreeMemBlock(
    uid: cint
  ): cint {.importc, header: "<psp2/kernel/sysmem.h>".}

  proc sceDisplaySetFrameBuf(
    fb: ptr SceDisplayFrameBuf, sync: cint
  ): cint {.importc, header: "<psp2/display.h>".}

  var framebufferBase: pointer = nil

  proc probeDisplayInit(): bool =
    if framebufferBase != nil:
      return true

    let uid = sceKernelAllocMemBlock(
      "play-probe-fb", memblockTypeCdramRw, framebufferSize, nil
    )
    if uid < 0:
      return false

    var base: pointer = nil
    if sceKernelGetMemBlockBase(uid, addr base) < 0 or base == nil:
      discard sceKernelFreeMemBlock(uid)
      return false

    framebufferBase = base
    true

  proc probeSetColor(color: uint32) =
    if framebufferBase == nil:
      return

    let pixels = cast[ptr UncheckedArray[uint32]](framebufferBase)
    for index in 0 ..< screenWidth * screenHeight:
      pixels[index] = color

    var fb = SceDisplayFrameBuf(
      size: cuint(sizeof(SceDisplayFrameBuf)),
      base: framebufferBase,
      pitch: screenWidth,
      pixelformat: 0,
      width: screenWidth,
      height: screenHeight
    )
    discard sceDisplaySetFrameBuf(addr fb, setBufNextFrame)
else:
  proc probeDisplayInit(): bool = false
  proc probeSetColor(color: uint32) = discard

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

proc defaultProbeConfig*(): ProbeConfig =
  when defined(playPlatformVita):
    ProbeConfig(
      options: initOptions(),
      logPath: "ux0:/data/play-vita-probe.log",
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
      logPath: getTempDir() / "play-vita-probe.log",
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

proc hold(ctx: var ProbeContext, durationMs: int) =
  if durationMs > 0:
    sleep(durationMs)

proc fail(
  ctx: var ProbeContext,
  probe: var ProbeResult,
  color: uint32,
  message: string
) =
  probe.failure = message
  ctx.log("FAIL: " & message)
  probeSetColor(color)
  ctx.hold(ctx.config.failureHoldMs)

proc assetCandidates(asset: ExampleAsset): seq[string] =
  result = @[exampleAssetPath(asset)]
  when defined(playPlatformVita):
    let name = extractFilename(result[0])
    result.add("app0:/tests/fixtures/generated/" & name)
    result.add("tests/fixtures/generated/" & name)

proc resolveProbeAsset(ctx: var ProbeContext, asset: ExampleAsset): string =
  ## Logs every candidate path and returns the first one that exists, so a
  ## wrong working directory on hardware is recorded but does not block the
  ## playback phases. Falls back to the default helper path.
  let candidates = assetCandidates(asset)
  result = candidates[0]
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

proc runVitaAudioProbe*(config = defaultProbeConfig()): ProbeResult =
  var ctx = ProbeContext(config: config)
  try:
    ctx.startTime = getMonoTime()
    ctx.clockOk = true
  except CatchableError:
    ctx.clockOk = false

  result.displayReady = probeDisplayInit()
  probeSetColor(colorBoot)

  if config.logPath.len > 0:
    try:
      ctx.logFile = open(config.logPath, fmWrite)
      ctx.logOpen = true
    except CatchableError:
      ctx.logOpen = false
  result.logOpened = ctx.logOpen

  if not ctx.logOpen and config.logPath.len > 0 and result.displayReady:
    probeSetColor(colorLogWarn)
    ctx.hold(min(config.failureHoldMs, 2000))
    probeSetColor(colorBoot)

  ctx.log("play vita audio probe starting, play version " & playVersion)
  ctx.log("display ready: " & $result.displayReady)
  ctx.log("log path: " & config.logPath)
  ctx.log("requested backend id " & $cuint(config.options.backend))

  var
    sfx = SoundResult()
    music = MusicResult()
    sfxHandle = noHandle
    musicHandle = noHandle

  try:
    ctx.log("calling init")
    let initResult = init(config.options)
    if not initResult.ok:
      ctx.fail(result, colorInitFail,
        "init failed: " & initResult.error.message &
        " (code " & $initResult.error.code & ")")
      return
    result.initOk = true
    ctx.log("init ok, active backend id " & $cuint(activeBackend()))
    probeSetColor(colorInitOk)
    ctx.hold(min(config.beepGapMs, 2000))

    try:
      ctx.log("cwd: " & getCurrentDir())
    except CatchableError:
      ctx.log("cwd: <unavailable>")

    let sfxPath = ctx.resolveProbeAsset(clickSfx)
    let musicPath = ctx.resolveProbeAsset(themeMusic)

    sfx = loadSound(sfxPath)
    if not sfx.ok:
      ctx.fail(result, colorLoadFail, "load sfx failed: " & sfx.error.message)
      return
    result.sfxLoaded = true
    ctx.log("sfx loaded")

    music = loadMusic(musicPath)
    if not music.ok:
      ctx.fail(result, colorLoadFail,
        "load music failed: " & music.error.message)
      return
    result.musicLoaded = true
    ctx.log("music loaded")

    probeSetColor(colorAssetsOk)

    for beep in 1 .. config.beepCount:
      ctx.log("beep " & $beep & "/" & $config.beepCount)
      probeSetColor(colorBeep)
      sfxHandle = play(sfx.sound, sfxBus)
      if not sfxHandle.isValid:
        result.sfxPlayed = false
        ctx.fail(result, colorPlayFail, "sfx play returned invalid handle")
        return
      result.sfxPlayed = true
      discard setVolume(sfxHandle, 1.0'f32)
      ctx.hold(config.beepMs)
      probeSetColor(colorAssetsOk)
      discard stop(sfxHandle)
      sfxHandle = noHandle
      ctx.hold(config.beepGapMs)

    ctx.log("starting streamed music for " & $config.musicMs & "ms")
    probeSetColor(colorMusic)
    musicHandle = playMusic(music.music)
    if not musicHandle.isValid:
      ctx.fail(result, colorPlayFail, "music play returned invalid handle")
      return
    result.musicPlayed = true
    discard setLooping(musicHandle, true)
    discard setVolume(musicHandle, 0.8'f32)
    ctx.hold(config.musicMs)
    discard stop(musicHandle)
    musicHandle = noHandle

    result.ok = true
    ctx.log("probe finished successfully, holding " &
      $config.successHoldMs & "ms before exit")
    probeSetColor(colorSuccess)
    ctx.hold(config.successHoldMs)
  except CatchableError as exc:
    result.ok = false
    ctx.fail(result, colorException, "unexpected exception: " & exc.msg)
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
  let probe = runVitaAudioProbe(configFromArgs(commandLineParams()))
  if not probe.ok:
    quit 1
