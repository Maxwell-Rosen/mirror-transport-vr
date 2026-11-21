shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 surface_ink : source_color;
uniform bool shelf;
uniform float m_per_decade;
uniform float base_ns;
uniform vec2 axis_scale;
varying vec3 plot;

void vertex() {
	plot = VERTEX;
}

// One anti-aliased engraved line per unit, fading out when narrower than a pixel.
float ruling(float coordinate) {
	float footprint = max(fwidth(coordinate), 0.0001);
	float distance_to_line = abs(fract(coordinate + 0.5) - 0.5);
	return (1.0 - smoothstep(0.25, 1.20, distance_to_line / footprint))
		* (1.0 - smoothstep(0.18, 0.5, footprint));
}

void fragment() {
	vec3 normal = normalize(cross(dFdx(plot), dFdy(plot)));
	if (normal.y < 0.0) {
		normal = -normal;
	}
	float wall = 1.0 - smoothstep(0.012, 0.18, abs(normal.y));
	float light = 0.70 + 0.30 * dot(normal, normalize(vec3(-0.52, 0.83, -0.34)));
	float decades = plot.y / m_per_decade;
	vec3 ink = surface_ink.rgb * (shelf ? 1.0 : mix(0.59, 1.09, clamp(decades / 3.4, 0.0, 1.0)));
	ink *= mix(light, 0.48, wall);
	float log_ns = decades + log(base_ns) / log(10.0);
	float contours = ruling(log_ns * 4.0);
	float lattice = max(ruling(plot.x / axis_scale.x), ruling(plot.z / (axis_scale.y * 5.0)));
	float lines = shelf ? mix(lattice, contours, wall) : contours;
	ALBEDO = mix(ink, vec3(1.0), (shelf ? 0.18 : 0.26) * lines);
}
