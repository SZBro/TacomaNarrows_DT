shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform float stress_level : hint_range(0.0, 1.0) = 0.0;

const vec3 COLOR_LOW  = vec3(0.20, 0.88, 0.20);
const vec3 COLOR_MID  = vec3(1.00, 0.85, 0.00);
const vec3 COLOR_HIGH = vec3(1.00, 0.15, 0.10);

void fragment() {
	vec3 stress_color;
	if (stress_level < 0.5) {
		stress_color = mix(COLOR_LOW, COLOR_MID, stress_level * 2.0);
	} else {
		stress_color = mix(COLOR_MID, COLOR_HIGH, (stress_level - 0.5) * 2.0);
	}
	ALBEDO = stress_color;
	ALPHA  = sqrt(stress_level) * 0.72;
}
