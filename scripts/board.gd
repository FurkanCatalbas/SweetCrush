extends Node2D
class_name Board

signal board_state_changed(state: Array)
signal swap_started(from_cell: Vector2i, to_cell: Vector2i)
signal swap_reverted(from_cell: Vector2i, to_cell: Vector2i)
signal move_used(from_cell: Vector2i, to_cell: Vector2i)
signal matches_cleared(cells: Array, cascade_index: int)
signal matches_resolved(match_groups: Array, cells: Array, cascade_index: int)
signal cascade_finished(total_cascades: int)
signal board_idle()

const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const SCORE_POPUP_RISE: float = 46.0

@export_range(4, 12, 1) var columns: int = 8
@export_range(4, 12, 1) var rows: int = 8
@export_range(3, 8, 1) var tile_type_count: int = 5
@export var tile_size: float = 72.0
@export var swap_duration: float = 0.12
@export var fall_duration_per_cell: float = 0.06
@export var max_cascade_steps: int = 32
@export var tile_scene: PackedScene = preload("res://scenes/Tile.tscn")
@export var floating_text_scene: PackedScene = preload("res://scenes/ui/FloatingText.tscn")

@onready var tile_layer: Node2D = $TileLayer
@onready var juice_layer: Node2D = $JuiceLayer

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var grid: Array = []
var resolving_move: bool = false
var external_input_locked: bool = false
var pressed_cell: Vector2i = INVALID_CELL
var selected_cell: Vector2i = INVALID_CELL


func _ready() -> void:
	rng.randomize()
	_build_board()
	queue_redraw()


