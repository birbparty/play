# Nim Successor Audio Project
## Coding Agent Handoff Document

Version: 0.1
Status: Architectural Planning
Goal: Build a modern open-source interactive audio middleware and runtime ecosystem for Nim applications and games.

---

# Project Vision

Create a fully open-source audio solution that combines:

- Lightweight runtime performance
- Data-driven authoring
- Adaptive music
- Interactive sound design
- Modern profiling tools
- Cross-platform deployment
- Extensible plugin architecture

The system should allow sound designers and programmers to work independently while sharing a common audio data model.

The runtime must remain small, deterministic, and embeddable.

---

# Non-Goals

The project is NOT attempting to clone any existing commercial middleware.

Avoid:

- Replicating proprietary UI layouts
- Reproducing proprietary file formats
- Reproducing proprietary APIs
- Reverse engineering implementation details

Focus exclusively on solving common game-audio problems using original implementations.

---

# Core Design Principles

## Data Driven

Game code should trigger high-level audio events.

Example:

```nim
audio.postEvent("footstep")
audio.postEvent("weapon.fire")
audio.postEvent("music.combat")
```

Game code should never directly reference audio files.

---

## Runtime Determinism

All audio behavior should be predictable.

Requirements:

- No runtime allocations in audio thread
- Lock-free where possible
- Fixed update scheduling
- Platform-independent behavior

---

## Authoring Independence

Audio designers should be able to:

- Create events
- Configure routing
- Build music systems
- Adjust mixing
- Configure randomization

without requiring engine code changes.

---

# Proposed Repository Layout

```text
nimsuccessor-audio/
├── runtime/
├── dsp/
├── assets/
├── profiler/
├── editor/
├── plugins/
├── examples/
├── tests/
└── docs/
```

---

# Runtime Architecture

## Layer 1: Public API

```nim
audio.init()

audio.postEvent("explosion")

audio.setParameter("playerSpeed", 3.4)

audio.setState("combat")

audio.update()
```

Responsibilities:

- User-facing API
- Event dispatch
- Parameter updates
- State changes

---

## Layer 2: Audio Graph

Runtime representation of:

- Events
- Containers
- Buses
- DSP chains
- Parameters

The graph should be immutable during playback.

Modifications occur through queued commands.

---

## Layer 3: Voice System

Responsibilities:

- Voice allocation
- Priority management
- Voice stealing
- Playback state

Potential structure:

```nim
Voice
VoicePool
VoiceManager
```

---

## Layer 4: Mixer

Responsibilities:

- Bus routing
- Gain staging
- DSP execution
- Output generation

Proposed bus hierarchy:

```text
Master
 ├── Music
 ├── Dialogue
 ├── Ambience
 ├── SFX
 └── UI
```

---

# Event System

Events are the primary gameplay interface.

Example:

```text
PlayExplosion
PlayFootstep
PlayDialogue
StopMusic
```

An event may:

- Start sounds
- Stop sounds
- Set parameters
- Trigger transitions

Events should be lightweight identifiers.

---

# Parameter System

Parameters provide runtime control.

Examples:

```text
PlayerSpeed
RPM
ThreatLevel
Health
WindStrength
```

Parameter values should drive:

- Volume
- Pitch
- Filter cutoff
- Blend weights
- Routing

Implementation target:

```nim
ParameterId
ParameterValue
ParameterCurve
```

Parameter curves should be data-driven.

