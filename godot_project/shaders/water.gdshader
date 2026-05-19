shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3  color_shallow : source_color = vec3(0.12, 0.36, 0.48);
uniform vec3  color_deep    : source_color = vec3(0.04, 0.16, 0.26);
uniform float wave_speed    : hint_range(0.0, 2.0) = 0.35;
uniform float wave_height   : hint_range(0.0, 10.0) = 0.6;
uniform float roughness     : hint_range(0.0, 1.0)  = 0.10;

void vertex() {
	float wx = sin(VERTEX.x * 0.018 + TIME * wave_speed)
			 + sin(VERTEX.x * 0.041 + TIME * wave_speed * 1.3) * 0.4;
	float wz = sin(VERTEX.z * 0.022 + TIME * wave_speed * 0.8)
			 + sin(VERTEX.z * 0.051 + TIME * wave_speed * 1.1) * 0.3;
	VERTEX.y += (wx + wz) * wave_height * 0.5;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO    = mix(color_deep, color_shallow, fresnel * 0.7);
	ROUGHNESS = roughness;
	METALLIC  = 0.08;
	SPECULAR  = 0.75;
}
