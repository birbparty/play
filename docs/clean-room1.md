# Nim Audio Middleware Successor Project
## Coding Agent Handoff Document

### Project Goal

Build a modern, open-source audio middleware and runtime library written primarily in Nim.

The system should provide professional game-audio capabilities while remaining lightweight, portable, extensible, and suitable for indie and commercial game development.

This document intentionally describes desired behaviors and architecture rather than implementation details from any existing middleware product.

---

# Design Principles

## Core Principles

1. Pure Nim first.
2. Cross-platform by default.
3. Data-oriented architecture.
4. Handle-based APIs.
5. Minimal runtime allocations.
6. Thread-safe resource management.
7. Extensible plugin architecture.
8. Deterministic behavior when possible.
9. Suitable for real-time applications.
10. No dependency on garbage collection during audio mixing.

---

# High-Level Architecture

```text
Application
    |
    v
AudioSystem
    |
    +-- Resource Manager
    +-- Event System
    +-- Mixer
    +-- DSP Graph
    +-- Streaming System
    +-- Spatial Audio System
    +-- Backend Layer
```

Subsystems should remain loosely coupled.

---

# Public API Goals

Example usage:

```nim
let audio = AudioSystem.create()

audio.initialize()

let sound = audio.loadSound(
  "laser.ogg"
)

let voice = audio.play(sound)
```

Streaming:

```nim
let music = audio.loadStream(
  "music.ogg"
)

audio.play(music)
```

Bus control:

```nim
let musicBus = audio.bus("music")

musicBus.volume = 0.5
```

Event playback:

```nim
audio.trigger("weapon.fire")
```

---

# Resource Model

Resources should be represented using handles.

Examples:

```nim
SoundHandle
VoiceHandle
BusHandle
EventHandle
DSPHandle
```

Avoid exposing internal pointers.

Handle validity checks should be inexpensive.

---

# Audio Resources

Support:

## Loaded Sounds

Entire asset resident in memory.

Suitable for:

- Sound effects
- UI sounds
- Short dialogue

## Streaming Sounds

Decoded incrementally.

Suitable for:

- Music
- Long dialogue
- Ambience

Requirements:

- Async loading
- Read-ahead buffering
- Underrun protection

---

# Mixer Architecture

Recommended hierarchy:

```text
Voice
  ->
Bus
  ->
Submix
  ->
Master
  ->
Output Device
```

Capabilities:

- Volume control
- Mute
- Solo
- Metering
- Runtime routing

---

# DSP Graph

The DSP system should be graph based.

Example:

```text
Voice
  ->
EQ
  ->
Compressor
  ->
Reverb
  ->
Bus
```

Requirements:

- Dynamic insertion
- Dynamic removal
- Bypass support
- Runtime parameter updates

DSP execution must occur on the mixer thread.

---

# Initial DSP Set

Implement:

1. Gain
2. Stereo Panner
3. Low Pass Filter
4. High Pass Filter
5. Parametric EQ
6. Delay
7. Reverb
8. Compressor
9. Limiter

Additional effects may be added later.

---

# Event System

Events are logical behaviors rather than individual files.

Example:

```text
weapon.fire
```

An event may contain:

- Sample selection
- Randomization
- Routing rules
- Parameter bindings
- DSP chains

---

# Runtime Parameters

Parameters drive event behavior.

Examples:

```text
speed
health
surface_type
combat_intensity
```

Parameters may affect:

- Volume
- Pitch
- Effect settings
- Sample selection

---

# Variation System

Support:

## Random Sample Selection

```text
footstep_01
footstep_02
footstep_03
footstep_04
```

## Pitch Randomization

Configurable ranges.

## Volume Randomization

Configurable ranges.

---

# Music System

Future support should include:

## Layered Music

Multiple synchronized stems.

## State-Based Music

Examples:

```text
exploration
combat
boss
victory
```

## Transitions

Support:

- Crossfade
- Layer enable/disable
- Scheduled transitions

---

# Scheduling

The engine should support sample-accurate timing.

Requirements:

- Future playback scheduling
- Future stop scheduling
- Timed parameter changes
- Fade automation

Use a mixer clock or DSP clock internally.

---

# Spatial Audio

## Listener

```nim
position
orientation
velocity
```

## Voice Modes

```text
2D
3D
```

## Distance Models

Support:

- Linear
- Logarithmic
- Custom curves

## Doppler

Optional velocity-based pitch shifting.

## Occlusion

Support runtime obstruction values.

Potential effects:

- Volume attenuation
- Low-pass filtering

---

# Threading Model

Recommended minimum:

## Main Thread

User API.

## Mixer Thread

DSP and mixing.

## Streaming Thread

Disk IO and buffering.

## Decode Workers

Optional pool.

Responsibilities should be clearly separated.

---

# Memory Management

Goals:

- Avoid allocations during audio callbacks.
- Preallocate critical structures.
- Use pools where appropriate.
- Support custom allocators.

The mixer thread should never block on disk IO.

---

# Backend Layer

Create a backend abstraction.

Potential implementations:

```text
WASAPI
CoreAudio
ALSA
PulseAudio
SDL Audio
OpenSL ES
AAudio
```

Public APIs should not depend on backend details.

---

# Plugin Architecture

Support plugins for:

- DSP effects
- Audio codecs
- Output backends
- Spatializers

Lifecycle:

```text
Create
Initialize
Process
Shutdown
Destroy
```

Plugins should be dynamically discoverable where platform support exists.

---

# Asset Pipeline

Future tooling should support:

## Audio Banks

Bundles of audio assets.

## Metadata

Store:

- Events
- Parameters
- Routing
- DSP chains

## Hot Reloading

Detect changes and reload during development.

---

# Testing Requirements

The project should include:

## Unit Tests

- Resource management
- DSP correctness
- Scheduling logic

## Integration Tests

- Streaming
- Routing
- Event playback

## Stress Tests

- Thousands of simultaneous voices
- Rapid creation/destruction
- Long-duration playback

---

# Performance Goals

Target:

- Thousands of virtual voices.
- Hundreds of active voices.
- Minimal allocations during playback.
- Stable frame times.
- Predictable CPU utilization.

---

# Recommended Development Order

Phase 1:

- AudioSystem
- Backend abstraction
- Loaded sound playback
- Voice management

Phase 2:

- Mixer buses
- Streaming
- Basic DSP

Phase 3:

- Event system
- Runtime parameters
- Scheduling

Phase 4:

- Spatial audio
- Plugin architecture

Phase 5:

- Asset pipeline
- Audio banks
- Hot reload

Phase 6:

- Tooling ecosystem
- Editor integration
- Advanced music systems

---

# Non-Goals (Initial Release)

Do not prioritize:

- Proprietary asset formats
- Visual authoring tools
- Networked audio synchronization
- Machine-learning audio generation
- DAW functionality

Focus first on a robust runtime library.

---

# Success Criteria

The project is considered successful when it can:

1. Load and play audio reliably.
2. Stream large assets.
3. Mix through configurable bus hierarchies.
4. Execute DSP graphs.
5. Support event-driven playback.
6. Schedule audio accurately.
7. Provide spatial audio capabilities.
8. Run across multiple operating systems.
9. Remain extensible through plugins.
10. Present a clean and idiomatic Nim API.

