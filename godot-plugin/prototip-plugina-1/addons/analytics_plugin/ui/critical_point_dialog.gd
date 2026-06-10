@tool
extends Window

signal point_saved(point: Dictionary)
signal dialog_cancelled

const SOURCE_TYPES = ["function", "scene", "node"]

@onready var name_input: LineEdit = $MainMargin/MainVBox/NameHBox/NameInput
@onready var source_type_option: OptionButton = $MainMargin/MainVBox/SourceTypeHBox/SourceTypeOption
@onready var source_path_input: LineEdit = $MainMargin/MainVBox/SourcePathHBox/SourcePathInput
@onready var collect_duration_check: CheckBox = $MainMargin/MainVBox/CollectVBox/CollectDurationCheck
@onready var collect_count_check: CheckBox = $MainMargin/MainVBox/CollectVBox/CollectCountCheck
@onready var collect_value_check: CheckBox = $MainMargin/MainVBox/CollectVBox/CollectValueCheck
@onready var collect_enter_exit_check: CheckBox = $MainMargin/MainVBox/CollectVBox/CollectEnterExitCheck
@onready var custom_props_input: LineEdit = $MainMargin/MainVBox/CustomPropsHBox/CustomPropsInput
@onready var weight_spin: SpinBox = $MainMargin/MainVBox/WeightHBox/WeightSpin
@onready var save_btn: Button = $MainMargin/MainVBox/ButtonsHBox/SaveBtn
@onready var cancel_btn: Button = $MainMargin/MainVBox/ButtonsHBox/CancelBtn

var _edit_index: int = -1

func _ready() -> void:
	source_type_option.clear()
	source_type_option.add_item("Функция", 0)
	source_type_option.add_item("Сцена", 1)
	source_type_option.add_item("Элемент (нода)", 2)
	save_btn.pressed.connect(_on_save_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)
	source_type_option.item_selected.connect(_on_source_type_changed)

func open_for_create() -> void:
	_edit_index = -1
	title = "Новая критическая точка"
	_reset_form()
	popup_centered()

func open_for_edit(point: Dictionary, index: int) -> void:
	_edit_index = index
	title = "Редактирование критической точки"
	_load_point(point)
	popup_centered()

func get_edit_index() -> int:
	return _edit_index

func _reset_form() -> void:
	name_input.text = ""
	source_type_option.select(0)
	_update_source_placeholder()
	source_path_input.text = ""
	collect_duration_check.button_pressed = false
	collect_count_check.button_pressed = true
	collect_value_check.button_pressed = false
	collect_enter_exit_check.button_pressed = false
	custom_props_input.text = ""
	weight_spin.value = 1.0

func _load_point(point: Dictionary) -> void:
	name_input.text = str(point.get("name", ""))
	var source_type = str(point.get("source_type", "function"))
	var type_index = SOURCE_TYPES.find(source_type)
	source_type_option.select(maxi(0, type_index))
	_update_source_placeholder()
	source_path_input.text = str(point.get("source_path", ""))
	var collect: Dictionary = point.get("collect", {})
	collect_duration_check.button_pressed = bool(collect.get("duration", false))
	collect_count_check.button_pressed = bool(collect.get("count", true))
	collect_value_check.button_pressed = bool(collect.get("value", false))
	collect_enter_exit_check.button_pressed = bool(collect.get("enter_exit", false))
	var props: Array = collect.get("custom_properties", [])
	if typeof(props) == TYPE_ARRAY:
		var parts = []
		for p in props:
			var s = str(p).strip_edges()
			if not s.is_empty():
				parts.append(s)
		custom_props_input.text = ", ".join(PackedStringArray(parts))
	else:
		custom_props_input.text = ""
	weight_spin.value = float(point.get("weight", 1.0))

func _update_source_placeholder() -> void:
	match source_type_option.get_selected_id():
		1:
			source_path_input.placeholder_text = "res://scenes/level_01.tscn"
		2:
			source_path_input.placeholder_text = "Player/Inventory или %NodePath"
		_:
			source_path_input.placeholder_text = "on_level_complete или GameManager.track_death"

func _on_source_type_changed(_index: int) -> void:
	_update_source_placeholder()

func _build_point() -> Dictionary:
	var custom_raw = custom_props_input.text.strip_edges()
	var custom_properties: Array = []
	if not custom_raw.is_empty():
		for part in custom_raw.split(","):
			var prop_name = str(part).strip_edges()
			if not prop_name.is_empty():
				custom_properties.append(prop_name)
	return {
		"name": name_input.text.strip_edges(),
		"source_type": SOURCE_TYPES[source_type_option.get_selected_id()],
		"source_path": source_path_input.text.strip_edges(),
		"collect": {
			"duration": collect_duration_check.button_pressed,
			"count": collect_count_check.button_pressed,
			"value": collect_value_check.button_pressed,
			"enter_exit": collect_enter_exit_check.button_pressed,
			"custom_properties": custom_properties
		},
		"weight": float(weight_spin.value)
	}

func _validate(point: Dictionary) -> bool:
	if str(point.get("name", "")).is_empty():
		push_warning("Укажите название критической точки")
		return false
	if str(point.get("source_path", "")).is_empty():
		push_warning("Укажите путь функции, сцены или элемента")
		return false
	var collect: Dictionary = point.get("collect", {})
	var has_metric = (
		bool(collect.get("duration", false))
		or bool(collect.get("count", false))
		or bool(collect.get("value", false))
		or bool(collect.get("enter_exit", false))
		or (collect.get("custom_properties", []) as Array).size() > 0
	)
	if not has_metric:
		push_warning("Выберите хотя бы один тип данных для сбора")
		return false
	return true

func _on_save_pressed() -> void:
	var point = _build_point()
	if not _validate(point):
		return
	emit_signal("point_saved", point)
	hide()

func _on_cancel_pressed() -> void:
	emit_signal("dialog_cancelled")
	hide()
