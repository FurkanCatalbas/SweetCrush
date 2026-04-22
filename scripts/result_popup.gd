extends Control
class_name ResultPopup

signal continue_pressed()
signal menu_pressed()

@onready var reward_value_label: Label = $Center/Panel/VBox/RewardValue
@onready var continue_button: Button = $Center/Panel/VBox/ContinueButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wire_button(continue_button)
	_wire_button(menu_button)


func show_result(total_reward: int) -> void:
	reward_value_label.text = str(total_reward)
	var tween: Tween = PopupAnimator.show_popup(self)
	if tween == null:
		show()


func hide_popup() -> void:
	var tween: Tween = PopupAnimator.hide_popup(self)
	if tween == null:
		hide()


func _on_continue_button_pressed() -> void:
	continue_pressed.emit()


func _on_menu_button_pressed() -> void:
	menu_pressed.emit()


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
