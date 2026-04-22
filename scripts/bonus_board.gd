extends Node2D
class_name BonusBoard

signal symbols_spawned(symbols: Array)

@export_range(4, 9, 1) var columns: int = 7
@export_range(4, 8, 1) var rows: int = 6
@export var cell_size: float = 58.0
@export var spawn_duration: float = 0.20
@export var fall_duration_per_cell: float = 0.07
@export var clear_duration: float = 0.14
@export var refresh_clear_duration: float = 0.20
@export var symbol_scene: PackedScene = preload("res://scenes/ui/FruitSymbol.tscn")

var manager: BonusManager
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var grid: Array = []


func _ready() -> void:
	rng.randomize()
	_reset_grid()
	queue_redraw()


func _draw() -> void:
	var board_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(columns * cell_size, rows * cell_size))
	draw_rect(board_rect, Color(0.19, 0.10, 0.24, 0.92), true)
	draw_rect(board_rect, Color(1, 1, 1, 0.16), false, 2.0)

	for x in range(columns + 1):
		var line_x: float = x * cell_size
		draw_line(Vector2(line_x, 0), Vector2(line_x, rows * cell_size), Color(1, 1, 1, 0.08), 1.0)

	for y in range(rows + 1):
		var line_y: float = y * cell_size
		draw_line(Vector2(0, line_y), Vector2(columns * cell_size, line_y), Color(1, 1, 1, 0.08), 1.0)


func set_manager(new_manager: BonusManager) -> void:
	manager = new_manager


func reset_board() -> void:
	for child: Node in get_children():
		child.queue_free()
	_reset_grid()


func build_initial_board() -> void:
	reset_board()
	await _spawn_full_board(true)


func refresh_full_board() -> void:
	await _clear_all_symbols()
	_reset_grid()
	await _spawn_full_board(false)


func _spawn_full_board(initial_fill: bool) -> void:
	var spawn_moves: Array[Dictionary] = []
	var spawned_entries: Array = []

	for y in range(rows):
		for x in range(columns):
			var cell: Vector2i = Vector2i(x, y)
			var symbol_data: Dictionary = manager.roll_symbol_data(rng, initial_fill)
			var start_row: int = -rows + y
			var symbol: FruitSymbol = _create_symbol(symbol_data, cell, start_row)
			grid[y][x] = symbol
			spawn_moves.append({
				"symbol": symbol,
				"target_cell": cell,
				"distance": rows - start_row,
			})
			spawned_entries.append(symbol.get_symbol_data())

	await _animate_moves(spawn_moves)
	symbols_spawned.emit(spawned_entries)


func get_symbol_entries() -> Array:
	var entries: Array = []
	for y in range(rows):
		for x in range(columns):
			var symbol: FruitSymbol = grid[y][x] as FruitSymbol
			if symbol == null:
				continue
			entries.append(symbol.get_symbol_data())
	return entries


func resolve_winning_step(step_result: Dictionary) -> void:
	var cells_to_clear: Array[Vector2i] = []
	cells_to_clear.append_array(step_result.get("winning_cells", []))
	cells_to_clear.append_array(step_result.get("multiplier_cells", []))
	var unique_cells: Array[Vector2i] = _unique_cells(cells_to_clear)
	await _play_step_feedback(step_result)

	await _clear_cells(unique_cells)

	var fall_moves: Array[Dictionary] = _apply_gravity()
	await _animate_moves(fall_moves)

	var refill_result: Dictionary = _refill_board()
	await _animate_moves(refill_result.get("moves", []))
	var spawned_entries: Array = refill_result.get("spawned_entries", [])
	if not spawned_entries.is_empty():
		symbols_spawned.emit(spawned_entries)


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2((cell.x * cell_size) + (cell_size * 0.5), (cell.y * cell_size) + (cell_size * 0.5))


func _reset_grid() -> void:
	grid.clear()
	for y in range(rows):
		var row_data: Array = []
		row_data.resize(columns)
		grid.append(row_data)


func _create_symbol(symbol_data: Dictionary, target_cell: Vector2i, start_row: int) -> FruitSymbol:
	var symbol: FruitSymbol = symbol_scene.instantiate() as FruitSymbol
	add_child(symbol)
	symbol.setup_from_data(symbol_data, target_cell, cell_size)
	symbol.position = cell_to_local(Vector2i(target_cell.x, start_row))
	return symbol


