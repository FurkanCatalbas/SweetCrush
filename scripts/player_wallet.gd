extends Node
class_name PlayerWallet

signal money_changed(new_amount: int)
signal money_spent(amount: int)
signal money_added(amount: int)

const DEFAULT_STARTING_MONEY: int = 1000

@export var starting_money: int = DEFAULT_STARTING_MONEY

var current_money: int = 0


func _ready() -> void:
	current_money = maxi(0, starting_money)
	money_changed.emit(current_money)


func add_money(amount: int) -> void:
	if amount <= 0:
		return

	current_money += amount
	money_added.emit(amount)
	money_changed.emit(current_money)


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false

	current_money -= amount
	money_spent.emit(amount)
	money_changed.emit(current_money)
	return true


func can_afford(amount: int) -> bool:
	if amount <= 0:
		return true
	return current_money >= amount


func set_money(amount: int) -> void:
	current_money = maxi(0, amount)
	money_changed.emit(current_money)


func get_save_data() -> Dictionary:
	return {
		"current_money": current_money,
	}


func load_from_data(data: Dictionary) -> void:
	set_money(int(data.get("current_money", starting_money)))
