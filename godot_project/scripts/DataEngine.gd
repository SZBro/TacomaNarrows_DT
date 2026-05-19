extends Node
## DataEngine — simulation infrastructure for the Tacoma Narrows digital twin.
## Autoload singleton: manages timing, section registry, scenario state, and tick dispatch.
## All physics/math is delegated to BridgeDataModel.

# ── Section Health State ──────────────────────────────────────────────────────
# Thresholds calibrated against raw BridgeDataModel output ranges:
#   CALM:      wind 3-7,  res 0-0.013, tors 0-0.018
#   MODERATE:  wind 17-33, res 0-0.082, tors 0-0.025
#   STORM:     wind 35-75, res 0-1.65,  tors 0-0.094
#   RESONANCE: wind 62-72, res 0-0.49,  tors 0-0.148
#   EARTHQUAKE:wind 7-13,  res 0-0.027, tors 0-0.020
enum SectionState { NORMAL, WARNING, CRITICAL, FAILURE }

const STATE_COLORS: Dictionary = {
	SectionState.NORMAL:   Color(0.20, 0.88, 0.20),
	SectionState.WARNING:  Color(1.00, 0.82, 0.00),
	SectionState.CRITICAL: Color(1.00, 0.28, 0.08),
	SectionState.FAILURE:  Color(0.50, 0.00, 0.00),
}

const STATE_NAMES: Dictionary = {
	SectionState.NORMAL:   "NORMAL",
	SectionState.WARNING:  "WARNING",
	SectionState.CRITICAL: "CRITICAL",
	SectionState.FAILURE:  "FAILURE",
}

func state_for(data: Dictionary) -> SectionState:
	var wind: float = data.get("wind_speed", 0.0)
	var res:  float = absf(data.get("resonance", 0.0))
	var tors: float = absf(data.get("torsion",   0.0))
	if wind > 65.0 or res > 1.20 or tors > 0.12:
		return SectionState.FAILURE
	if wind > 50.0 or res > 0.40 or tors > 0.06:
		return SectionState.CRITICAL
	if wind > 30.0 or res > 0.04 or tors > 0.02:
		return SectionState.WARNING
	return SectionState.NORMAL

func state_to_stress(state: SectionState) -> float:
	match state:
		SectionState.WARNING:  return 0.33
		SectionState.CRITICAL: return 0.66
		SectionState.FAILURE:  return 1.00
		_:                     return 0.00

# Continuous 0–1 stress from raw sensor data — use this for smooth shader visuals.
# Uses WARNING thresholds as the midpoint so typical conditions produce visible color.
func stress_continuous(data: Dictionary) -> float:
	var wind: float = clampf(data.get("wind_speed", 0.0) / 30.0, 0.0, 1.0)
	var res:  float = clampf(absf(data.get("resonance", 0.0)) / 0.04, 0.0, 1.0)
	var tors: float = clampf(absf(data.get("torsion",   0.0)) / 0.02, 0.0, 1.0)
	return clampf(res * 0.50 + wind * 0.30 + tors * 0.20, 0.0, 1.0)

# ── Stress Overlay Toggle ─────────────────────────────────────────────────────
var stress_overlay_enabled: bool = false
signal stress_overlay_changed(enabled: bool)

func set_stress_overlay(enabled: bool) -> void:
	stress_overlay_enabled = enabled
	stress_overlay_changed.emit(enabled)

# ── Scenarios ─────────────────────────────────────────────────────────────────
enum Scenario { CALM, MODERATE_WIND, STORM, RESONANCE_EVENT, EARTHQUAKE }

const SCENARIO_PARAMS: Dictionary = {
	Scenario.CALM: {
		"wind_speed_base": 5.0,  "wind_speed_variance": 2.0,
		"temperature_base": 15.0, "temperature_variance": 2.0,
		"seismic_base": 0.008,   "traffic_density": 0.60,
	},
	Scenario.MODERATE_WIND: {
		"wind_speed_base": 25.0, "wind_speed_variance": 8.0,
		"temperature_base": 10.0, "temperature_variance": 3.0,
		"seismic_base": 0.010,   "traffic_density": 0.40,
	},
	Scenario.STORM: {
		"wind_speed_base": 55.0, "wind_speed_variance": 20.0,
		"temperature_base": 5.0,  "temperature_variance": 5.0,
		"seismic_base": 0.020,   "traffic_density": 0.10,
	},
	Scenario.RESONANCE_EVENT: {
		# Historical: ~67 km/h westerly wind on November 7, 1940.
		"wind_speed_base": 67.0, "wind_speed_variance": 5.0,
		"temperature_base": 11.0, "temperature_variance": 1.0,
		"seismic_base": 0.010,   "traffic_density": 0.20,
	},
	Scenario.EARTHQUAKE: {
		"wind_speed_base": 10.0, "wind_speed_variance": 3.0,
		"temperature_base": 12.0, "temperature_variance": 2.0,
		"seismic_base": 0.800,   "traffic_density": 0.20,
	},
}

