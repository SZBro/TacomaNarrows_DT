extends Node3D

var _orbit_cam:  Camera3D
var _person_cam: CharacterBody3D

func _ready() -> void:
	add_child(preload("res://scripts/SceneEnvironment.gd").new())

	# ── Cameras ───────────────────────────────────────────────
	_orbit_cam = preload("res://scripts/OrbitCamera.gd").new()
	add_child(_orbit_cam)

	_person_cam = preload("res://scenes/camera/PersonCamera.tscn").instantiate()
	_person_cam.position = Vector3(0.0, 60.0, 0.0)  # safe starting height, falls to terrain
	add_child(_person_cam)

	# ── Camera manager (water clamp, terrain pushback, underwater overlay) ──
	add_child(preload("res://scripts/CameraManager.gd").new())

	# ── UI ────────────────────────────────────────────────────
	add_child(preload("res://scenes/ui/DebugOverlay.tscn").instantiate())
	var top_bar := preload("res://scripts/ui/TopBar.gd").new()
	add_child(top_bar)
	add_child(preload("res://scripts/bridge/HighlightRing.gd").new())
	add_child(preload("res://scenes/ui/Compass.tscn").instantiate())

	var stream_panel := preload("res://scripts/ui/DataStreamPanel.gd").new()
	add_child(stream_panel)
	top_bar.add_toggle("Streams", false,
			func(on: bool) -> void: stream_panel.set_panel_visible(on))

	var flow_panel := preload("res://scenes/ui/DataFlowPanel.tscn").instantiate()
	add_child(flow_panel)
	top_bar.add_toggle("Flow", false,
			func(on: bool) -> void: flow_panel.set_panel_visible(on))

	# ── Walk mode toggle ──────────────────────────────────────
	top_bar.add_toggle("Walk", false, func(on: bool) -> void:
		if on:
			_activate_walk()
		else:
			_activate_orbit()
	)

	# ── HTerrain collision ────────────────────────────────────
	# Enable physics collision on the terrain so PersonCamera and raycasts work.
	var terrain := get_node_or_null("HTerrain")
	if terrain and terrain.has_method("set_collision_enabled"):
		terrain.set_collision_enabled(true)

# ── Camera switching ──────────────────────────────────────────────────────────
const _SPAWN_X: float = -700.0
const _SPAWN_Z: float =  0.0
const _SPAWN_FACE_EAST: float = -PI * 0.5  # rotation.y so W key moves toward +X

func _activate_walk() -> void:
	var surface_y := _surface_y_at(_SPAWN_X, _SPAWN_Z)
	var spawn     := Vector3(_SPAWN_X, surface_y + 0.1, _SPAWN_Z)
	_person_cam.call("activate", spawn, _SPAWN_FACE_EAST, 0.0)

func _surface_y_at(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	if not space:
		return 48.0
	var params := PhysicsRayQueryParameters3D.create(
			Vector3(x, 300.0, z), Vector3(x, -50.0, z))
	var hit := space.intersect_ray(params)
	return (hit["position"] as Vector3).y if not hit.is_empty() else 48.0


func _activate_orbit() -> void:
	_person_cam.call("deactivate")
	_orbit_cam.make_current()
