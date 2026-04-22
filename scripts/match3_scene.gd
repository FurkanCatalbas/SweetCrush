extends Node2D
class_name Match3Scene

const MIN_TOP_MARGIN: float = 140.0

@onready var board: Board = $Board


func _ready() -> void:
	_layout_scene()
	get_viewport().size_changed.connect(_layout_scene)


func _layout_scene() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var board_size: Vector2 = Vector2(board.columns * board.tile_size, board.rows * board.tile_size)
	var board_x: float = floor((viewport_size.x - board_size.x) * 0.5)
	var board_y: float = maxf(MIN_TOP_MARGIN, floor((viewport_size.y - board_size.y) * 0.5))
	board.position = Vector2(board_x, board_y)
