extends Node
class_name BonusManager

signal bonus_started(bonus_data: Dictionary)
signal wins_found(result: Dictionary)
signal cascade_step_finished(step_index: int, step_win: int, total_base_win: int, total_multiplier: int)
signal bonus_finished(summary: Dictionary)
signal reward_collected(summary: Dictionary)

const FRUIT_IDS: Array[StringName] = [&"cherry", &"apple", &"grape", &"banana", &"watermelon"]
@onready var PAYOUT_THRESHOLDS: PackedInt32Array = PackedInt32Array([12, 10, 8])
const PAYTABLE: Dictionary = {
	&"cherry": {8: 5, 10: 8, 12: 12},
	&"apple": {8: 6, 10: 10, 12: 14},
	&"grape": {8: 8, 10: 12, 12: 18},
	&"banana": {8: 10, 10: 15, 12: 22},
	&"watermelon": {8: 12, 10: 18, 12: 28},
}
const BASE_FRUIT_WEIGHTS: Dictionary = {
	&"cherry": 28,
	&"apple": 27,
	&"grape": 24,
	&"banana": 20,
	&"watermelon": 18,
}
@onready var MULTIPLIER_VALUES: PackedInt32Array = PackedInt32Array([2, 5, 10, 25])
const MULTIPLIER_WEIGHTS: Dictionary = {
	2: 56,
	5: 25,
	10: 13,
	25: 6,
}

const POWER_TIER_DIVISOR: int = 5
const MAX_POWER_TIER: int = 5
const BASE_MULTIPLIER_CHANCE: float = 0.03
const MULTIPLIER_CHANCE_PER_TIER: float = 0.008
const MAX_MULTIPLIER_CHANCE: float = 0.07
const BASE_MAX_CASCADES: int = 6
const MAX_EXTRA_CASCADES: int = 5
const HIGH_VALUE_WEIGHT_PER_TIER: int = 3
const INITIAL_HIGH_VALUE_WEIGHT_PER_TIER: int = 2
const BASE_REFRESH_COUNT: int = 3
const MAX_REFRESH_COUNT: int = 6
const SCORE_REFRESH_DIVISOR: int = 12000
const SCORE_REFRESH_CAP: int = 1
const POWER_REFRESH_TIER_THRESHOLD: int = 2
const POWER_REFRESH_CAP: int = 1
const COMBO_REFRESH_THRESHOLD: int = 3
const COMBO_REFRESH_CAP: int = 1

var source_bonus_data: Dictionary = {}
var bonus_power: int = 0
var power_tier: int = 0
var multiplier_chance: float = BASE_MULTIPLIER_CHANCE
var max_cascade_steps: int = BASE_MAX_CASCADES
var extra_high_value_weight: int = 0
var extra_initial_high_value_weight: int = 0
var cascade_steps_completed: int = 0
var current_step_win: int = 0
var total_base_win: int = 0
var total_multiplier_sum: int = 0
var final_reward: int = 0
var finished: bool = false
var reward_already_collected: bool = false
var max_refresh_count: int = BASE_REFRESH_COUNT
var refreshes_used: int = 0


func start_bonus(bonus_data: Dictionary) -> void:
	source_bonus_data = bonus_data.duplicate(true)
	bonus_power = int(source_bonus_data.get("bonus_power", 0))
	var final_score: int = int(source_bonus_data.get("final_score", 0))
	var source_combo: int = int(source_bonus_data.get("max_combo", 0))
	power_tier = clampi(int(floor(float(bonus_power) / float(POWER_TIER_DIVISOR))), 0, MAX_POWER_TIER)
	multiplier_chance = minf(BASE_MULTIPLIER_CHANCE + (float(power_tier) * MULTIPLIER_CHANCE_PER_TIER), MAX_MULTIPLIER_CHANCE)
	max_cascade_steps = BASE_MAX_CASCADES + mini(power_tier, MAX_EXTRA_CASCADES)
	extra_high_value_weight = power_tier * HIGH_VALUE_WEIGHT_PER_TIER
	extra_initial_high_value_weight = power_tier * INITIAL_HIGH_VALUE_WEIGHT_PER_TIER
	max_refresh_count = _calculate_refresh_count(final_score, bonus_power, source_combo)
	cascade_steps_completed = 0
	current_step_win = 0
	total_base_win = 0
	total_multiplier_sum = 0
	final_reward = 0
	finished = false
	reward_already_collected = false
	refreshes_used = 0
	bonus_started.emit(source_bonus_data.duplicate(true))


