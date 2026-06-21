extends Node2D
## Тестовая мини-игра для проверки Analytics: сбор орбов, враги, track(), адаптация ML.

const ARENA_SIZE := Vector2(760, 520)
const ORBS_PER_WAVE := 5
const COLLECTIBLE_SCENE := preload("res://test_game/collectible.tscn")
const ENEMY_SCENE := preload("res://test_game/enemy.tscn")

enum State { MENU, PLAYING }

@onready var adaptation_bridge: AdaptationBridge = $AdaptationBridge
@onready var player: CharacterBody2D = $Player
@onready var collectibles_root: Node2D = $Collectibles
@onready var enemies_root: Node2D = $Enemies
@onready var spawner: Node = $EnemySpawner
@onready var menu_layer: Control = $CanvasLayer/Menu
@onready var hud_layer: Control = $CanvasLayer/HUD
@onready var new_game_btn: Button = $CanvasLayer/Menu/VBox/NewGameBtn
@onready var quit_btn: Button = $CanvasLayer/Menu/VBox/QuitBtn
@onready var menu_hint: Label = $CanvasLayer/Menu/VBox/HintLabel
@onready var score_label: Label = $CanvasLayer/HUD/Margin/VBox/StatsRow/ScoreLabel
@onready var deaths_label: Label = $CanvasLayer/HUD/Margin/VBox/StatsRow/DeathsLabel
@onready var time_label: Label = $CanvasLayer/HUD/Margin/VBox/StatsRow/TimeLabel
@onready var adapt_label: Label = $CanvasLayer/HUD/Margin/VBox/AdaptLabel
@onready var end_session_btn: Button = $CanvasLayer/HUD/Margin/VBox/EndSessionBtn

var _state: State = State.MENU
var _score: int = 0
var _deaths: int = 0
var _orbs_this_wave: int = 0
var _wave: int = 0
var _session_time: float = 0.0
var _loot_multiplier: float = 1.0


