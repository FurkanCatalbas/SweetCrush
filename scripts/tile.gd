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
