extends Node
class_name GameManager

signal bonus_bridge_requested(bonus_data: Dictionary)
signal bonus_reward_granted(summary: Dictionary)
signal level_start_failed(level_type: StringName, cost: int, current_money: int)

const REWARD_SOURCE_BONUS: StringName = &"bonus"
const DEFAULT_LEVEL_TYPE: StringName = EconomyManager.LEVEL_NORMAL
const LEVEL_RULES: Dictionary = {
	EconomyManager.LEVEL_NORMAL: {"target_score": 2500, "moves": 20},
	EconomyManager.LEVEL_MEDIUM: {"target_score": 4000, "moves": 18},
	EconomyManager.LEVEL_HARD: {"target_score": 6000, "moves": 16},
}

@export var use_bonus_popup_on_win: bool = true
@export var win_popup_delay: float = 0.35
@export var lose_popup_delay: float = 0.25

@onready var board: Board = $"../Board"
@onready var level_manager: LevelManager = $"../LevelManager"
@onready var wallet: PlayerWallet = SceneManager.wallet
@onready var economy_manager: EconomyManager = SceneManager.economy_manager
@onready var tycoon_manager: TycoonManager = SceneManager.tycoon_manager
@onready var hud: HUD = $"../UI/HUD"
@onready var win_popup: WinPopup = $"../UI/WinPopup"
@onready var lose_popup: LosePopup = $"../UI/LosePopup"
@onready var bonus_popup: BonusPopup = $"../UI/BonusPopup"
@onready var result_popup: ResultPopup = $"../UI/ResultPopup"

var turn_pending_resolution: bool = false
var popup_open: bool = false
var active_bonus_data: Dictionary = {}
var active_lose_summary: Dictionary = {}
var current_level_type: StringName = DEFAULT_LEVEL_TYPE
var level_active: bool = false
var pending_result_reward: int = 0


func _ready() -> void:
	_connect_signals()
	hud.bind_level_manager(level_manager)
	_hide_all_popups()
	board.set_input_locked(true)
	current_level_type = SceneManager.consume_requested_level_type()
	_attempt_start_level(current_level_type)


func _connect_signals() -> void:
	board.move_used.connect(_on_board_move_used)
	board.matches_resolved.connect(_on_board_matches_resolved)
	board.board_idle.connect(_on_board_idle)

	level_manager.board_lock_changed.connect(_on_board_lock_changed)
	level_manager.level_won.connect(_on_level_won)
	level_manager.level_lost.connect(_on_level_lost)
	economy_manager.insufficient_funds.connect(_on_economy_insufficient_funds)

	win_popup.continue_pressed.connect(_on_win_popup_continue_pressed)
	lose_popup.retry_pressed.connect(_on_lose_popup_retry_pressed)
	lose_popup.menu_pressed.connect(_on_lose_popup_menu_pressed)
	bonus_popup.bonus_started.connect(_on_bonus_popup_bonus_started)
	bonus_popup.reward_collected.connect(_on_bonus_popup_reward_collected)
	result_popup.continue_pressed.connect(_on_result_popup_continue_pressed)
	result_popup.menu_pressed.connect(_on_result_popup_menu_pressed)


func _begin_level(level_type: StringName) -> void:
	popup_open = false
	turn_pending_resolution = false
	level_active = true
	current_level_type = level_type
	active_bonus_data.clear()
	active_lose_summary.clear()
	pending_result_reward = 0
	_hide_all_popups()

	var level_rule: Dictionary = LEVEL_RULES.get(level_type, LEVEL_RULES[DEFAULT_LEVEL_TYPE])
	level_manager.start_level(int(level_rule.get("target_score", 2500)), int(level_rule.get("moves", 20)))
	board.set_input_locked(false)
	board.reset_board()


func _attempt_start_level(level_type: StringName) -> bool:
	if not economy_manager.try_pay_level_entry(level_type):
		level_active = false
		board.set_input_locked(true)
		level_start_failed.emit(level_type, economy_manager.get_level_entry_cost(level_type), wallet.current_money)
		return false

	_begin_level(level_type)
	return true


func _hide_all_popups() -> void:
	win_popup.hide_popup()
	lose_popup.hide_popup()
	bonus_popup.hide_popup()
	result_popup.hide_popup()


func _on_board_move_used(_from_cell: Vector2i, _to_cell: Vector2i) -> void:
	if popup_open:
		return

	turn_pending_resolution = true
	level_manager.set_board_input_locked(true)
	level_manager.register_move_used()


func _on_board_matches_resolved(match_groups: Array, _cells: Array, cascade_index: int) -> void:
	if popup_open:
		return

	level_manager.register_matches(match_groups, cascade_index)


func _on_board_idle() -> void:
	if popup_open:
		return

	if not turn_pending_resolution:
		return

	turn_pending_resolution = false
	level_manager.finalize_turn()

	if level_manager.can_play():
		level_manager.set_board_input_locked(false)


func _on_board_lock_changed(locked: bool) -> void:
	board.set_input_locked(locked)


func _on_level_won(bonus_data: Dictionary) -> void:
	if popup_open:
		return

	popup_open = true
	level_active = false
	active_bonus_data = bonus_data.duplicate(true)
	level_manager.set_board_input_locked(true)
	_open_win_flow.call_deferred()


func _on_level_lost(summary: Dictionary) -> void:
	if popup_open:
		return

	popup_open = true
	level_active = false
	active_lose_summary = summary.duplicate(true)
	level_manager.set_board_input_locked(true)
	_open_lose_flow.call_deferred()


func _open_win_flow() -> void:
	await get_tree().create_timer(win_popup_delay).timeout
	_hide_all_popups()
	if use_bonus_popup_on_win:
		bonus_popup.start_bonus(active_bonus_data)
		return

	win_popup.show_result(active_bonus_data)


func _open_lose_flow() -> void:
	await get_tree().create_timer(lose_popup_delay).timeout
	_hide_all_popups()
	lose_popup.show_result(active_lose_summary)


func _on_win_popup_continue_pressed() -> void:
	popup_open = false
	_hide_all_popups()
	_attempt_start_level(current_level_type)


func _on_lose_popup_retry_pressed() -> void:
	popup_open = false
	_hide_all_popups()
	_attempt_start_level(current_level_type)


func _on_lose_popup_menu_pressed() -> void:
	popup_open = false
	_hide_all_popups()
	SceneManager.change_scene_to_menu()


func _on_bonus_popup_bonus_started(bonus_data: Dictionary) -> void:
	bonus_bridge_requested.emit(bonus_data)


func _on_bonus_popup_reward_collected(summary: Dictionary) -> void:
	pending_result_reward = int(summary.get("final_reward", 0))
	economy_manager.grant_reward(pending_result_reward, REWARD_SOURCE_BONUS)
	bonus_reward_granted.emit(summary)
	_hide_all_popups()
	result_popup.show_result(pending_result_reward)


func _on_result_popup_continue_pressed() -> void:
	popup_open = false
	_hide_all_popups()
	_attempt_start_level(current_level_type)


func _on_result_popup_menu_pressed() -> void:
	popup_open = false
	_hide_all_popups()
	SceneManager.change_scene_to_menu()


func _on_economy_insufficient_funds(required: int, current: int, context: StringName) -> void:
	push_warning("Need %s for %s level (%s available)" % [required, economy_manager.get_level_display_name(context), current])
