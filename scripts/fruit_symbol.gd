extends Node2D
class_name FruitSymbol

const KIND_FRUIT: StringName = &"fruit"
const KIND_MULTIPLIER: StringName = &"multiplier"

const FRUIT_COLORS: Dictionary = {
	&"cherry": Color(0.96, 0.27, 0.40),
	&"apple": Color(0.78, 0.93, 0.31),
	&"grape": Color(0.62, 0.42, 0.95),
	&"banana": Color(0.99, 0.89, 0.30),
	&"watermelon": Color(0.24, 0.80, 0.50),
}
const FRUIT_LABELS: Dictionary = {
	&"cherry": "CH",
	&"apple": "AP",
	&"grape": "GR",
	&"banana": "BN",
	&"watermelon": "WM",
}
const MULTIPLIER_COLOR: Color = Color(0.99, 0.64, 0.25)

@onready var body: Polygon2D = $Body
@onready var outline: Line2D = $Outline
@onready var label: Label = $Label

var kind: StringName = KIND_FRUIT
var fruit_id: StringName = &"cherry"
var multiplier_value: int = 0
var cell: Vector2i = Vector2i.ZERO
var symbol_size: float = 64.0


func setup_from_data(symbol_data: Dictionary, new_cell: Vector2i, new_size: float) -> void:
	kind = symbol_data.get("kind", KIND_FRUIT)
	fruit_id = symbol_data.get("fruit_id", &"cherry")
	multiplier_value = int(symbol_data.get("multiplier_value", 0))
	cell = new_cell
	symbol_size = new_size
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)
	_update_geometry()
	_update_visuals()


func play_land_bounce() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.10, 0.92), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func play_multiplier_pulse() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "color", Color(1.0, 0.92, 0.40), 0.12)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "color", MULTIPLIER_COLOR, 0.14)


func play_win_burst(duration: float = 0.18) -> Tween:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	return tween


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell


func get_symbol_data() -> Dictionary:
	return {
		"kind": kind,
		"fruit_id": fruit_id,
		"multiplier_value": multiplier_value,
		"cell": cell,
	}


func _update_geometry() -> void:
	var half_size: float = symbol_size * 0.42
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(half_size, half_size),
		Vector2(-half_size, half_size),
	])
	body.polygon = points
	outline.points = points
	label.position = Vector2(-half_size, -half_size)
	label.size = Vector2(half_size * 2.0, half_size * 2.0)
	label.add_theme_font_size_override("font_size", int(symbol_size * 0.26))


func _update_visuals() -> void:
	if kind == KIND_MULTIPLIER:
		body.color = MULTIPLIER_COLOR
		label.text = "x%s" % multiplier_value
	else:
		body.color = FRUIT_COLORS.get(fruit_id, Color.WHITE)
		label.text = FRUIT_LABELS.get(fruit_id, "?")

	outline.default_color = Color(1, 1, 1, 0.26)
	outline.width = maxf(2.0, symbol_size * 0.04)
	label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.18))
