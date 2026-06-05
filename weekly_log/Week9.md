# Week 9

## Status: Environment and UI Sprint

## Completed This Week

### Terrain Implementation
- Integrated HTerrain plugin to create a Puget Sound shoreline environment
- Manually sculpted terrain with elevated land masses on east and west shores
- Applied four ground textures — grass, shoreline rock/dirt, cliff, and forest moss
- Terrain positioned to align with water plane at y=0 representing the strait
- Explored photogrammetry and AI model generation routes before settling on 
  procedural in-engine approach

### Environment Polish
- Extended water plane to cover full terrain area
- Adjusted water shader for better visual alignment with terrain shoreline
- Tuned sun lighting angle and intensity for better scene readability

### First Person Camera
- Implemented PersonCamera.gd as a CharacterBody3D with Camera3D at 1.7m height
- WASD movement with mouse look and configurable sensitivity
- Camera toggle added to TopBar — switch between orbit and walk mode
- Player spawns at west shoreline near bridge approach on activation
- Collision with HTerrain surface prevents clipping through ground
- Bridge deck collision shapes added to BridgeSection scenes for walkable deck

### Camera Clipping Fix
- Added water level boundary — all cameras clamped above y=1.7
- Underwater fog overlay activates when camera approaches y=0
- Prevents all camera modes from clipping through water plane

### UI Additions
- Compass added to bottom right corner — rotates based on active camera heading
- Compass oriented to real-world TNB geography — bridge runs NW to SE
- DataFlow panel added showing live pipeline visualization —
  Environment Resource → SyncLayer → DataEngine → Bridge Sections
- Each pipeline stage pulses when data flows through it
- Anomaly detection events flash red in DataFlow panel

### UI Refinements
- Overall UI layout and styling updated
- TopBar extended with Walk Mode and Flow toggle buttons
- Debug overlay and inspector panel refined for readability

## Challenges
- HTerrain texture persistence required saving TextureSet as external .tres resource
- Camera collision with CSG geometry required adding StaticBody3D shapes 
  programmatically to bridge sections
- Compass orientation required offset calibration to match real TNB geography

## Next Week
- Finalize poster and report documentation
- Complete weekly log files
- Prepare for colloquium presentation

## Resources
- HTerrain plugin: https://github.com/Zylann/godot_heightmap_plugin
- Terrain textures sourced from ambientcg.com (CC0 license)