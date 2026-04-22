extends Node
class_name LevelManager

signal state_changed(state: Dictionary)
signal move_count_changed(remaining_moves: int)
signal score_changed(current_score: int, target_score: int, delta: int)
signal combo_changed(current_combo: int, max_combo: int)
signal board_lock_changed(locked: bool)
signal level_won(bonus_data: Dictionary)
signal level_lost(summary: Dictionary)

const DEFAULT_STARTING_MOVES: int = 20
const DEFAULT_TARGET_SCORE: int = 2500

const MATCH_3_SCORE: int = 100
const MATCH_4_SCORE: int = 180
const MATCH_5_SCORE: int = 300
const EXTRA_TILE_SCORE: int = 90
const CASCADE_STEP_BONUS: int = 75

const BONUS_SCORE_DIVISOR: int = 1000

enum LevelResult {
	PLAYING,
	WON,
	LOST,
}

@export var default_starting_moves: int = DEFAULT_STARTING_MOVES
@export var default_target_score: int = DEFAULT_TARGET_SCORE

var starting_moves: int = DEFAULT_STARTING_MOVES
var remaining_moves: int = DEFAULT_STARTING_MOVES
var target_score: int = DEFAULT_TARGET_SCORE
var current_score: int = 0
var current_combo: int = 0
var max_combo: int = 0
var level_result: int = LevelResult.PLAYING
var board_input_locked: bool = false


func start_level(new_target_score: int = -1, new_starting_moves: int = -1) -> void:
	target_score = new_target_score if new_target_score > 0 else default_target_score
	starting_moves = new_starting_moves if new_starting_moves > 0 else default_starting_moves
	remaining_moves = starting_moves
	current_score = 0
	current_combo = 0
	max_combo = 0
	level_result = LevelResult.PLAYING
	board_input_locked = false
	_emit_all_state(0)


func can_play() -> bool:
	return level_result == LevelResult.PLAYING


func register_move_used() -> void:
	if not can_play():
		return

	remaining_moves = maxi(remaining_moves - 1, 0)
	current_combo = 0
	move_count_changed.emit(remaining_moves)
	combo_changed.emit(current_combo, max_combo)
	state_changed.emit(get_state_snapshot())


func register_matches(match_groups: Array, cascade_index: int) -> int:
	if not can_play():
		return 0

	if match_groups.is_empty():
		return 0

	current_combo = maxi(current_combo, cascade_index)
	max_combo = maxi(max_combo, current_combo)

	var delta: int = calculate_groups_score(match_groups, cascade_index)
	current_score += delta

	score_changed.emit(current_score, target_score, delta)
	combo_changed.emit(current_combo, max_combo)
	state_changed.emit(get_state_snapshot())
	return delta


func finalize_turn() -> void:
	if not can_play():
		return

	if current_score >= target_score:
		_set_level_won()
		return

	if remaining_moves <= 0:
		_set_level_lost()


func set_board_input_locked(locked: bool) -> void:
	if board_input_locked == locked:
		return

	board_input_locked = locked
	board_lock_changed.emit(board_input_locked)
	state_changed.emit(get_state_snapshot())


func get_state_snapshot() -> Dictionary:
	return {
		"starting_moves": starting_moves,
		"remaining_moves": remaining_moves,
		"target_score": target_score,
		"current_score": current_score,
		"current_combo": current_combo,
		"max_combo": max_combo,
		"level_won": level_result == LevelResult.WON,
		"level_lost": level_result == LevelResult.LOST,
		"board_input_locked": board_input_locked,
	}


func build_bonus_data() -> Dictionary:
	return {
		"final_score": current_score,
		"remaining_moves": remaining_moves,
		"max_combo": max_combo,
		"bonus_power": calculate_bonus_power(current_score, remaining_moves, max_combo),
	}


func build_lose_summary() -> Dictionary:
	return {
		"final_score": current_score,
		"target_score": target_score,
		"remaining_moves": remaining_moves,
		"max_combo": max_combo,
	}


func calculate_groups_score(match_groups: Array, cascade_index: int) -> int:
	var total_score: int = 0
	for group: Variant in match_groups:
		var group_size: int = (group as Array).size()
		total_score += calculate_match_base_score(group_size)

	if not match_groups.is_empty():
		total_score += calculate_cascade_bonus(cascade_index)

	return total_score


func calculate_match_base_score(match_count: int) -> int:
	if match_count <= 3:
		return MATCH_3_SCORE
	if match_count == 4:
		return MATCH_4_SCORE
	if match_count == 5:
		return MATCH_5_SCORE
	return MATCH_5_SCORE + ((match_count - 5) * EXTRA_TILE_SCORE)


func calculate_cascade_bonus(cascade_index: int) -> int:
	return maxi(0, cascade_index - 1) * CASCADE_STEP_BONUS


func calculate_bonus_power(final_score: int, remaining_move_count: int, combo_count: int) -> int:
	return int(floor(float(final_score) / float(BONUS_SCORE_DIVISOR))) + remaining_move_count + combo_count


func _set_level_won() -> void:
	if level_result != LevelResult.PLAYING:
		return

	level_result = LevelResult.WON
	state_changed.emit(get_state_snapshot())
	level_won.emit(build_bonus_data())


func _set_level_lost() -> void:
	if level_result != LevelResult.PLAYING:
		return

	level_result = LevelResult.LOST
	state_changed.emit(get_state_snapshot())
	level_lost.emit(build_lose_summary())


func _emit_all_state(score_delta: int) -> void:
	move_count_changed.emit(remaining_moves)
	score_changed.emit(current_score, target_score, score_delta)
	combo_changed.emit(current_combo, max_combo)
	board_lock_changed.emit(board_input_locked)
	state_changed.emit(get_state_snapshot())
