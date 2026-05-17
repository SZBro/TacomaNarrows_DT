class_name SceneEnvironment
extends Node
## Adds a sun (DirectionalLight3D) and procedural sky (WorldEnvironment) to the scene.

func _ready() -> void:
	_add_sun()
	_add_sky()

func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _add_sky() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()

	var env := Environment.new()
	env.background_mode      = Environment.BG_SKY
	env.sky                  = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5

	var env_node := WorldEnvironment.new()
	env_node.name        = "WorldEnvironment"
	env_node.environment = env
	add_child(env_node)
