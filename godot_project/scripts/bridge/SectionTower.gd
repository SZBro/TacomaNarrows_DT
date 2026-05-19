@tool
extends Node3D

# ── Configuration ──────────────────────────────────────────
@export var tower_height: float = 148.0
@export var leg_spacing: float = 20.0
@export var leg_width: float = 2.5
@export var leg_depth: float = 5.0
@export var deck_height: float = 48.0
@export var deck_opening: float = 14.0
@export var panels_below: int = 4
@export var panels_above: int = 2

@export var rebuild: bool = false:
	set(value):
		_build_tower()

var _base_position:     Vector3    = Vector3.ZERO
var _base_rotation_deg: Vector3    = Vector3.ZERO
var _data_engine:       Node       = null
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
func _ready():
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
		_apply_stress_shader(self)
		DataEngine.stress_overlay_changed.connect(_on_stress_overlay_changed)

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
		(mat as ShaderMaterial).set_shader_parameter("stress_level", _stress_current)

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

# Towers respond to wind sway (rotation_degrees.z) and seismic jitter (position x/z).
# Scale: wind × 0.004 → max ~0.3° lean at 67 km/h; seismic × 0.8 → visible shake.
func receive_data(data: Dictionary) -> void:
	last_data = data
	var wind_speed: float    = data.get("wind_speed", 0.0)
	var wind_dir_rad: float  = deg_to_rad(data.get("wind_direction", 270.0))
	var seismic: float       = data.get("seismic_vibration", 0.0)
	var t: float             = data.get("sim_time", 0.0)
	var lateral_lean: float  = sin(wind_dir_rad) * (wind_speed / 3.6) * 0.003
	var jitter_x: float      = sin(t * 13.7)       * seismic * 0.15
	var jitter_z: float      = sin(t * 17.3 + 1.0) * seismic * 0.15
	_target_pos = _base_position     + Vector3(jitter_x, 0.0, jitter_z)
	_target_rot = _base_rotation_deg + Vector3(0.0, 0.0, lateral_lean)

	if DataEngine.stress_overlay_enabled:
		_stress_target = DataEngine.stress_continuous(data)

# ── Build ──────────────────────────────────────────────────
func _build_tower():
	for child in get_children():
		remove_child(child)
		child.free()

	var combiner = CSGCombiner3D.new()
	combiner.name = "Geometry"
	add_child(combiner)
	combiner.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

	_build_legs(combiner)
	_build_pedestal(combiner)
	_build_panels_below_deck(combiner)
	_build_deck_opening(combiner)
	_build_panels_above_deck(combiner)
	_build_top_cap(combiner)

# ── Two Green Legs Full Height ─────────────────────────────
func _build_legs(parent: Node):
	const LEG_COLOR := Color(0.47, 0.53, 0.45)

	var left_z  = -(leg_spacing / 2.0)
	var right_z =  (leg_spacing / 2.0)

	_add_box(parent, "LegLeft",
		Vector3(leg_depth, tower_height, leg_width),
		Vector3(0, tower_height / 2.0, left_z),
		LEG_COLOR)

	_add_box(parent, "LegRight",
		Vector3(leg_depth, tower_height, leg_width),
		Vector3(0, tower_height / 2.0, right_z),
		LEG_COLOR)

# ── Concrete Pedestal At Base ──────────────────────────────
func _build_pedestal(parent: Node):
	const PEDESTAL_HEIGHT := 6.0
	const PEDESTAL_EXTRA  := 2.0    # just slightly wider than legs
	const PEDESTAL_COLOR   := Color(0.60, 0.62, 0.58)

	_add_box(parent, "Pedestal",
		Vector3(leg_depth + PEDESTAL_EXTRA,
				PEDESTAL_HEIGHT,
				leg_spacing + PEDESTAL_EXTRA),    # ← removed leg_width extra
		Vector3(0, -(PEDESTAL_HEIGHT * 0.75), 0),
		PEDESTAL_COLOR)