func _ready() -> void:
	add_to_group("game_root")
	player.add_to_group("player")
	player.arena_size = ARENA_SIZE
	player.movement_enabled = false
	spawner.arena_size = ARENA_SIZE
	new_game_btn.pressed.connect(_on_new_game_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	end_session_btn.pressed.connect(_on_end_session_pressed)
	adaptation_bridge.adaptation_applied.connect(_on_adaptation_applied)
	_show_menu()
	_refresh_hud()


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	_session_time += delta
	if has_meta("death_cooldown"):
		var cd: float = float(get_meta("death_cooldown")) - delta
		if cd <= 0.0:
			remove_meta("death_cooldown")
		else:
			set_meta("death_cooldown", cd)
	_check_pickups()
	_check_enemy_hits()
	_refresh_hud()


func _check_enemy_hits() -> void:
	var hit_radius := 30.0
	for child in enemies_root.get_children():
		if not is_instance_valid(child):
			continue
		if child.position.distance_to(player.position) <= hit_radius:
			child.queue_free()
			register_player_death()
			return


func _check_pickups() -> void:
	var pickup_radius := 32.0
	for child in collectibles_root.get_children():
		if not is_instance_valid(child):
			continue
		if child.position.distance_to(player.position) <= pickup_radius:
			_on_orb_collected(child as Area2D)


func _on_new_game_pressed() -> void:
	if not Analytics:
		push_error("Включите Analytics Plugin в Project Settings → Plugins")
		return
	Analytics.initialize()
	Analytics.start_new_game("telemetry-arena-1.0")
	_reset_run()
	_state = State.PLAYING
	player.movement_enabled = true
	menu_layer.hide()
	hud_layer.show()
	player.position = ARENA_SIZE * 0.5
	_spawn_collectible()
	spawner.configure(
		player,
		enemies_root,
		ENEMY_SCENE,
		adaptation_bridge.enemy_density,
		adaptation_bridge.difficulty
	)
	spawner.start()
	_track("session_start", {"wave": _wave})
	print("Тестовая игра: сессия начата")


func _on_end_session_pressed() -> void:
	_end_session()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _end_session() -> void:
	if _state == State.PLAYING:
		_track("session_end", {
			"score": float(_score),
			"time_sec": _session_time,
			"deaths": float(_deaths),
			"wave": float(_wave),
		})
		if Analytics:
			Analytics.sync_now()
			Analytics.end_game()
	spawner.stop()
	_clear_entities()
	_show_menu()
	print("Тестовая игра: сессия завершена")


func _show_menu() -> void:
	_state = State.MENU
	player.movement_enabled = false
	menu_layer.show()
	hud_layer.hide()


func _reset_run() -> void:
	_score = 0
	_deaths = 0
	_orbs_this_wave = 0
	_wave = 1
	_session_time = 0.0
	_loot_multiplier = adaptation_bridge.loot_multiplier
	_clear_entities()
	_refresh_hud()


func _clear_entities() -> void:
	for child in collectibles_root.get_children():
		child.queue_free()
	for child in enemies_root.get_children():
		child.queue_free()


func _spawn_collectible() -> void:
	var orb: Area2D = COLLECTIBLE_SCENE.instantiate()
	collectibles_root.add_child(orb)
	var margin := 48.0
	var spawn_pos := Vector2.ZERO
	for _attempt in range(12):
		spawn_pos = Vector2(
			randf_range(margin, ARENA_SIZE.x - margin),
			randf_range(margin, ARENA_SIZE.y - margin)
		)
		if spawn_pos.distance_to(player.position) >= 64.0:
			break
	orb.position = spawn_pos
	if orb.has_signal("collected"):
		orb.collected.connect(_on_orb_collected)


func _on_orb_collected(orb: Area2D) -> void:
	if _state != State.PLAYING:
		return
	if orb == null or not is_instance_valid(orb):
		return
	if not orb.is_inside_tree():
		return
	if orb.has_meta("picked"):
		return
	orb.set_meta("picked", true)
	orb.queue_free()
	var gained := int(10.0 * _loot_multiplier)
	_score += gained
	_orbs_this_wave += 1
	_track("orb_collected", {
		"score": float(_score),
		"time_sec": _session_time,
		"deaths": float(_deaths),
		"hints_used": 0.0,
	})
	if _orbs_this_wave >= ORBS_PER_WAVE:
		_complete_wave()
	else:
		_spawn_collectible()
	_refresh_hud()


func _complete_wave() -> void:
	_wave += 1
	_orbs_this_wave = 0
	_track("wave_complete", {
		"score": float(_score),
		"time_sec": _session_time,
		"deaths": float(_deaths),
		"hints_used": 0.0,
	})
	_track("puzzle_completed", {
		"score": float(_score),
		"time_sec": _session_time,
		"deaths": float(_deaths),
		"hints_used": 0.0,
	})
	_spawn_collectible()
	_refresh_hud()


func register_player_death() -> void:
	if _state != State.PLAYING:
		return
	if has_meta("death_cooldown") and float(get_meta("death_cooldown")) > 0.0:
		return
	set_meta("death_cooldown", 0.8)
	_deaths += 1
	_track("player_died", {
		"score": float(_score),
		"time_sec": _session_time,
		"deaths": float(_deaths),
	})
	player.position = ARENA_SIZE * 0.5
	_refresh_hud()


func _on_adaptation_applied(params: Dictionary) -> void:
	_loot_multiplier = adaptation_bridge.loot_multiplier
	spawner.set_adaptation(adaptation_bridge.enemy_density, adaptation_bridge.difficulty)
	_refresh_hud()
	print("Игра: применена адаптация ", params)


func _track(event_name: String, parameters: Dictionary) -> void:
	if Analytics and Analytics.game_session_active:
		Analytics.track(event_name, parameters)


func _refresh_hud() -> void:
	score_label.text = "Очки: %d" % _score
	deaths_label.text = "Смерти: %d" % _deaths
	time_label.text = "Время: %.0f с | Волна: %d" % [_session_time, _wave]
	var buf := 0
	if Analytics:
		buf = Analytics.event_buffer.size()
	adapt_label.text = (
		"ML: сложность %.2f | плотность %.2f | лут %.2f | буфер %d"
		% [
			adaptation_bridge.difficulty,
			adaptation_bridge.enemy_density,
			adaptation_bridge.loot_multiplier,
			buf,
		]
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_session()
