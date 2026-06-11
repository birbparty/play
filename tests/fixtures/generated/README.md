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

| File | Format | Duration | Sample Rate | Channels | Purpose |
| --- | --- | ---: | ---: | ---: | --- |
| `tone_sfx.wav` | PCM signed 16-bit WAV | 0.25s | 44100 Hz | 1 | Resident SFX tests |
| `tone_music.wav` | PCM signed 16-bit WAV | 2.0s | 44100 Hz | 1 | Short music/load tests |
| `tone_music.ogg` | Ogg Vorbis | 2.0s | 44100 Hz | 1 | Short OGG load tests |
| `tone_music_long.ogg` | Ogg Vorbis | 60.0s | 44100 Hz | 1 | Streamed music tests |

All tones are generated sine waves with deterministic frequencies and fade
ramps. No third-party audio recordings or sample packs are used.
