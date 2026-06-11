# Nim Successor Project – SoLoud Audio Integration Handoff

## Executive Summary

The project should adopt **SoLoud** as its primary audio engine rather than building a custom audio stack on top of SDL_mixer or directly implementing a bespoke mixer.

SoLoud provides a mature, permissively licensed, cross-platform audio engine that already implements many advanced audio features required by modern games. The engineering effort should focus on:

1. Creating robust Nim bindings.
2. Designing a Nim-first API layer.
3. Implementing custom SoLoud backends for unsupported platforms such as Nintendo 3DS and PS Vita.
4. Integrating audio cleanly into the larger Nim Successor game framework.

---

# Goals

## Primary Goals

- Open-source audio subsystem
- Commercial-friendly licensing
- Cross-platform deployment
- Minimal external dependencies
- Strong support for retro and indie games
- Future console portability

## Target Platforms

### Tier 1

- Windows
- Linux
- macOS

### Tier 2

- WebAssembly
- Nintendo 3DS (homebrew)
- PS Vita (homebrew)

### Future

- Nintendo Switch homebrew
- Android
- iOS
- Steam Deck

---

# Why SoLoud

SoLoud already provides functionality that would otherwise require significant custom engineering:

## Playback

- WAV
- OGG
- MP3
- FLAC
- Streaming music

## Voice Management

- Voice handles
- Automatic voice stealing
- Prioritization
- Pause/resume

## Audio Effects

- Echo
- Reverb
- Flanger
- Chorus
- Biquad filters

## Mixing

- Multiple buses
- Bus routing
- Per-bus volume

## Advanced Features

- 3D positional audio
- Doppler effects
- Distance attenuation
- Scheduling
- Fading

## Procedural Audio

- Speech synthesis
- Sfxr generators
- Basic synthesis sources

---

# Recommended Architecture

```text
Game Code
    │
    ▼
Nim Audio API
    │
    ▼
SoLoud Wrapper Layer
    │
    ├──────── Desktop Backend
    ├──────── Web Backend
    ├──────── 3DS Backend
    └──────── Vita Backend
```

Game code should never directly interact with SoLoud.

The framework should expose a stable Nim-centric API.

---

# Nim Audio API Proposal

## Initialization

```nim
audio.init()
audio.shutdown()
```

## Sound Assets

```nim
let laser = loadSound("laser.wav")
let explosion = loadSound("explosion.wav")
```

## Playback

```nim
play(laser)
play(explosion)
```

## Handles

```nim
let handle = play(laser)

pause(handle)
resume(handle)
stop(handle)
```

## Volume

```nim
setMasterVolume(0.8)
setMusicVolume(0.5)
setSfxVolume(1.0)
```

## Music

```nim
let music = loadMusic("theme.ogg")

playMusic(music)
stopMusic()
```

## Fades

```nim
fadeOutMusic(2.0)
fadeInMusic("theme.ogg", 2.0)
```

---

# Asset Pipeline

## Preferred Formats

### Sound Effects

- WAV

### Music

- OGG Vorbis

### Streaming Music

- OGG

### Legacy Support

- MOD
- XM
- IT

Optional support through OpenMPT integration.

---

# Backend Strategy

## Desktop

Use existing SoLoud backends.

Potential candidates:

- SDL2
- WASAPI
- ALSA
- CoreAudio

No custom work expected.

---

# WebAssembly

Investigate SoLoud Emscripten support.

Goals:

- Browser playback
- OGG support
- Streaming music

---

# Nintendo 3DS Backend

## Recommended SDK

- devkitARM
- libctru
- NDSP

## High-Level Design

```text
SoLoud Mixer
      │
mixSigned16()
      │
NDSP Buffers
      │
3DS Audio Hardware
```

### Responsibilities

- Initialize NDSP
- Maintain ring buffers
- Request PCM samples from SoLoud
- Feed buffers to NDSP

### Expected Output Format

Investigate:

- Stereo support
- Signed 16-bit PCM
- Sample rate expectations

---

# PS Vita Backend

## Recommended SDK

- VitaSDK

## High-Level Design

```text
SoLoud Mixer
      │
mixSigned16()
      │
AudioOut Buffers
      │
PS Vita Hardware
```

### Responsibilities

- Initialize AudioOut
- Allocate audio buffers
- Feed PCM samples from SoLoud
- Handle timing

---

# Nim Binding Strategy

## Preferred Approach

Write a thin wrapper over SoLoud's C API.

Avoid wrapping large portions of the C++ API directly.

Benefits:

- Easier maintenance
- Better portability
- Cleaner Nim bindings

## Layer Structure

### Layer 1

Raw bindings

```nim
soloud_raw.nim
```

### Layer 2

Safe wrapper

```nim
soloud.nim
```

### Layer 3

Engine-facing API

```nim
audio.nim
```

Game code should only use Layer 3.

---

# Feature Priorities

## Phase 1

Core playback

- WAV
- OGG
- Volume control
- Music playback
- Sound playback

## Phase 2

Handles

- Pause
- Resume
- Stop
- Looping

## Phase 3

Buses

- Music bus
- SFX bus
- UI bus

## Phase 4

Effects

- Reverb
- Echo
- Filters

## Phase 5

3D Audio

- Listener
- Emitters
- Distance attenuation

---

# Risks

## Custom Console Backends

Most engineering effort will be here.

Desktop support is largely solved.

3DS and Vita support require platform-specific implementation.

## Audio Threading

Investigate:

- Callback models
- Thread safety
- Shutdown ordering

## Memory Usage

Handheld platforms have significantly less memory.

Ensure:

- Streaming support
- Voice limits
- Asset unloading

---

# Licensing

## SoLoud

License: zlib

Compatible with:

- Open source projects
- Commercial projects
- Proprietary games

## Homebrew Toolchains

Preferred:

- devkitARM
- libctru
- VitaSDK

Avoid introducing dependencies that require proprietary SDK redistribution.

---

# Success Criteria

The audio subsystem should ultimately allow game code such as:

```nim
audio.init()

let laser = loadSound("laser.wav")
let music = loadMusic("theme.ogg")

playMusic(music)
play(laser)

audio.shutdown()
```

without requiring any platform-specific code from game developers.

The framework should provide a single API that functions identically across:

- Windows
- Linux
- macOS
- WebAssembly
- Nintendo 3DS
- PS Vita

while leveraging SoLoud internally as the audio engine.
