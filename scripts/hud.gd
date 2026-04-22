extends Control
class_name HUD

@onready var score_value_label: Label = $Margin/Panel/VBox/ScoreValue
@onready var target_value_label: Label = $Margin/Panel/VBox/TargetValue
@onready var moves_value_label: Label = $Margin/Panel/VBox/MovesValue
@onready var combo_value_label: Label = $Margin/Panel/VBox/ComboValue
@onready var status_value_label: Label = $Margin/Panel/VBox/StatusValue

var level_manager: LevelManager
var previous_score: int = 0
var previous_combo: int = 0


func bind_level_manager(new_level_manager: LevelManager) -> void:
	level_manager = new_level_manager
	if not level_manager.state_changed.is_connected(_on_state_changed):
		level_manager.state_changed.connect(_on_state_changed)
	_on_state_changed(level_manager.get_state_snapshot())


func _on_state_changed(state: Dictionary) -> void:
	if not is_node_ready():
		await ready
	var score_value: int = int(state.get("current_score", 0))
	var combo_value: int = int(state.get("current_combo", 0))
	score_value_label.text = str(score_value)
	target_value_label.text = str(state.get("target_score", 0))
	moves_value_label.text = str(state.get("remaining_moves", 0))
	combo_value_label.text = "x%s / max x%s" % [combo_value, state.get("max_combo", 0)]

	if score_value > previous_score:
		UIAnimator.pulse_control(score_value_label, Color(1.0, 0.93, 0.45))
	if combo_value > previous_combo:
		UIAnimator.pulse_control(combo_value_label, Color(1.0, 0.60, 0.85))
	previous_score = score_value
	previous_combo = combo_value

	if state.get("level_won", false):
		status_value_label.text = "WIN"
	elif state.get("level_lost", false):
		status_value_label.text = "LOSE"
	elif state.get("board_input_locked", false):
		status_value_label.text = "Resolving"
	else:
		status_value_label.text = "Playing"
