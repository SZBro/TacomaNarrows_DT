extends CanvasLayer
## DataFlowPanel — compact bottom bar showing live data moving through each
## pipeline stage: ENV RESOURCE → SYNC LAYER → DATA ENGINE → BRIDGE SECTIONS.

# ── Layout constants ──────────────────────────────────────────────────────────
const PANEL_HEIGHT:          int   = 80
const STAGE_MIN_WIDTH:       int   = 190
const FLASH_DURATION:        float = 0.30
const ANOMALY_HOLD_DURATION: float = 3.00

# ── Color palette (matches existing TopBar / DataStreamPanel dark theme) ──────
const COLOR_BG:            Color = Color(0.05, 0.05, 0.09, 0.92)
const COLOR_BORDER:        Color = Color(0.20, 0.26, 0.35, 0.80)
const COLOR_STAGE_NORMAL:  Color = Color(0.10, 0.14, 0.22, 0.85)
const COLOR_FLASH_DATA:    Color = Color(0.10, 0.38, 0.62, 0.95)
const COLOR_FLASH_ANOMALY: Color = Color(0.58, 0.06, 0.06, 0.95)
const COLOR_TITLE:         Color = Color(0.65, 0.82, 1.00)
const COLOR_DIM:           Color = Color(0.45, 0.55, 0.68)
const COLOR_VALUE:         Color = Color(0.90, 0.94, 0.96)
const COLOR_OK:            Color = Color(0.28, 0.88, 0.42)
const COLOR_WARNING:       Color = Color(1.00, 0.72, 0.20)

# Stage index constants
const STAGE_ENV:    int = 0
const STAGE_SYNC:   int = 1
const STAGE_ENGINE: int = 2
const STAGE_BRIDGE: int = 3

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _panel:              PanelContainer
var _stage_styles:       Array = []   # StyleBoxFlat per stage
var _stage_tweens:       Array = []   # active Tween per stage

var _lbl_ingestion:      Label
var _lbl_anomaly:        Label
var _lbl_buffer:         Label
var _lbl_anomaly_detail: Label
var _lbl_tick:           Label
var _lbl_rate:           Label
var _lbl_engine_sects:   Label
var _lbl_sect_total:     Label
var _lbl_sect_warn:      Label

# ── Runtime state ─────────────────────────────────────────────────────────────
var _anomaly_timer:    float = 0.0
var _last_global_data: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 15
	_build_ui()
	_panel.visible = false
	DataEngine.tick_completed.connect(_on_tick)
	SyncLayer.anomaly_detected.connect(_on_anomaly)

func set_panel_visible(on: bool) -> void:
	_panel.visible = on

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_tick(data: Dictionary) -> void:
	_last_global_data = data

	# Flash every stage to show data propagating left → right.
	_flash_stage(STAGE_ENV,    COLOR_FLASH_DATA)
	_flash_stage(STAGE_SYNC,   COLOR_FLASH_DATA)
	_flash_stage(STAGE_ENGINE, COLOR_FLASH_DATA)
	_flash_stage(STAGE_BRIDGE, COLOR_FLASH_DATA)

	# ── SYNC LAYER indicators ──────────────────────────────────────
	_lbl_ingestion.modulate = COLOR_OK

	var anomaly_count: int = SyncLayer.get_anomaly_log().size()
	_lbl_anomaly.text     = "  Anomalies: %d" % anomaly_count
	_lbl_anomaly.modulate = COLOR_WARNING if anomaly_count > 0 else COLOR_DIM

	var max_fill: int = 0
	for sid in SyncLayer.get_section_ids():
		max_fill = maxi(max_fill, SyncLayer.get_buffer(sid).size())
	_lbl_buffer.text = "Buffer: %d/60" % max_fill

	# ── DATA ENGINE indicators ─────────────────────────────────────
	_lbl_tick.text         = "Tick: %d"         % data.get("tick", 0)
	_lbl_rate.text         = "Rate: %.0f Hz"     % DataEngine.tick_rate
	_lbl_engine_sects.text = "Sections: %d"      % DataEngine.get_section_count()

	# ── BRIDGE SECTIONS indicators ─────────────────────────────────
	var total: int = DataEngine.get_section_count()
	var warn:  int = _count_warning_sections()
	_lbl_sect_total.text  = "Total: %d" % total
	_lbl_sect_warn.text   = "WARNING+: %d" % warn
	_lbl_sect_warn.modulate = COLOR_WARNING if warn > 0 else COLOR_DIM


func _on_anomaly(
		section_id:  String,
		stream_name: String,
		value:       float,
		prev:        float
) -> void:
	_flash_stage_hold(STAGE_SYNC, COLOR_FLASH_ANOMALY, ANOMALY_HOLD_DURATION)
	_lbl_anomaly_detail.text    = "%s · %s: %.3f → %.3f" % [section_id, stream_name, prev, value]
	_lbl_anomaly_detail.visible = true
	_anomaly_timer              = ANOMALY_HOLD_DURATION


func _process(delta: float) -> void:
	if _anomaly_timer > 0.0:
		_anomaly_timer -= delta
		if _anomaly_timer <= 0.0:
			_lbl_anomaly_detail.visible = false
			_anomaly_timer = 0.0

# ── Warning section count ─────────────────────────────────────────────────────
func _count_warning_sections() -> int:
	var count: int = 0
	for sid in SyncLayer.get_section_ids():
		var spatial: Dictionary = SyncLayer.get_latest_spatial(sid)
		if spatial.is_empty():
			continue
		var merged: Dictionary = _last_global_data.duplicate()
		merged.merge(spatial, true)
		if DataEngine.state_for(merged) >= DataEngine.SectionState.WARNING:
			count += 1
	return count

