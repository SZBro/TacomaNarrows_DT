# Week 6-7 — Small Changes, Features, Research & Second Bridge

## Small Changes and Features

- Changed the tick rate for the data engine to 1 tick per second to allow for more realistic data generation and reaction.
- Added water plane to make the digital twin more visually realistic.
- Added sun/directional light environment.
- Researching adding terrain (still in progress) — evaluating HTerrain and Terrain3D plugins.

## Second Bridge

- Created a rough model of the second bridge's tower (1950 replacement design — thick concrete legs with X-brace).
- Created the second bridge inside the main scene.
- Had to adjust the data engine to incorporate the second bridge.
- Both bridges receive data from the same DataEngine but use it differently — the traffic model is inverted for the second bridge to reflect opposite traffic direction.
