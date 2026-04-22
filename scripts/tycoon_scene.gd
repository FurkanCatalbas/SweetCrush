extends Node2D
class_name TycoonScene

@onready var tycoon_panel: TycoonPanel = $UI/TycoonPanel
@onready var menu_button: Button = $UI/MenuButton


func _ready() -> void:
	tycoon_panel.bind_systems(SceneManager.wallet, SceneManager.economy_manager, SceneManager.tycoon_manager)
	tycoon_panel.level_start_requested.connect(_on_level_start_requested)
	menu_button.pressed.connect(_on_menu_button_pressed)
	_wire_button(menu_button)
	tycoon_panel.set_status_message("Casino management")


func _on_level_start_requested(level_type: StringName) -> void:
	SceneManager.change_scene_to_game(level_type)


func _on_menu_button_pressed() -> void:
	SceneManager.change_scene_to_menu()


func _wire_button(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		UIAnimator.animate_button_hover(button, true)
	)
	button.mouse_exited.connect(func() -> void:
		UIAnimator.animate_button_hover(button, false)
	)
	button.button_down.connect(func() -> void:
		UIAnimator.animate_button_press(button, true)
	)
	button.button_up.connect(func() -> void:
		UIAnimator.animate_button_press(button, false)
	)
