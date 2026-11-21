shader_type spatial;
render_mode unshaded;

uniform sampler2D lettering : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 face_color : source_color;
uniform vec4 text_color : source_color;

void fragment() {
	ALBEDO = mix(face_color.rgb, text_color.rgb, texture(lettering, UV).r);
}
