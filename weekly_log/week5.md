# Week 4-5 — General Digital Twin Structure & Data Architecture

## Digital Twin Pipeline

The general structure of the digital twin follows three stages:

**Physical Side**
- Physical Object → Sensors → Real Conditions (Synthetic Data)

**Data Synchronization Layer** (middle layer)
- Data Ingestion from sensors
- State Synchronization
- Anomaly Detection
- Temporal Buffering
- Data Provenance and Tagging

**Digital Twin Side**
- 3D Model → Data Engine → Visualization and Live Model

---

## Data Streams

Two types of data streams feed into the bridge sections each tick:

| Variable | Type | What is it | How it's calculated |
|---|---|---|---|
| Wind Speed | Global | Primary environmental effect, affects all sections equally | Sine wave + noise |
| Temperature | Global | Air temperature affects material expansion and thresholds | Slow sine wave |
| Cable Tension | Global | Suspension cable load | Sine wave affected by wind speed and traffic |
| Seismic | Global | Ground vibration, affects all sections | Near zero with small chance of events |
| Traffic Model | Spatial | Per-section deck load | Traffic position moves across x-axis, load follows |
| Resonance | Spatial | Wind frequency vs. natural frequency of the bridge | Accumulates when both frequencies match |
| Torsion | Spatial | Deck twisting and stress | Wind speed × direction angle × resonance |

**Global** streams are the same value for every section each tick.  
**Spatial** streams are computed per section based on that section's position along the span.

---

## Data Architecture

```
Environment Resource        Playback Control
        ↓                          ↓
   Data Engine (singleton — timer-driven, generates data each tick)
        ├── Global: Wind Speed/Direction, Temp °C, Cable Tension, Seismic Vibrations
        └── Spatial: Traffic Model, Resonance (wind/natural freq), Torsion (twist stress)
                            ↓
                    Bridge Sections
          (the different scenes that make up the bridge)
```

The Data Engine is a singleton that runs on a timer and pushes a data payload to every registered bridge section each tick. The tick rate was initially 20/sec and subject to change as the model is refined.
