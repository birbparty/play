## Safe resident sound and streamed music asset internals.

import std/os

import play/bindings/soloud_raw as raw
import play/errors

type
  Sound* = ref object
    handle: raw.Wav

  Music* = ref object
    handle: raw.WavStream

  SoundResult* = object
    ok*: bool
    sound*: Sound
    error*: PlayError

  MusicResult* = object
    ok*: bool
    music*: Music
    error*: PlayError

proc soundSuccess(sound: Sound): SoundResult =
  SoundResult(ok: true, sound: sound)

proc soundFailure(error: PlayError): SoundResult =
  SoundResult(ok: false, error: error)

proc musicSuccess(music: Music): MusicResult =
  MusicResult(ok: true, music: music)

proc musicFailure(error: PlayError): MusicResult =
  MusicResult(ok: false, error: error)

proc missingAsset(path: string): PlayError =
  loadError("Audio asset does not exist: " & path)

proc loadAssetError(kind: string, path: string, code: raw.SoloudResult): PlayError =
  loadError("Failed to load " & kind & " asset: " & path, code)

proc isDisposed*(sound: Sound): bool =
  sound == nil or sound.handle == nil

proc isDisposed*(music: Music): bool =
  music == nil or music.handle == nil

proc audioSource*(sound: Sound): raw.AudioSource =
  if sound == nil or sound.isDisposed:
    return nil

  raw.AudioSource(sound.handle)

proc audioSource*(music: Music): raw.AudioSource =
  if music == nil or music.isDisposed:
    return nil

  raw.AudioSource(music.handle)

proc dispose*(sound: Sound) =
  if sound == nil or sound.handle == nil:
    return

  raw.Wav_stop(sound.handle)
  raw.Wav_destroy(sound.handle)
  sound.handle = nil

proc dispose*(music: Music) =
  if music == nil or music.handle == nil:
    return

  raw.WavStream_stop(music.handle)
  raw.WavStream_destroy(music.handle)
  music.handle = nil

proc loadSound*(path: string): SoundResult =
  if not fileExists(path):
    return soundFailure(missingAsset(path))

  let handle = raw.Wav_create()
  if handle == nil:
    return soundFailure(allocationError("SoLoud Wav allocation failed"))

  result = soundSuccess(Sound(handle: handle))
  let code = raw.Wav_load(handle, path)
  if code != 0:
    result.sound.dispose()
    return soundFailure(loadAssetError("sound", path, code))

proc loadMusic*(path: string): MusicResult =
  if not fileExists(path):
    return musicFailure(missingAsset(path))

  let handle = raw.WavStream_create()
  if handle == nil:
    return musicFailure(allocationError("SoLoud WavStream allocation failed"))

  result = musicSuccess(Music(handle: handle))
  let code = raw.WavStream_load(handle, path)
  if code != 0:
    result.music.dispose()
    return musicFailure(loadAssetError("music", path, code))
