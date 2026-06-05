extends Node
# =============================================================================
# SyncLayer.gd — Data Validation, Buffering, and Anomaly Detection Layer
# Author: Skyler Z. Broussard | Course: TCSS 499 | Spring 2026
# =============================================================================
# What:  Autoload that sits between BridgeDataModel (raw physics output) and
#        DataEngine (tick dispatch). Every sensor packet is validated against
#        declared physical bounds, buffered for UI history graphs, checked for
#        sudden anomalous changes, and stamped with provenance metadata.
# Role:  Quality-control pipeline ensuring downstream consumers (bridge section
#        scripts, stream panels, debug overlay) receive clean, bounded, traceable
#        data. Maintains a 60-tick rolling history per section for graph rendering.
# Deps:  BridgeDataModel (instantiated internally as _model).
# Signals: anomaly_detected(section_id, stream_name, value, previous_value).
# =============================================================================

# ── Constants ─────────────────────────────────────────────────────────────────
const BUFFER_SIZE:              int    = 60      # ticks of history kept per section
const ANOMALY_CHANGE_THRESHOLD: float  = 0.20   # 20 % single-tick change → anomaly
const ANOMALY_MIN_MAGNITUDE:    float  = 1.0e-4  # denominator floor (near-zero guard)
const PROVENANCE_SOURCE:        String = "BridgeDataModel"

## Validated min/max for global sensor streams.
const GLOBAL_RANGES: Dictionary = {
	"wind_speed":        [    0.0,  150.0],  # km/h
	"wind_direction":    [    0.0,  360.0],  # degrees
	"temperature":       [  -20.0,   50.0],  # °C
	"cable_tension":     [50000.0, 200000.0], # kN
	"seismic_vibration": [    0.0,   20.0],  # m/s²
}

## Validated min/max for per-section spatial streams.
const SPATIAL_RANGES: Dictionary = {
	"traffic_load": [0.0,  1.0],
	"resonance":    [-5.0, 5.0],
	"torsion":      [-2.0, 2.0],
	"x_norm":       [-1.0, 1.0],
}

## Keys never checked for anomalies: positional constants and provenance metadata.
const ANOMALY_EXEMPT_KEYS: Array[String] = [
	"x_norm",
	"simulation_tick",
	"simulation_time",
	"source",
]

# ── Signals ───────────────────────────────────────────────────────────────────
signal anomaly_detected(
		section_id:     String,
		stream_name:    String,
		value:          float,
		previous_value: float)

# ── State ─────────────────────────────────────────────────────────────────────
var _model:        BridgeDataModel = BridgeDataModel.new()

## Rolling 60-tick buffer keyed by section_id.
var _buffer:       Dictionary = {}  # section_id -> Array[Dictionary]

## Last validated values for substitution on null/missing inputs.
var _last_global:  Dictionary = {}  # stream_name -> float
var _last_spatial: Dictionary = {}  # section_id  -> { stream_name -> float }

## Append-only anomaly event log.
var _anomaly_log:  Array = []

# ── Public API ────────────────────────────────────────────────────────────────
# Returns the underlying BridgeDataModel instance (used by UI for direct queries).
func get_model() -> BridgeDataModel:
	return _model

## Returns a copy of the 60-tick history for section_id (for UI graphs).
func get_buffer(section_id: String) -> Array:
	return _buffer.get(section_id, []).duplicate()

## Returns a copy of all logged anomaly events.
func get_anomaly_log() -> Array:
	return _anomaly_log.duplicate()

# Clears the in-memory anomaly event log.
func clear_anomaly_log() -> void:
	_anomaly_log.clear()

## Returns all section IDs that have buffer history (excludes synthetic IDs like __midspan__).
func get_section_ids() -> Array:
	var ids: Array = []
	for key in _buffer.keys():
		if not (key as String).begins_with("__"):
			ids.append(key)
	return ids

## Returns the most recent validated spatial snapshot for a section, or {} if none.
func get_latest_spatial(section_id: String) -> Dictionary:
	var buf: Array = _buffer.get(section_id, [])
	return buf.back().duplicate() if not buf.is_empty() else {}

