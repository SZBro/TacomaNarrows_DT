extends Node
# =============================================================================
# DataEngine.gd — Simulation Engine Singleton
# Author: Skyler Z. Broussard | Course: TCSS 499 | Spring 2026
# =============================================================================
# What:  Autoload singleton that drives the digital twin simulation clock and
#        distributes physics data to every registered bridge section each tick.
# Role:  Central hub of the data pipeline. Owns play/pause state, scenario
#        selection, tick rate, and the section registry. On each tick it calls
#        SyncLayer to produce validated sensor data, then pushes per-section
#        payloads to BridgeSection, SectionTower, and CableSystem nodes.
# Deps:  SyncLayer (autoload), BridgeDataModel (owned by SyncLayer).
#        Bridge components register themselves via register_section() on _ready.
# Signals: tick_completed, sim_state_changed, scenario_changed,
#          stress_overlay_changed, multiplier_changed.
# =============================================================================

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

# Returns the discrete structural health state for a data packet by comparing
# wind speed, resonance, and torsion against calibrated severity thresholds.
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

# Converts a discrete SectionState to a normalized 0–1 float for
# threshold-based shader or UI color mapping.
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

# Enables or disables the stress-color shader overlay on all bridge sections
# and broadcasts the change so every registered section can react.
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

# ── Signals ───────────────────────────────────────────────────────────────────
signal tick_completed(global_data: Dictionary)
signal sim_state_changed(new_state: SimState)
signal scenario_changed(new_scenario: Scenario)

# ── Lifecycle ─────────────────────────────────────────────────────────────────
# Starts the engine in CALM mode and begins ticking immediately on scene load.
func _ready() -> void:
	set_process(true)
	load_scenario(Scenario.CALM)
	play()

# Accumulates frame delta time and fires fixed-rate simulation ticks at tick_rate Hz.
func _process(delta: float) -> void:
	if sim_state != SimState.PLAYING:
		return
	_tick_accum += delta
	var dt: float = 1.0 / tick_rate
	while _tick_accum >= dt:
		_tick_accum -= dt
		_fire_tick()

# ── Section Registry ──────────────────────────────────────────────────────────
# Adds a bridge component to the tick dispatch list. Called from each component's _ready().
func register_section(section: Node) -> void:
	if not _sections.has(section):
		_sections.append(section)

# Removes a bridge component from the dispatch list when it exits the scene tree.
func unregister_section(section: Node) -> void:
	_sections.erase(section)

# ── Playback Control ──────────────────────────────────────────────────────────
# Resumes tick generation if currently paused.
func play() -> void:
	if sim_state == SimState.PLAYING:
		return
	sim_state = SimState.PLAYING
	sim_state_changed.emit(sim_state)

# Halts tick generation and clears the accumulator to prevent a burst on resume.
func pause() -> void:
	if sim_state == SimState.PAUSED:
		return
	sim_state   = SimState.PAUSED
	_tick_accum = 0.0
	sim_state_changed.emit(sim_state)

# Fires a single tick regardless of play/pause state (used for manual stepping).
func step() -> void:
	_fire_tick()

# Stops playback and resets simulation time and tick counter to zero.
func reset() -> void:
	sim_state   = SimState.PAUSED
	_sim_time   = 0.0
	_tick       = 0
	_tick_accum = 0.0
	sim_state_changed.emit(sim_state)

# Toggles between playing and paused states.
func toggle_play_pause() -> void:
	if sim_state == SimState.PLAYING:
		pause()
	else:
		play()

# ── Scenario ──────────────────────────────────────────────────────────────────
# Switches the active environmental scenario and notifies all listeners.
func load_scenario(scenario: Scenario) -> void:
	current_scenario = scenario
	scenario_changed.emit(scenario)

# Returns a human-readable display name for the given (or current) scenario.
func get_scenario_name(scenario: Scenario = current_scenario) -> String:
	match scenario:
		Scenario.CALM:            return "Calm"
		Scenario.MODERATE_WIND:   return "Moderate Wind"
		Scenario.STORM:           return "Storm"
		Scenario.RESONANCE_EVENT: return "Resonance Event (1940)"
		Scenario.EARTHQUAKE:      return "Earthquake"
		_:                        return "Unknown"

# ── Tick ──────────────────────────────────────────────────────────────────────
# Core dispatch: advances sim time, generates a validated global data packet via
# SyncLayer, then builds and delivers a per-section payload to every registered node.
func _fire_tick() -> void:
	_sim_time += 1.0 / tick_rate
	_tick     += 1

	var params:      Dictionary = SCENARIO_PARAMS[current_scenario]
	var is_quake:    bool       = current_scenario == Scenario.EARTHQUAKE

	# BridgeDataModel → SyncLayer (validate, buffer, anomaly-detect, tag provenance).
	var global_data: Dictionary = SyncLayer.process_global(params, _sim_time, is_quake, _tick)
	# Preserve legacy keys used by existing section scripts.
	global_data["sim_time"] = _sim_time
	global_data["tick"]     = _tick
	_apply_multipliers(global_data)

	for i: int in range(_sections.size() - 1, -1, -1):
		var section: Node = _sections[i]
		if not is_instance_valid(section):
			# Prune stale section references during reverse iteration to avoid index skew.
			_sections.remove_at(i)
			continue
		var pos:      Vector3    = section.global_position if section is Node3D else Vector3.ZERO
		var reversed: bool       = section.get("reverse_traffic") == true
		var payload:  Dictionary = global_data.duplicate()
		var spatial:  Dictionary = SyncLayer.process_spatial(
				section.name, pos, global_data, params, _sim_time, _tick, reversed)
		_apply_multipliers(spatial)
		payload.merge(spatial)
		if section.has_method("receive_data"):
			section.receive_data(payload)

	# Signal payload: global + midspan for the stream panel / debug overlay.
	var signal_data: Dictionary = global_data.duplicate()
	var midspan:     Dictionary = SyncLayer.process_spatial(
			"__midspan__", Vector3.ZERO, global_data, params, _sim_time, _tick, false)
	_apply_multipliers(midspan)
	signal_data.merge(midspan)
	tick_completed.emit(signal_data)

# ── Channel Multipliers ────────────────────────────────────────────────────────
# Each entry scales the named key in the tick data. Default (absent) = 1.0.
var _multipliers: Dictionary = {}
signal multiplier_changed(key: String, value: float)

# Sets a per-channel scalar applied to that data key on every future tick.
func set_multiplier(key: String, value: float) -> void:
	_multipliers[key] = value
	multiplier_changed.emit(key, value)

# Removes a channel multiplier, returning that key to its unscaled (×1.0) value.
func reset_multiplier(key: String) -> void:
	_multipliers.erase(key)
	multiplier_changed.emit(key, 1.0)

# Returns the current multiplier for a channel (1.0 if none is set).
func get_multiplier(key: String) -> float:
	return _multipliers.get(key, 1.0)

# Scales data channel values in-place for every active multiplier entry.
func _apply_multipliers(data: Dictionary) -> void:
	for key in _multipliers:
		if data.has(key):
			data[key] = data[key] * _multipliers[key]

# ── Accessors ─────────────────────────────────────────────────────────────────
func get_section_count() -> int: return _sections.size()
func is_playing()        -> bool: return sim_state == SimState.PLAYING