extends Control
class_name TycoonPanel

signal level_start_requested(level_type: StringName)

const STATUS_READY: String = "Ready"
const STATUS_INSUFFICIENT_FUNDS: String = "Insufficient funds"

@onready var wallet_value_label: Label = $Margin/Panel/Root/HeaderGrid/WalletValue
@onready var income_value_label: Label = $Margin/Panel/Root/HeaderGrid/IncomeValue
@onready var status_value_label: Label = $Margin/Panel/Root/HeaderGrid/StatusValue
@onready var normal_level_button: Button = $Margin/Panel/Root/LevelButtons/NormalLevelButton
@onready var medium_level_button: Button = $Margin/Panel/Root/LevelButtons/MediumLevelButton
@onready var hard_level_button: Button = $Margin/Panel/Root/LevelButtons/HardLevelButton
@onready var building_list: VBoxContainer = $Margin/Panel/Root/BuildingsScroll/BuildingsList

var wallet: PlayerWallet
var economy_manager: EconomyManager
var tycoon_manager: TycoonManager
var building_cards: Dictionary = {}
var building_card_scene: PackedScene = preload("res://scenes/ui/BuildingCard.tscn")
var level_buttons_connected: bool = false
var floating_text_scene: PackedScene = preload("res://scenes/ui/FloatingText.tscn")
var previous_wallet_amount: int = 0
var feedback_layer: Node2D


func bind_systems(new_wallet: PlayerWallet, new_economy_manager: EconomyManager, new_tycoon_manager: TycoonManager) -> void:
	if not is_node_ready():
		await ready

	wallet = new_wallet
	economy_manager = new_economy_manager
	tycoon_manager = new_tycoon_manager

	if not wallet.money_changed.is_connected(_on_money_changed):
		wallet.money_changed.connect(_on_money_changed)
	if not economy_manager.insufficient_funds.is_connected(_on_insufficient_funds):
		economy_manager.insufficient_funds.connect(_on_insufficient_funds)
	if not economy_manager.level_entry_paid.is_connected(_on_level_entry_paid):
		economy_manager.level_entry_paid.connect(_on_level_entry_paid)
	if not economy_manager.reward_granted.is_connected(_on_reward_granted):
		economy_manager.reward_granted.connect(_on_reward_granted)
	if not tycoon_manager.building_updated.is_connected(_on_building_updated):
		tycoon_manager.building_updated.connect(_on_building_updated)
	if not tycoon_manager.passive_income_rate_changed.is_connected(_on_passive_income_rate_changed):
		tycoon_manager.passive_income_rate_changed.connect(_on_passive_income_rate_changed)
	if not tycoon_manager.passive_income_generated.is_connected(_on_passive_income_generated):
		tycoon_manager.passive_income_generated.connect(_on_passive_income_generated)

	if not level_buttons_connected:
		normal_level_button.pressed.connect(_on_normal_level_pressed)
		medium_level_button.pressed.connect(_on_medium_level_pressed)
		hard_level_button.pressed.connect(_on_hard_level_pressed)
		_wire_button(normal_level_button)
		_wire_button(medium_level_button)
		_wire_button(hard_level_button)
		level_buttons_connected = true

	if feedback_layer == null:
		feedback_layer = Node2D.new()
		feedback_layer.name = "FeedbackLayer"
		add_child(feedback_layer)

	_rebuild_building_cards()
	_update_wallet(wallet.current_money)
	_update_income(tycoon_manager.calculate_total_income_per_minute())
	_update_level_button_texts()
	set_status_message(STATUS_READY)
	previous_wallet_amount = wallet.current_money


func set_status_message(message: String) -> void:
	if not is_node_ready():
		await ready
	status_value_label.text = message


func _rebuild_building_cards() -> void:
	for child: Node in building_list.get_children():
		child.queue_free()
	building_cards.clear()

	for building: BuildingData in tycoon_manager.get_buildings():
		var card: BuildingCard = building_card_scene.instantiate() as BuildingCard
		building_list.add_child(card)
		card.upgrade_requested.connect(_on_upgrade_requested)
		building_cards[building.id] = card
		card.set_building(building, wallet.current_money)


func _refresh_building_cards() -> void:
	for building: BuildingData in tycoon_manager.get_buildings():
		var card: BuildingCard = building_cards.get(building.id, null) as BuildingCard
		if card != null:
			card.set_building(building, wallet.current_money)