func get_max_cascade_steps() -> int:
	return max_cascade_steps


func get_cascade_steps_completed() -> int:
	return cascade_steps_completed


func get_current_step_win() -> int:
	return current_step_win


func get_effective_multiplier() -> int:
	return maxi(1, total_multiplier_sum)


func get_final_reward() -> int:
	return final_reward


func get_remaining_refreshes() -> int:
	return maxi(0, max_refresh_count - refreshes_used)


func get_max_refresh_count() -> int:
	return max_refresh_count


func has_refresh_available() -> bool:
	return refreshes_used < max_refresh_count


func consume_refresh() -> bool:
	if not has_refresh_available():
		return false

	refreshes_used += 1
	current_step_win = 0
	return true


func is_finished() -> bool:
	return finished


func roll_symbol_data(rng: RandomNumberGenerator, initial_fill: bool) -> Dictionary:
	if rng.randf() < multiplier_chance:
		return {
			"kind": FruitSymbol.KIND_MULTIPLIER,
			"fruit_id": StringName(),
			"multiplier_value": _roll_multiplier_value(rng),
		}

	return {
		"kind": FruitSymbol.KIND_FRUIT,
		"fruit_id": _roll_fruit_id(rng, initial_fill),
		"multiplier_value": 0,
	}


func evaluate_board(symbol_entries: Array) -> Dictionary:
	var fruit_counts: Dictionary = {}
	var fruit_cells: Dictionary = {}
	for fruit_id: StringName in FRUIT_IDS:
		fruit_counts[fruit_id] = 0
		fruit_cells[fruit_id] = []

	var multiplier_values: Array[int] = []
	var multiplier_cells: Array[Vector2i] = []

	for entry: Variant in symbol_entries:
		var symbol_entry: Dictionary = entry as Dictionary
		var kind: StringName = symbol_entry.get("kind", StringName())
		var cell: Vector2i = symbol_entry.get("cell", Vector2i.ZERO)

		if kind == FruitSymbol.KIND_FRUIT:
			var fruit_id: StringName = symbol_entry.get("fruit_id", StringName())
			fruit_counts[fruit_id] = int(fruit_counts.get(fruit_id, 0)) + 1
			(fruit_cells[fruit_id] as Array).append(cell)
		elif kind == FruitSymbol.KIND_MULTIPLIER:
			multiplier_values.append(int(symbol_entry.get("multiplier_value", 0)))
			multiplier_cells.append(cell)

	var win_entries: Array = []
	var winning_cells: Array[Vector2i] = []
	var step_base_win: int = 0

	for fruit_id: StringName in FRUIT_IDS:
		var count: int = int(fruit_counts.get(fruit_id, 0))
		var payout: int = _get_payout_for_count(fruit_id, count)
		if payout <= 0:
			continue

		step_base_win += payout
		for win_cell: Variant in fruit_cells[fruit_id]:
			winning_cells.append(win_cell as Vector2i)
		win_entries.append({
			"fruit_id": fruit_id,
			"count": count,
			"payout": payout,
		})

	var active_multiplier_sum: int = 0
	var active_multiplier_values: Array[int] = []
	var active_multiplier_cells: Array[Vector2i] = []
	if step_base_win > 0:
		active_multiplier_values = multiplier_values.duplicate()
		active_multiplier_cells = multiplier_cells.duplicate()
		for value: int in active_multiplier_values:
			active_multiplier_sum += value

	return {
		"has_win": step_base_win > 0,
		"win_entries": win_entries,
		"winning_cells": winning_cells,
		"multiplier_cells": active_multiplier_cells,
		"active_multiplier_values": active_multiplier_values,
		"active_multiplier_sum": active_multiplier_sum,
		"step_base_win": step_base_win,
	}


