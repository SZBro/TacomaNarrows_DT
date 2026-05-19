extends CanvasLayer
## In-game debug overlay — shows live sensor data for the selected bridge section.
## Connects to DataEngine.tick_completed; updated every simulation tick.
## Click a BridgeSection in the viewport to select it.

# ── UI Node References ────────────────────────────────────────────────────────
var _panel:       PanelContainer
var _lbl_section: Label
var _lbl_state:   Label
var _lbl_hint:    Label
var _grid:        GridContainer

# field_key → { lbl: Label, unit: String }
var _val: Dictionary = {}

# ── Runtime State ─────────────────────────────────────────────────────────────
var _selected: Node = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
const TOP_BAR_HEIGHT: int = 36
const PANEL_OFFSET:   int = 8

func _ready() -> void:
	layer = 10
	_build_ui()
	get_node("/root/DataEngine").tick_completed.connect(_on_tick)
	get_node("/root/SelectionManager").section_selected.connect(_on_section_selected)
	get_node("/root/SelectionManager").section_deselected.connect(_on_section_deselected)
	_panel.visible = false

# ── UI Construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = Vector2(12, TOP_BAR_HEIGHT + PANEL_OFFSET)
	_panel.custom_minimum_size = Vector2(252, 0)

	var bg := StyleBoxFlat.new()
	bg.bg_color                  = Color(0.06, 0.06, 0.10, 0.80)
	bg.corner_radius_top_left    = 6
	bg.corner_radius_top_right   = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left   = 12
	bg.content_margin_right  = 12
	bg.content_margin_top    = 10
	bg.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(vbox)

	# Title
	var title := _lbl("BRIDGE MONITOR", 10)
	title.modulate = Color(0.65, 0.82, 1.00)
	vbox.add_child(title)
	vbox.add_child(_sep())

	# Section ID
	_lbl_section = _lbl("", 9)
	_lbl_section.modulate = Color(0.85, 0.88, 0.92)
	vbox.add_child(_lbl_section)

	# State badge
	_lbl_state = _lbl("", 10)
	vbox.add_child(_lbl_state)
	vbox.add_child(_sep())

	# Data rows
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_grid)

	var rows: Array = [
		["wind_speed",    "Wind Speed",    "km/h"],
		["temperature",   "Temperature",   "°C"  ],
		["cable_tension", "Cable Tension", "kN"  ],
		["traffic_load",  "Deck Load",     "%"   ],
		["torsion",       "Torsion",       "°"   ],
		["resonance",     "Resonance",     "m"   ],
	]

	for r: Array in rows:
		var k := _lbl(r[1] + ":", 9)
		k.modulate = Color(0.60, 0.68, 0.78)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(k)

		var v := _lbl("—", 9)
		v.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.modulate = Color(0.92, 0.94, 0.96)
		_grid.add_child(v)
		_val[r[0]] = {"lbl": v, "unit": r[2]}

	vbox.add_child(_sep())
	_lbl_hint = _lbl("Click a section to inspect", 9)
	_lbl_hint.modulate = Color(0.45, 0.52, 0.60)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_lbl_hint)

	vbox.add_child(_sep())
	var btn := Button.new()
	btn.text = "Reset Camera  [Home]"
	btn.add_theme_font_size_override("font_size", 9)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color                   = Color(0.14, 0.18, 0.26, 0.90)
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_left  = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_top    = 5
	btn_style.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(_on_reset_camera)
	vbox.add_child(btn)

func _lbl(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

func _sep() -> HSeparator:
	var s     := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.30, 0.36, 0.60)
	s.add_theme_stylebox_override("separator", style)
	return s

func _on_section_selected(section: Node) -> void:
	_selected = section
	_panel.visible = true

func _on_section_deselected() -> void:
	_selected = null
	_panel.visible = false

# ── Tick Handler ──────────────────────────────────────────────────────────────
func _on_tick(_global: Dictionary) -> void:
	if _selected == null or not is_instance_valid(_selected):
		_selected = null
		_panel.visible = false
		return
	if not "last_data" in _selected or (_selected.last_data as Dictionary).is_empty():
		return
	_show_data(_selected.last_data)

# ── Display ───────────────────────────────────────────────────────────────────
func _show_empty() -> void:
	_lbl_section.text   = "No section selected"
	_lbl_state.text     = "—"
	_lbl_state.modulate = Color(0.45, 0.50, 0.55)
	_lbl_hint.visible   = true
	_grid.visible       = false

func _show_data(data: Dictionary) -> void:
	_lbl_section.text = _selected.name
	_lbl_hint.visible = false
	_grid.visible     = true

	var state           := DataEngine.state_for(data)
	_lbl_state.text     = DataEngine.STATE_NAMES[state]
	_lbl_state.modulate = DataEngine.STATE_COLORS[state]

	_set_val("wind_speed",    "%.1f"  % data.get("wind_speed",    0.0))
	_set_val("temperature",   "%.1f"  % data.get("temperature",   0.0))
	_set_val("cable_tension", "%.0f"  % data.get("cable_tension", 0.0))
	_set_val("traffic_load",  "%.0f"  % (data.get("traffic_load", 0.0) * 100.0))
	_set_val("torsion",       "%.3f"  % data.get("torsion",       0.0))
	_set_val("resonance",     "%.4f"  % data.get("resonance",     0.0))

func _set_val(field: String, value: String) -> void:
	if field in _val:
		_val[field]["lbl"].text = value + " " + _val[field]["unit"]

func _on_reset_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("reset_view"):
		cam.reset_view()

