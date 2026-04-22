extends RefCounted
class_name UIAnimator

const HOVER_SCALE: float = 1.05
const PRESSED_SCALE: float = 0.94
const ANIMATION_DURATION: float = 0.12
const DISABLED_ALPHA: float = 0.45


static func animate_button_hover(button: BaseButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return

	button.set_meta("ui_hovered", hovered)
	_refresh_button_visual(button)
	var target_scale: float = _get_button_target_scale(button)
	_tween_control_scale(button, target_scale, ANIMATION_DURATION)


static func animate_button_press(button: BaseButton, pressed: bool) -> void:
	if not is_instance_valid(button):
		return

	button.set_meta("ui_pressed", pressed)
	var target_scale: float = _get_button_target_scale(button)
	_tween_control_scale(button, target_scale, ANIMATION_DURATION * 0.85)


static func refresh_button_disabled(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	_refresh_button_visual(button)
	_tween_control_scale(button, _get_button_target_scale(button), ANIMATION_DURATION)


static func pulse_control(control: CanvasItem, tint: Color = Color(1.0, 0.95, 0.55, 1.0), duration: float = 0.28) -> void:
	if not is_instance_valid(control):
		return

	var tween: Tween = control.create_tween()
	tween.tween_property(control, "modulate", tint, duration * 0.45)
	tween.tween_property(control, "modulate", Color(1, 1, 1, 1), duration * 0.55)


static func punch_scale(control: Node2D, multiplier: float = 1.14, duration: float = 0.18) -> void:
	if not is_instance_valid(control):
		return

	var tween: Tween = control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * multiplier, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func count_label_int(label: Label, from_value: int, to_value: int, duration: float = 0.45, prefix: String = "", suffix: String = "") -> Tween:
	if not is_instance_valid(label):
		return null

	var tween: Tween = label.create_tween()
	var value_holder: Array[int] = [from_value]
	tween.tween_method(func(value: int) -> void:
		value_holder[0] = value
		label.text = "%s%s%s" % [prefix, value, suffix]
	, from_value, to_value, duration)
	return tween


static func _get_button_target_scale(button: BaseButton) -> float:
	if button.disabled:
		return 1.0

	var is_pressed: bool = bool(button.get_meta("ui_pressed")) if button.has_meta("ui_pressed") else false
	if is_pressed:
		return PRESSED_SCALE

	var is_hovered: bool = bool(button.get_meta("ui_hovered")) if button.has_meta("ui_hovered") else false
	return HOVER_SCALE if is_hovered else 1.0


static func _refresh_button_visual(button: BaseButton) -> void:
	button.modulate = Color(1, 1, 1, DISABLED_ALPHA) if button.disabled else Color(1, 1, 1, 1)


static func _tween_control_scale(button: BaseButton, target_scale: float, duration: float) -> void:
	button.pivot_offset = button.size * 0.5
	var previous_tween: Variant = button.get_meta("ui_scale_tween") if button.has_meta("ui_scale_tween") else null
	if previous_tween is Tween:
		(previous_tween as Tween).kill()

	var tween: Tween = button.create_tween()
	button.set_meta("ui_scale_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
