extends Resource
class_name BuildingData

const DEFAULT_COST_GROWTH_FACTOR: float = 1.5

@export var id: StringName = StringName()
@export var display_name: String = ""
@export var level: int = 0
@export var base_cost: int = 100
@export var base_income_per_minute: int = 10
@export var unlocked: bool = false
@export var max_level: int = 5
@export var cost_growth_factor: float = DEFAULT_COST_GROWTH_FACTOR


func setup_from_config(config: Dictionary) -> void:
	id = config.get("id", StringName())
	display_name = str(config.get("display_name", ""))
	level = int(config.get("level", 0))
	base_cost = int(config.get("base_cost", 100))
	base_income_per_minute = int(config.get("base_income_per_minute", 10))
	unlocked = bool(config.get("unlocked", false))
	max_level = int(config.get("max_level", 5))
	cost_growth_factor = float(config.get("cost_growth_factor", DEFAULT_COST_GROWTH_FACTOR))


func is_max_level() -> bool:
	return level >= max_level


func get_next_upgrade_cost() -> int:
	if is_max_level():
		return 0
	return roundi(float(base_cost) * pow(cost_growth_factor, level))


func get_income_per_minute() -> int:
	if not unlocked or level <= 0:
		return 0
	return base_income_per_minute * level


func can_upgrade() -> bool:
	return not is_max_level()


func apply_upgrade() -> bool:
	if is_max_level():
		return false

	level += 1
	unlocked = true
	return true


func get_save_data() -> Dictionary:
	return {
		"id": String(id),
		"level": level,
		"unlocked": unlocked,
	}


func load_from_data(data: Dictionary) -> void:
	level = int(data.get("level", level))
	unlocked = bool(data.get("unlocked", unlocked))
