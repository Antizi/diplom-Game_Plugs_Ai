extends Node
## Минимальная проверка cloud: повесьте на Node в своём Godot-проекте.

@onready var _game_manager: GameManager = GameManager.new()

func _ready() -> void:
	if not Analytics:
		push_error("Включите плагин: Project → Project Settings → Plugins → Analytics Plugin")
		return

	add_child(_game_manager)
	_game_manager.adaptation_applied.connect(_on_adaptation_applied)

	_game_manager.start_new_game("integration-test-1.0")

	for i in range(12):
		_game_manager.track_event("puzzle_completed", {
			"time_sec": 10.0 + i * 3.0,
			"hints_used": i % 3,
			"deaths": i % 2,
			"score": 10.0 * (i + 1),
		})
		await get_tree().create_timer(0.15).timeout

	print("Stats:", Analytics.get_stats())

func _on_adaptation_applied(params: Dictionary) -> void:
	print("✅ adaptation applied in game:", params)
	print("   difficulty = ", _game_manager.current_difficulty)

func _exit_tree() -> void:
	if Analytics:
		Analytics.end_game()
