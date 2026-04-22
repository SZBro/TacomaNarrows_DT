@tool
extends Node3D

# ── Configuration ──────────────────────────────────────────
@export var approach_length: float = 335.0
@export var deck_width: float = 14.0
@export var deck_thickness: float = 3.0
@export var girder_height: float = 4.0

@export var rebuild: bool = false:
	set(value):
		_build_approach()

# ── Entry Point ────────────────────────────────────────────
func _ready():
	_build_approach()

# ── Build ──────────────────────────────────────────────────
func _build_approach():
	for child in get_children():
		child.free()

	var combiner = CSGCombiner3D.new()
	combiner.name = "Geometry"
	add_child(combiner)
	combiner.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

	_build_deck(combiner)
	_build_girders(combiner)

# ── Road Deck ──────────────────────────────────────────────
func _build_deck(parent: Node):
	const DECK_COLOR := Color(0.40, 0.42, 0.38)

	_add_box(parent, "Deck",
		Vector3(approach_length, deck_thickness, deck_width),
		Vector3(0, 0, 0),
		DECK_COLOR)

# ── Side Girders ───────────────────────────────────────────
func _build_girders(parent: Node):
	const GIRDER_THICKNESS := 0.5
	const GIRDER_COLOR      := Color(0.47, 0.53, 0.45)

	var left_z  = -(deck_width / 2.0)
	var right_z =  (deck_width / 2.0)
	var girder_y = -(girder_height / 2.0)

	_add_box(parent, "GirderLeft",
		Vector3(approach_length, girder_height, GIRDER_THICKNESS),
		Vector3(0, girder_y, left_z),
		GIRDER_COLOR)

	_add_box(parent, "GirderRight",
		Vector3(approach_length, girder_height, GIRDER_THICKNESS),
		Vector3(0, girder_y, right_z),
		GIRDER_COLOR)

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
