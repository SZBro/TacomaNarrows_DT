extends CanvasLayer
## ControlPanel — collapsible toolbar for runtime toggles and overrides.
## Add new controls here as features are implemented.

var _panel:         PanelContainer
var _content:       VBoxContainer
var _btn_collapse:  Button
var _collapsed:     bool = false

const PANEL_WIDTH := 220

func _ready() -> void:
	layer = 5
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ControlPanel"
	_panel.anchor_left   = 1.0
	_panel.anchor_right  = 1.0
	_panel.anchor_top    = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-PANEL_WIDTH - 12, -12)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.06, 0.06, 0.10, 0.85)
	bg.corner_radius_top_left     = 6
	bg.corner_radius_top_right    = 6
	bg.corner_radius_bottom_left  = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left   = 10
	bg.content_margin_right  = 10
	bg.content_margin_top    = 8
	bg.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(root_vbox)

	# Header row
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 10)
	title.modulate = Color(0.65, 0.82, 1.00)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_btn_collapse = Button.new()
	_btn_collapse.text = "▼"
	_btn_collapse.add_theme_font_size_override("font_size", 9)
	_btn_collapse.flat = true
	_btn_collapse.pressed.connect(_toggle_collapse)
	header.add_child(_btn_collapse)

	var sep := _make_sep()
	root_vbox.add_child(sep)

	# Collapsible content area
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_content)

	# ── Stress Overlay toggle ──────────────────────────────
	_content.add_child(_make_section_label("VISUALS"))
	_content.add_child(_make_toggle(
		"Stress Overlay",
		DataEngine.stress_overlay_enabled,
		func(on: bool) -> void: DataEngine.set_stress_overlay(on)
	))

func _toggle_collapse() -> void:
	_collapsed = not _collapsed
	_content.visible   = not _collapsed
	_btn_collapse.text = "▶" if _collapsed else "▼"

# ── Helpers ────────────────────────────────────────────────
func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.modulate = Color(0.50, 0.60, 0.72)
	return lbl

func _make_toggle(label_text: String, initial: bool, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.modulate = Color(0.88, 0.90, 0.94)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn := CheckButton.new()
	btn.button_pressed = initial
	btn.add_theme_font_size_override("font_size", 9)
	btn.toggled.connect(callback)
	row.add_child(btn)

	return row

func _make_sep() -> HSeparator:
	var s     := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.30, 0.36, 0.60)
	s.add_theme_stylebox_override("separator", style)
	return s
