extends Node
## Шаблон интеграции Analytics — скопируйте в свой проект.
## Autoload «GameManager» или вызовите методы из своего менеджера.

class_name GameManager

signal difficulty_changed(difficulty: float)
signal adaptation_applied(parameters: Dictionary)

@export var current_difficulty: float = 1.0
@export var current_enemy_density: float = 1.0
@export var current_loot_multiplier: float = 1.0

func _ready() -> void:
	boot_analytics()

func boot_analytics() -> void:
	if not Analytics:
		push_error("Analytics autoload не найден. Включите плагин в Project Settings → Plugins.")
		return
	Analytics.initialize()
	if not Analytics.adaptation_received.is_connected(_on_adaptation_received):
		Analytics.adaptation_received.connect(_on_adaptation_received)

func start_new_game(game_version: String = "1.0.0") -> void:
	current_difficulty = 1.0
	current_enemy_density = 1.0
	current_loot_multiplier = 1.0
	if Analytics:
		Analytics.start_new_game(game_version)

func quit_to_menu() -> void:
	if Analytics:
		Analytics.end_game()

func track_event(event_name: String, parameters: Dictionary = {}) -> void:
	if Analytics:
		Analytics.track(event_name, parameters)

func _on_adaptation_received(adaptation: Dictionary) -> void:
	var params: Dictionary = adaptation.get("parameters", {})
	if params.is_empty():
		return
	apply_adaptation(params)

func apply_adaptation(params: Dictionary) -> void:
	if params.has("difficulty"):
		current_difficulty = float(params["difficulty"])
		difficulty_changed.emit(current_difficulty)
	if params.has("enemy_density"):
		current_enemy_density = float(params["enemy_density"])
	if params.has("loot_multiplier"):
		current_loot_multiplier = float(params["loot_multiplier"])

	adaptation_applied.emit(params.duplicate())
	print(
		"🎮 Адаптация: difficulty=%.2f density=%.2f loot=%.2f"
		% [current_difficulty, current_enemy_density, current_loot_multiplier]
	)
	# Пример для своей игры:
	# get_tree().call_group("difficulty_system", "apply", params)
