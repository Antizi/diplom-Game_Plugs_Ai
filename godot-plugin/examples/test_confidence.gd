extends Node2D
## Демонстрация уверенности ML-модели: три сценария подряд.
## Показывает что уверенность = 1.0 для чистых паттернов
## и < 1.0 для смешанного поведения игрока.
##
## Использование:
##   1. Убедитесь что backend запущен: docker compose up -d
##   2. Плагин Analytics включён, URL настроен
##   3. Прикрепите скрипт к Node2D в сцене, запустите F5
##
## Почему сценарий 2 даёт < 1.0:
##   Seed-данные: explorer → item_collected≈45%, jump≈15%
##                socializer → jump≈45%,          item_collected≈20%
##   При 6 item_collected + 6 jump: деревья RF голосуют 50/50 → confidence ~0.5–0.7

var _scenario := 0
var _scenarios := [
	{
		"name": "Чистый killer (ожидается 1.0)",
		"events": [
			{"event": "enemy_killed", "params": {"score": 70.0, "deaths": 4.0, "time_sec": 35.0}},
		],
		"repeat": 12
	},
	{
		"name": "Explorer/Socializer граница (ожидается < 1.0)",
		"events": [
			# 6 пар: item_collected (сигнал explorer) + jump (сигнал socializer)
			# Итого 6 item_collected + 6 jump → деревья голосуют по-разному
			{"event": "item_collected", "params": {"score": 47.0, "deaths": 0.0, "time_sec": 80.0}},
			{"event": "jump",           "params": {"score": 47.0, "deaths": 0.0, "time_sec": 80.0}},
		],
		"repeat": 6
	},
	{
		"name": "Чистый achiever (ожидается 1.0)",
		"events": [
			{"event": "level_complete", "params": {"score": 95.0, "deaths": 1.0, "time_sec": 45.0}},
		],
		"repeat": 12
	},
]


func _ready() -> void:
	Analytics.initialize()
	Analytics.adaptation_received.connect(_on_adaptation)
	_run_scenario()


func _run_scenario() -> void:
	if _scenario >= _scenarios.size():
		print("\n=== ВСЕ СЦЕНАРИИ ЗАВЕРШЕНЫ ===")
		return
	var s: Dictionary = _scenarios[_scenario]
	print("\n--- Сценарий %d: %s ---" % [_scenario + 1, s["name"]])
	Analytics.start_new_game("demo-1.0")
	# Ждём session_id от сервера перед отправкой событий
	await get_tree().create_timer(2.0).timeout
	var evs: Array = s["events"]
	for _i in range(s["repeat"]):
		for e in evs:
			Analytics.track(e["event"], e["params"])
	# Явная отправка сразу — не ждём 30-секундный таймер
	Analytics.sync_now()


func _on_adaptation(adaptation: Dictionary) -> void:
	var p: Dictionary = adaptation.get("parameters", {})
	print("  Архетип:     ", adaptation.get("predicted_archetype"))
	print("  Уверенность: ", adaptation.get("confidence"))
	print("  difficulty:  ", p.get("difficulty"))
	_scenario += 1
	await get_tree().create_timer(1.0).timeout
	_run_scenario()
