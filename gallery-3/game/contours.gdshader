shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 ink : source_color;
uniform vec3 domain_min;
uniform vec3 domain_max;
uniform bool outline = false;
uniform bool open_ends = true;
varying vec3 phase_position;

void vertex() {
	phase_position = VERTEX;
}

void fragment() {
	// The GLB caps its cell unions for volume checks. Display the internal threshold faces.
	vec3 to_limit = min(abs(phase_position - domain_min), abs(phase_position - domain_max));
	if (open_ends && min(to_limit.x, min(to_limit.y, to_limit.z)) < 0.000001) {
		discard;
	}
	// A 3 mm band on the first positive velocity bin traces the section marked on the print.
	// Integrate the band over a pixel footprint so it fades continuously when subpixel.
	float footprint = max(fwidth(phase_position.z), 0.0001);
	float low = phase_position.z - 0.5 * footprint;
	float high = phase_position.z + 0.5 * footprint;
	float coverage = max(0.0, min(high, 0.0) - max(low, -0.003)) / footprint;
	// Faces on a constant velocity plane never cross the section.
	coverage *= smoothstep(0.0001, 0.0002, footprint);
	ALBEDO = ink.rgb;
	float opacity = outline ? mix(0.045, 0.80, pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0)) : ink.a;
	ALPHA = mix(opacity, 0.95, clamp(coverage, 0.0, 1.0));
}
