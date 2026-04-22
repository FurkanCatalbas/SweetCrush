extends RefCounted
class_name PopupAnimator

const SHOW_DURATION: float = 0.20
const HIDE_DURATION: float = 0.16
const START_SCALE: Vector2 = Vector2(0.9, 0.9)


static func show_popup(popup: Control, duration: float = SHOW_DURATION) -> Tween:
	if not is_instance_valid(popup):
		return null
	_kill_existing_tween(popup)

	popup.show()
	popup.visible = true
	popup.modulate = Color(1, 1, 1, 0)
	popup.scale = START_SCALE
	popup.pivot_offset = popup.size * 0.5

	var tween: Tween = popup.create_tween()
	popup.set_meta("popup_animator_tween", tween)
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 1), duration)
	tween.parallel().tween_property(popup, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


static func hide_popup(popup: Control, duration: float = HIDE_DURATION) -> Tween:
	if not is_instance_valid(popup):
		return null
	if not popup.visible:
		popup.modulate = Color(1, 1, 1, 1)
		popup.scale = Vector2.ONE
		return null
	_kill_existing_tween(popup)

	popup.pivot_offset = popup.size * 0.5
	var tween: Tween = popup.create_tween()
	popup.set_meta("popup_animator_tween", tween)
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), duration)
	tween.parallel().tween_property(popup, "scale", START_SCALE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			if popup.has_meta("popup_animator_tween"):
				popup.remove_meta("popup_animator_tween")
			popup.hide()
			popup.modulate = Color(1, 1, 1, 1)
			popup.scale = Vector2.ONE
	)
	return tween


static func _kill_existing_tween(popup: Control) -> void:
	if not popup.has_meta("popup_animator_tween"):
		return
	var tween_ref: Variant = popup.get_meta("popup_animator_tween")
	if tween_ref is Tween:
		(tween_ref as Tween).kill()
	popup.remove_meta("popup_animator_tween")
