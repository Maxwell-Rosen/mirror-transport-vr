shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D history : filter_linear, repeat_disable;
uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float frame_row;
uniform float travel;
uniform int channel;
uniform float pack_max;
uniform float dye_top;
uniform float mouth;
uniform float mouth_half_width;
uniform float parcel_q;

float waves(vec2 uv) {
	float n = channel == 0 ? 5.0 : (channel == 2 ? 2.0 : 6.0);
	return TAU * (n * uv.x - travel + 0.12 * cos(TAU * uv.y + 1.1 * sin(TAU * uv.x)));
}

void vertex() {
	float a = waves(UV);
	float open_water = smoothstep(0.0, 0.2, min(UV.y, 1.0-UV.y));
	if (channel == 2) {
		open_water *= smoothstep(0.0, 0.15, min(UV.x, 1.0-UV.x));
	}
	VERTEX.y += open_water * (0.0027 * sin(a) + 0.0012 * sin(2.0*a + 3.0*UV.y));
}

float concentration(int strip, float q) {
	ivec2 pixels = textureSize(history, 0);
	float columns = float(pixels.x / 3);
	vec2 texel = vec2(float(strip) * columns + q * (columns - 1.0), frame_row);
	vec2 bytes = texture(history, (texel + 0.5) / vec2(pixels)).rg;
	return pack_max * dot(bytes, vec2(256.0, 1.0)) / 257.0;
}

void fragment() {
	float f;
	if (channel == 2) {
		// The mouth spans the same receiving-bank coordinates as the sluice mesh.
		float bank_q = mouth + (2.0 * UV.y - 1.0) * mouth_half_width;
		f = mix(concentration(1, mouth), concentration(1, bank_q), smoothstep(0.65, 1.0, UV.x));
	} else {
		f = concentration(channel == 3 ? 2 : channel, UV.x);
	}
	vec3 dye = texture(palette, vec2(f / dye_top, 0.5)).rgb;
	float wave = waves(UV);
	float crest = pow(0.5+0.5*cos(wave), 6.0);
	float glint = pow(0.5+0.5*cos(TAU*UV.y*2.3+sin(wave)), 8.0);
	ALBEDO = dye * (0.91 + 0.12*crest) + vec3(0.07*crest + 0.040*glint*(0.5+0.5*sin(wave)));
	if (channel == 3) {
		vec2 offset = (UV - vec2(parcel_q, 0.5)) * vec2(100.0, 5.0);
		float ring = 1.0 - smoothstep(0.12, 0.28, abs(length(offset) - 0.76));
		float visible = smoothstep(0.0, 0.02, min(parcel_q, 1.0-parcel_q));
		ALBEDO = mix(ALBEDO, vec3(1.0), ring * visible);
	}
}
