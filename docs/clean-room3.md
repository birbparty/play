# Nim Audio Successor Project — Coding Agent Handoff

## Purpose

This document provides implementation guidance for the development of a new cross-platform audio runtime written in Nim. The goal is to create a modern, extensible, low-latency audio system suitable for games, multimedia applications, simulations, and experimental audio projects.

This document intentionally focuses on architectural requirements and desired capabilities rather than any specific third-party audio API.

---

# Project Goals

The runtime should provide:

- Cross-platform audio playback
- Real-time mixing
- Spatial audio
- Streaming audio support
- DSP effects
- Extensible backend architecture
- Low-latency operation
- Thread-safe APIs
- Minimal runtime allocations
- Strong Nim ergonomics

The resulting library should feel native to Nim rather than a direct translation of existing audio APIs.

---

# High-Level Architecture

```text
Application
    ↓
Public API
    ↓
Audio Commands
    ↓
Audio Thread
    ↓
Mixer
    ↓
DSP Graph
    ↓
Backend
    ↓
Audio Device
```

The public API should never communicate directly with platform audio systems.

All audio state changes should be submitted through a command queue.

---

# Core Objects

## AudioBuffer

Represents immutable decoded audio data.

Responsibilities:

- Store PCM samples
- Track sample rate
- Track channel count
- Support shared ownership

Example:

```nim
type AudioBuffer = ref object
  sampleRate: uint32
  channels: uint8
  frames: uint32
  samples: seq[float32]
```

---

## AudioEmitter

Represents a playable sound instance.

Responsibilities:

- Playback state
- Position
- Velocity
- Gain
- Pitch
- Looping

Example:

```nim
type AudioEmitter = ref object
  buffer: AudioBuffer
  position: Vec3
  velocity: Vec3
  gain: float32
  pitch: float32
```

---

## AudioListener

Represents the listening point.

```nim
type AudioListener = object
  position: Vec3
  velocity: Vec3
  forward: Vec3
  up: Vec3
  gain: float32
```

Only one active listener is required initially.

Future versions may support multiple listeners.

---

## AudioStream

Represents streamed audio.

Use cases:

- Music
- Voice
- Long ambience
- Podcasts

Streaming should operate through internal chunk queues rather than loading entire assets into memory.

---

## AudioBus

Represents a mixer routing destination.

Initial buses:

```text
Master
Music
SFX
Voice
Ambient
```

Every emitter should route through a bus.

---

# Mixer Requirements

The mixer should support:

- Multiple active emitters
- Per-emitter gain
- Per-emitter pitch
- Distance attenuation
- Bus routing
- DSP insertion

Mixing should occur entirely on the audio thread.

No application thread mixing is permitted.

---

# Spatial Audio Requirements

## Phase 1

Implement:

- Position
- Distance attenuation
- Stereo panning
- Velocity tracking

### Distance Models

Support:

```nim
type DistanceModel = enum
  dmLinear
  dmInverse
  dmExponential
```

---

## Phase 2

Add:

- Directional emitters
- Cone attenuation
- Doppler effects

---

## Phase 3

Add:

- HRTF
- Ambisonics
- Advanced spatialization

These should be plugins rather than core features.

---

# DSP System

The DSP architecture should be graph-based.

Example:

```text
Emitter
  ↓
Filter
  ↓
Bus
  ↓
Reverb
  ↓
Master
```

Every DSP unit should implement a common processing interface.

Example:

```nim
type DSPNode = ref object of RootObj

method process(
  self,
  input: ptr float32,
  output: ptr float32,
  frames: int
)
```

---

# Initial DSP Effects

Required:

- Gain
- Low-pass filter
- High-pass filter

Planned:

- Reverb
- Delay
- Compressor
- Limiter
- EQ

---

# Backend Layer

The backend layer should abstract all platform-specific audio systems.

Required interface:

```nim
type AudioBackend = ref object of RootObj

method initialize(self)
method shutdown(self)
method submitFrames(
  self,
  samples: ptr float32,
  frameCount: int
)
```

The rest of the engine must not depend on backend implementation details.

---

# Target Platforms

Priority order:

## Tier 1

- Windows
- Linux
- macOS

## Tier 2

- WebAssembly
- Android
- iOS

## Tier 3

- PlayStation Vita homebrew
- Nintendo 3DS homebrew
- Dreamcast homebrew
- Other retro/homebrew targets

Platform support should be isolated behind backend implementations.

---

# Threading Model

Recommended:

```text
Game Thread
      ↓
 Lock-Free Queue
      ↓
 Audio Thread
      ↓
 Mixer
      ↓
 Device
```

Requirements:

- No blocking audio callback
- No heap allocations inside audio callback
- No mutex contention on render path

---

# Memory Management

Goals:

- Predictable allocation behavior
- Shared audio buffers
- Reusable emitter pools

Avoid:

- Per-frame allocations
- Frequent object creation/destruction

Investigate:

- Object pools
- Fixed-size allocator strategies
- Stack-friendly DSP processing

---

# Nim-Specific Opportunities

## Compile-Time Audio Graphs

Potential future DSL:

```nim
audioGraph:
  music -> reverb -> master
  sfx -> compressor -> master
```

---

## ECS Integration

Potential components:

```nim
AudioEmitterComponent
AudioListenerComponent
AudioBusComponent
```

Support common Nim ECS frameworks where practical.

---

## Conditional Backends

Example:

```nim
when defined(windows):
  import backend_wasapi

when defined(linux):
  import backend_pipewire
```

The public API should remain identical regardless of backend.

---

# Public API Philosophy

Prefer:

```nim
let sound = loadSound("laser.wav")
play(sound)
```

Over:

```nim
var src = createEmitter()
bindBuffer(src, buf)
startPlayback(src)
```

Expose advanced control when needed but keep common operations simple.

---

# Testing Requirements

## Unit Tests

- Buffer loading
- DSP correctness
- Distance calculations
- Command queue behavior

## Integration Tests

- Device startup
- Streaming playback
- Multi-emitter mixing

## Stress Tests

- Hundreds of emitters
- Rapid emitter creation/destruction
- Long-duration playback

---

# Milestone Roadmap

## Milestone 1

Core foundation:

- Audio device abstraction
- Mixer
- Buffers
- Emitters
- Listener
- Playback

## Milestone 2

Spatial audio:

- Attenuation
- Panning
- Velocity support

## Milestone 3

Streaming:

- Music playback
- Ring buffers
- Background decoding

## Milestone 4

DSP:

- Filters
- Bus routing
- Effect chains

## Milestone 5

Plugin system:

- DSP plugins
- Spatialization plugins
- Analysis plugins

## Milestone 6

Platform expansion:

- Mobile
- Web
- Homebrew platforms

---

# Success Criteria

The project should ultimately provide:

- A modern Nim-native audio API
- Strong cross-platform support
- Excellent game-development ergonomics
- Extensible DSP architecture
- Low-latency playback
- Minimal runtime overhead
- Long-term maintainability

The implementation should prioritize correctness, clean architecture, and extensibility over feature count during the early milestones.

