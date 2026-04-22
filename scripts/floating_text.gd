extends Node2D
class_name FloatingText

@onready var label: Label = $Label


func play(text: String, color: Color, world_position: Vector2, scale_multiplier: float = 1.0, duration: float = 0.75, rise_distance: float = 44.0) -> void:
	position = world_position
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE * maxf(0.8, scale_multiplier)
	label.text = text
	label.modulate = color

	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", position.y - rise_distance, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * scale_multiplier * 1.08, duration * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)
