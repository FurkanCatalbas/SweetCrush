extends Node
class_name EconomyManager

signal insufficient_funds(required: int, current: int, context: StringName)
signal level_entry_paid(level_type: StringName, cost: int)
signal reward_granted(amount: int, source: StringName)

const LEVEL_NORMAL: StringName = &"normal"
const LEVEL_MEDIUM: StringName = &"medium"
const LEVEL_HARD: StringName = &"hard"

const LEVEL_ENTRY_COSTS: Dictionary = {
	LEVEL_NORMAL: 100,
	LEVEL_MEDIUM: 250,
	LEVEL_HARD: 500,
}

const REWARD_SOURCE_BONUS: StringName = &"bonus"

@onready var wallet: PlayerWallet = $"../PlayerWallet"


func get_level_entry_cost(level_type: StringName) -> int:
	return int(LEVEL_ENTRY_COSTS.get(level_type, LEVEL_ENTRY_COSTS[LEVEL_NORMAL]))


func can_enter_level(level_type: StringName) -> bool:
	return wallet.can_afford(get_level_entry_cost(level_type))


func try_pay_level_entry(level_type: StringName) -> bool:
	var cost: int = get_level_entry_cost(level_type)
	if wallet.spend_money(cost):
		level_entry_paid.emit(level_type, cost)
		return true

	insufficient_funds.emit(cost, wallet.current_money, level_type)
	return false


func grant_reward(amount: int, source: StringName = REWARD_SOURCE_BONUS) -> void:
	if amount <= 0:
		return

	wallet.add_money(amount)
	reward_granted.emit(amount, source)


func get_level_display_name(level_type: StringName) -> String:
	match level_type:
		LEVEL_MEDIUM:
			return "Medium"
		LEVEL_HARD:
			return "Hard"
		_:
			return "Normal"
