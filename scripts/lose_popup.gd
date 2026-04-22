extends Control
class_name LosePopup

signal retry_pressed()
signal menu_pressed()

@onready var score_value_label: Label = $Center/Panel/VBox/ScoreValue
@onready var target_value_label: Label = $Center/Panel/VBox/TargetValue
@onready var combo_value_label: Label = $Center/Panel/VBox/ComboValue
@onready var retry_button: Button = $Center/Panel/VBox/RetryButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wire_button(retry_button)
	_wire_button(menu_button)


func show_result(result: Dictionary) -> void:
	score_value_label.text = str(result.get("final_score", 0))
	target_value_label.text = str(result.get("target_score", 0))
	combo_value_label.text = str(result.get("max_combo", 0))
	var tween: Tween = PopupAnimator.show_popup(self)
	if tween == null:
		show()


func hide_popup() -> void:
	var tween: Tween = PopupAnimator.hide_popup(self)
	if tween == null:
		hide()


func _on_retry_button_pressed() -> void:
	retry_pressed.emit()


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
