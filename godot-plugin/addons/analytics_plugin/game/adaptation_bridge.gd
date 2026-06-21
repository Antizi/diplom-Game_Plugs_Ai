extends Node
class_name AdaptationBridge
## Подключите к сцене игры: применяет adaptation.parameters из Analytics к export-полям.

signal adaptation_applied(parameters: Dictionary)
signal difficulty_changed(difficulty: float)

@export var difficulty: float = 1.0
@export var enemy_density: float = 1.0
@export var loot_multiplier: float = 1.0


func _ready() -> void:
	var analytics = get_node_or_null("/root/Analytics")
	if not analytics:
		push_warning("AdaptationBridge: включите Analytics Plugin и autoload Analytics")
		return
	if not analytics.adaptation_received.is_connected(_on_adaptation_received):
		analytics.adaptation_received.connect(_on_adaptation_received)
	if analytics.has_method("get_last_adaptation"):
		var last: Dictionary = analytics.get_last_adaptation()
		if not last.is_empty():
			_apply_adaptation(last)


func _on_adaptation_received(adaptation: Dictionary) -> void:
	_apply_adaptation(adaptation)


func _apply_adaptation(adaptation: Dictionary) -> void:
	var params: Dictionary = adaptation.get("parameters", {})
	if typeof(params) != TYPE_DICTIONARY or params.is_empty():
		return
	if params.has("difficulty"):
		difficulty = float(params["difficulty"])
		difficulty_changed.emit(difficulty)
	if params.has("enemy_density"):
		enemy_density = float(params["enemy_density"])
	if params.has("loot_multiplier"):
		loot_multiplier = float(params["loot_multiplier"])
	adaptation_applied.emit(params.duplicate(true))
	print(
		"AdaptationBridge: difficulty=%.2f density=%.2f loot=%.2f"
		% [difficulty, enemy_density, loot_multiplier]
	)
