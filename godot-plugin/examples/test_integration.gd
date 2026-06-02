extends Node
## Пример для своего тестового узла в проекте разработчика.
## Не входит в аддон — скопируйте логику или подключите скрипт на Node в демо-сцене.

func _ready() -> void:
	if not Analytics:
		push_error("Включите плагин: Project → Project Settings → Plugins → Analytics Plugin")
		return

	Analytics.initialize()
	Analytics.adaptation_received.connect(_on_adaptation_received)
	Analytics.start_new_game("example-1.0")

	Analytics.track("test_event", {"message": "hello", "time_sec": 1.0})
	Analytics.set_state("test_mode", true)
	print(Analytics.get_stats())

func _on_adaptation_received(adaptation: Dictionary) -> void:
	print("adaptation_received:", adaptation)

func _exit_tree() -> void:
	if Analytics:
		Analytics.end_game()
