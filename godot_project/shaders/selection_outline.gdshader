shader_type spatial;
// Renders only back faces, expanded along normals — outline peeks out behind original geometry.
render_mode cull_front, unshaded;

uniform float outline_width : hint_range(0.1, 2.0) = 0.45;
uniform vec4  outline_color : source_color          = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
