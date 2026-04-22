extends Node
class_name TycoonManager

signal building_added(building: BuildingData)
signal building_updated(building: BuildingData)
signal passive_income_generated(amount: int)
signal passive_income_rate_changed(total_income_per_minute: int)
signal state_changed(state: Dictionary)

const PASSIVE_TICK_SECONDS: float = 1.0
const BUILDING_CONFIGS: Array[Dictionary] = [
	{"id": &"slot_room", "display_name": "Slot Room", "base_cost": 150, "base_income_per_minute": 20, "max_level": 10},
	{"id": &"vip_room", "display_name": "VIP Room", "base_cost": 320, "base_income_per_minute": 42, "max_level": 8},
	{"id": &"bar", "display_name": "Bar", "base_cost": 240, "base_income_per_minute": 28, "max_level": 9},
	{"id": &"lounge", "display_name": "Lounge", "base_cost": 450, "base_income_per_minute": 58, "max_level": 8},
	{"id": &"high_roller_room", "display_name": "High Roller Room", "base_cost": 800, "base_income_per_minute": 110, "max_level": 7},
]

@onready var wallet: PlayerWallet = $"../PlayerWallet"

var buildings: Array[BuildingData] = []
var passive_income_accumulator: float = 0.0
var income_timer: Timer
var last_income_unix_time: int = 0


func _ready() -> void:
	_build_default_buildings()
	_setup_income_timer()
	_emit_full_state()


func get_buildings() -> Array[BuildingData]:
	return buildings


func get_building_by_id(building_id: StringName) -> BuildingData:
	for building: BuildingData in buildings:
		if building.id == building_id:
			return building
	return null


func try_upgrade_building(building_id: StringName) -> bool:
	var building: BuildingData = get_building_by_id(building_id)
	if building == null or not building.can_upgrade():
		return false

	var upgrade_cost: int = calculate_upgrade_cost(building)
	if not wallet.spend_money(upgrade_cost):
		return false
	if not building.apply_upgrade():
		wallet.add_money(upgrade_cost)
		return false

	building_updated.emit(building)
	_emit_income_state()
	state_changed.emit(get_save_data())
	return true


func calculate_upgrade_cost(building: BuildingData) -> int:
	return building.get_next_upgrade_cost()


func calculate_building_income_per_minute(building: BuildingData) -> int:
	return building.get_income_per_minute()


func calculate_total_income_per_minute() -> int:
	var total_income: int = 0
	for building: BuildingData in buildings:
		total_income += calculate_building_income_per_minute(building)
	return total_income


func calculate_income_per_second() -> float:
	return float(calculate_total_income_per_minute()) / 60.0


func calculate_income_for_duration(duration_seconds: float) -> int:
	if duration_seconds <= 0.0:
		return 0
	return int(floor(calculate_income_per_second() * duration_seconds))


func get_save_data() -> Dictionary:
	var building_data: Array[Dictionary] = []
	for building: BuildingData in buildings:
		building_data.append(building.get_save_data())

	return {
		"buildings": building_data,
		"passive_income_accumulator": passive_income_accumulator,
		"last_income_unix_time": last_income_unix_time,
	}


func load_from_data(data: Dictionary) -> void:
	var saved_buildings: Array = data.get("buildings", [])
	for saved_entry: Variant in saved_buildings:
		var entry: Dictionary = saved_entry as Dictionary
		var building_id: StringName = StringName(str(entry.get("id", "")))
		var building: BuildingData = get_building_by_id(building_id)
		if building != null:
			building.load_from_data(entry)

	passive_income_accumulator = float(data.get("passive_income_accumulator", 0.0))
	last_income_unix_time = int(data.get("last_income_unix_time", Time.get_unix_time_from_system()))
	_emit_full_state()


func _build_default_buildings() -> void:
	buildings.clear()
	for config: Dictionary in BUILDING_CONFIGS:
		var building: BuildingData = BuildingData.new()
		building.setup_from_config(config)
		buildings.append(building)
		building_added.emit(building)


func _setup_income_timer() -> void:
	income_timer = Timer.new()
	income_timer.wait_time = PASSIVE_TICK_SECONDS
	income_timer.one_shot = false
	income_timer.autostart = true
	add_child(income_timer)
	income_timer.timeout.connect(_on_income_timer_timeout)
	last_income_unix_time = int(Time.get_unix_time_from_system())


func _on_income_timer_timeout() -> void:
	last_income_unix_time = int(Time.get_unix_time_from_system())
	passive_income_accumulator += calculate_income_per_second() * PASSIVE_TICK_SECONDS
	var payout: int = int(floor(passive_income_accumulator))
	if payout <= 0:
		return

	passive_income_accumulator -= float(payout)
	wallet.add_money(payout)
	passive_income_generated.emit(payout)
	state_changed.emit(get_save_data())


func _emit_income_state() -> void:
	passive_income_rate_changed.emit(calculate_total_income_per_minute())


func _emit_full_state() -> void:
	_emit_income_state()
	state_changed.emit(get_save_data())
