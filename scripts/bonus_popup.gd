extends Control
class_name BonusPopup

signal bonus_started(bonus_data: Dictionary)
signal symbols_spawned(symbols: Array)
signal wins_found(result: Dictionary)
signal cascade_step_finished(step_index: int, summary: Dictionary)
signal bonus_finished(summary: Dictionary)
signal reward_collected(summary: Dictionary)

const STATUS_HIDDEN: String = "Hidden"
const STATUS_STARTING: String = "Starting"
const STATUS_DROPPING: String = "Dropping"
const STATUS_EVALUATING: String = "Evaluating"
const STATUS_TUMBLING: String = "Tumbling"
const STATUS_REDROPPING: String = "Re-Dropping"
const STATUS_FINISHED: String = "Finished"
const REFRESH_WAIT_MIN: float = 1.0
const REFRESH_WAIT_MAX: float = 2.0

@onready var source_score_value_label: Label = $Backdrop/Center/Panel/Margin/Root/SourceGrid/SourceScoreValue
@onready var source_moves_value_label: Label = $Backdrop/Center/Panel/Margin/Root/SourceGrid/SourceMovesValue
@onready var source_combo_value_label: Label = $Backdrop/Center/Panel/Margin/Root/SourceGrid/SourceComboValue
@onready var source_power_value_label: Label = $Backdrop/Center/Panel/Margin/Root/SourceGrid/SourcePowerValue
@onready var step_win_value_label: Label = $Backdrop/Center/Panel/Margin/Root/RunGrid/StepWinValue
@onready var total_win_value_label: Label = $Backdrop/Center/Panel/Margin/Root/RunGrid/TotalWinValue
@onready var multiplier_value_label: Label = $Backdrop/Center/Panel/Margin/Root/RunGrid/MultiplierValue
@onready var refresh_value_label: Label = $Backdrop/Center/Panel/Margin/Root/RunGrid/RefreshValue
@onready var status_value_label: Label = $Backdrop/Center/Panel/Margin/Root/RunGrid/StatusValue
@onready var collect_button: Button = $Backdrop/Center/Panel/Margin/Root/Footer/CollectButton
@onready var bonus_board: BonusBoard = $Backdrop/Center/Panel/Margin/Root/BoardHolder/BonusBoard
@onready var feedback_layer: Node2D = $Backdrop/Center/Panel/Margin/Root/FeedbackLayer
@onready var bonus_manager: BonusManager = $BonusManager

var display_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var active_bonus_data: Dictionary = {}
var bonus_running: bool = false
var total_display_value: int = 0
var count_tween: Tween
var floating_text_scene: PackedScene = preload("res://scenes/ui/FloatingText.tscn")


func _ready() -> void:
	bonus_board.set_manager(bonus_manager)
	display_rng.randomize()
	bonus_board.symbols_spawned.connect(_on_board_symbols_spawned)
	bonus_manager.bonus_started.connect(_on_manager_bonus_started)
	bonus_manager.wins_found.connect(_on_manager_wins_found)
	bonus_manager.cascade_step_finished.connect(_on_manager_cascade_step_finished)
	bonus_manager.bonus_finished.connect(_on_manager_bonus_finished)
	bonus_manager.reward_collected.connect(_on_manager_reward_collected)
	collect_button.pressed.connect(_on_collect_button_pressed)
	_wire_button(collect_button)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_ui()
	hide()


func start_bonus(bonus_data: Dictionary) -> void:
	if bonus_running:
		return

	active_bonus_data = bonus_data.duplicate(true)
	bonus_running = true
	_reset_ui()
	_set_status(STATUS_STARTING)
	_apply_source_data(active_bonus_data)
	var popup_tween: Tween = PopupAnimator.show_popup(self)
	if popup_tween != null:
		await popup_tween.finished
	bonus_manager.start_bonus(active_bonus_data)
	await _run_bonus_round()


func hide_popup() -> void:
	if not is_node_ready():
		await ready
	bonus_running = false
	active_bonus_data.clear()
	bonus_board.reset_board()
	_reset_ui()
	var popup_tween: Tween = PopupAnimator.hide_popup(self)
	if popup_tween != null:
		await popup_tween.finished
	else:
		hide()


