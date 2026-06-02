extends Node
## Шаблон интеграции Analytics — скопируйте в свой проект.
## Варианты: autoload «GameManager» (уберите class_name при конфликте) или методы в своём менеджере.

class_name GameManager
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
	# Пример: применить сложность в игре
	# get_tree().call_group("difficulty_system", "apply", params)
	print("🎮 Применить адаптацию:", params)
