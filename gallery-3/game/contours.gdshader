shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 ink : source_color;
uniform vec3 domain_min;
uniform vec3 domain_max;
uniform bool outline = false;
varying vec3 phase_position;

void vertex() {
	phase_position = VERTEX;
}

void fragment() {
	// The GLB caps its cell unions for volume checks. Display the internal threshold faces.
	vec3 to_limit = min(abs(phase_position - domain_min), abs(phase_position - domain_max));
	if (min(to_limit.x, min(to_limit.y, to_limit.z)) < 0.000001) {
		discard;
	}
	// A 3 mm band on the first positive velocity bin traces the section marked on the print.
	bool trace = phase_position.z <= 0.0 && phase_position.z > -0.003 && fwidth(phase_position.z) > 0.0000001;
	ALBEDO = ink.rgb;
	float opacity = outline ? mix(0.045, 0.80, pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0)) : ink.a;
	ALPHA = trace ? 0.95 : opacity;
}
