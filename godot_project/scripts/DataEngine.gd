extends Node
## DataEngine — simulation infrastructure for the Tacoma Narrows digital twin.
## Autoload singleton: manages timing, section registry, scenario state, and tick dispatch.
## All physics/math is delegated to BridgeDataModel.

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
var tick_rate:   float = 20.0

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

	for i: int in range(_sections.size() - 1, -1, -1):
		var section: Node = _sections[i]
		if not is_instance_valid(section):
			_sections.remove_at(i)
			continue
		var pos: Vector3    = section.global_position if section is Node3D else Vector3.ZERO
		var payload: Dictionary = global_data.duplicate()
		payload.merge(_model.generate_spatial(pos, global_data, params, _sim_time))
		if section.has_method("receive_data"):
			section.receive_data(payload)

	tick_completed.emit(global_data)

# ── Accessors ─────────────────────────────────────────────────────────────────
func get_section_count() -> int: return _sections.size()
func is_playing()        -> bool: return sim_state == SimState.PLAYING
