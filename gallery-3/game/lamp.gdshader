shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 glass : source_color = vec4(0.29, 0.24, 0.18, 1.0);
uniform vec4 amber : source_color = vec4(1.0, 0.67, 0.29, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.96, 0.77, 1.0);
varying float intensity;

void vertex() {
	intensity = INSTANCE_CUSTOM.r;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float filament = intensity * (0.45 + 0.95 * pow(facing, 2.5));
	ALBEDO = glass.rgb * (0.5 + 0.5 * facing)
		+ amber.rgb * filament + hot.rgb * pow(filament, 3.0);
}