func _update_wallet(amount: int) -> void:
	wallet_value_label.text = str(amount)
	if amount > previous_wallet_amount:
		UIAnimator.pulse_control(wallet_value_label, Color(1.0, 0.93, 0.45))
		_spawn_money_feedback(amount - previous_wallet_amount)
	previous_wallet_amount = amount
	_refresh_building_cards()
	_update_level_button_texts()


func _update_income(total_income_per_minute: int) -> void:
	income_value_label.text = "%s / min" % total_income_per_minute


func _update_level_button_texts() -> void:
	var normal_cost: int = economy_manager.get_level_entry_cost(EconomyManager.LEVEL_NORMAL)
	var medium_cost: int = economy_manager.get_level_entry_cost(EconomyManager.LEVEL_MEDIUM)
	var hard_cost: int = economy_manager.get_level_entry_cost(EconomyManager.LEVEL_HARD)

	normal_level_button.text = "Normal (%s)" % normal_cost
	medium_level_button.text = "Medium (%s)" % medium_cost
	hard_level_button.text = "Hard (%s)" % hard_cost

	normal_level_button.disabled = not wallet.can_afford(normal_cost)
	medium_level_button.disabled = not wallet.can_afford(medium_cost)
	hard_level_button.disabled = not wallet.can_afford(hard_cost)
	UIAnimator.refresh_button_disabled(normal_level_button)
	UIAnimator.refresh_button_disabled(medium_level_button)
	UIAnimator.refresh_button_disabled(hard_level_button)


func _on_money_changed(new_amount: int) -> void:
	_update_wallet(new_amount)


func _on_building_updated(_building: BuildingData) -> void:
	_refresh_building_cards()
	_update_income(tycoon_manager.calculate_total_income_per_minute())
	set_status_message("Upgrade complete")


func _on_passive_income_rate_changed(total_income_per_minute: int) -> void:
	_update_income(total_income_per_minute)


func _on_passive_income_generated(amount: int) -> void:
	set_status_message("Passive income +%s" % amount)


func _on_reward_granted(amount: int, _source: StringName) -> void:
	set_status_message("Bonus reward +%s" % amount)


func _on_insufficient_funds(required: int, current: int, _context: StringName) -> void:
	set_status_message("%s (%s / %s)" % [STATUS_INSUFFICIENT_FUNDS, current, required])


func _on_level_entry_paid(level_type: StringName, cost: int) -> void:
	set_status_message("%s level entered for %s" % [economy_manager.get_level_display_name(level_type), cost])


func _on_upgrade_requested(building_id: StringName) -> void:
	if tycoon_manager.try_upgrade_building(building_id):
		return

	var building: BuildingData = tycoon_manager.get_building_by_id(building_id)
	if building == null:
		return
	if building.is_max_level():
		set_status_message("Building already maxed")
		return
	set_status_message(STATUS_INSUFFICIENT_FUNDS)


func _on_normal_level_pressed() -> void:
	level_start_requested.emit(EconomyManager.LEVEL_NORMAL)


func _on_medium_level_pressed() -> void:
	level_start_requested.emit(EconomyManager.LEVEL_MEDIUM)


func _on_hard_level_pressed() -> void:
	level_start_requested.emit(EconomyManager.LEVEL_HARD)


func _wire_button(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		UIAnimator.animate_button_hover(button, true)
	)
	button.mouse_exited.connect(func() -> void:
		UIAnimator.animate_button_hover(button, false)
	)
	button.button_down.connect(func() -> void:
		UIAnimator.animate_button_press(button, true)
	)
	button.button_up.connect(func() -> void:
		UIAnimator.animate_button_press(button, false)
	)


func _spawn_money_feedback(amount: int) -> void:
	if amount <= 0 or feedback_layer == null:
		return
	var floating_text: FloatingText = floating_text_scene.instantiate() as FloatingText
	feedback_layer.add_child(floating_text)
	var local_position: Vector2 = Vector2(wallet_value_label.global_position.x - global_position.x + 50.0, wallet_value_label.global_position.y - global_position.y + 10.0)
	floating_text.play("+%s" % amount, Color(0.95, 0.92, 0.45), local_position, 1.0, 0.8, 36.0)
