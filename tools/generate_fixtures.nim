## Generate deterministic audio fixtures for wrapper and API tests.

import std/[math, os, osproc, sequtils, strformat, strutils]

const
  sampleRate = 44100
  channels = 1
  bitsPerSample = 16
  amplitude = 0.35
  twoPi = 2.0 * PI

type Fixture = object
  path: string
  durationSeconds: float
  frequency: float
  description: string

proc addLe16(data: var string, value: uint16) =
  data.add char(value and 0xff)
  data.add char((value shr 8) and 0xff)

proc addLe32(data: var string, value: uint32) =
  data.add char(value and 0xff)
  data.add char((value shr 8) and 0xff)
  data.add char((value shr 16) and 0xff)
  data.add char((value shr 24) and 0xff)

proc writeWav(path: string, durationSeconds, frequency: float) =
  let sampleCount = int(round(durationSeconds * sampleRate.float))
  let blockAlign = uint16(channels * (bitsPerSample div 8))
  let byteRate = uint32(sampleRate * int(blockAlign))
  let dataBytes = uint32(sampleCount * int(blockAlign))

  var data = "RIFF"
  data.addLe32(36'u32 + dataBytes)
  data.add "WAVEfmt "
  data.addLe32 16'u32
  data.addLe16 1'u16
  data.addLe16 uint16(channels)
  data.addLe32 uint32(sampleRate)
  data.addLe32 byteRate
  data.addLe16 blockAlign
  data.addLe16 uint16(bitsPerSample)
  data.add "data"
  data.addLe32 dataBytes

  for i in 0 ..< sampleCount:
    let t = i.float / sampleRate.float
    let envelope =
      if i < 128:
        i.float / 128.0
      elif i >= sampleCount - 128:
        max(0.0, (sampleCount - i).float / 128.0)
      else:
        1.0
    let sample = int16(round(sin(twoPi * frequency * t) * amplitude * envelope * 32767.0))
    data.addLe16 uint16(sample)

  writeFile(path, data)

proc needsEncode(outputPath: string, force: bool): bool =
  force or not fileExists(outputPath)

proc runFfmpeg(inputPath, outputPath: string, force: bool) =
  if fileExists(outputPath) and not force:
    return

  if findExe("ffmpeg").len == 0:
    raise newException(OSError, "ffmpeg is required to generate missing or refreshed OGG fixtures")

  # -map_metadata is an output option and must come after -i; newer ffmpeg
  # rejects it as an input option otherwise.
  let args = [
    "-y",
    "-hide_banner",
    "-loglevel", "error",
    "-i", inputPath,
    "-map_metadata", "-1",
    "-c:a", "libvorbis",
    "-q:a", "4",
    outputPath
  ]
  let ffmpeg = execCmdEx("ffmpeg " & args.mapIt(quoteShell(it)).join(" "))
  if ffmpeg.exitCode != 0:
    raise newException(OSError, "ffmpeg failed: " & ffmpeg.output)

proc main() =
  let force = commandLineParams().contains("--force")
  let outDir = currentSourcePath.parentDir.parentDir / "tests" / "fixtures" / "generated"
  createDir(outDir)

  let wavFixtures = [
    Fixture(
      path: outDir / "tone_sfx.wav",
      durationSeconds: 0.25,
      frequency: 880.0,
      description: "short resident WAV sound effect"
    ),
    Fixture(
      path: outDir / "tone_music.wav",
      durationSeconds: 2.0,
      # Keep music fixtures at 400 Hz or above: handheld console speakers
      # (3DS especially) roll off steeply below that, and the original
      # 220 Hz tone played correctly on hardware while being inaudible
      # (play-pm2).
      frequency: 440.0,
      description: "short WAV music/loading fixture"
    ),
    Fixture(
      path: outDir / "tone_music_long_source.wav",
      durationSeconds: 60.0,
      frequency: 523.25,
      description: "temporary long WAV source for streamed OGG generation"
    )
  ]

  for fixture in wavFixtures:
    writeWav(fixture.path, fixture.durationSeconds, fixture.frequency)

  let longSource = outDir / "tone_music_long_source.wav"
  try:
    if needsEncode(outDir / "tone_music.ogg", force):
      runFfmpeg(outDir / "tone_music.wav", outDir / "tone_music.ogg", force)
    if needsEncode(outDir / "tone_music_long.ogg", force):
      runFfmpeg(longSource, outDir / "tone_music_long.ogg", force)
  finally:
    if fileExists(longSource):
      removeFile(longSource)

  let manifest = fmt"""# Generated Audio Fixtures

These fixtures are generated, not recorded, and are CC0-compatible. Regenerate
them from the repository root with:

```sh
nim r tools/generate_fixtures.nim
```

The WAV files are written directly by the Nim generator. OGG files are encoded
from generated WAV sources with `ffmpeg -c:a libvorbis -q:a 4`. Normal reruns
preserve existing committed OGG bytes; pass `--force` to intentionally refresh
the OGG files from the generated WAV sources.

| File | Format | Duration | Tone | Sample Rate | Channels | Purpose |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `tone_sfx.wav` | PCM signed 16-bit WAV | 0.25s | 880 Hz | {sampleRate} Hz | {channels} | Resident SFX tests |
| `tone_music.wav` | PCM signed 16-bit WAV | 2.0s | 440 Hz | {sampleRate} Hz | {channels} | Short music/load tests |
| `tone_music.ogg` | Ogg Vorbis | 2.0s | 440 Hz | {sampleRate} Hz | {channels} | Short OGG load tests |
| `tone_music_long.ogg` | Ogg Vorbis | 60.0s | 523.25 Hz | {sampleRate} Hz | {channels} | Streamed music tests |

All tones are generated sine waves with deterministic frequencies and fade
ramps. Keep every tone at 400 Hz or above: handheld console speakers (3DS
especially) roll off steeply below that, and sub-400 Hz fixtures play
correctly while being inaudible on hardware (play-pm2). No third-party audio
recordings or sample packs are used.
"""
  writeFile(outDir / "README.md", manifest)

when isMainModule:
  main()
