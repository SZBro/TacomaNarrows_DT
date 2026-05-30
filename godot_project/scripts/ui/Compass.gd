extends CanvasLayer
## Compass — always-on orientation widget, bottom-right corner.
## North = world -Z (bridge runs East-West along the X axis).
## Reads the active Camera3D each frame so it works with any camera mode.

# ── Layout ────────────────────────────────────────────────────────────────────
const COMPASS_SIZE:  int   = 80
const RADIUS:        float = 34.0   # circle background radius
const NEEDLE_LEN:    float = 22.0   # north needle arm length
const LABEL_RADIUS:  float = 23.0   # distance from centre to cardinal letters
const FONT_SIZE:     int   = 11
const MARGIN:        int   = 12
const FLOW_PANEL_H:  int   = 80     # DataFlowPanel height — stay above it

# ── Colors (matching project dark theme) ──────────────────────────────────────
const COLOR_BG:         Color = Color(0.05, 0.05, 0.09, 0.88)
const COLOR_RIM:        Color = Color(0.22, 0.28, 0.36, 0.80)
const COLOR_TICK:       Color = Color(0.28, 0.36, 0.48, 0.70)
const COLOR_NORTH:      Color = Color(0.92, 0.20, 0.20)
const COLOR_CARDINAL:   Color = Color(0.88, 0.92, 0.96)
const COLOR_NEEDLE_S:   Color = Color(0.55, 0.58, 0.62)
const COLOR_CENTER_DOT: Color = Color(0.84, 0.88, 0.92)

# ── Internal ──────────────────────────────────────────────────────────────────
var _ctrl: Control
var _font: Font

# Cardinal directions: [label, angle_from_north_radians, color]
const _CARDINALS: Array = [
	["N",  0.0,          true ],   # true = use COLOR_NORTH
	["E",  PI * 0.5,     false],
	["S",  PI,           false],
	["W",  PI * 1.5,     false],
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 12   # above 3D view; below TopBar (20) and DataFlowPanel (15)
	_font = ThemeDB.fallback_font

	_ctrl = Control.new()
	_ctrl.custom_minimum_size = Vector2(COMPASS_SIZE, COMPASS_SIZE)
	# Anchor to bottom-right, sitting above the DataFlowPanel strip.
	_ctrl.anchor_left   = 1.0
	_ctrl.anchor_top    = 1.0
	_ctrl.anchor_right  = 1.0
	_ctrl.anchor_bottom = 1.0
	_ctrl.offset_right  = -MARGIN
	_ctrl.offset_left   = -(MARGIN + COMPASS_SIZE)
	_ctrl.offset_bottom = -(MARGIN + FLOW_PANEL_H)
	_ctrl.offset_top    = -(MARGIN + FLOW_PANEL_H + COMPASS_SIZE)
	_ctrl.draw.connect(_draw_compass)
	add_child(_ctrl)


func _process(_delta: float) -> void:
	_ctrl.queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw_compass() -> void:
	var center := Vector2(COMPASS_SIZE * 0.5, COMPASS_SIZE * 0.5)
	var yaw:   float = _camera_yaw()

	# Background circle
	_ctrl.draw_circle(center, RADIUS, COLOR_BG)
	_ctrl.draw_arc(center, RADIUS, 0.0, TAU, 64, COLOR_RIM, 1.0, true)

	# Eight minor tick marks
	for i in 8:
		var a: float = (TAU / 8.0) * i - yaw - PI * 0.5
		var inner := center + Vector2(cos(a), sin(a)) * (RADIUS - 6.0)
		var outer := center + Vector2(cos(a), sin(a)) * (RADIUS - 2.0)
		_ctrl.draw_line(inner, outer, COLOR_TICK, 1.0)

	# Cardinal letters
	for c in _CARDINALS:
		var world_angle: float  = float(c[1])
		var screen_angle: float = world_angle - yaw - PI * 0.5
		var pos := center + Vector2(cos(screen_angle), sin(screen_angle)) * LABEL_RADIUS
		# Offset so the glyph is visually centred on pos (baseline correction).
		var str_w: float = _font.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT,
				-1, FONT_SIZE).x
		var asc:   float = _font.get_ascent(FONT_SIZE)
		var draw_pos := pos + Vector2(-str_w * 0.5, asc * 0.4)
		var col: Color = COLOR_NORTH if c[2] else COLOR_CARDINAL
		_ctrl.draw_string(_font, draw_pos, c[0], HORIZONTAL_ALIGNMENT_LEFT,
				-1, FONT_SIZE, col)

	# Needle — north half red, south half gray
	var north_angle: float = -yaw - PI * 0.5
	var tip  := center + Vector2(cos(north_angle), sin(north_angle)) * NEEDLE_LEN
	var tail := center - Vector2(cos(north_angle), sin(north_angle)) * (NEEDLE_LEN * 0.45)
	_ctrl.draw_line(center, tail, COLOR_NEEDLE_S, 2.0, true)
	_ctrl.draw_line(center, tip,  COLOR_NORTH,    2.5, true)

	# Centre pivot dot
	_ctrl.draw_circle(center, 2.5, COLOR_CENTER_DOT)

# ── Camera heading ────────────────────────────────────────────────────────────
## Returns the camera's horizontal yaw in radians.
## 0 = facing world -Z (North).  +π/2 = facing +X (East).
func _camera_yaw() -> float:
	var vp := get_viewport()
	if not vp:
		return 0.0
	var cam := vp.get_camera_3d()
	if not cam:
		return 0.0
	# Camera forward in world space = -basis.z (OpenGL convention).
	var fwd := -cam.global_transform.basis.z
	# atan2(east_component, north_component) — north is -Z, east is +X.
	return atan2(fwd.x, -fwd.z)
