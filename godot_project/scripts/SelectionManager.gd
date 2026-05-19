extends Node
## Autoload singleton: /root/SelectionManager
## Raycasts into the 3-D scene on left-click and emits section_selected
## when a node with receive_data() is hit.
## All bridge components register an Area3D so this raycast can find them.

signal section_selected(section: Node)
signal section_deselected()

var selected: Node = null

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_try_select(event.position)

func _try_select(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var space  := camera.get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(screen_pos)
	var query  := PhysicsRayQueryParameters3D.create(
		origin,
		origin + camera.project_ray_normal(screen_pos) * 5000.0
	)
	query.collide_with_areas  = true
	query.collide_with_bodies = false
	var result := space.intersect_ray(query)
	if result.is_empty():
		if selected != null:
			selected = null
			section_deselected.emit()
		return
	var parent: Node = result["collider"].get_parent()
	if parent.has_method("receive_data"):
		selected = parent
		section_selected.emit(selected)
