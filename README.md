# Tacoma Narrows Bridge Digital Twin
### Exploring a Game Engine Approach to Structural Health Monitoring Visualization

**Course:** TCSS 499 — Self-Directed Research  
**Institution:** University of Washington Tacoma  
**Faculty Supervisor:** Dr. Wei Cai  
**Quarter:** Spring 2026  
**Developer:** Skyler Z Broussard

---

## Overview

This project investigates the feasibility of using an open-source game engine 
as a platform for digital twin development. A real-time digital twin of the 
Tacoma Narrows Bridge (TNB) was built using Godot 4 and GDScript, modeling 
both the 1950 westbound and 2007 eastbound bridge spans with approximately 
30 independent modular sections responding to synthetic sensor data simultaneously.

**Research Question:**  
*"What is the feasibility of open-source game engines for the creation of digital twins?"*

---

## Features

- **Two bridge models** — 1950 westbound and 2007 eastbound TNB spans
- **~30 modular sections** — deck spans, towers, cable system, approach spans
- **7 synthetic data streams** — wind, temperature, cable tension, seismic, 
  traffic load, resonance, torsion
- **Synchronization layer** — data ingestion, temporal buffering, 
  anomaly detection, provenance tagging
- **Stress color overlay** — green to red per section based on data values
- **State machine** — Normal, Warning, Critical, Failure per section
- **Interactive UI** — DataStream panel, multiplier sliders, section inspection
- **First person camera** — ground level bridge exploration
- **Puget Sound environment** — HTerrain terrain, procedural water shader
- **Compass navigation** — real-world TNB geographic orientation
- **Data flow visualization** — live pipeline panel

---

## Tech Stack

- **Engine:** Godot 4.6
- **Language:** GDScript
- **Terrain:** HTerrain plugin by Zylann
- **Development:** AI-assisted agentic workflow using Claude and Claude Code

---

## How to Run

1. Download and install [Godot 4.6](https://godotengine.org)
2. Clone this repository
3. Open Godot → Import Project → select `godot_project/project.godot`
4. Press **F5** or click Play to run the simulation

---

## Controls

| Action | Input |
|---|---|
| Orbit camera | Middle mouse + drag |
| Zoom | Scroll wheel |
| Pan | Shift + middle mouse |
| Walk mode toggle | TopBar — Walk button |
| Move (walk mode) | WASD |
| Look (walk mode) | Mouse |
| Select section | Left click on section |
| Toggle data streams | TopBar — Streams button |
| Toggle data flow | TopBar — Flow button |

---

## Documentation

- [SRS Document](https://docs.google.com/document/d/1wUe8depGdCbOKfPtmznpiu1qJhy08Lib/edit?usp=sharing&ouid=107826471012954059229&rtpof=true&sd=true)
- [Weekly Progress Slides](https://docs.google.com/document/d/1wUe8depGdCbOKfPtmznpiu1qJhy08Lib/edit?usp=sharing&ouid=107826471012954059229&rtpof=true&sd=true)
- [Research References](https://docs.google.com/document/d/1HsmDCvE5ajtnlmhh0C4_c-PVK7p3eQx8nywQi1DMcL0/edit?tab=t.0)

---

## Research Findings

Godot's modular scene architecture maps naturally to digital twin component 
design, enabling independent per-section data response without specialized 
software. The primary limitation is physical accuracy — visual responses are 
scripted approximations rather than solutions to structural engineering equations.

---

## Future Work

- Real sensor data integration via HTTP/WebSocket
- Physically accurate responses using structural engineering equations
- Formal user evaluation study
- Performance testing at larger scale
- Multi-user monitoring via Godot multiplayer networking
- IEEE VIS / CHI conference submission

---

## Acknowledgements

Faculty Supervisor: Dr. Wei Cai, University of Washington Tacoma  
Development assisted by Claude and Claude Code (Anthropic)

---

*University of Washington Tacoma | TCSS 499 | Spring 2026*