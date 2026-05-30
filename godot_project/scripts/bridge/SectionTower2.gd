@tool
extends Node3D
## SectionTower2 — tower design matching the 1950 replacement Tacoma Narrows Bridge.
## Thick concrete legs, single large X-brace, horizontal portal beams.
## Drop-in replacement geometry; same DataEngine interface as SectionTower.

# ── Configuration ──────────────────────────────────────────
@export var tower_height:  float = 148.0
@export var leg_spacing:   float = 34.0   # Z center-to-center distance between legs
@export var leg_width:     float = 11.0   # Z thickness of each leg
@export var leg_depth:     float = 9.0    # X thickness of each leg
@export var deck_height:   float = 48.0   # Y where the road deck passes through
@export var deck_opening:  float = 16.0   # vertical clearance for traffic

@export var rebuild: bool = false:
	set(value):
		_build_tower()

# ── Runtime State ──────────────────────────────────────────
var _base_position:     Vector3 = Vector3.ZERO
var _base_rotation_deg: Vector3 = Vector3.ZERO
var _data_engine:       Node    = null
var last_data:          Dictionary = {}

# ── Motion Lerp ────────────────────────────────────────────
@export var motion_lerp_speed: float = 4.0

var _target_pos:  Vector3 = Vector3.ZERO
var _target_rot:  Vector3 = Vector3.ZERO
var _current_pos: Vector3 = Vector3.ZERO
var _current_rot: Vector3 = Vector3.ZERO

# ── Stress Shader ──────────────────────────────────────────
@export var stress_lerp_speed: float = 3.0

var _stress_materials: Array = []
var _stress_target:    float = 0.0
var _stress_current:   float = 0.0
var _outline_mat:      ShaderMaterial = null

# ── Entry Point ────────────────────────────────────────────
func _ready() -> void:
	_build_tower()
	if not Engine.is_editor_hint():
		_base_position     = position
		_base_rotation_deg = rotation_degrees
		_current_pos = position
		_current_rot = rotation_degrees
		_target_pos  = position
		_target_rot  = rotation_degrees
		_data_engine = get_node("/root/DataEngine")
		_data_engine.register_section(self)
		_add_selection_area()
		_add_leg_collision()
		_apply_stress_shader(self)
		DataEngine.stress_overlay_changed.connect(_on_stress_overlay_changed)

func _add_leg_collision() -> void:
	for side in [-1, 1]:
		var sb  := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size     = Vector3(leg_depth, tower_height, leg_width)
		col.shape    = box
		col.position = Vector3(0.0, tower_height * 0.5, side * leg_spacing * 0.5)
		sb.add_child(col)
		add_child(sb)

func _add_selection_area() -> void:
	var area := Area3D.new()
	area.name = "SelectionArea"
	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size     = Vector3(leg_depth + 4.0, tower_height, leg_spacing + 6.0)
	col.shape    = box
	col.position = Vector3(0.0, tower_height * 0.5, 0.0)
	area.add_child(col)
	add_child(area)

func _exit_tree() -> void:
	if _data_engine:
		_data_engine.unregister_section(self)

func set_highlighted(on: bool) -> void:
	if on and _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/selection_outline.gdshader")
	for mat in _stress_materials:
		(mat as ShaderMaterial).next_pass = _outline_mat if on else null