# ── Flash helpers ─────────────────────────────────────────────────────────────
func _flash_stage(idx: int, color: Color) -> void:
	var existing = _stage_tweens[idx]
	if existing != null and (existing as Tween).is_valid():
		(existing as Tween).kill()
	_stage_styles[idx].bg_color = color
	var tw: Tween = create_tween()
	tw.tween_property(_stage_styles[idx], "bg_color", COLOR_STAGE_NORMAL, FLASH_DURATION)
	_stage_tweens[idx] = tw


func _flash_stage_hold(idx: int, color: Color, hold: float) -> void:
	var existing = _stage_tweens[idx]
	if existing != null and (existing as Tween).is_valid():
		(existing as Tween).kill()
	_stage_styles[idx].bg_color = color
	var tw: Tween = create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_stage_styles[idx], "bg_color", COLOR_STAGE_NORMAL, FLASH_DURATION)
	_stage_tweens[idx] = tw

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.0
	_panel.anchor_top    = 1.0
	_panel.anchor_right  = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top    = -PANEL_HEIGHT
	_panel.offset_bottom = 0.0

	var bg := StyleBoxFlat.new()
	bg.bg_color            = COLOR_BG
	bg.border_width_top    = 1
	bg.border_color        = COLOR_BORDER
	bg.content_margin_left   = 14
	bg.content_margin_right  = 14
	bg.content_margin_top    = 6
	bg.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(outer)

	# Left label
	var pipe_lbl := _lbl("PIPELINE", 9)
	pipe_lbl.modulate = COLOR_DIM
	outer.add_child(pipe_lbl)

	outer.add_child(_vsep())

	# ── Stage 0: ENV RESOURCE ────────────────────────────────────
	var env_vbox := _add_stage(outer, "ENV RESOURCE", STAGE_ENV)
	var env_sub  := _lbl("BridgeDataModel", 8)
	env_sub.modulate = COLOR_DIM
	env_vbox.add_child(env_sub)

	outer.add_child(_arrow())

	# ── Stage 1: SYNC LAYER ──────────────────────────────────────
	var sync_vbox := _add_stage(outer, "SYNC LAYER", STAGE_SYNC)

	var sync_row := HBoxContainer.new()
	sync_row.add_theme_constant_override("separation", 4)
	sync_vbox.add_child(sync_row)

	_lbl_ingestion = _lbl("● Ingestion", 8)
	_lbl_ingestion.modulate = COLOR_OK
	sync_row.add_child(_lbl_ingestion)

	_lbl_anomaly = _lbl("  Anomalies: 0", 8)
	_lbl_anomaly.modulate = COLOR_DIM
	sync_row.add_child(_lbl_anomaly)

	_lbl_buffer = _lbl("Buffer: 0/60", 8)
	_lbl_buffer.modulate = COLOR_DIM
	sync_vbox.add_child(_lbl_buffer)

	_lbl_anomaly_detail = _lbl("", 8)
	_lbl_anomaly_detail.modulate = Color(1.0, 0.45, 0.35)
	_lbl_anomaly_detail.visible  = false
	sync_vbox.add_child(_lbl_anomaly_detail)

	outer.add_child(_arrow())

	# ── Stage 2: DATA ENGINE ─────────────────────────────────────
	var eng_vbox := _add_stage(outer, "DATA ENGINE", STAGE_ENGINE)

	_lbl_tick = _lbl("Tick: 0", 8)
	_lbl_tick.modulate = COLOR_VALUE
	eng_vbox.add_child(_lbl_tick)

	_lbl_rate = _lbl("Rate: %.0f Hz" % DataEngine.tick_rate, 8)
	_lbl_rate.modulate = COLOR_DIM
	eng_vbox.add_child(_lbl_rate)

	_lbl_engine_sects = _lbl("Sections: 0", 8)
	_lbl_engine_sects.modulate = COLOR_DIM
	eng_vbox.add_child(_lbl_engine_sects)

	outer.add_child(_arrow())

	# ── Stage 3: BRIDGE SECTIONS ─────────────────────────────────
	var bridge_vbox := _add_stage(outer, "BRIDGE SECTIONS", STAGE_BRIDGE)

	_lbl_sect_total = _lbl("Total: 0", 8)
	_lbl_sect_total.modulate = COLOR_VALUE
	bridge_vbox.add_child(_lbl_sect_total)

	_lbl_sect_warn = _lbl("WARNING+: 0", 8)
	_lbl_sect_warn.modulate = COLOR_DIM
	bridge_vbox.add_child(_lbl_sect_warn)


func _add_stage(parent: HBoxContainer, title: String, idx: int) -> VBoxContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size    = Vector2(STAGE_MIN_WIDTH, 0)
	box.size_flags_horizontal  = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color                   = COLOR_STAGE_NORMAL
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = COLOR_BORDER
	style.content_margin_top    = 4
	style.content_margin_bottom = 4
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	box.add_theme_stylebox_override("panel", style)

	_stage_styles.append(style)
	_stage_tweens.append(null)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	box.add_child(vbox)

	var title_lbl := _lbl(title, 9)
	title_lbl.modulate = COLOR_TITLE
	vbox.add_child(title_lbl)

	parent.add_child(box)
	return vbox

# ── Widget helpers (match existing panel style) ───────────────────────────────
func _lbl(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _arrow() -> Label:
	var l := Label.new()
	l.text = " → "
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(0.32, 0.45, 0.60)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _vsep() -> VSeparator:
	var s  := VSeparator.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.22, 0.28, 0.36, 0.70)
	s.add_theme_stylebox_override("separator", st)
	return s
