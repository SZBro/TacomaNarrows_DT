# Week 3 — Picture to Model AI Tools

## Goal

Attempted to generate a 3D model of the Tacoma Narrows Bridge using photogrammetry / AI image-to-3D tools, with the intent of importing real geometry into the project rather than building it procedurally.

## Tools Tried

- **KIRI Engine**
- **Luma AI**
- **Meshy AI**

All three produced negative results for the bridge.

## Findings

- The lack of proper photography equipment and the sheer scale of the bridge led to poor results. Phone camera coverage of a structure this large does not provide the angle density these tools require.
- Most AI photogrammetry tools are calibrated for holdable objects up to roughly room-scale — a bridge is simply too large and too narrow to capture effectively.
- A handheld plushy did produce good results with the same tools, confirming the technology works well when all angles of a compact object can be captured.
- It may be theoretically possible to generate the bridge using these tools, but the long and narrow shape requires far more photo engineering than is reasonably achievable with a phone camera.
- Reference pictures shown were generated using KIRI Engine.

## Decision

Pivoted away from AI photogrammetry. Bridge geometry will be built procedurally in GDScript using CSG primitives inside Godot 4, giving full parametric control over all dimensions and sections.