# ── Component 1 + 4: Global Ingestion + Tagging ───────────────────────────────
# Generates a global sensor packet from BridgeDataModel, validates it against
# GLOBAL_RANGES, detects anomalies, updates the last-good baseline, and stamps
# provenance metadata before returning the clean packet to DataEngine.
func process_global(
		params:   Dictionary,
		sim_time: float,
		is_quake: bool,
		tick:     int
) -> Dictionary:
	var raw:       Dictionary = _model.generate_global(params, sim_time, is_quake)
	var validated: Dictionary = _validate(raw, GLOBAL_RANGES, _last_global)
	_check_anomalies("global", validated, _last_global)
	_last_global = validated.duplicate()
	return _tag_provenance(validated, tick, sim_time)

# ── Component 1 + 2 + 3 + 4: Spatial Ingestion + Buffer + Anomaly + Tagging ──
# Generates per-section sensor data (traffic load, resonance, torsion) from
# BridgeDataModel, validates it, detects anomalies, pushes into the rolling
# buffer, and returns a provenance-tagged packet to DataEngine.
func process_spatial(
		section_id:  String,
		world_pos:   Vector3,
		global_data: Dictionary,
		params:      Dictionary,
		sim_time:    float,
		tick:        int,
		reversed:    bool
) -> Dictionary:
	var raw: Dictionary = (
		_model.generate_spatial_reversed(world_pos, global_data, params, sim_time)
		if reversed
		else _model.generate_spatial(world_pos, global_data, params, sim_time)
	)

	if not _last_spatial.has(section_id):
		_last_spatial[section_id] = {}

	var prev:      Dictionary = _last_spatial[section_id]
	var validated: Dictionary = _validate(raw, SPATIAL_RANGES, prev)

	_check_anomalies(section_id, validated, prev)
	_last_spatial[section_id] = validated.duplicate()
	_update_buffer(section_id, validated)

	return _tag_provenance(validated, tick, sim_time)

# ── Component 1: Validation ───────────────────────────────────────────────────
# Clamps each key in raw against its declared physical range. Substitutes the
# last known good value for any null or missing keys so downstream code always
# receives floats within safe bounds.
func _validate(
		raw:       Dictionary,
		ranges:    Dictionary,
		last_good: Dictionary
) -> Dictionary:
	var out: Dictionary = {}
	for key in raw:
		var val = raw[key]
		if val == null:
			# Missing value → substitute last known good.
			out[key] = last_good.get(key, 0.0)
		elif ranges.has(key):
			out[key] = clampf(float(val), ranges[key][0], ranges[key][1])
		else:
			out[key] = val
	# Fill expected keys absent from the raw packet.
	for key in ranges:
		if not out.has(key):
			out[key] = last_good.get(key, 0.0)
	return out

# ── Component 3: Anomaly Detection ───────────────────────────────────────────
# Flags any data channel whose single-tick relative change exceeds
# ANOMALY_CHANGE_THRESHOLD (20%). Emits anomaly_detected and appends to the log.
func _check_anomalies(
		section_id: String,
		current:    Dictionary,
		previous:   Dictionary
) -> void:
	for key in current:
		if key in ANOMALY_EXEMPT_KEYS:
			continue
		if not previous.has(key):
			continue  # no baseline yet on first tick
		var cur:   float = float(current[key])
		var prev:  float = float(previous[key])
		# Use max(|prev|, floor) as denominator to avoid division near zero.
		var denom: float = maxf(absf(prev), ANOMALY_MIN_MAGNITUDE)
		if absf(cur - prev) / denom > ANOMALY_CHANGE_THRESHOLD:
			var event: Dictionary = {
				"section_id":     section_id,
				"stream_name":    key,
				"value":          cur,
				"previous_value": prev,
			}
			_anomaly_log.append(event)
			anomaly_detected.emit(section_id, key, cur, prev)

# ── Component 2: Temporal Buffer ──────────────────────────────────────────────
# Appends the validated snapshot to the section's rolling history and trims
# the oldest entry once the buffer exceeds BUFFER_SIZE ticks.
func _update_buffer(section_id: String, data: Dictionary) -> void:
	if not _buffer.has(section_id):
		_buffer[section_id] = []
	var buf: Array = _buffer[section_id]
	buf.append(data.duplicate())
	while buf.size() > BUFFER_SIZE:
		buf.pop_front()

# ── Component 4: Provenance Tagging ──────────────────────────────────────────
# Stamps simulation_tick, simulation_time, and source onto each outgoing packet
# so consumers can trace exactly when and where every data point was produced.
func _tag_provenance(data: Dictionary, tick: int, sim_time: float) -> Dictionary:
	var out: Dictionary = data.duplicate()
	out["simulation_tick"] = tick
	out["simulation_time"] = sim_time
	out["source"]          = PROVENANCE_SOURCE
	return out