# ── Simulation State ──────────────────────────────────────────────────────────
enum SimState { PAUSED, PLAYING }
var sim_state: SimState = SimState.PAUSED

var _sim_time:   float = 0.0
var _tick:       int   = 0
var _tick_accum: float = 0.0
var tick_rate:   float = 1.0

var current_scenario: Scenario = Scenario.CALM

var _sections: Array[Node] = []
var _model:    BridgeDataModel

# ── Signals ───────────────────────────────────────────────────────────────────
signal tick_completed(global_data: Dictionary)
signal sim_state_changed(new_state: SimState)
signal scenario_changed(new_scenario: Scenario)

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_model = BridgeDataModel.new()
	set_process(true)
	load_scenario(Scenario.CALM)
	play()

func _process(delta: float) -> void:
	if sim_state != SimState.PLAYING:
		return
	_tick_accum += delta
	var dt: float = 1.0 / tick_rate
	while _tick_accum >= dt:
		_tick_accum -= dt
		_fire_tick()

# ── Section Registry ──────────────────────────────────────────────────────────
func register_section(section: Node) -> void:
	if not _sections.has(section):
		_sections.append(section)

func unregister_section(section: Node) -> void:
	_sections.erase(section)

# ── Playback Control ──────────────────────────────────────────────────────────
func play() -> void:
	if sim_state == SimState.PLAYING:
		return
	sim_state = SimState.PLAYING
	sim_state_changed.emit(sim_state)

func pause() -> void:
	if sim_state == SimState.PAUSED:
		return
	sim_state   = SimState.PAUSED
	_tick_accum = 0.0
	sim_state_changed.emit(sim_state)

func step() -> void:
	_fire_tick()

func reset() -> void:
	sim_state   = SimState.PAUSED
	_sim_time   = 0.0
	_tick       = 0
	_tick_accum = 0.0
	sim_state_changed.emit(sim_state)

func toggle_play_pause() -> void:
	if sim_state == SimState.PLAYING:
		pause()
	else:
		play()

# ── Scenario ──────────────────────────────────────────────────────────────────
func load_scenario(scenario: Scenario) -> void:
	current_scenario = scenario
	scenario_changed.emit(scenario)

func get_scenario_name(scenario: Scenario = current_scenario) -> String:
	match scenario:
		Scenario.CALM:            return "Calm"
		Scenario.MODERATE_WIND:   return "Moderate Wind"
		Scenario.STORM:           return "Storm"
		Scenario.RESONANCE_EVENT: return "Resonance Event (1940)"
		Scenario.EARTHQUAKE:      return "Earthquake"
		_:                        return "Unknown"

# ── Tick ──────────────────────────────────────────────────────────────────────
func _fire_tick() -> void:
	_sim_time += 1.0 / tick_rate
	_tick     += 1

	var params:      Dictionary = SCENARIO_PARAMS[current_scenario]
	var is_quake:    bool       = current_scenario == Scenario.EARTHQUAKE
	var global_data: Dictionary = _model.generate_global(params, _sim_time, is_quake)
	global_data["sim_time"] = _sim_time
	global_data["tick"]     = _tick
	_apply_multipliers(global_data)

	for i: int in range(_sections.size() - 1, -1, -1):
		var section: Node = _sections[i]
		if not is_instance_valid(section):
			_sections.remove_at(i)
			continue
		var pos: Vector3        = section.global_position if section is Node3D else Vector3.ZERO
		var payload: Dictionary = global_data.duplicate()
		var spatial: Dictionary
		if section.get("reverse_traffic"):
			spatial = _model.generate_spatial_reversed(pos, global_data, params, _sim_time)
		else:
			spatial = _model.generate_spatial(pos, global_data, params, _sim_time)
		_apply_multipliers(spatial)
		payload.merge(spatial)
		if section.has_method("receive_data"):
			section.receive_data(payload)

	# Build signal payload: global + midspan spatial for the stream panel display.
	var signal_data: Dictionary = global_data.duplicate()
	var midspan: Dictionary = _model.generate_spatial(Vector3.ZERO, global_data, params, _sim_time)
	_apply_multipliers(midspan)
	signal_data.merge(midspan)
	tick_completed.emit(signal_data)

# ── Channel Multipliers ────────────────────────────────────────────────────────
# Each entry scales the named key in the tick data. Default (absent) = 1.0.
var _multipliers: Dictionary = {}
signal multiplier_changed(key: String, value: float)

func set_multiplier(key: String, value: float) -> void:
	_multipliers[key] = value
	multiplier_changed.emit(key, value)

func reset_multiplier(key: String) -> void:
	_multipliers.erase(key)
	multiplier_changed.emit(key, 1.0)

func get_multiplier(key: String) -> float:
	return _multipliers.get(key, 1.0)

func _apply_multipliers(data: Dictionary) -> void:
	for key in _multipliers:
		if data.has(key):
			data[key] = data[key] * _multipliers[key]

# ── Accessors ─────────────────────────────────────────────────────────────────
func get_section_count() -> int: return _sections.size()
func is_playing()        -> bool: return sim_state == SimState.PLAYING
