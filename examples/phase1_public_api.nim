import play

proc logFailure(label: string, result: PlayResult) =
  if not result.ok:
    echo label, ": ", result.error.message

proc main() =
  let initResult = init(initOptions())
  if not initResult.ok:
    logFailure("init", initResult)
    return

  try:
    discard setMasterVolume(0.9'f32)
    discard setMusicVolume(0.6'f32)
    discard setSfxVolume(1.0'f32)
    discard setUiVolume(0.8'f32)

    let click = loadSound("assets/click.wav")
    if click.ok:
      let handle = play(click.sound, sfxBus)
      if handle.isValid:
        discard setVolume(handle, 0.75'f32)
        discard pause(handle)
        discard resume(handle)
        discard fadeVolume(handle, 0.4'f32, 0.25)
        discard stop(handle)
      click.sound.dispose()

    let music = loadMusic("assets/theme.ogg")
    if music.ok:
      let handle = fadeInMusic(music.music, 1.0, 0.7'f32)
      if handle.isValid:
        discard setLooping(handle, true)
        discard fadeOutMusic(handle, 1.0)
        discard stop(handle)
      music.music.dispose()
  finally:
    shutdown()

when isMainModule:
  main()
