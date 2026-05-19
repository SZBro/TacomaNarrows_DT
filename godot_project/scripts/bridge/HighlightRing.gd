extends Node
## SelectionHighlight — drives the outline shader on whichever section is selected.
## No 3D geometry of its own; the outline is rendered by the section's own meshes.

var _current: Node = null

func _ready() -> void:
	SelectionManager.section_selected.connect(_on_selected)
	SelectionManager.section_deselected.connect(_on_deselected)

func _on_selected(section: Node) -> void:
	if is_instance_valid(_current) and _current.has_method("set_highlighted"):
		_current.set_highlighted(false)
	_current = section
	if section.has_method("set_highlighted"):
		section.set_highlighted(true)

func _on_deselected() -> void:
	if is_instance_valid(_current) and _current.has_method("set_highlighted"):
		_current.set_highlighted(false)
	_current = null
