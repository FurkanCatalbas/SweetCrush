extends RefCounted
class_name JuiceHelper

const MATCH_SCORE_BASE: int = 100
const MATCH_SCORE_STEP: int = 70
const BONUS_WIN_BIG_THRESHOLD: int = 500
const BONUS_WIN_MEGA_THRESHOLD: int = 1200


static func get_combo_feedback(cascade_index: int) -> Dictionary:
	if cascade_index >= 5:
		return {"text": "Mega", "color": Color(1.0, 0.58, 0.28), "scale": 1.5}
	if cascade_index == 4:
		return {"text": "Tasty", "color": Color(1.0, 0.72, 0.35), "scale": 1.36}
	if cascade_index == 3:
		return {"text": "Sweet", "color": Color(0.98, 0.48, 0.80), "scale": 1.24}
	return {"text": "Nice", "color": Color(0.55, 0.92, 1.0), "scale": 1.12}


static func get_bonus_win_feedback(amount: int) -> Dictionary:
	if amount >= BONUS_WIN_MEGA_THRESHOLD:
		return {"text": "Mega Win", "color": Color(1.0, 0.58, 0.28), "scale": 1.7}
	if amount >= BONUS_WIN_BIG_THRESHOLD:
		return {"text": "Big Win", "color": Color(1.0, 0.84, 0.30), "scale": 1.45}
	return {"text": "Nice Win", "color": Color(0.62, 0.96, 0.64), "scale": 1.18}


static func get_group_score_value(group_size: int, cascade_index: int) -> int:
	return MATCH_SCORE_BASE + maxi(0, group_size - 3) * MATCH_SCORE_STEP + maxi(0, cascade_index - 1) * 35
