extends Node3D

func _ready() -> void:
	add_child(preload("res://scripts/SceneEnvironment.gd").new())
	add_child(preload("res://scripts/OrbitCamera.gd").new())
	add_child(preload("res://scenes/ui/DebugOverlay.tscn").instantiate())
	var top_bar := preload("res://scripts/ui/TopBar.gd").new()
	add_child(top_bar)
	add_child(preload("res://scripts/bridge/HighlightRing.gd").new())
	var stream_panel := preload("res://scripts/ui/DataStreamPanel.gd").new()
	add_child(stream_panel)
	top_bar.add_toggle("Streams", false,
		func(on: bool) -> void: stream_panel.set_panel_visible(on))
