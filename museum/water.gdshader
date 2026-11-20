shader_type spatial;
varying vec2 plane;
void vertex() {
	plane = VERTEX.xz;
}
void fragment() {
	float rings = sin(length(plane - vec2(0.12, 0.28)) * 165.0 - TIME * 4.0);
	float cross_wave = sin(length(plane + vec2(0.21, 0.05)) * 117.0 - TIME * 3.2);
	float glint = smoothstep(0.84, 1.0, rings * 0.74 + cross_wave * 0.26);
	ALBEDO = mix(vec3(0.08, 0.31, 0.32), vec3(0.57, 0.81, 0.76), glint);
	ROUGHNESS = 0.23;
}
