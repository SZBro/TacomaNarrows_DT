# Week 8 — Compass Fix & Geographic Orientation

## Issue

The compass was showing North as exactly perpendicular (90°) to the bridge span. Based on a satellite image of the actual Tacoma Narrows Bridge, this is not geographically accurate.

## Root Cause

The bridge is modeled along the game X axis (East–West by assumption), but the real Tacoma Narrows Bridge runs ENE–WSW — approximately 15° north of due East. Using tower coordinates:

- ΔLat ≈ 334 m north, ΔLon ≈ 1232 m east
- Bridge bearing = atan(334 / 1232) ≈ **15° above East (ENE)**

This means the game -Z axis (perpendicular to bridge, treated as "North") actually corresponds to geographic **NNW (345°)**, not true North (0°).

## Fix

Added a `GEOGRAPHIC_CORRECTION` constant of `-15°` to the compass heading calculation in `Compass.gd`. The correction shifts the displayed heading so that the N label aligns with real-world North rather than game -Z.

When facing perpendicular to the bridge (game -Z), the compass now correctly shows **NNW** instead of N — matching the satellite image.