# ── Braced Panels BELOW Deck ───────────────────────────────
func _build_panels_below_deck(parent: Node):
	const BEAM_THICKNESS  := 1.5
	const BRACE_THICKNESS := 0.4
	const BEAM_COLOR       := Color(0.47, 0.53, 0.45)
	const BRACE_COLOR      := Color(0.42, 0.48, 0.40)

	var panel_height = deck_height / float(panels_below)
	var span         = leg_spacing + leg_width

	for i in range(panels_below):
		var bot_y    = i * panel_height
		var top_y    = bot_y + panel_height
		var center_y = (bot_y + top_y) / 2.0

		_add_box(parent, "BelowBeam_%d" % i,
			Vector3(leg_depth, BEAM_THICKNESS, span),
			Vector3(0, bot_y, 0),
			BEAM_COLOR)

		_add_single_x(parent, "BelowX_%d" % i,
			center_y, panel_height, span,
			BRACE_THICKNESS, BRACE_COLOR)

	_add_box(parent, "BelowBeam_Top",
		Vector3(leg_depth, BEAM_THICKNESS, span),
		Vector3(0, deck_height, 0),
		BEAM_COLOR)

# ── Deck Opening ───────────────────────────────────────────
func _build_deck_opening(parent: Node):
	const BEAM_THICKNESS := 1.5
	const BEAM_COLOR      := Color(0.47, 0.53, 0.45)

	var span = leg_spacing + leg_width

	_add_box(parent, "DeckBeam_Bot",
		Vector3(leg_depth, BEAM_THICKNESS, span),
		Vector3(0, deck_height, 0),
		BEAM_COLOR)

	_add_box(parent, "DeckBeam_Top",
		Vector3(leg_depth, BEAM_THICKNESS, span),
		Vector3(0, deck_height + deck_opening, 0),
		BEAM_COLOR)

# ── Braced Panels ABOVE Deck ───────────────────────────────
func _build_panels_above_deck(parent: Node):
	const BEAM_THICKNESS  := 1.5
	const BRACE_THICKNESS := 0.4
	const BEAM_COLOR       := Color(0.47, 0.53, 0.45)
	const BRACE_COLOR      := Color(0.42, 0.48, 0.40)

	var above_start  = deck_height + deck_opening
	var above_height = tower_height - above_start - 6.0
	var panel_height = above_height / float(panels_above)
	var span         = leg_spacing + leg_width

	for i in range(panels_above):
		var bot_y    = above_start + (i * panel_height)
		var top_y    = bot_y + panel_height
		var center_y = (bot_y + top_y) / 2.0

		_add_box(parent, "AboveBeam_%d" % i,
			Vector3(leg_depth, BEAM_THICKNESS, span),
			Vector3(0, bot_y, 0),
			BEAM_COLOR)

		_add_single_x(parent, "AboveX_%d" % i,
			center_y, panel_height, span,
			BRACE_THICKNESS, BRACE_COLOR)

	_add_box(parent, "AboveBeam_Top",
		Vector3(leg_depth, BEAM_THICKNESS, span),
		Vector3(0, tower_height - 6.0, 0),
		BEAM_COLOR)

# ── Top Cap ────────────────────────────────────────────────
func _build_top_cap(parent: Node):
	const CAP_COLOR := Color(0.47, 0.53, 0.45)
	var span = leg_spacing + leg_width

	_add_box(parent, "TopCap",
		Vector3(leg_depth, 3.0, span),
		Vector3(0, tower_height - 1.5, 0),
		CAP_COLOR)

# ── Single X Per Panel ─────────────────────────────────────
func _add_single_x(parent: Node, brace_name: String,
		center_y: float, panel_h: float, span: float,
		thickness: float, color: Color):

	var diag_length = sqrt(pow(span, 2) + pow(panel_h, 2))
	var diag_angle  = rad_to_deg(atan2(panel_h, span))

	for k in range(2):
		var d = CSGBox3D.new()
		d.name = brace_name + ("_A" if k == 0 else "_B")
		d.size = Vector3(thickness, thickness, diag_length)
		d.position = Vector3(0, center_y, 0)
		d.rotation_degrees = Vector3(
			diag_angle if k == 0 else -diag_angle, 0, 0)

		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		d.material = mat
		parent.add_child(d)
		d.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ── Helpers ────────────────────────────────────────────────
func _add_box(parent: Node, box_name: String, size: Vector3,
		pos: Vector3, color: Color) -> CSGBox3D:
	var box = CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat

	parent.add_child(box)
	box.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
	return box
