## Shared asset lookup and loading helpers for play examples.

import std/os

import play

when defined(playPlatform3ds):
  const
    examplesRoot* = "sdmc:/examples"
    repoRoot* = "sdmc:"
elif defined(playPlatformVita):
  const
    examplesRoot* = "examples"
    repoRoot* = "."
else:
  const
    examplesRoot* = currentSourcePath().parentDir.parentDir
    repoRoot* = examplesRoot.parentDir

const
  exampleAssetRoot* = examplesRoot / "assets"
  fixtureAssetRoot* = repoRoot / "tests" / "fixtures" / "generated"

type ExampleAsset* = enum
  clickSfx
  themeMusic
  longThemeMusic

proc fileName(asset: ExampleAsset): string =
  case asset
  of clickSfx:
    "tone_sfx.wav"
  of themeMusic:
    "tone_music.ogg"
  of longThemeMusic:
    "tone_music_long.ogg"

proc exampleAssetPath*(asset: ExampleAsset): string =
  let name = fileName(asset)
  let primary = exampleAssetRoot / name
  if fileExists(primary):
    return primary
  fixtureAssetRoot / name

proc requireExampleAsset*(asset: ExampleAsset): string =
  result = exampleAssetPath(asset)
  if not fileExists(result):
    raise newException(IOError, "Missing example asset: " & result)

proc loadExampleSound*(asset: ExampleAsset): SoundResult =
  loadSound(exampleAssetPath(asset))

proc loadExampleMusic*(asset: ExampleAsset): MusicResult =
  loadMusic(exampleAssetPath(asset))
