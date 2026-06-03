extends Node
## Smoke-тест: F5 в редакторе → события в буфер, логи, POST /telemetry/ingest.
## Перед запуском: docker compose up -d и URL ingest в панели Analytics.

func _ready() -> void:
	if not Analytics:
		push_error("Включите плагин: Project → Project Settings → Plugins → Analytics Plugin")
		return

	var bridge = AdaptationBridge.new()
	add_child(bridge)
	bridge.adaptation_applied.connect(func(p): print("Smoke: adaptation ", p))

	Analytics.initialize()
	Analytics.start_new_game("smoke-test-1.0")

	for i in range(12):
		Analytics.track("puzzle_completed", {
			"time_sec": 10.0 + i * 3.0,
			"hints_used": i % 3,
			"deaths": i % 2,
			"score": 10.0 * (i + 1),
		})
		await get_tree().create_timer(0.15).timeout

	print("📊 Stats: ", Analytics.get_stats())
	Analytics.sync_now()


func _exit_tree() -> void:
	if Analytics:
		Analytics.end_game()
