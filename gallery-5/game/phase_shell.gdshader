shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 ink : source_color;
uniform float opacity = 0.4;
uniform bool clipped = false;
uniform float cut_x = 0.0;
varying vec3 position_in_mesh;

void vertex() {
	position_in_mesh = VERTEX;
}

void fragment() {
	if (clipped && position_in_mesh.x > cut_x) {
		discard;
	}
	vec3 face = abs(normalize(cross(dFdx(position_in_mesh), dFdy(position_in_mesh))));
	ALBEDO = ink.rgb * dot(face, vec3(0.55, 0.95, 0.70));
	ALPHA = opacity;
}
