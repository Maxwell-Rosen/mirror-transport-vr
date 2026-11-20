shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float streak = sin(UV.y * 49.0 - TIME * 9.4 + sin(UV.x * 12.0 + UV.y * 9.0) * 2.4);
	float froth = smoothstep(0.2, 0.99, streak);
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = mix(vec3(0.46, 0.70, 0.72), vec3(0.76, 0.91, 0.89), 0.54 * froth + 0.36 * edge);
	ALPHA = 0.34 + 0.37 * froth + 0.24 * edge;
	ROUGHNESS = 0.19;
}
