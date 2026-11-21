extends SubViewport
## Cache filtered sizes on the GPU whenever the instrument face changes.

var paper := StandardMaterial3D.new()
var print_texture := DrawableTexture2D.new()

func _ready() -> void:
	disable_3d = true
	gui_disable_input = true
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	paper.texture_repeat = false
	if DisplayServer.get_name() == "headless":
		paper.albedo_texture = get_texture()
	else:
		print_texture.setup(size.x, size.y, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.BLACK, true)
		paper.albedo_texture = print_texture
	request_print()

func request_print() -> void:
	render_target_update_mode = UPDATE_ONCE
	if paper.albedo_texture == print_texture and not RenderingServer.frame_post_draw.is_connected(_copy_print):
		RenderingServer.frame_post_draw.connect(_copy_print, CONNECT_ONE_SHOT)

func _copy_print() -> void:
	print_texture.blit_rect(Rect2i(Vector2i.ZERO, size), get_texture())
	print_texture.generate_mipmaps()
