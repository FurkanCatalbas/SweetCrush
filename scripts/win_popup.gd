extends Control
class_name WinPopup

signal continue_pressed()

@onready var score_value_label: Label = $Center/Panel/VBox/ScoreValue
@onready var moves_value_label: Label = $Center/Panel/VBox/MovesValue
@onready var combo_value_label: Label = $Center/Panel/VBox/ComboValue
@onready var bonus_value_label: Label = $Center/Panel/VBox/BonusValue
@onready var continue_button: Button = $Center/Panel/VBox/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wire_button(continue_button)


func show_result(result: Dictionary) -> void:
	score_value_label.text = str(result.get("final_score", 0))
	moves_value_label.text = str(result.get("remaining_moves", 0))
	combo_value_label.text = str(result.get("max_combo", 0))
	bonus_value_label.text = str(result.get("bonus_power", 0))
	var tween: Tween = PopupAnimator.show_popup(self)
	if tween == null:
		show()


func hide_popup() -> void:
	var tween: Tween = PopupAnimator.hide_popup(self)
	if tween == null:
		hide()


func _on_continue_button_pressed() -> void:
	continue_pressed.emit()


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
