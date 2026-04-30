@tool
extends Node3D

# ── Configuration ──────────────────────────────────────────
# Tower saddle points match SectionTower: height=148, scene positions -426 / +422.785
@export var tower_w_pos: Vector3 = Vector3(-426, 148, 0)
@export var tower_e_pos: Vector3 = Vector3(423, 148, 0)

# Cable geometry
@export var cable_radius: float = 0.9
@export var cable_segments: int = 160

# Z spacing: legs are at z = ±(leg_spacing/2) = ±10, so cables sit directly over them
@export var cable_spacing_z: float = 20.0

# Hangers
@export var hanger_spacing: float = 14.0

# Deck surface: section centers at world y=46, road deck local y=5 → world y=51
@export var deck_y: float = 51.0

# Sag from tower top to midspan cable. Real TNB diagram puts midspan ~35% of
# tower-above-deck clearance, so: 148 - 65 = 83, which is 32 units above deck (y=51).
@export var main_span_sag: float = 65.0

# Approach span sag: slight parabolic bow below the anchor-to-tower chord
@export var side_span_sag: float = 8.0

# Anchorage: approach decks end ~320 units past towers; anchor just beyond
@export var anchorage_distance: float = 330.0

# Cable height at the anchor point. Set below deck (y=51) but above ground so
# the anchor block sits partially embedded and the back-stay cable runs at a
# shallow angle above the approach deck for most of its length.
@export var anchor_y: float = 40.0

# Anchor block dimensions (large concrete mass, partially embedded in ground)
@export var anchor_depth: float = 48.0
@export var anchor_height: float = 28.0
@export var anchor_width: float = 38.0

@export var rebuild: bool = false:
	set(value):
		_build_cables()

# ── Entry Point ────────────────────────────────────────────
func _ready():
	_build_cables()

# ── Build ──────────────────────────────────────────────────
func _build_cables():
	print("BUILD CABLES CALLED")
	for child in get_children():
		child.free()

	_build_main_cable("CableLeft",  -cable_spacing_z / 2.0)
	_build_main_cable("CableRight",  cable_spacing_z / 2.0)
	_build_anchorages()

# ── Main Cable ─────────────────────────────────────────────
func _build_main_cable(cable_name: String, z_offset: float):
	const CABLE_COLOR := Color(0.73, 0.73, 0.70)

	var curve = Curve3D.new()
	var west_anchor_x := tower_w_pos.x - anchorage_distance
	var east_anchor_x := tower_e_pos.x + anchorage_distance
	var total_x := east_anchor_x - west_anchor_x
	var tower_y := tower_w_pos.y  # both towers same height

	for i in range(cable_segments + 1):
		var t := float(i) / float(cable_segments)
		var x := west_anchor_x + t * total_x
		var y: float

		if x <= tower_w_pos.x:
			# West approach: parabolic arc from anchor (low) rising to tower saddle
			var ts := (x - west_anchor_x) / (tower_w_pos.x - west_anchor_x)
			var y_chord := anchor_y + ts * (tower_y - anchor_y)
			y = y_chord - 4.0 * side_span_sag * ts * (1.0 - ts)

		elif x <= tower_e_pos.x:
			# Main span: symmetric parabolic dip between tower saddles
			var ts := (x - tower_w_pos.x) / (tower_e_pos.x - tower_w_pos.x)
			y = tower_y - 4.0 * main_span_sag * ts * (1.0 - ts)

		else:
			# East approach: parabolic arc from tower saddle descending to anchor
			var ts := (x - tower_e_pos.x) / (east_anchor_x - tower_e_pos.x)
			var y_chord := tower_y + ts * (anchor_y - tower_y)
			y = y_chord - 4.0 * side_span_sag * ts * (1.0 - ts)

		curve.add_point(Vector3(x, y, z_offset))

	_build_cable_geometry(cable_name, curve, CABLE_COLOR)
	_build_hangers(cable_name, curve, z_offset)

