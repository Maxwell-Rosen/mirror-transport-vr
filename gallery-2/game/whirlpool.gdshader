shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D history : filter_linear, repeat_disable;
uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform bool transit = false;
uniform float frame_row;
// Turns on a closed disk, or complete trips down the collector and exhaust.
uniform float travel;

void fragment() {
	vec2 pixels = vec2(textureSize(history, 0));
	float samples = pixels.x * 0.5;
	float column = transit ? samples + UV.x * (samples - 1.0) : UV.y * (samples - 1.0);
	vec2 bytes = texture(history, (vec2(column, frame_row) + 0.5) / pixels).rg;
	float concentration = dot(bytes, vec2(256.0, 1.0)) / 257.0;
	vec3 dye = texture(palette, vec2(concentration, 0.5)).rgb;

	// Neutral reflections trace motion. Only the model concentration sets the dye hue.
	float crest;
	float glint;
	float detail;
	if (transit) {
		float wave = TAU * (7.0 * (UV.x - travel) + 0.20 * cos(PI * UV.y));
		crest = pow(0.5 + 0.5 * cos(wave), 12.0);
		glint = 0.5 + 0.5 * cos(TAU * 2.5 * UV.y + 0.65 * sin(wave));
		float strand = pow(0.5 + 0.5 * cos(TAU * 3.5 * UV.y + 0.5 * sin(wave)), 10.0);
		detail = 0.085 * strand * smoothstep(0.0, 0.90, cos(wave - 2.0 * UV.y));
	} else {
		float spiral = TAU * (5.0 * (UV.x - travel) - 1.24 * UV.y + 0.08 * sin(TAU * UV.y));
		crest = pow(0.5 + 0.5 * cos(spiral), 14.0);
		glint = 0.5 + 0.5 * cos(TAU * 4.0 * UV.y);
		float rings = 4.0 * UV.y;
		float groove = abs(fract(rings + 0.5) - 0.5);
		detail = 0.052 * (1.0 - smoothstep(0.0, max(0.016, fwidth(rings)), groove));
	}
	ALBEDO = dye * (0.94 + 0.06 * glint) + vec3(detail + 0.16 * crest * (0.25 + 0.75 * glint));
}
