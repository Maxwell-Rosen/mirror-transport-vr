shader_type spatial;
global uniform float visit_time;
varying vec2 plane;
void vertex() {
	plane = VERTEX.xz;
}
// Fade wave contrast as crests approach one cycle per two screen pixels.
float ripple(vec2 offset, float frequency, float speed) {
	float phase = length(offset) * frequency;
	float visibility = 1.0 - smoothstep(1.0, 3.14159, fwidth(phase));
	return sin(phase - visit_time * speed) * visibility;
}
void fragment() {
	float rings = ripple(plane - vec2(0.12, 0.28), 165.0, 4.0);
	float cross_wave = ripple(plane + vec2(0.21, 0.05), 117.0, 3.2);
	float glint = smoothstep(0.84, 1.0, rings * 0.74 + cross_wave * 0.26);
	ALBEDO = mix(vec3(0.08, 0.31, 0.32), vec3(0.57, 0.81, 0.76), glint);
	ROUGHNESS = 0.23;
}