func apply_step_result(step_result: Dictionary) -> void:
	current_step_win = int(step_result.get("step_base_win", 0))
	total_base_win += current_step_win
	total_multiplier_sum += int(step_result.get("active_multiplier_sum", 0))
	cascade_steps_completed += 1
	final_reward = _calculate_final_reward(total_base_win, total_multiplier_sum)
	wins_found.emit(step_result.duplicate(true))
	cascade_step_finished.emit(cascade_steps_completed, current_step_win, total_base_win, total_multiplier_sum)


func finish_bonus() -> Dictionary:
	if not finished:
		finished = true
		final_reward = _calculate_final_reward(total_base_win, total_multiplier_sum)
		bonus_finished.emit(build_summary())
	return build_summary()


func collect_reward() -> Dictionary:
	if not finished:
		return {}
	if reward_already_collected:
		return build_summary()

	reward_already_collected = true
	var summary: Dictionary = build_summary()
	reward_collected.emit(summary)
	return summary


func build_summary() -> Dictionary:
	return {
		"source_bonus_data": source_bonus_data.duplicate(true),
		"bonus_power": bonus_power,
		"cascade_steps": cascade_steps_completed,
		"current_step_win": current_step_win,
		"base_win": total_base_win,
		"total_multiplier": total_multiplier_sum,
		"effective_multiplier": get_effective_multiplier(),
		"final_reward": final_reward,
		"max_refresh_count": max_refresh_count,
		"refreshes_used": refreshes_used,
		"refreshes_left": get_remaining_refreshes(),
		"reward_collected": reward_already_collected,
	}


func _calculate_refresh_count(final_score: int, current_bonus_power: int, source_combo: int) -> int:
	var refresh_count: int = BASE_REFRESH_COUNT
	refresh_count += mini(SCORE_REFRESH_CAP, int(floor(float(final_score) / float(SCORE_REFRESH_DIVISOR))))
	refresh_count += mini(POWER_REFRESH_CAP, int(floor(float(current_bonus_power) / float(POWER_TIER_DIVISOR * POWER_REFRESH_TIER_THRESHOLD))))
	refresh_count += mini(COMBO_REFRESH_CAP, int(floor(float(source_combo) / float(COMBO_REFRESH_THRESHOLD))))
	return clampi(refresh_count, BASE_REFRESH_COUNT, MAX_REFRESH_COUNT)


func _get_payout_for_count(fruit_id: StringName, count: int) -> int:
	var fruit_table: Dictionary = PAYTABLE.get(fruit_id, {})
	for threshold: int in PAYOUT_THRESHOLDS:
		if count >= threshold:
			return int(fruit_table.get(threshold, 0))
	return 0


func _roll_fruit_id(rng: RandomNumberGenerator, initial_fill: bool) -> StringName:
	var weights: Array[int] = []
	for fruit_id: StringName in FRUIT_IDS:
		var weight: int = int(BASE_FRUIT_WEIGHTS.get(fruit_id, 1))
		if fruit_id == &"banana" or fruit_id == &"watermelon":
			weight += extra_high_value_weight
			if initial_fill:
				weight += extra_initial_high_value_weight
		weights.append(maxi(1, weight))

	var selected_index: int = _roll_weighted_index(weights, rng)
	return FRUIT_IDS[selected_index]


func _roll_multiplier_value(rng: RandomNumberGenerator) -> int:
	var weights: Array[int] = []
	for multiplier_value: int in MULTIPLIER_VALUES:
		weights.append(int(MULTIPLIER_WEIGHTS.get(multiplier_value, 1)))
	return MULTIPLIER_VALUES[_roll_weighted_index(weights, rng)]


func _roll_weighted_index(weights: Array[int], rng: RandomNumberGenerator) -> int:
	var total_weight: int = 0
	for weight: int in weights:
		total_weight += maxi(0, weight)

	if total_weight <= 0:
		return 0

	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for index in range(weights.size()):
		cursor += maxi(0, weights[index])
		if roll <= cursor:
			return index

	return weights.size() - 1


func _calculate_final_reward(base_win: int, multiplier_sum: int) -> int:
	return base_win * maxi(1, multiplier_sum)