# ── Cable Cylinders Along Curve ────────────────────────────
func _build_cable_geometry(cable_name: String, curve: Curve3D, color: Color):
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var metallic_mat := mat
	metallic_mat.metallic = 0.3
	metallic_mat.roughness = 0.6

	var baked_length := curve.get_baked_length()

	for i in range(cable_segments):
		var p0 := curve.sample_baked(float(i) / float(cable_segments) * baked_length)
		var p1 := curve.sample_baked(float(i + 1) / float(cable_segments) * baked_length)

		var distance := p0.distance_to(p1)
		if distance < 0.01:
			continue

		var seg := CSGCylinder3D.new()
		seg.name = cable_name + "_Seg_%d" % i
		seg.radius = cable_radius
		seg.height = distance
		seg.material = mat
		seg.position = (p0 + p1) / 2.0

		var direction := (p1 - p0).normalized()
		if not direction.is_zero_approx() and not direction.is_equal_approx(Vector3.UP):
			seg.quaternion = Quaternion(Vector3.UP, direction)

		add_child(seg)
		seg.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ── Hanger Cables ──────────────────────────────────────────
# Hangers drop from the main cable to the deck wherever the cable clears the deck.
func _build_hangers(cable_name: String, curve: Curve3D, z_offset: float):
	const HANGER_RADIUS := 0.18
	const HANGER_COLOR  := Color(0.68, 0.70, 0.66)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = HANGER_COLOR

	var west_anchor_x := tower_w_pos.x - anchorage_distance
	var east_anchor_x := tower_e_pos.x + anchorage_distance
	var num_hangers := int((east_anchor_x - west_anchor_x) / hanger_spacing)

	for i in range(num_hangers + 1):
		var x_pos := west_anchor_x + float(i) * hanger_spacing
		var cable_y := _sample_cable_y(curve, x_pos)

		var hanger_height := cable_y - deck_y
		if hanger_height < 0.5:
			continue

		var hanger := CSGCylinder3D.new()
		hanger.name = cable_name + "_Hanger_%d" % i
		hanger.radius = HANGER_RADIUS
		hanger.height = hanger_height
		hanger.material = mat
		hanger.position = Vector3(x_pos, deck_y + hanger_height * 0.5, z_offset)

		add_child(hanger)
		hanger.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ── Sample Curve Y at World X ──────────────────────────────
func _sample_cable_y(curve: Curve3D, target_x: float) -> float:
	var baked_length := curve.get_baked_length()
	var closest_y := 0.0
	var closest_dist := INF

	for i in range(500):
		var t := float(i) / 500.0
		var pt := curve.sample_baked(t * baked_length)
		var d: float = abs(pt.x - target_x)
		if d < closest_dist:
			closest_dist = d
			closest_y = pt.y

	return closest_y

# ── Anchor Blocks ──────────────────────────────────────────
# Blocks are sized so their top face is at anchor_y where the cable terminates.
# Partially embedded underground for the look of real mass-concrete anchorages.
func _build_anchorages():
	const ANCHOR_COLOR := Color(0.52, 0.53, 0.50)

	var west_x := tower_w_pos.x - anchorage_distance
	var east_x := tower_e_pos.x + anchorage_distance
	# Block center y: top of block sits at anchor_y
	var block_center_y := anchor_y - anchor_height * 0.5

	_add_box("AnchorWest",
		Vector3(anchor_depth, anchor_height, anchor_width),
		Vector3(west_x, block_center_y, 0),
		ANCHOR_COLOR)

	_add_box("AnchorEast",
		Vector3(anchor_depth, anchor_height, anchor_width),
		Vector3(east_x, block_center_y, 0),
		ANCHOR_COLOR)

# ── Helpers ────────────────────────────────────────────────
func _add_box(box_name: String, size: Vector3, pos: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat

	add_child(box)
	box.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
	return box
