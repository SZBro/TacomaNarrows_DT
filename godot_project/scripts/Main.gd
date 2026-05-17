extends Node3D

func _ready() -> void:
	add_child(preload("res://scripts/SceneEnvironment.gd").new())
	add_child(preload("res://scripts/OrbitCamera.gd").new())
	add_child(preload("res://scenes/ui/DebugOverlay.tscn").instantiate())