Adaptive audio is one of the defining capabilities of modern middleware systems.  [oai_citation:0‡Game Developer](https://www.gamedeveloper.com/audio/audio-middleware-why-would-i-want-it-in-my-game-?utm_source=chatgpt.com)

---

# State System

States represent global gameplay context.

Examples:

```text
Exploration
Combat
Boss
Paused
```

States can affect:

- Music
- Mix snapshots
- Effects
- Routing

Only one state may be active per state group.

---

# Switch System

Switches represent contextual choices.

Examples:

```text
SurfaceType
WeaponType
Biome
```

Example:

```text
Footstep
 ├── Grass
 ├── Dirt
 ├── Stone
 └── Metal
```

The runtime selects the correct variation automatically.

---

# Audio Containers

## Random Container

Purpose:

Prevent repetition.

Features:

- Weighted selection
- Shuffle mode
- Avoid-repeat count

---

## Sequence Container

Purpose:

Ordered playback.

Example:

```text
Intro
Loop
Outro
```

---

## Blend Container

Purpose:

Crossfade based on parameters.

Example:

```text
RPM -> Engine Layers
```

---

# Music System

Music should be a first-class subsystem.

Modern adaptive audio solutions commonly support state-driven music, transitions, and parameter-controlled layering.  [oai_citation:1‡Game Developer](https://www.gamedeveloper.com/audio/audio-middleware-why-would-i-want-it-in-my-game-?utm_source=chatgpt.com)

## Required Features

### Music Segments

```text
Intro
Loop
Transition
Outro
```

### Music States

```text
Exploration
Combat
Boss
Victory
```

### Transition Types

```text
Immediate
NextBeat
NextBar
CustomCue
```

### Layered Music

Allow enabling/disabling layers independently.

Example:

```text
Percussion
Bass
Pads
Strings
```

---

# Spatial Audio

Required emitter properties:

```text
Position
Velocity
Orientation
Spread
```

---

## Attenuation

Support curves for:

- Volume
- LPF
- HPF
- Priority

---

## Occlusion

Initial implementation:

```text
None
Simple
Raycast
```

Advanced methods can be added later.

---

# Asset Pipeline

Build system should generate:

```text
Metadata
Banks
Streaming Data
Localization Data
```

Separating metadata from streamed audio is common practice in modern audio pipelines.  [oai_citation:2‡Game Developer](https://www.gamedeveloper.com/audio/audio-middleware-why-would-i-want-it-in-my-game-?utm_source=chatgpt.com)

---

# Compression Support

Initial codecs:

```text
PCM
Vorbis
Opus
```

Future:

```text
FLAC
ADPCM
Platform Native
```

---

# Streaming System

Playback modes:

```text
Resident
Streaming
Hybrid
```

Large music assets should stream from disk.

---

# Profiling Requirements

This is a mandatory subsystem.

Professional audio workflows rely heavily on runtime profiling and live inspection capabilities.  [oai_citation:3‡designingsound.org](https://designingsound.org/2010/01/13/audio-implementation-greats-1-audio-toolsets-part-1/?utm_source=chatgpt.com)

Required metrics:

```text
Voice Count
CPU
Memory
Streaming Usage
DSP Usage
Bus Levels
```

---

# Live Debugging

Long-term goal:

Remote connection to a running application.

Capabilities:

```text
Inspect Voices
Monitor Buses
View Parameters
Trigger Events
Adjust Mix
```

Hot iteration is considered a major productivity feature in modern middleware workflows.  [oai_citation:4‡Wikipedia](https://en.wikipedia.org/wiki/Audiokinetic_Wwise?utm_source=chatgpt.com)

---

# Plugin SDK

The runtime should support dynamically loaded plugins.

## Source Plugins

Generate audio.

Examples:

```text
Noise
Oscillator
Granular
Speech
```

---

## Effect Plugins

Process audio.

Examples:

```text
EQ
Limiter
Compressor
Reverb
Delay
```

---

## Codec Plugins

Provide:

```text
Decode
Encode
Streaming
```

---

# Nim-Specific Opportunities

The project can differentiate itself through Nim features.

## Macros

Generate compile-time bindings:

```nim
AudioEvent
AudioParameter
AudioState
AudioSwitch
```

from authored metadata.

---

## ARC/ORC Compatibility

Target:

- ARC
- ORC

Avoid GC dependencies in audio thread.

---

## Backend Abstraction

Potential backends:

```text
SDL
OpenAL
WASAPI
CoreAudio
ALSA
PulseAudio
```

Future:

```text
Vita
3DS
Dreamcast
Homebrew Platforms
```

---

# Milestone Plan

## Milestone 1

Runtime MVP

Deliver:

- Voice playback
- Mixing
- Event system
- Bus hierarchy

---

## Milestone 2

Adaptive Audio

Deliver:

- Parameters
- States
- Switches
- Random containers

---

## Milestone 3

Music System

Deliver:

- Segments
- Transitions
- Layering

---

## Milestone 4

Asset Pipeline

Deliver:

- Audio banks
- Compression
- Streaming

---

## Milestone 5

Profiler

Deliver:

- Runtime inspection
- Performance metrics
- Debug visualization

---

## Milestone 6

Authoring Tools

Deliver:

- Visual editor
- Graph editing
- Bank generation

---

# Success Criteria

The project is successful if it can:

1. Drive an entire game's audio through events.
2. Support adaptive music without custom game code.
3. Support designer-authored logic.
4. Maintain low CPU and memory overhead.
5. Provide live profiling and debugging.
6. Remain fully open-source.
7. Support multiple audio backends.
8. Feel native to Nim rather than a wrapper around another solution.

