extends Node2D
class_name Tile

const TILE_COLORS: Array[Color] = [
	Color(0.95, 0.35, 0.45),
	Color(0.30, 0.75, 0.98),
	Color(0.99, 0.84, 0.28),
	Color(0.54, 0.84, 0.38),
	Color(0.72, 0.52, 0.95),
]

const TILE_SYMBOLS: Array[String] = ["A", "B", "C", "D", "E"]

@onready var body: Polygon2D = $Body
@onready var outline: Line2D = $Outline
@onready var symbol: Label = $Symbol

var tile_type: int = 0
var cell: Vector2i = Vector2i.ZERO
var tile_size: float = 72.0
var is_selected: bool = false


func setup(new_type: int, new_cell: Vector2i, new_size: float) -> void:
	tile_type = new_type
	cell = new_cell
	tile_size = new_size
	_update_geometry()
	_update_visuals()


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_visuals()
	if selected:
		play_pulse(1.08, 0.14)


func play_pulse(scale_multiplier: float = 1.12, duration: float = 0.16) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * scale_multiplier, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_land_bounce() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.08, 0.92), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func play_match_clear(duration: float = 0.18) -> Tween:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	return tween


func reset_visual_state() -> void:
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)


func _update_geometry() -> void:
	var half_size: float = tile_size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(half_size, half_size),
		Vector2(-half_size, half_size),
	])
	body.polygon = points
	outline.points = points
	symbol.position = Vector2(-half_size, -half_size)
	symbol.size = Vector2(tile_size, tile_size)
	symbol.add_theme_font_size_override("font_size", int(tile_size * 0.42))


func _update_visuals() -> void:
	var safe_type: int = clampi(tile_type, 0, TILE_COLORS.size() - 1)
	body.color = TILE_COLORS[safe_type]
	symbol.text = TILE_SYMBOLS[safe_type]
	symbol.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))

	if is_selected:
		outline.default_color = Color(1, 1, 1, 0.95)
		outline.width = maxf(4.0, tile_size * 0.08)
	else:
		outline.default_color = Color(1, 1, 1, 0.28)
		outline.width = maxf(2.0, tile_size * 0.04)
