shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://gallery-3/game/wave.gdshaderinc"

uniform vec4 glass : source_color = vec4(0.09, 0.12, 0.12, 1.0);
uniform vec4 amber : source_color = vec4(1.0, 0.70, 0.29, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.97, 0.76, 1.0);
varying float intensity;

void vertex() {
	intensity = lamp_drive(INSTANCE_CUSTOM);
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float filament = intensity * (0.70 + 0.30 * facing);
	ALBEDO = mix(glass.rgb * (0.5 + 0.5 * facing), amber.rgb, filament)
		+ hot.rgb * (0.30 * filament * filament);
}
