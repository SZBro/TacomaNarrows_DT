@tool
extends Node3D

# ── Configuration ──────────────────────────────────────────
@export var deck_length: float = 106.6
@export var deck_width: float = 14.0
@export var truss_depth: float = 10.0
@export var truss_segments: int = 7

@export var rebuild: bool = false:
	set(value):
		_build_section()

# ── Entry Point ────────────────────────────────────────────
func _ready():
	_build_section()

# ── Build ──────────────────────────────────────────────────
func _build_section():
	for child in get_children():
		child.queue_free()

	var combiner = CSGCombiner3D.new()
	combiner.name = "Geometry"
	add_child(combiner)
	combiner.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

	_build_road_deck(combiner)
	_build_truss_left(combiner)
	_build_truss_right(combiner)
	_build_cross_struts(combiner)
	_build_bottom_diagonals(combiner)

# ── Road Deck (thin slab on top) ───────────────────────────
func _build_road_deck(parent: Node):
	const ROAD_THICKNESS     := 0.8
	const ROAD_COLOR          := Color(0.40, 0.42, 0.38)

	var road_y = truss_depth / 2.0

	_add_box(parent, "RoadDeck",
		Vector3(deck_length, ROAD_THICKNESS, deck_width),
		Vector3(0, road_y, 0),
		ROAD_COLOR)

# ── Truss Face (one side) ──────────────────────────────────
func _build_truss_face(parent: Node, side_z: float, side_name: String):
	const CHORD_THICKNESS     := 0.4
	const VERTICAL_THICKNESS  := 0.3
	const DIAGONAL_THICKNESS  := 0.3
	const TRUSS_COLOR          := Color(0.47, 0.53, 0.45)

	var top_y    =  truss_depth / 2.0
	var bottom_y = -truss_depth / 2.0

	# Top chord
	_add_box(parent, side_name + "_TopChord",
		Vector3(deck_length, CHORD_THICKNESS, CHORD_THICKNESS),
		Vector3(0, top_y, side_z),
		TRUSS_COLOR)

	# Bottom chord
	_add_box(parent, side_name + "_BottomChord",
		Vector3(deck_length, CHORD_THICKNESS, CHORD_THICKNESS),
		Vector3(0, bottom_y, side_z),
		TRUSS_COLOR)

	# Vertical and diagonal members
	var segment_spacing = deck_length / float(truss_segments)
	var start_x = -(deck_length / 2.0)

	for i in range(truss_segments + 1):
		var x_pos = start_x + (i * segment_spacing)

		# Vertical member
		_add_box(parent, side_name + "_Vert_%d" % i,
			Vector3(VERTICAL_THICKNESS, truss_depth, VERTICAL_THICKNESS),
			Vector3(x_pos, 0, side_z),
			TRUSS_COLOR)

		# Diagonal member (alternating direction)
		if i < truss_segments:
			var diag_x = x_pos + (segment_spacing / 2.0)
			var diag_length = sqrt(
				pow(segment_spacing, 2) + pow(truss_depth, 2)
			)
			var diag_angle = rad_to_deg(
				atan2(truss_depth, segment_spacing)
			)

			# Alternate direction each segment
			var angle = diag_angle if i % 2 == 0 else -diag_angle

			var diag = CSGBox3D.new()
			diag.name = side_name + "_Diag_%d" % i
			diag.size = Vector3(diag_length, DIAGONAL_THICKNESS, DIAGONAL_THICKNESS)
			diag.position = Vector3(diag_x, 0, side_z)
			diag.rotation_degrees = Vector3(0, 0, angle)

			var mat = StandardMaterial3D.new()
			mat.albedo_color = TRUSS_COLOR
			diag.material = mat

			parent.add_child(diag)
			diag.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ── Left and Right Truss Faces ─────────────────────────────
func _build_truss_left(parent: Node):
	_build_truss_face(parent, -(deck_width / 2.0), "Left")

func _build_truss_right(parent: Node):
	_build_truss_face(parent,  (deck_width / 2.0), "Right")

# ── Cross Struts (connecting left and right across width) ──
func _build_cross_struts(parent: Node):
	const STRUT_THICKNESS     := 0.3
	const STRUT_COLOR          := Color(0.42, 0.48, 0.40)

	var top_y    =  truss_depth / 2.0
	var bottom_y = -truss_depth / 2.0
	var segment_spacing = deck_length / float(truss_segments)
	var start_x = -(deck_length / 2.0)

	for i in range(truss_segments + 1):
		var x_pos = start_x + (i * segment_spacing)

		# Top strut
		_add_box(parent, "StrutTop_%d" % i,
			Vector3(STRUT_THICKNESS, STRUT_THICKNESS, deck_width),
			Vector3(x_pos, top_y, 0),
			STRUT_COLOR)

		# Bottom strut
		_add_box(parent, "StrutBottom_%d" % i,
			Vector3(STRUT_THICKNESS, STRUT_THICKNESS, deck_width),
			Vector3(x_pos, bottom_y, 0),
			STRUT_COLOR)

func _build_bottom_diagonals(parent: Node):
	const DIAG_THICKNESS      := 0.3
	const DIAG_COLOR           := Color(0.42, 0.48, 0.40)

	var bottom_y = -(truss_depth / 2.0)
	var segment_spacing = deck_length / float(truss_segments)
	var start_x = -(deck_length / 2.0)

	for i in range(truss_segments):
		var x_pos = start_x + (i * segment_spacing)
		var x_center = x_pos + (segment_spacing / 2.0)

		var diag_length = sqrt(
			pow(segment_spacing, 2) + pow(deck_width, 2)
		)
		var diag_angle = rad_to_deg(
			atan2(deck_width, segment_spacing)
		)

		# Diagonal going one way
		var d1 = CSGBox3D.new()
		d1.name = "BottomDiag_%d_A" % i
		d1.size = Vector3(diag_length, DIAG_THICKNESS, DIAG_THICKNESS)
		d1.position = Vector3(x_center, bottom_y, 0)
		d1.rotation_degrees = Vector3(0, diag_angle, 0)    # ← Y axis not X

		var mat1 = StandardMaterial3D.new()
		mat1.albedo_color = DIAG_COLOR
		d1.material = mat1
		parent.add_child(d1)
		d1.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

		# Diagonal going other way
		var d2 = CSGBox3D.new()
		d2.name = "BottomDiag_%d_B" % i
		d2.size = Vector3(diag_length, DIAG_THICKNESS, DIAG_THICKNESS)
		d2.position = Vector3(x_center, bottom_y, 0)
		d2.rotation_degrees = Vector3(0, -diag_angle, 0)   # ← Y axis not X

		var mat2 = StandardMaterial3D.new()
		mat2.albedo_color = DIAG_COLOR
		d2.material = mat2
		parent.add_child(d2)
		d2.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ── Helpers ────────────────────────────────────────────────
func _add_box(parent: Node, box_name: String, size: Vector3, pos: Vector3, color: Color) -> CSGBox3D:
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
