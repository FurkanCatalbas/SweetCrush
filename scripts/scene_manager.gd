extends Node


const MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"
const GAME_SCENE_PATH: String = "res://scenes/Match3Scene.tscn"
const TYCOON_SCENE_PATH: String = "res://scenes/TycoonScene.tscn"
const DEFAULT_LEVEL_TYPE: StringName = EconomyManager.LEVEL_NORMAL

const FADE_DURATION: float = 0.2

var wallet: PlayerWallet
var economy_manager: EconomyManager
var tycoon_manager: TycoonManager
var requested_level_type: StringName = DEFAULT_LEVEL_TYPE
var current_scene: Node
var fade_layer: CanvasLayer
var fade_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_persistent_systems()
	_create_fade_layer()
	call_deferred("_capture_initial_scene")


func change_scene_to_game(level_type: StringName = DEFAULT_LEVEL_TYPE) -> void:
	requested_level_type = level_type
	await _switch_to_scene(GAME_SCENE_PATH)


func change_scene_to_menu() -> void:
	await _switch_to_scene(MENU_SCENE_PATH)


func change_scene_to_tycoon() -> void:
	await _switch_to_scene(TYCOON_SCENE_PATH)


func consume_requested_level_type() -> StringName:
	var level_type: StringName = requested_level_type
	requested_level_type = DEFAULT_LEVEL_TYPE
	return level_type


func _switch_to_scene(scene_path: String) -> void:
	if current_scene == null:
		current_scene = get_tree().current_scene

	await _fade_to_black()

	if current_scene != null:
		current_scene.queue_free()
		await get_tree().process_frame

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Failed to load scene: %s" % scene_path)
		await _fade_from_black()
		return

	current_scene = packed_scene.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	await get_tree().process_frame
	await _fade_from_black()


func _capture_initial_scene() -> void:
	current_scene = get_tree().current_scene


func _create_persistent_systems() -> void:
	wallet = PlayerWallet.new()
	wallet.name = "PlayerWallet"
	add_child(wallet)

	economy_manager = EconomyManager.new()
	economy_manager.name = "EconomyManager"
	add_child(economy_manager)

	tycoon_manager = TycoonManager.new()
	tycoon_manager.name = "TycoonManager"
	add_child(tycoon_manager)


func _create_fade_layer() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 100
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0, 0, 0, 0)
	fade_layer.add_child(fade_rect)


func _fade_to_black() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), FADE_DURATION)
	await tween.finished


func _fade_from_black() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), FADE_DURATION)
	await tween.finished
