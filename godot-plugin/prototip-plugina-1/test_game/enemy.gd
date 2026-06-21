extends CharacterBody2D

var target: Node2D
var speed: float = 90.0


func _ready() -> void:
	$HitArea.monitoring = true
	$HitArea.body_entered.connect(_on_hit_area_body_entered)


func _on_hit_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var game = get_tree().get_first_node_in_group("game_root")
	if game and game.has_method("register_player_death"):
		game.register_player_death()
	queue_free()


func setup(chase_target: Node2D, move_speed: float) -> void:
	target = chase_target
	speed = move_speed


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir := (target.position - position).normalized()
	velocity = dir * speed
	move_and_slide()
