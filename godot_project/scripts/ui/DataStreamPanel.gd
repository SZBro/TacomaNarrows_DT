extends CanvasLayer
## DataStreamPanel — live sensor readout with per-channel multiplier sliders.
## The simulation always runs; sliders scale the output (×0 to ×5, default ×1).
## Drag the title bar to reposition.

const TOP_BAR_HEIGHT: int = 36
const PANEL_WIDTH:    int = 300
const PANEL_OFFSET:   int = 8

# Multiplier range for every channel.
const MULT_MIN:  float = 0.0
const MULT_MAX:  float = 5.0
const MULT_STEP: float = 0.05

const FIELDS: Array = [
	{key="wind_speed",        label="Wind Speed",  unit="km/h", fmt="%.1f"},
	{key="wind_direction",    label="Direction",   unit="°",    fmt="%.0f"},
	{key="temperature",       label="Temperature", unit="°C",   fmt="%.1f"},
	{key="cable_tension",     label="Cable Tens.", unit="kN",   fmt="%.0f"},
	{key="seismic_vibration", label="Seismic",     unit="m/s²", fmt="%.3f"},
	{key="resonance",         label="Resonance",   unit="m",    fmt="%.3f"},
	{key="torsion",           label="Torsion",     unit="°",    fmt="%.4f"},
]

var _panel:        PanelContainer
var _drag_handle:  Control
var _panel_drag:   bool    = false
var _panel_offset: Vector2 = Vector2.ZERO

# key → {val_lbl, mult_lbl, slider, reset_btn, fmt}
var _rows: Dictionary = {}

func _ready() -> void:
	layer = 10
	_build_ui()
	var vp_w: float = get_viewport().get_visible_rect().size.x
	_panel.position = Vector2(vp_w - PANEL_WIDTH - 12.0, TOP_BAR_HEIGHT + PANEL_OFFSET)
	_panel.visible = false
	DataEngine.tick_completed.connect(_on_tick)

func set_panel_visible(on: bool) -> void:
	_panel.visible = on

# ── UI Construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DataStreamPanel"
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.06, 0.06, 0.10, 0.92)
	bg.corner_radius_top_left     = 6
	bg.corner_radius_top_right    = 6
	bg.corner_radius_bottom_left  = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left   = 12
	bg.content_margin_right  = 12
	bg.content_margin_top    = 10
	bg.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# ── Drag handle / title ──
	_drag_handle = HBoxContainer.new()
	(_drag_handle as HBoxContainer).add_theme_constant_override("separation", 4)
	_drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	vbox.add_child(_drag_handle)

	var grip := _lbl("⠿", 11)
	grip.modulate = Color(0.40, 0.50, 0.65)
	(_drag_handle as HBoxContainer).add_child(grip)

	var title := _lbl("DATA STREAMS", 10)
	title.modulate = Color(0.65, 0.82, 1.00)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_drag_handle as HBoxContainer).add_child(title)

	var reset_all := Button.new()
	reset_all.text = "Reset All ×1"
	reset_all.add_theme_font_size_override("font_size", 9)
	reset_all.flat = true
	reset_all.modulate = Color(0.55, 0.65, 0.75)
	reset_all.pressed.connect(_reset_all)
	(_drag_handle as HBoxContainer).add_child(reset_all)

	vbox.add_child(_sep(Color(0.25, 0.30, 0.36, 0.60)))

	# Column header
	var col_hdr := HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 4)
	vbox.add_child(col_hdr)

	var h_stream := _lbl("STREAM", 8)
	h_stream.modulate = Color(0.40, 0.48, 0.58)
	h_stream.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_hdr.add_child(h_stream)

	var h_val := _lbl("LIVE VALUE", 8)
	h_val.modulate = Color(0.40, 0.48, 0.58)
	h_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col_hdr.add_child(h_val)

	var h_mult := _lbl("  SCALE", 8)
	h_mult.modulate = Color(0.40, 0.48, 0.58)
	col_hdr.add_child(h_mult)

	vbox.add_child(_sep(Color(0.20, 0.24, 0.30, 0.40)))

	for fd: Dictionary in FIELDS:
		_build_row(vbox, fd)