func _on_stress_overlay_changed(enabled: bool) -> void:
	if not enabled:
		_stress_target  = 0.0
		_stress_current = 0.0
		for mat in _stress_materials:
			if is_instance_valid(mat):
				(mat as ShaderMaterial).set_shader_parameter("stress_level", 0.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_current_pos = _current_pos.lerp(_target_pos, delta * motion_lerp_speed)
	_current_rot = _current_rot.lerp(_target_rot, delta * motion_lerp_speed)
	position         = _current_pos
	rotation_degrees = _current_rot
	if _stress_materials.is_empty():
		return
	_stress_current = lerpf(_stress_current, _stress_target, delta * stress_lerp_speed)
	for mat in _stress_materials:
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter("stress_level", _stress_current)

func receive_data(data: Dictionary) -> void:
	last_data = data
	var wind_speed: float   = data.get("wind_speed", 0.0)
	var wind_dir_rad: float = deg_to_rad(data.get("wind_direction", 270.0))
	var seismic: float      = data.get("seismic_vibration", 0.0)
	var t: float            = data.get("sim_time", 0.0)
	var lateral_lean: float = sin(wind_dir_rad) * (wind_speed / 3.6) * 0.003
	var jitter_x: float     = sin(t * 13.7)       * seismic * 0.15
	var jitter_z: float     = sin(t * 17.3 + 1.0) * seismic * 0.15
	_target_pos = _base_position     + Vector3(jitter_x, 0.0, jitter_z)
	_target_rot = _base_rotation_deg + Vector3(0.0, 0.0, lateral_lean)
	if DataEngine.stress_overlay_enabled:
		_stress_target = DataEngine.stress_continuous(data)

# ── Stress Shader Helpers ──────────────────────────────────
func _apply_stress_shader(node: Node) -> void:
	for child in node.get_children():
		if child is CSGBox3D or child is CSGCylinder3D:
			if child.material == null:
				child.material = StandardMaterial3D.new()
			var smat := ShaderMaterial.new()
			smat.shader = load("res://shaders/stress_overlay.gdshader")
			child.material.next_pass = smat
			_stress_materials.append(smat)
		if child.get_child_count() > 0:
			_apply_stress_shader(child)

# ── Build ──────────────────────────────────────────────────
func _build_tower() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var root := CSGCombiner3D.new()
	root.name = "Geometry"
	add_child(root)
	root.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

	_build_legs(root)
	_build_pedestal(root)
	_build_deck_strut(root)
	_build_lower_portal(root)
	_build_x_brace(root)
	_build_upper_portal(root)
	_build_saddle_caps(root)

# ── Two Thick Concrete Legs ────────────────────────────────
func _build_legs(parent: Node) -> void:
	const LEG_COLOR := Color(0.82, 0.82, 0.78)
	var left_z  := -(leg_spacing * 0.5)
	var right_z :=  (leg_spacing * 0.5)

	_add_box(parent, "LegLeft",
		Vector3(leg_depth, tower_height, leg_width),
		Vector3(0.0, tower_height * 0.5, left_z),
		LEG_COLOR)

	_add_box(parent, "LegRight",
		Vector3(leg_depth, tower_height, leg_width),
		Vector3(0.0, tower_height * 0.5, right_z),
		LEG_COLOR)

# ── Wide Base Pedestal ─────────────────────────────────────
func _build_pedestal(parent: Node) -> void:
	const PED_HEIGHT := 8.0
	const PED_COLOR  := Color(0.72, 0.72, 0.68)
	_add_box(parent, "Pedestal",
		Vector3(leg_depth + 4.0, PED_HEIGHT, leg_spacing + leg_width),
		Vector3(0.0, -(PED_HEIGHT * 0.6), 0.0),
		PED_COLOR)

# ── Thin Strut at Road Deck Level ─────────────────────────
# The deck passes between the legs here; this strut is a real structural element.
func _build_deck_strut(parent: Node) -> void:
	const STRUT_H    := 3.0
	const STRUT_COLOR := Color(0.79, 0.79, 0.75)
	var inner_span := leg_spacing - leg_width
	_add_box(parent, "DeckStrut",
		Vector3(leg_depth * 0.85, STRUT_H, inner_span),
		Vector3(0.0, deck_height + deck_opening * 0.5, 0.0),
		STRUT_COLOR)

# ── Lower Portal Beam — bottom boundary of the X frame ────
# Positioned at 60 % of tower height; legs are bare below this.
func _build_lower_portal(parent: Node) -> void:
	const PORTAL_H    := 6.0
	const PORTAL_COLOR := Color(0.78, 0.78, 0.74)
	var inner_span := leg_spacing - leg_width
	var y := tower_height * 0.60
	_add_box(parent, "LowerPortal",
		Vector3(leg_depth, PORTAL_H, inner_span),
		Vector3(0.0, y, 0.0),
		PORTAL_COLOR)

# ── Single Large X-Brace ───────────────────────────────────
# Spans only the upper window between the two portal beams.
func _build_x_brace(parent: Node) -> void:
	const BRACE_THICK := 3.0
	const BRACE_COLOR  := Color(0.73, 0.73, 0.69)

	# Window: from lower portal centre to upper portal centre.
	var y_bot: float     = tower_height * 0.60
	var y_top: float     = tower_height - 18.0
	var span_h: float    = y_top - y_bot          # ≈ 41 units
	var inner_gap: float = leg_spacing - leg_width # = 23 units → angle ≈ 60°
	var center_y: float  = (y_bot + y_top) * 0.5

	# Long axis along Z; rotating around X makes it diagonal in the Y-Z plane.
	var diag_len: float   = sqrt(inner_gap * inner_gap + span_h * span_h)
	var diag_angle: float = rad_to_deg(atan2(span_h, inner_gap))

	for k in range(2):
		var d := CSGBox3D.new()
		d.name = "XBrace_" + ("A" if k == 0 else "B")
		d.size = Vector3(BRACE_THICK, BRACE_THICK, diag_len)
		d.position = Vector3(0.0, center_y, 0.0)
		d.rotation_degrees = Vector3(
			diag_angle if k == 0 else -diag_angle, 0.0, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BRACE_COLOR
		d.material = mat
		parent.add_child(d)
		d.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ── Upper Portal Beam — top boundary of the X frame ───────
func _build_upper_portal(parent: Node) -> void:
	const PORTAL_H    := 7.0
	const PORTAL_COLOR := Color(0.78, 0.78, 0.74)
	var inner_span := leg_spacing - leg_width
	_add_box(parent, "UpperPortal",
		Vector3(leg_depth, PORTAL_H, inner_span),
		Vector3(0.0, tower_height - 18.0, 0.0),
		PORTAL_COLOR)

# ── Saddle Caps at Peak ────────────────────────────────────
func _build_saddle_caps(parent: Node) -> void:
	const CAP_COLOR := Color(0.80, 0.80, 0.76)
	var left_z  := -(leg_spacing * 0.5)
	var right_z :=  (leg_spacing * 0.5)

	for i in range(2):
		var z: float = left_z if i == 0 else right_z
		_add_box(parent, "Saddle_" + str(i),
			Vector3(leg_depth + 1.0, 5.0, leg_width + 2.0),
			Vector3(0.0, tower_height + 1.0, z),
			CAP_COLOR)

# ── Helper ─────────────────────────────────────────────────
func _add_box(parent: Node, box_name: String, size: Vector3,
		pos: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name     = box_name
	box.size     = size
	box.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	parent.add_child(box)
	box.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
	return box
