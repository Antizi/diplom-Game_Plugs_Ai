extends Node

signal enemy_spawned(enemy: CharacterBody2D)

@export var arena_size: Vector2 = Vector2(760, 520)

var _timer: Timer
var _density: float = 1.0
var _difficulty: float = 1.0
var _player: Node2D
var _enemies_root: Node2D
var _enemy_scene: PackedScene


func configure(
	player: Node2D,
	enemies_root: Node2D,
	enemy_scene: PackedScene,
	density: float,
	difficulty: float
) -> void:
	_player = player
	_enemies_root = enemies_root
	_enemy_scene = enemy_scene
	_density = maxf(density, 0.2)
	_difficulty = maxf(difficulty, 0.3)
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = false
		add_child(_timer)
		_timer.timeout.connect(_spawn_one)
	_rearm_timer()


func set_adaptation(density: float, difficulty: float) -> void:
	_density = maxf(density, 0.2)
	_difficulty = maxf(difficulty, 0.3)
	_rearm_timer()


func start() -> void:
	_timer.start()


func stop() -> void:
	_timer.stop()


func _rearm_timer() -> void:
	if _timer == null:
		return
	_timer.wait_time = clampf(2.8 / _density, 0.8, 5.0)


func _spawn_one() -> void:
	if _enemy_scene == null or _enemies_root == null or _player == null:
		return
	var enemy: CharacterBody2D = _enemy_scene.instantiate()
	_enemies_root.add_child(enemy)
	var margin := 40.0
	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0:
			pos = Vector2(randf_range(margin, arena_size.x - margin), margin)
		1:
			pos = Vector2(randf_range(margin, arena_size.x - margin), arena_size.y - margin)
		2:
			pos = Vector2(margin, randf_range(margin, arena_size.y - margin))
		_:
			pos = Vector2(arena_size.x - margin, randf_range(margin, arena_size.y - margin))
	enemy.position = pos
	var speed := 70.0 + 35.0 * _difficulty
	if enemy.has_method("setup"):
		enemy.setup(_player, speed)
	enemy_spawned.emit(enemy)
