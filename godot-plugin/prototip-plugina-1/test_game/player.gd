extends CharacterBody2D

const SPEED := 220.0

@export var arena_size: Vector2 = Vector2(760, 520)

var movement_enabled: bool = false


func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		return

	var direction := _read_move_direction()
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	velocity = direction * SPEED
	move_and_slide()

	var margin := 20.0
	position.x = clampf(position.x, margin, arena_size.x - margin)
	position.y = clampf(position.y, margin, arena_size.y - margin)


func _read_move_direction() -> Vector2:
	var direction := Vector2.ZERO
	# Стрелки (ui_*)
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		direction.y += 1.0
	# WASD
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	return direction
