import std/[os, strutils]

import bddy
import common/test_helpers

type WavInfo = object
  sampleRate: uint32
  channels: uint16
  bitsPerSample: uint16
  dataBytes: uint32

type OggInfo = object
  sampleRate: uint32
  channels: uint8
  finalGranule: uint64

proc readLe16(data: string, offset: int): uint16 =
  uint16(data[offset].ord) or (uint16(data[offset + 1].ord) shl 8)

proc readLe32(data: string, offset: int): uint32 =
  uint32(data[offset].ord) or
    (uint32(data[offset + 1].ord) shl 8) or
    (uint32(data[offset + 2].ord) shl 16) or
    (uint32(data[offset + 3].ord) shl 24)

proc readLe64(data: string, offset: int): uint64 =
  for shift in 0 .. 7:
    result = result or (uint64(data[offset + shift].ord) shl (shift * 8))

proc wavInfo(path: string): WavInfo =
  let data = readFile(path)
  doAssert data.len >= 44
  doAssert data[0 .. 3] == "RIFF"
  doAssert data[8 .. 11] == "WAVE"
  doAssert data[12 .. 15] == "fmt "
  doAssert data[36 .. 39] == "data"
  result.channels = readLe16(data, 22)
  result.sampleRate = readLe32(data, 24)
  result.bitsPerSample = readLe16(data, 34)
  result.dataBytes = readLe32(data, 40)

proc durationSeconds(info: WavInfo): float =
  info.dataBytes.float / (info.sampleRate.float * info.channels.float * (info.bitsPerSample.float / 8.0))

proc oggInfo(path: string): OggInfo =
  let data = readFile(path)
  doAssert data.len >= 58
  doAssert data[0 .. 3] == "OggS"
  doAssert data[28 .. 34] == "\x01vorbis"
  result.channels = uint8(data[39].ord)
  result.sampleRate = readLe32(data, 40)

  var offset = 0
  while offset + 27 <= data.len:
    doAssert data[offset .. offset + 3] == "OggS"
    let segmentCount = data[offset + 26].ord
    doAssert offset + 27 + segmentCount <= data.len
    var payloadBytes = 0
    for i in 0 ..< segmentCount:
      payloadBytes += data[offset + 27 + i].ord
    let nextOffset = offset + 27 + segmentCount + payloadBytes
    doAssert nextOffset <= data.len
    result.finalGranule = readLe64(data, offset + 6)
    offset = nextOffset

  doAssert offset == data.len

proc durationSeconds(info: OggInfo): float =
  info.finalGranule.float / info.sampleRate.float

spec "generated audio fixtures":
  it "commits deterministic WAV fixtures for resident and short music tests":
    given:
      let sfx = wavInfo(fixturePath("generated", "tone_sfx.wav"))
      let music = wavInfo(fixturePath("generated", "tone_music.wav"))
    then:
      sfx.sampleRate == 44100'u32
      sfx.channels == 1'u16
      sfx.bitsPerSample == 16'u16
      abs(sfx.durationSeconds - 0.25) < 0.001
      music.sampleRate == 44100'u32
      music.channels == 1'u16
      music.bitsPerSample == 16'u16
      abs(music.durationSeconds - 2.0) < 0.001

  it "commits OGG fixtures for loaded and streamed music paths":
    given:
      let shortOgg = fixturePath("generated", "tone_music.ogg")
      let longOgg = fixturePath("generated", "tone_music_long.ogg")
      let shortInfo = oggInfo(shortOgg)
      let longInfo = oggInfo(longOgg)
    then:
      shortInfo.sampleRate == 44100'u32
      shortInfo.channels == 1'u8
      abs(shortInfo.durationSeconds - 2.0) < 0.001
      longInfo.sampleRate == 44100'u32
      longInfo.channels == 1'u8
      abs(longInfo.durationSeconds - 60.0) < 0.001
      getFileSize(shortOgg) > 1024
      getFileSize(longOgg) > getFileSize(shortOgg)
      getFileSize(longOgg) < 200_000

  it "records fixture provenance next to generated assets":
    given:
      let manifest = readFile(fixturePath("generated", "README.md"))
    then:
      manifest.contains("nim r tools/generate_fixtures.nim")
      manifest.contains("CC0-compatible")
      manifest.contains("Resident SFX tests")
      manifest.contains("Streamed music tests")
