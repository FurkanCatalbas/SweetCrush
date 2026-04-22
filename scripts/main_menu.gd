extends Control
class_name MainMenu

@onready var play_button: Button = $Center/VBox/PlaySlot/PlayButton
@onready var tycoon_button: Button = $Center/VBox/TycoonSlot/TycoonButton
@onready var play_art: TextureRect = $Center/VBox/PlaySlot/PlayArt
@onready var tycoon_art: TextureRect = $Center/VBox/TycoonSlot/TycoonArt

var play_normal_texture: Texture2D
var play_hover_texture: Texture2D
var tycoon_normal_texture: Texture2D
var tycoon_hover_texture: Texture2D


func _ready() -> void:
	play_normal_texture = play_art.texture
	play_hover_texture = load("res://assets/button/oyna1.png") as Texture2D
	tycoon_normal_texture = tycoon_art.texture
	tycoon_hover_texture = load("res://assets/button/kumarhane1.png") as Texture2D

	play_button.pressed.connect(_on_play_button_pressed)
	tycoon_button.pressed.connect(_on_tycoon_button_pressed)
	_wire_button(play_button, play_art)
	_wire_button(tycoon_button, tycoon_art)


func _on_play_button_pressed() -> void:
	SceneManager.change_scene_to_game()


func _on_tycoon_button_pressed() -> void:
	SceneManager.change_scene_to_tycoon()


func _wire_button(button: Button, target_visual: CanvasItem) -> void:
	button.mouse_entered.connect(func() -> void:
		UIAnimator.animate_button_hover(button, true)
		UIAnimator.pulse_control(target_visual, Color(1, 1, 1, 1), 0.12)
		_set_button_hover_texture(button, true)
	)
	button.mouse_exited.connect(func() -> void:
		UIAnimator.animate_button_hover(button, false)
		_set_button_hover_texture(button, false)
	)
	button.button_down.connect(func() -> void:
		UIAnimator.animate_button_press(button, true)
	)
	button.button_up.connect(func() -> void:
		UIAnimator.animate_button_press(button, false)
	)


func _set_button_hover_texture(button: Button, hovered: bool) -> void:
	if button == play_button:
		play_art.texture = play_hover_texture if hovered and play_hover_texture != null else play_normal_texture
		return

	if button == tycoon_button:
		tycoon_art.texture = tycoon_hover_texture if hovered and tycoon_hover_texture != null else tycoon_normal_texture
