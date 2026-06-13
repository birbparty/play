## Nintendo 3DS hardware diagnostic probe.
##
## The standard examples are short headless smoke programs: on hardware they
## show a black screen briefly and exit even when they succeed (confirmed on
## PS Vita via examples/vita_audio_probe.nim). This probe is the observable
## replacement for 3DS hardware verification. It:
##
## - prints live status text to the top screen via the libctru console,
## - writes a flushed line-by-line log to `sdmc:/play-3ds-probe.log`,
## - plays a repeated SFX beep pattern, then a four-phase music matrix
##   (A: streamed OGG, B: streamed WAV, C: preloaded OGG on the sfx bus,
##   D: preloaded OGG on the music bus) so a silent-music failure can be
##   attributed to the decoding/IO/bus layer by which phases are audible,
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
  # The main thread fully decodes an OGG at load time in the preloaded music
  # phases; libctru's default 32 KiB main stack is too tight for stb_vorbis.
  {.emit: "unsigned int __stacksize__ = 256 * 1024;".}

  const
    gfxTopScreen = 0'i32 # gfxScreen_t GFX_TOP
    keyStart = 0x8'u32   # KEY_START (BIT(3))

  proc gfxInitDefault() {.importc, header: "<3ds.h>".}
  proc gfxExit() {.importc, header: "<3ds.h>".}
  proc threadCreate(
    entry: proc (arg: pointer) {.cdecl.}, arg: pointer, stackSize: csize_t,
    prio: cint, coreId: cint, detached: bool
  ): pointer {.importc: "threadCreate", header: "<3ds.h>".}
  proc threadJoin(
    thread: pointer, timeoutNs: uint64
  ): cint {.importc: "threadJoin", header: "<3ds.h>".}
  proc threadFree(thread: pointer) {.importc: "threadFree", header: "<3ds.h>".}
  proc cFopen(
    path, mode: cstring
  ): pointer {.importc: "fopen", header: "<stdio.h>".}
  proc cFread(
    dst: pointer, size, count: csize_t, file: pointer
  ): csize_t {.importc: "fread", header: "<stdio.h>".}
  proc cFclose(
    file: pointer
  ): cint {.importc: "fclose", header: "<stdio.h>".}
  proc cFseek(
    file: pointer, offset: clong, whence: cint
  ): cint {.importc: "fseek", header: "<stdio.h>".}
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

  # Thread read check (phase E): the SoLoud mixer thread streams file data on
  # a libctru thread, and silent streamed playback would be explained by file
  # reads failing off the main thread. The worker only touches C FFI and
  # plain globals - no Nim strings/seqs, which need runtime state this
  # foreign thread does not have.
  var
    threadReadPath: array[512, char]
    threadMainFile: pointer = nil
    threadReadMainBytes: int = -1
    threadReadOwnBytes: int = -1
    threadSeekReadBytes: int = -1
    threadFirstBytes: array[4, byte]

  proc threadReadWorker(arg: pointer) {.cdecl.} =
    var buf: array[4096, byte]
    if threadMainFile != nil:
      threadReadMainBytes =
        int(cFread(addr buf[0], 1, csize_t(buf.len), threadMainFile))
      if threadReadMainBytes >= 4:
        for i in 0 .. 3:
          threadFirstBytes[i] = buf[i]
    let own = cFopen(cast[cstring](addr threadReadPath[0]), "rb")
    if own == nil:
      threadReadOwnBytes = -2
    else:
      threadReadOwnBytes =
        int(cFread(addr buf[0], 1, csize_t(buf.len), own))
      # Streaming decoders seek constantly; model a mid-file seek-then-read.
      if cFseek(own, 1000, 0) == 0:
        threadSeekReadBytes =
          int(cFread(addr buf[0], 1, csize_t(buf.len), own))
      else:
        threadSeekReadBytes = -3
      discard cFclose(own)

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

  proc probeThreadReadCheck(
    path: string
  ): tuple[attempted, spawned: bool, mainBytes, ownBytes, seekBytes: int,
      magic: array[4, byte]] =
    ## Reads the file from a worker thread created like the SoLoud mixer
    ## thread (same priority/core), both through a FILE opened on the main
    ## thread and through one the worker opens itself, plus a mid-file
    ## seek-then-read. Returns the first four bytes read so garbage reads
    ## are distinguishable from real data.
    result = (true, false, -1, -1, -1, default(array[4, byte]))
    if path.len >= threadReadPath.len:
      return
    for i in 0 ..< threadReadPath.len:
      threadReadPath[i] = '\0'
    for i, c in path:
      threadReadPath[i] = c
    threadReadMainBytes = -1
    threadReadOwnBytes = -1
    threadSeekReadBytes = -1
    threadFirstBytes = default(array[4, byte])
    threadMainFile = cFopen(path.cstring, "rb")
    let worker = threadCreate(
      threadReadWorker, nil, csize_t(131072), 0x30, -2, false
    )
    if worker == nil:
      if threadMainFile != nil:
        discard cFclose(threadMainFile)
        threadMainFile = nil
      return
    discard threadJoin(worker, high(uint64))
    threadFree(worker)
    if threadMainFile != nil:
      discard cFclose(threadMainFile)
      threadMainFile = nil
    result = (true, true, threadReadMainBytes, threadReadOwnBytes,
      threadSeekReadBytes, threadFirstBytes)

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
  proc probeThreadReadCheck(
    path: string
  ): tuple[attempted, spawned: bool, mainBytes, ownBytes, seekBytes: int,
      magic: array[4, byte]] =
    discard path
    (false, false, -1, -1, -1, default(array[4, byte]))
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
    musicPlayed*: bool          # phase A: streamed OGG on music bus
    musicStreamedWavPlayed*: bool # phase B: streamed WAV on music bus
    musicPreloadedOggPlayed*: bool # phase C: preloaded OGG on sfx bus
    preloadedOggMusicBusPlayed*: bool # phase D: preloaded OGG on music bus
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
      musicMs: 5000,
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
    musicWav = MusicResult()
    oggSound = SoundResult()
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

    ctx.log("thread read check: starting worker")
    let threadRead = probeThreadReadCheck(musicPath)
    if not threadRead.attempted:
      ctx.log("thread read check: not available on this platform")
    elif not threadRead.spawned:
      ctx.log("thread read check: worker spawn failed")
    else:
      var magic = ""
      for b in threadRead.magic:
        if b >= 32'u8 and b <= 126'u8:
          magic.add(char(b))
        else:
          magic.add('.')
      ctx.log("thread read check (4096 requested): mainOpenedFile=" &
        $threadRead.mainBytes & " ownOpenedFile=" & $threadRead.ownBytes &
        " seekThenRead=" & $threadRead.seekBytes &
        " firstBytes=\"" & magic & "\"")

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

    # Music matrix: four phases that vary decode location, file I/O, and bus,
    # so a hardware tester reporting which phases were audible attributes a
    # silent-music failure to the right layer (play-pm2).
    #   A: streamed OGG, music bus  - vorbis decode + file reads, mixer thread
    #   B: streamed WAV, music bus  - file reads in mixer thread, no vorbis
    #   C: preloaded OGG, sfx bus   - vorbis decoded at load, main thread
    #   D: preloaded OGG, music bus - same source as C, isolates the bus
    # A 1 s silence gap follows each phase so the phases are separable by ear
    # (the fixtures sound identical across phases).
    template phaseGap() =
      if config.musicMs > 0:
        ctx.log("phase gap (silence)")
        ctx.pause(1000)

    if not ctx.aborted:
      ctx.banner("MUSIC A: STREAMED OGG - " & $config.musicMs & "ms")
      musicHandle = playMusic(music.music)
      if not musicHandle.isValid:
        ctx.log("FAIL: phase A play returned invalid handle")
      else:
        result.musicPlayed = true
        discard setLooping(musicHandle, true)
        discard setVolume(musicHandle, 0.8'f32)
        ctx.pause(config.musicMs)
        discard stop(musicHandle)
        musicHandle = noHandle
      phaseGap()

    if not ctx.aborted:
      let wavMusicPath = changeFileExt(musicPath, "wav")
      ctx.banner("MUSIC B: STREAMED WAV - " & $config.musicMs & "ms")
      ctx.log("phase B path: " & wavMusicPath)
      var wavExists = false
      try:
        wavExists = fileExists(wavMusicPath)
      except CatchableError:
        discard
      if not wavExists:
        ctx.log("FAIL: phase B wav file missing: " & wavMusicPath)
      else:
        musicWav = loadMusic(wavMusicPath)
        if not musicWav.ok:
          ctx.log("FAIL: phase B load failed: " & musicWav.error.message)
        else:
          musicHandle = playMusic(musicWav.music)
          if not musicHandle.isValid:
            ctx.log("FAIL: phase B play returned invalid handle")
          else:
            result.musicStreamedWavPlayed = true
            discard setLooping(musicHandle, true)
            discard setVolume(musicHandle, 0.8'f32)
            ctx.pause(config.musicMs)
            discard stop(musicHandle)
            musicHandle = noHandle
      phaseGap()

    if not ctx.aborted:
      ctx.banner("MUSIC C: PRELOADED OGG, SFX BUS - " & $config.musicMs & "ms")
      oggSound = loadSound(musicPath)
      if not oggSound.ok:
        ctx.log("FAIL: phase C load failed: " & oggSound.error.message)
      else:
        sfxHandle = play(oggSound.sound, sfxBus)
        if not sfxHandle.isValid:
          ctx.log("FAIL: phase C play returned invalid handle")
        else:
          result.musicPreloadedOggPlayed = true
          discard setLooping(sfxHandle, true)
          discard setVolume(sfxHandle, 0.8'f32)
          ctx.pause(config.musicMs)
          discard stop(sfxHandle)
          sfxHandle = noHandle
      phaseGap()

    if not ctx.aborted:
      ctx.banner("MUSIC D: PRELOADED OGG, MUSIC BUS - " &
        $config.musicMs & "ms")
      if not oggSound.ok:
        ctx.log("FAIL: phase D skipped, phase C load failed")
      else:
        musicHandle = play(oggSound.sound, musicBus)
        if not musicHandle.isValid:
          ctx.log("FAIL: phase D play returned invalid handle")
        else:
          result.preloadedOggMusicBusPlayed = true
          discard setLooping(musicHandle, true)
          discard setVolume(musicHandle, 0.8'f32)
          ctx.pause(config.musicMs)
          discard stop(musicHandle)
          musicHandle = noHandle

    if ctx.aborted:
      result.failure = "aborted by user (HOME menu close)"
      ctx.log("ABORTED BY USER - probe did not run to completion")
      return

    ctx.log("music matrix: A streamedOgg=" & $result.musicPlayed &
      " B streamedWav=" & $result.musicStreamedWavPlayed &
      " C preloadedOggSfxBus=" & $result.musicPreloadedOggPlayed &
      " D preloadedOggMusicBus=" & $result.preloadedOggMusicBusPlayed)

    result.ok = result.sfxPlayed and result.musicPlayed and
      result.musicStreamedWavPlayed and result.musicPreloadedOggPlayed and
      result.preloadedOggMusicBusPlayed
    if result.ok:
      ctx.log("probe finished successfully")
      ctx.banner("SUCCESS - holding " & $config.successHoldMs &
        "ms, press START to exit")
      discard probeHold(config.successHoldMs)
    else:
      ctx.fail(result, "PARTIAL - SOME MUSIC PHASES FAILED",
        "music matrix incomplete; see log for per-phase failures")
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
    if musicWav.ok:
      musicWav.music.dispose()
    if oggSound.ok:
      oggSound.sound.dispose()
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
