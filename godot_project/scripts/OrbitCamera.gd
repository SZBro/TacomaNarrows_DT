class_name OrbitCamera
extends Camera3D
## Orbit camera controller. Scroll to zoom, right-drag to orbit, middle-drag to pan.

const _DEFAULT_PIVOT:    Vector3 = Vector3(0.0, 50.0, 0.0)
const _DEFAULT_DISTANCE: float   = 1050.0
const _DEFAULT_YAW:      float   = 0.0
const _DEFAULT_PITCH:    float   = -12.0

var _pivot:    Vector3 = _DEFAULT_PIVOT
var _distance: float   = _DEFAULT_DISTANCE
var _yaw:      float   = _DEFAULT_YAW
var _pitch:    float   = _DEFAULT_PITCH

const _ZOOM_STEP:   float = 80.0
const _ZOOM_MIN:    float = 40.0
const _ZOOM_MAX:    float = 1500.0
const _ORBIT_SPEED: float = 0.25
const _PAN_SPEED:   float = 0.08

func _ready() -> void:
	_update()

func reset_view() -> void:
	_pivot    = _DEFAULT_PIVOT
	_distance = _DEFAULT_DISTANCE
	_yaw      = _DEFAULT_YAW
	_pitch    = _DEFAULT_PITCH
	_update()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME:
			reset_view()

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_distance = maxf(_distance - _ZOOM_STEP * (_distance / 400.0), _ZOOM_MIN)
				_update()
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(_distance + _ZOOM_STEP * (_distance / 400.0), _ZOOM_MAX)
				_update()

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_yaw   -= event.relative.x * _ORBIT_SPEED
			_pitch  = clampf(_pitch - event.relative.y * _ORBIT_SPEED, -89.0, 89.0)
			_update()
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var scale := _distance * _PAN_SPEED * 0.01
			_pivot -= global_transform.basis.x * event.relative.x * scale
			_pivot += global_transform.basis.y * event.relative.y * scale
			_update()

func _update() -> void:
	var yr := deg_to_rad(_yaw)
	var pr := deg_to_rad(_pitch)
	position = _pivot + Vector3(
		_distance * cos(pr) * sin(yr),
		-_distance * sin(pr),
		_distance * cos(pr) * cos(yr)
	)
	look_at(_pivot)
