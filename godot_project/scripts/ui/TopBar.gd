extends CanvasLayer
## TopBar — full-width toolbar anchored to the top of the screen.
## Add new controls with add_toggle() or add_separator() from other scripts.

const HEIGHT: int = 36

var _hbox:         HBoxContainer
var _btn_playpause: Button
var _lbl_hz:        Label
var _spacer:        Control

func _ready() -> void:
	layer = 20
	_build_ui()
	DataEngine.sim_state_changed.connect(_on_sim_state_changed)

func _build_ui() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right  = 1.0
	bar.anchor_bottom = 0.0
	bar.custom_minimum_size = Vector2(0, HEIGHT)

	var bg := StyleBoxFlat.new()
	bg.bg_color              = Color(0.05, 0.05, 0.09, 0.92)
	bg.border_width_bottom   = 1
	bg.border_color          = Color(0.20, 0.26, 0.35, 0.80)
	bg.content_margin_left   = 14
	bg.content_margin_right  = 14
	bg.content_margin_top    = 0
	bg.content_margin_bottom = 0
	bar.add_theme_stylebox_override("panel", bg)
	add_child(bar)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 10)
	bar.add_child(_hbox)

	# ── Title ────────────────────────────────────────────
	var title := _lbl("TACOMA NARROWS  DT", 10)
	title.modulate = Color(0.65, 0.82, 1.00)
	_hbox.add_child(title)

	_hbox.add_child(_vsep())

	# ── Sim controls ─────────────────────────────────────
	_btn_playpause = _btn("⏸  Pause", _on_playpause)
	_hbox.add_child(_btn_playpause)

	_hbox.add_child(_btn("  Step", func(): DataEngine.step()))

	_lbl_hz = _lbl("%.0f Hz" % DataEngine.tick_rate, 9)
	_lbl_hz.modulate = Color(0.45, 0.58, 0.72)
	_hbox.add_child(_lbl_hz)

	_hbox.add_child(_vsep())

	# ── Overlays label ───────────────────────────────────
	var ov_lbl := _lbl("OVERLAYS", 9)
	ov_lbl.modulate = Color(0.45, 0.55, 0.68)
	_hbox.add_child(ov_lbl)

	# Stress toggle — first feature toggle
	add_toggle("Stress", DataEngine.stress_overlay_enabled,
		func(on: bool): DataEngine.set_stress_overlay(on))

	# ── Expanding spacer — add_toggle() inserts before this ─
	_spacer = Control.new()
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.add_child(_spacer)

	_hbox.add_child(_vsep())

	# ── Exit ─────────────────────────────────────────────
	var exit_btn := _btn("✕  Exit", func(): get_tree().quit())
	exit_btn.modulate = Color(1.0, 0.45, 0.45)
	_hbox.add_child(exit_btn)

# ── Public API for adding controls ──────────────────────
func add_toggle(label_text: String, initial: bool, callback: Callable) -> Button:
	var b := Button.new()
	b.text         = label_text
	b.toggle_mode  = true
	b.button_pressed = initial
	b.add_theme_font_size_override("font_size", 9)
	_apply_toggle_style(b, initial)
	b.toggled.connect(func(on: bool) -> void:
		_apply_toggle_style(b, on)
		callback.call(on)
	)
	_hbox.add_child(b)
	if _spacer != null:
		_hbox.move_child(b, _spacer.get_index())
	return b

func _apply_toggle_style(b: Button, on: bool) -> void:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	if on:
		s.bg_color   = Color(0.10, 0.45, 0.62, 0.95)
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_color        = Color(0.20, 0.75, 1.00, 0.90)
		b.modulate = Color(1.0, 1.0, 1.0)
	else:
		s.bg_color = Color(0.13, 0.17, 0.26, 0.70)
		b.modulate = Color(0.55, 0.60, 0.68)
	b.add_theme_stylebox_override("normal",   s)
	b.add_theme_stylebox_override("pressed",  s)
	b.add_theme_stylebox_override("hover",    s)

func add_separator() -> void:
	_hbox.add_child(_vsep())

# ── Sim callbacks ────────────────────────────────────────
func _on_playpause() -> void:
	DataEngine.toggle_play_pause()

func _on_sim_state_changed(state: DataEngine.SimState) -> void:
	if state == DataEngine.SimState.PLAYING:
		_btn_playpause.text = "⏸  Pause"
	else:
		_btn_playpause.text = "▶  Play"

# ── Helpers ──────────────────────────────────────────────
func _lbl(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(cb)
	var s := StyleBoxFlat.new()
	s.bg_color                   = Color(0.13, 0.17, 0.26, 0.95)
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	b.add_theme_stylebox_override("normal", s)
	return b

func _vsep() -> VSeparator:
	var s := VSeparator.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.22, 0.28, 0.36, 0.70)
	s.add_theme_stylebox_override("separator", st)
	return s
