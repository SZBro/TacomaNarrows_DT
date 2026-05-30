extends Node3D
## CameraManager — global per-frame camera constraints.
## Prevents cameras from going below water, pushes orbit camera above terrain,
## and drives the underwater fog overlay.
## Added to the scene by Main.gd.

# ── Constants ─────────────────────────────────────────────────────────────────
## Minimum world-Y for any camera (water surface + standing eye height).
const MIN_CAM_Y:          float = 1.7
## Camera Y below which the underwater overlay begins fading in.
const OVERLAY_FADE_START: float = 5.0
## How far above a terrain hit-point the orbit camera must stay.
const TERRAIN_CLEARANCE:  float = 2.0
## Base color of the underwater overlay (alpha driven at runtime).
const OVERLAY_COLOR:      Color = Color(0.02, 0.04, 0.14)

# ── Internal ──────────────────────────────────────────────────────────────────
var _overlay:      ColorRect
var _canvas_layer: CanvasLayer

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Full-screen overlay — sits above all other layers.
	_canvas_layer       = CanvasLayer.new()
	_canvas_layer.layer = 99

	_overlay               = ColorRect.new()
	_overlay.color         = Color(OVERLAY_COLOR, 0.0)
	_overlay.anchor_right  = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_overlay)
	add_child(_canvas_layer)

# ── Per-frame constraints ─────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	var vp := get_viewport()
	if not vp:
		return
	var cam := vp.get_camera_3d()
	if not cam:
		return

	var parent     := cam.get_parent()
	var is_body:   bool = parent is CharacterBody3D

	if is_body:
		_clamp_character_body(parent as CharacterBody3D, cam)
	else:
		_push_above_terrain(cam)
		_clamp_orbit_camera(cam)

	# Underwater overlay driven by the camera's actual world Y.
	var cam_y: float = cam.global_position.y
	var alpha: float = clampf(
		remap(cam_y, OVERLAY_FADE_START, 0.0, 0.0, 1.0), 0.0, 1.0)
	_overlay.color = Color(OVERLAY_COLOR, alpha)

# ── Water floor — CharacterBody3D ─────────────────────────────────────────────
func _clamp_character_body(body: CharacterBody3D, cam: Camera3D) -> void:
	# Derive the minimum body-Y such that the camera stays at MIN_CAM_Y.
	var cam_local_y: float = cam.position.y  # e.g. 1.6
	var min_body_y:  float = MIN_CAM_Y - cam_local_y
	if body.global_position.y < min_body_y:
		body.global_position.y = min_body_y
		# Cancel downward momentum so the body doesn't fight the clamp.
		if body.velocity.y < 0.0:
			body.velocity.y = 0.0

# ── Water floor — Camera3D directly (orbit camera) ───────────────────────────
func _clamp_orbit_camera(cam: Camera3D) -> void:
	if cam.global_position.y < MIN_CAM_Y:
		cam.global_position.y = MIN_CAM_Y

# ── Terrain collision — orbit camera ─────────────────────────────────────────
func _push_above_terrain(cam: Camera3D) -> void:
	var space := get_world_3d().direct_space_state
	if not space:
		return
	# Cast from slightly above the camera straight down.
	var origin := cam.global_position + Vector3(0.0, 5.0, 0.0)
	var target := cam.global_position - Vector3(0.0, 200.0, 0.0)
	var params := PhysicsRayQueryParameters3D.create(origin, target)
	var hit    := space.intersect_ray(params)
	if hit.is_empty():
		return
	var terrain_y: float = (hit["position"] as Vector3).y
	if cam.global_position.y < terrain_y + TERRAIN_CLEARANCE:
		cam.global_position.y = terrain_y + TERRAIN_CLEARANCE
