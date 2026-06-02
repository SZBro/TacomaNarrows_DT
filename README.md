# TacomaNarrows_DT

Tacoma Narrows Bridge — Digital Twin  
A quarter-long capstone project (TCSS 499) exploring digital twin architecture, with a focus on the Tacoma Narrows Bridge (TNB).

---

## Overview

This project builds a real-time digital twin of the Tacoma Narrows Bridge using the Godot 4 game engine. The simulation models how individual bridge sections respond to incoming sensor data, visualizing structural behavior such as stress, deformation, and oscillation across discrete modular segments of the bridge.

Two bridges are simulated simultaneously — the original 1940 bridge (lattice steel towers) and the 1950 replacement bridge (thick concrete towers with X-brace) — placed side by side with opposite traffic directions and independent structural responses.

---

## Features

### Simulation & Data
- **Live physics model** — `BridgeDataModel` generates per-tick sensor values: wind speed/direction, temperature, cable tension, seismic vibration, resonance, torsion, and traffic load
- **DataEngine** — autoload singleton driving a 1 Hz simulation tick; manages scenarios, section registry, play/pause/step/reset, and user multipliers
- **SyncLayer** — architectural sync layer between model and engine: validates and clamps all data, buffers 60 ticks of history per section, detects anomalies (>20% change per tick), stamps provenance metadata (`simulation_tick`, `simulation_time`, `source`)
- **Channel multipliers** — per-stream 0×–5× gain sliders let users scale simulation output without breaking the live model
- **Scenarios** — Calm, Moderate Wind, Storm, Resonance Event (1940 historical conditions), Earthquake
- **Reverse traffic** — Bridge 2 sections receive spatially mirrored data so traffic platoon waves travel in the opposite direction

### Bridge Geometry
- **Bridge 1 (1940)** — original Tacoma Narrows design; slender lattice steel towers with multiple X-braced panels above and below deck
- **Bridge 2 (1950)** — replacement bridge; thick concrete legs with a single large X-brace in an upper window frame, lower and upper portal beams
- **Main span** — 8 deck sections per bridge with full Warren truss geometry (top/bottom chords, verticals, diagonals, cross struts)
- **Approach spans** — 3 east + 3 west approach sections per bridge with deck slab and side girders
- **Cable system** — parabolic main cables, hangers at 14 m spacing, anchor blocks; procedurally generated per bridge
- **All geometry** — built procedurally via `@tool` GDScript using CSG primitives; no external 3D assets

### Visual Systems
- **Stress overlay shader** — per-section color gradient (green → yellow → red) driven by live wind/resonance/torsion values
- **Motion lerp** — deck sections and towers smoothly animate at 60 fps between 1 Hz data ticks; resonance drives vertical oscillation, torsion drives twist
- **Section selection** — click any section to highlight it and view live sensor data in the debug overlay
- **Water shader** — vertex-displaced wave surface with fresnel depth coloring
- **Procedural environment** — directional sun, procedural sky, terrain ground plane, animated water plane (3000 × 3100 m)

### Camera System
- **Orbit camera** — scroll to zoom, right-drag to orbit, middle-drag to pan; default view of full bridge scene
- **First-person walk mode** — WASD + mouse look; CharacterBody3D with capsule collider; walks on terrain and bridge deck surfaces; toggle via TopBar "Walk" button
- **Camera manager** — global water floor clamp (y ≥ 1.7 m), terrain collision pushback for orbit camera, underwater fog overlay that fades in as the camera descends toward water level
- **Compass** — always-on orientation widget (bottom-right); rotates in real time based on active camera heading; North = world −Z

### Collision
- Bridge deck sections, approach spans, and tower legs all have `StaticBody3D` collision shapes added at runtime so the player can walk on the bridge
- HTerrain plugin collision enabled at startup for terrain walking

### UI
- **TopBar** — full-width dark toolbar; sim play/pause/step, scenario selector, stress overlay toggle, Streams/Flow/Walk toggles
- **Data Stream Panel** — draggable panel showing 7 live sensor streams with per-channel multiplier sliders and badge indicators
- **Data Flow Panel** — bottom-of-screen pipeline diagram showing live data moving through: ENV RESOURCE → SYNC LAYER → DATA ENGINE → BRIDGE SECTIONS; stage boxes flash on each tick, anomaly events flash red
- **Debug Overlay** — selected section's full data dictionary displayed live
- **Compass** — 80 × 80 px circular compass rose, bottom-right corner

---

## Architecture

```
BridgeDataModel          Pure math / physics model (stateless)
      ↓
SyncLayer (autoload)     Validate → Buffer → Anomaly detect → Tag provenance
      ↓
DataEngine (autoload)    Tick clock → Scenarios → Multipliers → Section dispatch
      ↓
Bridge Sections          Receive data → Animate geometry → Update stress shader
```

---

## Tech Stack

| | |
|---|---|
| Engine | Godot 4.6 |
| Language | GDScript only |
| Terrain | zylann HTerrain plugin |
| Physics | Godot built-in 3D physics (CharacterBody3D, StaticBody3D, Area3D) |

---

## Links

- **SRS Document** — https://docs.google.com/document/d/1wUe8depGdCbOKfPtmznpiu1qJhy08Lib/edit?usp=sharing&ouid=107826471012954059229&rtpof=true&sd=true
- **Weekly Progress Slides** — https://docs.google.com/presentation/d/1VfKIUkqi8TDXqGucYQEztaO6AhnYtIxB7nXJ9mufKh4/edit?usp=sharing