func _clear_cells(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return

	var symbols_to_free: Array[FruitSymbol] = []
	var tweens: Array[Tween] = []

	for cell: Vector2i in cells:
		if not _is_inside(cell):
			continue
		var symbol: FruitSymbol = grid[cell.y][cell.x] as FruitSymbol
		if symbol == null:
			continue

		grid[cell.y][cell.x] = null
		symbols_to_free.append(symbol)
		tweens.append(symbol.play_win_burst(clear_duration))

	for tween: Tween in tweens:
		await tween.finished

	for symbol: FruitSymbol in symbols_to_free:
		symbol.queue_free()


func _clear_all_symbols() -> void:
	var symbols_to_free: Array[FruitSymbol] = []
	for child: Node in get_children():
		var symbol: FruitSymbol = child as FruitSymbol
		if symbol != null:
			symbols_to_free.append(symbol)

	if symbols_to_free.is_empty():
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for symbol: FruitSymbol in symbols_to_free:
		tween.tween_property(symbol, "scale", Vector2(0.2, 0.2), refresh_clear_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(symbol, "modulate:a", 0.0, refresh_clear_duration)

	await tween.finished
	for symbol: FruitSymbol in symbols_to_free:
		symbol.queue_free()


func _apply_gravity() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []

	for x in range(columns):
		var write_row: int = rows - 1

		for y in range(rows - 1, -1, -1):
			var symbol: FruitSymbol = grid[y][x] as FruitSymbol
			if symbol == null:
				continue

			if y != write_row:
				grid[write_row][x] = symbol
				grid[y][x] = null
				symbol.set_cell(Vector2i(x, write_row))
				moves.append({
					"symbol": symbol,
					"target_cell": Vector2i(x, write_row),
					"distance": write_row - y,
				})

			write_row -= 1

		for empty_row in range(write_row, -1, -1):
			grid[empty_row][x] = null

	return moves


func _refill_board() -> Dictionary:
	var moves: Array[Dictionary] = []
	var spawned_entries: Array = []

	for x in range(columns):
		var spawn_count: int = 0
		for y in range(rows - 1, -1, -1):
			if grid[y][x] != null:
				continue

			spawn_count += 1
			var cell: Vector2i = Vector2i(x, y)
			var start_row: int = -spawn_count
			var symbol_data: Dictionary = manager.roll_symbol_data(rng, false)
			var symbol: FruitSymbol = _create_symbol(symbol_data, cell, start_row)
			grid[y][x] = symbol
			moves.append({
				"symbol": symbol,
				"target_cell": cell,
				"distance": y - start_row,
			})
			spawned_entries.append(symbol.get_symbol_data())

	return {
		"moves": moves,
		"spawned_entries": spawned_entries,
	}


func _animate_moves(moves: Array) -> void:
	if moves.is_empty():
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for move: Variant in moves:
		var move_data: Dictionary = move as Dictionary
		var symbol: FruitSymbol = move_data.get("symbol", null) as FruitSymbol
		if symbol == null:
			continue
		var target_cell: Vector2i = move_data.get("target_cell", Vector2i.ZERO)
		var distance: int = int(move_data.get("distance", 1))
		var duration: float = maxf(spawn_duration, float(distance) * fall_duration_per_cell)
		tween.tween_property(symbol, "position", cell_to_local(target_cell), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished

	var bounced: Dictionary = {}
	for move: Variant in moves:
		var move_data: Dictionary = move as Dictionary
		var symbol: FruitSymbol = move_data.get("symbol", null) as FruitSymbol
		if symbol == null or bounced.has(symbol):
			continue
		bounced[symbol] = true
		symbol.play_land_bounce()


func _unique_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var unique_map: Dictionary = {}
	for cell: Vector2i in cells:
		unique_map[cell] = true

	var unique_cells: Array[Vector2i] = []
	for cell_key: Variant in unique_map.keys():
		unique_cells.append(cell_key as Vector2i)
	return unique_cells


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


func _play_step_feedback(step_result: Dictionary) -> void:
	for cell_value: Variant in step_result.get("multiplier_cells", []):
		var cell: Vector2i = cell_value as Vector2i
		if not _is_inside(cell):
			continue
		var symbol: FruitSymbol = grid[cell.y][cell.x] as FruitSymbol
		if symbol != null:
			symbol.play_multiplier_pulse()

	await get_tree().create_timer(0.12).timeout