func _build_row(parent: VBoxContainer, fd: Dictionary) -> void:
	var key: String = fd["key"]

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	# ── Top line: label | live value | ×N.N | ✕ ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	row.add_child(header)

	var lbl_key := _lbl(fd["label"] + ":", 9)
	lbl_key.modulate = Color(0.60, 0.68, 0.78)
	lbl_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_key)

	var val_lbl := _lbl("—", 9)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.modulate = Color(0.92, 0.94, 0.96)
	header.add_child(val_lbl)

	var unit_lbl := _lbl(" " + fd["unit"], 9)
	unit_lbl.modulate = Color(0.50, 0.58, 0.68)
	header.add_child(unit_lbl)

	var mult_lbl := _lbl("  ×1.0", 9)
	mult_lbl.modulate = Color(0.50, 0.60, 0.50)  # dim green = neutral
	header.add_child(mult_lbl)

	var reset_btn := Button.new()
	reset_btn.text = "✕"
	reset_btn.add_theme_font_size_override("font_size", 8)
	reset_btn.flat = true
	reset_btn.modulate = Color(0.75, 0.30, 0.30)
	reset_btn.visible = false
	reset_btn.pressed.connect(func() -> void: _reset_row(key))
	header.add_child(reset_btn)

	# ── Multiplier slider ──
	var slider := HSlider.new()
	slider.min_value = MULT_MIN
	slider.max_value = MULT_MAX
	slider.step      = MULT_STEP
	slider.value     = 1.0
	slider.custom_minimum_size   = Vector2(0, 14)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void: _on_mult_changed(key, v))
	row.add_child(slider)

	_rows[key] = {
		"val_lbl":   val_lbl,
		"mult_lbl":  mult_lbl,
		"slider":    slider,
		"reset_btn": reset_btn,
		"fmt":       fd["fmt"],
	}

	parent.add_child(_sep(Color(0.18, 0.22, 0.28, 0.50)))

# ── Multiplier change ─────────────────────────────────────────────────────────
func _on_mult_changed(key: String, v: float) -> void:
	DataEngine.set_multiplier(key, v)
	var row: Dictionary = _rows[key]
	var is_neutral: bool = absf(v - 1.0) < 0.01
	row["mult_lbl"].text    = "  ×%.2f" % v
	row["mult_lbl"].modulate = (
		Color(0.50, 0.60, 0.50) if is_neutral else Color(1.0, 0.72, 0.20)
	)
	row["reset_btn"].visible = not is_neutral

func _reset_row(key: String) -> void:
	DataEngine.reset_multiplier(key)
	(_rows[key]["slider"] as HSlider).set_value_no_signal(1.0)
	_rows[key]["mult_lbl"].text     = "  ×1.0"
	_rows[key]["mult_lbl"].modulate = Color(0.50, 0.60, 0.50)
	_rows[key]["reset_btn"].visible = false

func _reset_all() -> void:
	for key: String in _rows:
		_reset_row(key)

# ── Tick — update live value display ─────────────────────────────────────────
func _on_tick(data: Dictionary) -> void:
	for key: String in _rows:
		var v: float = data.get(key, 0.0)
		_rows[key]["val_lbl"].text = _rows[key]["fmt"] % v

# ── Panel drag ────────────────────────────────────────────────────────────────
# SelectionManager uses _unhandled_input; PanelContainer's default MOUSE_FILTER_STOP
# already blocks bridge-selection clicks, so we only need to handle the title-bar drag.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and _drag_handle != null \
				and _drag_handle.get_global_rect().has_point(mb.position):
			_panel_drag   = true
			_panel_offset = _panel.position - mb.position
			get_viewport().set_input_as_handled()
		elif not mb.pressed:
			_panel_drag = false

	elif event is InputEventMouseMotion and _panel_drag:
		var mm := event as InputEventMouseMotion
		var vp := get_viewport().get_visible_rect().size
		var np := mm.position + _panel_offset
		np.x = clampf(np.x, 0.0, vp.x - _panel.size.x)
		np.y = clampf(np.y, 0.0, vp.y - _panel.size.y)
		_panel.position = np
		get_viewport().set_input_as_handled()

# ── Helpers ───────────────────────────────────────────────────────────────────
func _lbl(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

func _sep(color: Color) -> HSeparator:
	var s     := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	s.add_theme_stylebox_override("separator", style)
	return s
