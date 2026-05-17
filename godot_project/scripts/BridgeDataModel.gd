class_name BridgeDataModel
extends RefCounted
## Pure physics/math model for the Tacoma Narrows digital twin.
## No state — all functions are deterministic given (params, sim_time, position).
## DataEngine owns an instance and calls generate_global / generate_spatial each tick.

# ── Bridge Geometry (matches CableSystem.gd) ─────────────────────────────────
const TOWER_W_X: float = -426.0
const TOWER_E_X: float =  423.0
const MIDSPAN_X: float = (TOWER_W_X + TOWER_E_X) * 0.5
const HALF_SPAN: float = (TOWER_E_X - TOWER_W_X) * 0.5

# ── Structural Dynamics — original 1940 TNB (approximate) ────────────────────
const F1_VERTICAL:   float = 0.125  # Hz — first symmetric bending mode
const F2_VERTICAL:   float = 0.256  # Hz — second vertical mode
const F1_TORSIONAL:  float = 0.200  # Hz — first torsional mode (1940 collapse driver)
const ZETA_VERTICAL: float = 0.020  # structural damping ratio, bending
const ZETA_TORSION:  float = 0.015  # structural damping ratio, torsion

# Strouhal number for original solid-plate girder deck (~0.11 for bluff body, D=14m)
const STROUHAL: float = 0.11

# Cable baseline pre-tension (kN)
const CABLE_T0: float = 85_000.0

# ── Global Stream Generation ──────────────────────────────────────────────────
## Returns sensor readings uniform across the entire bridge.
## is_earthquake: passed from DataEngine so the seismic pulse can be added.
func generate_global(params: Dictionary, sim_time: float, is_earthquake: bool) -> Dictionary:
	var t: float = sim_time

	# Wind speed — base + three-harmonic turbulence
	var turbulence: float = (
		sin(t * 0.71)         * 0.50 +
		sin(t * 1.37 + 1.10) * 0.30 +
		sin(t * 2.93 + 2.43) * 0.20
	) * params["wind_speed_variance"]
	var wind_speed: float = maxf(0.0, params["wind_speed_base"] + turbulence)

	# Wind direction (°, 0=N CW) — slow drift + gust swing
	var wind_direction: float = fmod(
		270.0 + sin(t * 0.09) * 30.0 + sin(t * 0.41) * 10.0, 360.0
	)

	# Temperature — sinusoidal diurnal cycle
	var temperature: float = (
		params["temperature_base"] + sin(t * 0.044) * params["temperature_variance"]
	)

	# Cable tension (kN) — wind drag + thermal contraction + dynamic oscillation
	var cable_tension: float = (
		CABLE_T0
		+ wind_speed   * 115.0
		+ (temperature - params["temperature_base"]) * -180.0
		+ sin(t * PI)  * 450.0
	)

	# Seismic acceleration (m/s²) — noise floor; earthquake adds P-wave pulse
	var seismic: float = absf(randfn(0.0, params["seismic_base"]))
	if is_earthquake:
		seismic += absf(sin(t * 7.8)) * params["seismic_base"] * 0.60

	return {
		"wind_speed":        wind_speed,
		"wind_direction":    wind_direction,
		"temperature":       temperature,
		"cable_tension":     cable_tension,
		"seismic_vibration": seismic,
	}

# ── Spatial Stream Generation ─────────────────────────────────────────────────
## Returns readings that vary by position along the bridge span.
## x_norm: −1 = west tower, 0 = midspan, +1 = east tower.
func generate_spatial(
		world_pos:   Vector3,
		global_data: Dictionary,
		params:      Dictionary,
		sim_time:    float
) -> Dictionary:
	var t:      float = sim_time
	var x_norm: float = clampf((world_pos.x - MIDSPAN_X) / HALF_SPAN, -1.0, 1.0)

	# ── Traffic ─────────────────────────────────────────────────────────────
	# Two opposing platoon waves; result is always [0, 1].
	var eastbound: float = sin(x_norm * PI * 2.0 - t * 1.40) * 0.5 + 0.5
	var westbound: float = sin(x_norm * PI * 2.0 + t * 1.15) * 0.5 + 0.5
	var traffic_load: float = (eastbound * 0.55 + westbound * 0.45) * params["traffic_density"]

	# ── Resonance ────────────────────────────────────────────────────────────
	# f_vs = St · V(m/s) / D   — vortex-shedding frequency
	var wind_speed: float = global_data["wind_speed"]
	var f_vs:       float = (wind_speed / 3.6) * STROUHAL / 14.0

	# Mode shapes on x_norm ∈ [−1, +1] for a simply-supported span.
	# mode1: zero at towers, max at midspan.
	# mode2: zero at towers + midspan, ±1 at quarter-spans.
	var mode1: float = sin(PI * 0.5 * (x_norm + 1.0))
	var mode2: float = sin(PI * (x_norm + 1.0))

	var resonance: float = (
		(_daf(f_vs, F1_VERTICAL, ZETA_VERTICAL) * mode1 * 0.80 +
		 _daf(f_vs, F2_VERTICAL, ZETA_VERTICAL) * mode2 * 1.20)
		* sin(t * f_vs * TAU)
		* wind_speed * 0.012
	)

	# ── Torsion ──────────────────────────────────────────────────────────────
	# Driven by lateral wind + lane imbalance (scaled by traffic density).
	var lateral_wind:   float = sin(deg_to_rad(global_data["wind_direction"])) * (wind_speed / 3.6)
	var lane_imbalance: float = (eastbound - westbound) * 0.50 * params["traffic_density"] * 0.30
	# First torsional mode: zero at towers, max twist at midspan.
	var torsion_mode:   float = sin(PI * 0.5 * (x_norm + 1.0))

	var torsion: float = (
		_daf(f_vs, F1_TORSIONAL, ZETA_TORSION)
		* (lateral_wind * 0.010 + lane_imbalance * 1.80)
		* torsion_mode
		* sin(t * F1_TORSIONAL * TAU)
	)

	return {
		"traffic_load": traffic_load,
		"resonance":    resonance,
		"torsion":      torsion,
		"x_norm":       x_norm,
	}

# ── Dynamic Amplification Factor ──────────────────────────────────────────────
## Single-DOF harmonic excitation: DAF = 1 / sqrt((1−r²)² + (2ζr)²)
func _daf(f_drive: float, f_natural: float, zeta: float) -> float:
	var r: float = f_drive / maxf(f_natural, 1.0e-4)
	return clampf(
		1.0 / sqrt(pow(1.0 - r * r, 2.0) + pow(2.0 * zeta * r, 2.0)),
		0.0, 60.0
	)
