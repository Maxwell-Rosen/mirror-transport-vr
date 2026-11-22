shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 tile;
uniform vec2 tile_count;
void fragment() {
	float mu = (1.0-UV.y)*70.99155;
	float y = 1.0-log(mu+sqrt(1.0+mu*mu))/log(70.99155+sqrt(1.0+70.99155*70.99155));
	vec2 pt = clamp(vec2((UV.x*4.0+1.0)/6.0, y),vec2(0.001,0.002),vec2(0.999,0.998));
	ALBEDO = texture(atlas,(tile+pt)/tile_count).rgb;
}
