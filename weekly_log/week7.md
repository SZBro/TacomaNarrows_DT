# Week 6-7 — Visualization and UI

- Added a top toolbar UI (TopBar) with simulation controls: play/pause, step, tick rate display, overlay toggles, and stream panel toggle.
- Added a stress overlay shader for the bridge sections to visually represent overall structural stress — sections shift color from green to yellow to red based on live wind, resonance, and torsion values.
- Added highlighting for selected parts of the bridge — clicking a section outlines it and displays its live sensor data.
- Added a DataStream panel with per-channel multiplier sliders, allowing users to scale individual data streams (0× to 5×) applied on top of the live model output.
