@tool
extends Node3D
## Second bridge (1950 replacement) — same deck/cable layout as bridge 1,
## SectionTower2 replaces SectionTower. Parent node is offset Z=70 in Main.tscn.
## Scene X-axis: +X = Gig Harbor / NW end (315°), -X = Tacoma / SE end (135°).

const _TOWER_SCENE   := preload("res://scenes/bridge/SectionTower2.tscn")
const _SECTION_SCENE := preload("res://scenes/bridge/BridgeSection.tscn")
const _CABLE_SCENE   := preload("res://scenes/bridge/CableSystem.tscn")

const _TOWER_SE_POS := Vector3(-426.0,   0.0, 0.0)  # Tacoma / SE end
const _TOWER_NW_POS := Vector3(422.785,  0.0, 0.0)  # Gig Harbor / NW end

const _SECTION_POSITIONS := [
	# Main span (between towers)
	Vector3(-373.0,   46.0, 0.0),
	Vector3(-267.0,   46.0, 0.0),
	Vector3(-161.0,   46.0, 0.0),
	Vector3( -55.0,   46.0, 0.0),
	Vector3(  51.42,  46.0, 0.0),
	Vector3( 157.88,  46.0, 0.0),
	Vector3( 263.59,  46.0, 0.0),
	Vector3( 369.66,  46.0, 0.0),
	# NW approach (Gig Harbor)
	Vector3( 475.0,   46.0, 0.0),
	Vector3( 581.832, 46.0, 0.0),
	Vector3( 688.0,   46.0, 0.0),
	# SE approach (Tacoma)
	Vector3(-479.747, 46.0, 0.0),
	Vector3(-586.594, 46.0, 0.0),
	Vector3(-693.271, 46.0, 0.0),
]

@export var rebuild: bool = false:
	set(_v):
		_spawn()

func _ready() -> void:
	_spawn()

func _spawn() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var scene_root = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	var tw := _TOWER_SCENE.instantiate()
	tw.name     = "Tower2_SE"
	tw.position = _TOWER_SE_POS
	add_child(tw)
	if scene_root:
		tw.owner = scene_root

	var te := _TOWER_SCENE.instantiate()
	te.name     = "Tower2_NW"
	te.position = _TOWER_NW_POS
	add_child(te)
	if scene_root:
		te.owner = scene_root

	for i in _SECTION_POSITIONS.size():
		var sec := _SECTION_SCENE.instantiate()
		sec.name            = "Bridge2_Section_%d" % (i + 1)
		sec.position        = _SECTION_POSITIONS[i]
		sec.reverse_traffic = true
		add_child(sec)
		if scene_root:
			sec.owner = scene_root

	var cables := _CABLE_SCENE.instantiate()
	cables.name = "CableSystem2"
	add_child(cables)
	if scene_root:
		cables.owner = scene_root
