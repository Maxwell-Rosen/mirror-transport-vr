shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 amber : source_color = vec4(1.0, 0.67, 0.29, 1.0);
varying float intensity;

void vertex() {
	VERTEX *= 2.65;
	intensity = INSTANCE_CUSTOM.r;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = amber.rgb;
	ALPHA = intensity * 0.36 * pow(facing, 8.0);
}