func _draw() -> void:
	var board_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(columns * tile_size, rows * tile_size))
	draw_rect(board_rect, Color(0.11, 0.12, 0.18, 1.0), true)
	draw_rect(board_rect, Color(1, 1, 1, 0.18), false, 2.0)

	for x in range(columns + 1):
		var line_x: float = x * tile_size
		draw_line(Vector2(line_x, 0), Vector2(line_x, rows * tile_size), Color(1, 1, 1, 0.08), 1.0)

	for y in range(rows + 1):
		var line_y: float = y * tile_size
		draw_line(Vector2(0, line_y), Vector2(columns * tile_size, line_y), Color(1, 1, 1, 0.08), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_busy():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_position: Vector2 = to_local(event.position)
		var cell: Vector2i = local_to_cell(local_position)

		if event.pressed:
			pressed_cell = cell if is_inside(cell) else INVALID_CELL
			return

		if pressed_cell == INVALID_CELL:
			return

		if is_inside(cell) and pressed_cell != cell and are_adjacent(pressed_cell, cell):
			clear_selection()
			_try_swap(pressed_cell, cell)
		elif is_inside(cell) and pressed_cell == cell:
			handle_click_selection(cell)

		pressed_cell = INVALID_CELL


func handle_click_selection(cell: Vector2i) -> void:
	if not is_inside(cell):
		clear_selection()
		return

	if selected_cell == INVALID_CELL:
		set_selected_cell(cell)
		return

	if selected_cell == cell:
		clear_selection()
		return

	if are_adjacent(selected_cell, cell):
		var from_cell: Vector2i = selected_cell
		clear_selection()
		_try_swap(from_cell, cell)
		return

	set_selected_cell(cell)


func get_board_state() -> Array[PackedInt32Array]:
	var state: Array[PackedInt32Array] = []
	for y in range(rows):
		var row_state: PackedInt32Array = PackedInt32Array()
		for x in range(columns):
			var tile: Tile = get_tile(Vector2i(x, y))
			row_state.append(tile.tile_type if tile != null else -1)
		state.append(row_state)
	return state


func get_tile(cell: Vector2i) -> Tile:
	if not is_inside(cell):
		return null
	return grid[cell.y][cell.x] as Tile


func get_tile_type(cell: Vector2i) -> int:
	var tile: Tile = get_tile(cell)
	return tile.tile_type if tile != null else -1


func is_busy() -> bool:
	return resolving_move or external_input_locked


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func set_input_locked(locked: bool) -> void:
	external_input_locked = locked
	if locked:
		pressed_cell = INVALID_CELL
		clear_selection()


func reset_board() -> void:
	pressed_cell = INVALID_CELL
	clear_selection()
	resolving_move = false
	_build_board()


func local_to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(floori(local_position.x / tile_size), floori(local_position.y / tile_size))


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2((cell.x * tile_size) + (tile_size * 0.5), (cell.y * tile_size) + (tile_size * 0.5))


func _build_board() -> void:
	for child: Node in tile_layer.get_children():
		child.queue_free()

	grid.clear()
	for y in range(rows):
		var row_data: Array = []
		row_data.resize(columns)
		grid.append(row_data)

	for y in range(rows):
		for x in range(columns):
			var cell: Vector2i = Vector2i(x, y)
			var tile_type: int = _pick_starting_tile_type(cell)
			var tile: Tile = _create_tile(cell, tile_type, y)
			grid[y][x] = tile

	board_state_changed.emit(get_board_state())
	board_idle.emit()


func _pick_starting_tile_type(cell: Vector2i) -> int:
	var options: Array[int] = []
	for tile_type in range(tile_type_count):
		if not _would_create_match_at(cell, tile_type):
			options.append(tile_type)

	if options.is_empty():
		return rng.randi_range(0, tile_type_count - 1)

	return options[rng.randi_range(0, options.size() - 1)]


func _would_create_match_at(cell: Vector2i, tile_type: int) -> bool:
	if cell.x >= 2:
		var left_1: Tile = get_tile(Vector2i(cell.x - 1, cell.y))
		var left_2: Tile = get_tile(Vector2i(cell.x - 2, cell.y))
		if left_1 != null and left_2 != null and left_1.tile_type == tile_type and left_2.tile_type == tile_type:
			return true

	if cell.y >= 2:
		var up_1: Tile = get_tile(Vector2i(cell.x, cell.y - 1))
		var up_2: Tile = get_tile(Vector2i(cell.x, cell.y - 2))
		if up_1 != null and up_2 != null and up_1.tile_type == tile_type and up_2.tile_type == tile_type:
			return true

	return false


func _create_tile(target_cell: Vector2i, tile_type: int, start_row: int) -> Tile:
	var tile: Tile = tile_scene.instantiate() as Tile
	tile_layer.add_child(tile)
	tile.setup(tile_type, target_cell, tile_size)
	tile.reset_visual_state()
	tile.position = cell_to_local(Vector2i(target_cell.x, start_row))
	return tile


func set_selected_cell(cell: Vector2i) -> void:
	if selected_cell != INVALID_CELL:
		var previous_tile: Tile = get_tile(selected_cell)
		if previous_tile != null:
			previous_tile.set_selected(false)

	selected_cell = cell
	var tile: Tile = get_tile(selected_cell)
	if tile != null:
		tile.set_selected(true)


func clear_selection() -> void:
	if selected_cell == INVALID_CELL:
		return

	var tile: Tile = get_tile(selected_cell)
	if tile != null:
		tile.set_selected(false)
	selected_cell = INVALID_CELL


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	if is_busy():
		return
	if not is_inside(a) or not is_inside(b):
		return
	if not are_adjacent(a, b):
		return

	resolving_move = true
	await _process_swap(a, b)
	resolving_move = false
	board_idle.emit()


func _process_swap(a: Vector2i, b: Vector2i) -> void:
	var first_tile: Tile = get_tile(a)
	var second_tile: Tile = get_tile(b)
	if first_tile == null or second_tile == null:
		return

	swap_started.emit(a, b)
	_swap_grid_cells(a, b)
	first_tile.play_pulse(1.06, 0.12)
	second_tile.play_pulse(1.06, 0.12)
	await _animate_pair(first_tile, b, second_tile, a, swap_duration, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	board_state_changed.emit(get_board_state())

	var match_groups: Array = find_match_groups()
	if match_groups.is_empty():
		_swap_grid_cells(a, b)
		await _animate_pair(first_tile, a, second_tile, b, swap_duration * 1.08, Tween.TRANS_BACK, Tween.EASE_OUT)
		first_tile.play_pulse(1.04, 0.12)
		second_tile.play_pulse(1.04, 0.12)
		board_state_changed.emit(get_board_state())
		swap_reverted.emit(a, b)
		return

	move_used.emit(a, b)
	await _resolve_matches(match_groups)


func _swap_grid_cells(a: Vector2i, b: Vector2i) -> void:
	var first_tile: Tile = get_tile(a)
	var second_tile: Tile = get_tile(b)
	grid[a.y][a.x] = second_tile
	grid[b.y][b.x] = first_tile

	if first_tile != null:
		first_tile.set_cell(b)
	if second_tile != null:
		second_tile.set_cell(a)


func _animate_pair(first_tile: Tile, first_target: Vector2i, second_tile: Tile, second_target: Vector2i, duration: float, transition: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(first_tile, "position", cell_to_local(first_target), duration).set_trans(transition).set_ease(ease_type)
	tween.tween_property(second_tile, "position", cell_to_local(second_target), duration).set_trans(transition).set_ease(ease_type)
	await tween.finished


func find_matches() -> Array[Vector2i]:
	return _flatten_match_groups(find_match_groups())


func find_match_groups() -> Array:
	var groups: Array = []

	for y in range(rows):
		var run_type: int = -1
		var run_start: int = 0
		var run_length: int = 0

		for x in range(columns):
			var tile: Tile = get_tile(Vector2i(x, y))
			var current_type: int = tile.tile_type if tile != null else -1

			if current_type != -1 and current_type == run_type:
				run_length += 1
			else:
				_append_run_group(groups, true, y, run_start, run_length, run_type)
				run_type = current_type
				run_start = x
				run_length = 1

		_append_run_group(groups, true, y, run_start, run_length, run_type)

	for x in range(columns):
		var run_type: int = -1
		var run_start: int = 0
		var run_length: int = 0

		for y in range(rows):
			var tile: Tile = get_tile(Vector2i(x, y))
			var current_type: int = tile.tile_type if tile != null else -1

			if current_type != -1 and current_type == run_type:
				run_length += 1
			else:
				_append_run_group(groups, false, x, run_start, run_length, run_type)
				run_type = current_type
				run_start = y
				run_length = 1

		_append_run_group(groups, false, x, run_start, run_length, run_type)

	return groups


func _append_run_group(groups: Array, horizontal: bool, fixed_index: int, run_start: int, run_length: int, run_type: int) -> void:
	if run_type == -1 or run_length < 3:
		return

	var group: Array[Vector2i] = []
	for offset in range(run_length):
		var cell: Vector2i = Vector2i(run_start + offset, fixed_index) if horizontal else Vector2i(fixed_index, run_start + offset)
		group.append(cell)
	groups.append(group)


func _flatten_match_groups(match_groups: Array) -> Array[Vector2i]:
	var unique_cells: Dictionary = {}
	for group: Variant in match_groups:
		for cell: Variant in group:
			unique_cells[cell] = true

	var results: Array[Vector2i] = []
	for cell_key: Variant in unique_cells.keys():
		results.append(cell_key as Vector2i)
	return results


func _resolve_matches(initial_match_groups: Array) -> void:
	var cascade_index: int = 0
	var pending_groups: Array = initial_match_groups

	# Random refill can chain repeatedly, so guard the loop explicitly.
	while not pending_groups.is_empty() and cascade_index < max_cascade_steps:
		cascade_index += 1
		var cleared_cells: Array[Vector2i] = _flatten_match_groups(pending_groups)
		_emit_match_feedback(pending_groups, cascade_index)
		matches_cleared.emit(cleared_cells, cascade_index)
		matches_resolved.emit(pending_groups, cleared_cells, cascade_index)
		await _clear_matches(cleared_cells)
		board_state_changed.emit(get_board_state())

		var fall_moves: Array[Dictionary] = _apply_gravity()
		await _animate_moves(fall_moves)

		var refill_moves: Array[Dictionary] = _refill_board()
		await _animate_moves(refill_moves)
		board_state_changed.emit(get_board_state())

		pending_groups = find_match_groups()

	if cascade_index > 0:
		cascade_finished.emit(cascade_index)

	if cascade_index >= max_cascade_steps and not pending_groups.is_empty():
		push_warning("Cascade limit reached. Board was stopped to avoid an endless loop.")



func _clear_matches(cells: Array[Vector2i]) -> void:
	var tweens: Array[Tween] = []
	for cell: Vector2i in cells:
		var tile: Tile = get_tile(cell)
		if tile == null:
			continue
		grid[cell.y][cell.x] = null
		tweens.append(tile.play_match_clear())

	for tween: Tween in tweens:
		await tween.finished

	for cell: Vector2i in cells:
		var tile: Tile = get_tile(cell)
		if tile != null:
			continue
		for child: Node in tile_layer.get_children():
			var tile_node: Tile = child as Tile
			if tile_node != null and tile_node.cell == cell:
				tile_node.queue_free()


func _apply_gravity() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []

	for x in range(columns):
		var write_row: int = rows - 1

		for y in range(rows - 1, -1, -1):
			var tile: Tile = get_tile(Vector2i(x, y))
			if tile == null:
				continue

			if y != write_row:
				grid[write_row][x] = tile
				grid[y][x] = null
				tile.set_cell(Vector2i(x, write_row))
				moves.append({
					"tile": tile,
					"target_cell": Vector2i(x, write_row),
					"distance": write_row - y,
				})

			write_row -= 1

		for empty_row in range(write_row, -1, -1):
			grid[empty_row][x] = null

	return moves


func _refill_board() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []

	for x in range(columns):
		var spawn_count: int = 0
		for y in range(rows - 1, -1, -1):
			if grid[y][x] != null:
				continue

			spawn_count += 1
			var target_cell: Vector2i = Vector2i(x, y)
			var start_row: int = -spawn_count
			var tile_type: int = rng.randi_range(0, tile_type_count - 1)
			var tile: Tile = _create_tile(target_cell, tile_type, start_row)
			grid[y][x] = tile
			moves.append({
				"tile": tile,
				"target_cell": target_cell,
				"distance": y - start_row,
			})

	return moves


func _animate_moves(moves: Array[Dictionary]) -> void:
	if moves.is_empty():
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	for move: Dictionary in moves:
		var tile: Tile = move["tile"] as Tile
		var target_cell: Vector2i = move["target_cell"]
		var distance: int = int(move["distance"])
		var duration: float = maxf(swap_duration, distance * fall_duration_per_cell)
		tween.tween_property(tile, "position", cell_to_local(target_cell), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished

	var bounced: Dictionary = {}
	for move: Dictionary in moves:
		var tile: Tile = move["tile"] as Tile
		if tile == null or bounced.has(tile):
			continue
		bounced[tile] = true
		tile.play_land_bounce()


func _emit_match_feedback(match_groups: Array, cascade_index: int) -> void:
	for group: Variant in match_groups:
		var cells: Array = group as Array
		if cells.is_empty():
			continue
		var center: Vector2 = Vector2.ZERO
		for cell_value: Variant in cells:
			center += cell_to_local(cell_value as Vector2i)
		center /= float(cells.size())
		var popup_score: int = JuiceHelper.get_group_score_value(cells.size(), cascade_index)
		_spawn_floating_text("+%s" % popup_score, center, Color(1.0, 0.93, 0.45), 1.0)

	if cascade_index > 1:
		var combo_feedback: Dictionary = JuiceHelper.get_combo_feedback(cascade_index)
		var combo_position: Vector2 = Vector2((columns * tile_size) * 0.5, tile_size * 0.6)
		_spawn_floating_text(str(combo_feedback.get("text", "Combo")), combo_position, combo_feedback.get("color", Color.WHITE), float(combo_feedback.get("scale", 1.0)), 0.95, SCORE_POPUP_RISE + 18.0)


func _spawn_floating_text(text: String, local_position: Vector2, color: Color, scale_multiplier: float, duration: float = 0.75, rise_distance: float = SCORE_POPUP_RISE) -> void:
	var floating_text: FloatingText = floating_text_scene.instantiate() as FloatingText
	juice_layer.add_child(floating_text)
	floating_text.play(text, color, local_position, scale_multiplier, duration, rise_distance)
