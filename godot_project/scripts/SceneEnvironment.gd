class_name SceneEnvironment
extends Node
## Adds a sun (DirectionalLight3D) and procedural sky (WorldEnvironment) to the scene.

func _ready() -> void:
	_add_sun()
	_add_sky()
	_add_ground()
	_add_water()

func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _add_ground() -> void:
	# One large flat plane covering everything — land color shows where water doesn't cover it.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6000.0, 3000.0)
	mesh.subdivide_width  = 1
	mesh.subdivide_depth  = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.40, 0.32)  # muted olive-earth

	var ground := MeshInstance3D.new()
	ground.name      = "Ground"
	ground.mesh      = mesh
	ground.material_override = mat
	ground.position  = Vector3(0.0, -6.0, 0.0)
	add_child(ground)

func _add_water() -> void:
	# Water plane covering the strait between the two anchorages (x ≈ -756 to +753).
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1600.0, 2500.0)
	mesh.subdivide_width  = 120
	mesh.subdivide_depth  = 120

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")

	var water := MeshInstance3D.new()
	water.name             = "Water"
	water.mesh             = mesh
	water.material_override = mat
	water.position         = Vector3(-1.5, 0.0, 0.0)
	add_child(water)

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
