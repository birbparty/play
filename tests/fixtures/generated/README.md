# Generated Audio Fixtures

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
| `tone_sfx.wav` | PCM signed 16-bit WAV | 0.25s | 880 Hz | 44100 Hz | 1 | Resident SFX tests |
| `tone_music.wav` | PCM signed 16-bit WAV | 2.0s | 440 Hz | 44100 Hz | 1 | Short music/load tests |
| `tone_music.ogg` | Ogg Vorbis | 2.0s | 440 Hz | 44100 Hz | 1 | Short OGG load tests |
| `tone_music_long.ogg` | Ogg Vorbis | 60.0s | 523.25 Hz | 44100 Hz | 1 | Streamed music tests |

All tones are generated sine waves with deterministic frequencies and fade
ramps. Keep every tone at 400 Hz or above: handheld console speakers (3DS
especially) roll off steeply below that, and sub-400 Hz fixtures play
correctly while being inaudible on hardware (play-pm2). No third-party audio
recordings or sample packs are used.
