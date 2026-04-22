extends PanelContainer
class_name BuildingCard

signal upgrade_requested(building_id: StringName)

@onready var name_value_label: Label = $Margin/VBox/NameValue
@onready var level_value_label: Label = $Margin/VBox/LevelValue
@onready var income_value_label: Label = $Margin/VBox/IncomeValue
@onready var cost_value_label: Label = $Margin/VBox/CostValue
@onready var upgrade_button: Button = $Margin/VBox/UpgradeButton

var building_id: StringName = StringName()


func _ready() -> void:
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	_wire_button(upgrade_button)


func set_building(building: BuildingData, wallet_amount: int) -> void:
	building_id = building.id
	name_value_label.text = building.display_name
	level_value_label.text = "%s / %s" % [building.level, building.max_level]
	income_value_label.text = "%s / min" % building.get_income_per_minute()

	if building.is_max_level():
		cost_value_label.text = "MAX"
		upgrade_button.text = "Maxed"
		upgrade_button.disabled = true
		UIAnimator.refresh_button_disabled(upgrade_button)
		return

	var upgrade_cost: int = building.get_next_upgrade_cost()
	cost_value_label.text = str(upgrade_cost)
	upgrade_button.text = "Upgrade"
	upgrade_button.disabled = wallet_amount < upgrade_cost
	UIAnimator.refresh_button_disabled(upgrade_button)


func _on_upgrade_button_pressed() -> void:
	upgrade_requested.emit(building_id)


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