func _run_bonus_round() -> void:
	_set_status(STATUS_DROPPING)
	await bonus_board.build_initial_board()

	var cascade_limit: int = bonus_manager.get_max_cascade_steps()
	while true:
		_set_status(STATUS_EVALUATING)
		var step_result: Dictionary = bonus_manager.evaluate_board(bonus_board.get_symbol_entries())
		if not bool(step_result.get("has_win", false)):
			if bonus_manager.has_refresh_available():
				bonus_manager.consume_refresh()
				_update_runtime_labels()
				_set_status(STATUS_REDROPPING)
				await get_tree().create_timer(display_rng.randf_range(REFRESH_WAIT_MIN, REFRESH_WAIT_MAX)).timeout
				await bonus_board.refresh_full_board()
				continue
			break

		if bonus_manager.get_cascade_steps_completed() >= cascade_limit:
			break

		bonus_manager.apply_step_result(step_result)
		_set_status(STATUS_TUMBLING)
		await bonus_board.resolve_winning_step(step_result)

	_set_status(STATUS_FINISHED)
	bonus_running = false
	collect_button.disabled = false
	UIAnimator.refresh_button_disabled(collect_button)
	bonus_manager.finish_bonus()
	_update_runtime_labels()


func _apply_source_data(bonus_data: Dictionary) -> void:
	source_score_value_label.text = str(bonus_data.get("final_score", 0))
	source_moves_value_label.text = str(bonus_data.get("remaining_moves", 0))
	source_combo_value_label.text = str(bonus_data.get("max_combo", 0))
	source_power_value_label.text = str(bonus_data.get("bonus_power", 0))


func _reset_ui() -> void:
	step_win_value_label.text = "0"
	total_display_value = 0
	if count_tween != null:
		count_tween.kill()
	total_win_value_label.text = "0"
	multiplier_value_label.text = "x1"
	refresh_value_label.text = "0 / 0"
	collect_button.disabled = true
	UIAnimator.refresh_button_disabled(collect_button)
	_set_status(STATUS_HIDDEN)


func _set_status(status_text: String) -> void:
	status_value_label.text = status_text


func _update_runtime_labels() -> void:
	step_win_value_label.text = str(bonus_manager.get_current_step_win())
	multiplier_value_label.text = "x%s" % bonus_manager.get_effective_multiplier()
	refresh_value_label.text = "%s / %s" % [bonus_manager.get_remaining_refreshes(), bonus_manager.get_max_refresh_count()]
	_animate_total_reward_to(bonus_manager.get_final_reward())


func _on_board_symbols_spawned(symbols: Array) -> void:
	emit_signal("symbols_spawned", symbols)


func _on_manager_bonus_started(bonus_data: Dictionary) -> void:
	_update_runtime_labels()
	emit_signal("bonus_started", bonus_data)


func _on_manager_wins_found(result: Dictionary) -> void:
	_update_runtime_labels()
	var step_win: int = int(result.get("step_base_win", 0))
	if step_win > 0:
		_spawn_feedback_text("+%s" % step_win, Vector2(360, 332), Color(1.0, 0.93, 0.45), 1.18, 0.8, 54.0)
	emit_signal("wins_found", result)


func _on_manager_cascade_step_finished(step_index: int, _step_win: int, _base_total: int, _multiplier_total: int) -> void:
	_update_runtime_labels()
	if step_index > 1:
		var combo_feedback: Dictionary = JuiceHelper.get_combo_feedback(step_index)
		_spawn_feedback_text(str(combo_feedback.get("text", "Sweet")), Vector2(360, 110), combo_feedback.get("color", Color.WHITE), float(combo_feedback.get("scale", 1.0)), 0.95, 66.0)
	emit_signal("cascade_step_finished", step_index, bonus_manager.build_summary())


func _on_manager_bonus_finished(summary: Dictionary) -> void:
	_update_runtime_labels()
	var total_reward: int = int(summary.get("final_reward", 0))
	var win_feedback: Dictionary = JuiceHelper.get_bonus_win_feedback(total_reward)
	_spawn_feedback_text(str(win_feedback.get("text", "Nice Win")), Vector2(360, 74), win_feedback.get("color", Color.WHITE), float(win_feedback.get("scale", 1.0)), 1.2, 80.0)
	emit_signal("bonus_finished", summary)


func _on_manager_reward_collected(summary: Dictionary) -> void:
	emit_signal("reward_collected", summary)


func _on_collect_button_pressed() -> void:
	if bonus_running or not bonus_manager.is_finished():
		return

	bonus_manager.collect_reward()
	hide_popup()


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


func _animate_total_reward_to(target_value: int) -> void:
	if total_display_value == target_value:
		return
	if count_tween != null:
		count_tween.kill()
	count_tween = UIAnimator.count_label_int(total_win_value_label, total_display_value, target_value, 0.36)
	total_display_value = target_value


func _spawn_feedback_text(text: String, local_position: Vector2, color: Color, scale_multiplier: float, duration: float, rise: float) -> void:
	var floating_text: FloatingText = floating_text_scene.instantiate() as FloatingText
	feedback_layer.add_child(floating_text)
	floating_text.play(text, color, local_position, scale_multiplier, duration, rise)
