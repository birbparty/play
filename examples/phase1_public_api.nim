import play
import common/assets

proc logFailure(label: string, result: PlayResult) =
  if not result.ok:
    echo label, ": ", result.error.message

proc main() =
  # Device-free by default on desktop: this example is an API-surface smoke
  # exercise (never run with --audio by build_desktop_examples.sh), so it must
  # not open a real audio device once miniaudio is compiled. Console targets keep
  # their real backend via AUTO. Mirrors the bus_volume_demo / music_fades /
  # sfx_keypress default-config pattern. See docs/desktop-backend-decisions.md D1.
  when defined(playPlatform3ds) or defined(playPlatformVita):
    let options = initOptions()
  else:
    let options = initOptions(backend = nullBackend)
  let initResult = init(options)
  if not initResult.ok:
    logFailure("init", initResult)
    return

  try:
    discard setMasterVolume(0.9'f32)
    discard setMusicVolume(0.6'f32)
    discard setSfxVolume(1.0'f32)
    discard setUiVolume(0.8'f32)

    let click = loadExampleSound(clickSfx)
    if click.ok:
      let handle = play(click.sound, sfxBus)
      if handle.isValid:
        discard setVolume(handle, 0.75'f32)
        discard pause(handle)
        discard resume(handle)
        discard fadeVolume(handle, 0.4'f32, 0.25)
        discard stop(handle)
      click.sound.dispose()

    let music = loadExampleMusic(themeMusic)
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
