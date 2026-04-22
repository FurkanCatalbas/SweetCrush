extends Control
class_name BackgroundLayer

@export var background_texture: Texture2D
@export var fallback_top_color: Color = Color(0.16, 0.14, 0.28, 1.0)
@export var fallback_bottom_color: Color = Color(0.07, 0.07, 0.14, 1.0)
@export var overlay_color: Color = Color(1, 1, 1, 0.0)

@onready var gradient_rect: TextureRect = $Gradient
@onready var texture_rect: TextureRect = $Texture
@onready var overlay_rect: ColorRect = $Overlay


func _ready() -> void:
	_apply_background()


func set_background_texture(texture: Texture2D) -> void:
	background_texture = texture
	_apply_background()


func _apply_background() -> void:
	if not is_node_ready():
		return

	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([fallback_top_color, fallback_bottom_color])
	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	gradient_texture.gradient = gradient
	gradient_texture.width = 16
	gradient_texture.height = 512
	gradient_rect.texture = gradient_texture

	texture_rect.texture = background_texture
	texture_rect.visible = background_texture != null
	overlay_rect.color = overlay_color
