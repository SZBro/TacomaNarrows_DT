extends CharacterBody3D
## First-person walk camera.
## WASD movement, mouse-look, gravity via move_and_slide().
## Collision against HTerrain handled by the physics engine automatically.

# ── Configuration ─────────────────────────────────────────────────────────────
const SPEED:             float = 10.0
const GRAVITY:           float = 20.0
const MOUSE_SENSITIVITY: float = 0.002
const CAM_HEIGHT:        float = 1.6    # eye level above foot position
const PITCH_MIN:         float = -1.48  # ≈ -85 degrees
const PITCH_MAX:         float =  1.48  # ≈ +85 degrees
const CAP_HEIGHT:        float =  1.7   # total capsule height
const CAP_RADIUS:        float =  0.4

# ── State ─────────────────────────────────────────────────────────────────────
var _cam:    Camera3D
var _pitch:  float = 0.0
var _active: bool  = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Eye-level camera
	_cam          = Camera3D.new()
	_cam.name     = "Camera3D"
	_cam.position = Vector3(0.0, CAM_HEIGHT, 0.0)
	add_child(_cam)

	# Capsule collider centred at mid-body height
	var col   := CollisionShape3D.new()
	var cap   := CapsuleShape3D.new()
	cap.height    = CAP_HEIGHT
	cap.radius    = CAP_RADIUS
	col.shape     = cap
	col.position  = Vector3(0.0, CAP_HEIGHT * 0.5, 0.0)
	add_child(col)

	# Allow walking on moderate slopes
	floor_max_angle = deg_to_rad(55.0)

# ── Public API ────────────────────────────────────────────────────────────────
func activate(start_pos: Vector3, start_yaw: float, start_pitch: float) -> void:
	global_position = start_pos
	rotation.y      = start_yaw
	_pitch          = clampf(start_pitch, PITCH_MIN, PITCH_MAX)
	_cam.rotation.x = _pitch
	_cam.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_active = true


func deactivate() -> void:
	_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ── Input — mouse look ────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch          = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY,
				PITCH_MIN, PITCH_MAX)
		_cam.rotation.x = _pitch

# ── Physics — movement + gravity ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _active:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# WASD in body-local horizontal space
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move -= basis.z
	if Input.is_key_pressed(KEY_S): move += basis.z
	if Input.is_key_pressed(KEY_A): move -= basis.x
	if Input.is_key_pressed(KEY_D): move += basis.x

	move.y = 0.0
	if move.length_squared() > 0.0:
		move = move.normalized()

	velocity.x = move.x * SPEED
	velocity.z = move.z * SPEED

	move_and_slide()
