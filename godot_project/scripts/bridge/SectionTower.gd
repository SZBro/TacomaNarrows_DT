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

# ── Entry Point ────────────────────────────────────────────
func _ready():
	_build_tower()

# ── Build ──────────────────────────────────────────────────
func _build_tower():
	for child in get_children():
		child.free()					# ← free() not queue_free()

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
