@tool
extends Panel

const PROFILE_PATH := "user://ml_profile.json"

@onready var cloud_mode_check = $MainMargin/MainVBox/ModeHBox/RadioContainer/CloudModeCheck
@onready var local_mode_check = $MainMargin/MainVBox/ModeHBox/RadioContainer/LocalModeCheck
@onready var cloud_settings_btn = $MainMargin/MainVBox/SettingsButtonsHBox/CloudSettingsBtn
@onready var local_settings_btn = $MainMargin/MainVBox/SettingsButtonsHBox/LocalSettingsBtn
@onready var events_list = $MainMargin/MainVBox/EventsList
@onready var add_event_btn = $MainMargin/MainVBox/EventButtonsHBox/AddEventBtn
@onready var edit_event_btn = $MainMargin/MainVBox/EventButtonsHBox/EditEventBtn
@onready var delete_event_btn = $MainMargin/MainVBox/EventButtonsHBox/DeleteEventBtn
@onready var critical_point_name_input = $MainMargin/MainVBox/CriticalPointInputHBox/CriticalPointNameInput
@onready var critical_point_weight_spin = $MainMargin/MainVBox/CriticalPointInputHBox/CriticalPointWeightSpin
@onready var add_critical_point_btn = $MainMargin/MainVBox/CriticalPointInputHBox/AddCriticalPointBtn
@onready var critical_points_list = $MainMargin/MainVBox/CriticalPointsList
@onready var delete_critical_point_btn = $MainMargin/MainVBox/CriticalPointButtonsHBox/DeleteCriticalPointBtn
@onready var archetype_name_input = $MainMargin/MainVBox/ArchetypeInputHBox/ArchetypeNameInput
@onready var add_archetype_btn = $MainMargin/MainVBox/ArchetypeInputHBox/AddArchetypeBtn
@onready var archetypes_list = $MainMargin/MainVBox/ArchetypesList
@onready var delete_archetype_btn = $MainMargin/MainVBox/ArchetypeButtonsHBox/DeleteArchetypeBtn
@onready var save_ml_profile_btn = $MainMargin/MainVBox/ProfileButtonsHBox/SaveMlProfileBtn
@onready var session_id_value = $MainMargin/MainVBox/StatsGrid/SessionIdValue
@onready var buffer_count_value = $MainMargin/MainVBox/StatsGrid/BufferCountValue
@onready var send_now_btn = $MainMargin/MainVBox/ActionButtonsHBox/SendNowBtn
@onready var view_logs_btn = $MainMargin/MainVBox/ActionButtonsHBox/ViewLogsBtn
@onready var reset_stats_btn = $MainMargin/MainVBox/ActionButtonsHBox/ResetStatsBtn

var events = ["dialog_choice", "item_pickup", "location_change", "combat_start"]
var critical_points: Array = []
var archetypes: Array = []
var cloud_settings_window = null

func _ready():
	for event in events:
		events_list.add_item(event)
	_load_ml_profile()
	_redraw_critical_points()
	_redraw_archetypes()

	cloud_mode_check.toggled.connect(_on_cloud_mode_toggled)
	local_mode_check.toggled.connect(_on_local_mode_toggled)
	cloud_settings_btn.pressed.connect(_on_cloud_settings_pressed)
	local_settings_btn.pressed.connect(_on_local_settings_pressed)
	add_event_btn.pressed.connect(_on_add_event_pressed)
	edit_event_btn.pressed.connect(_on_edit_event_pressed)
	delete_event_btn.pressed.connect(_on_delete_event_pressed)
	add_critical_point_btn.pressed.connect(_on_add_critical_point_pressed)
	delete_critical_point_btn.pressed.connect(_on_delete_critical_point_pressed)
	add_archetype_btn.pressed.connect(_on_add_archetype_pressed)
	delete_archetype_btn.pressed.connect(_on_delete_archetype_pressed)
	save_ml_profile_btn.pressed.connect(_on_save_ml_profile_pressed)
	send_now_btn.pressed.connect(_on_send_now_pressed)
	view_logs_btn.pressed.connect(_on_view_logs_pressed)
	reset_stats_btn.pressed.connect(_on_reset_stats_pressed)

	update_stats()

func _on_cloud_mode_toggled(enabled):
	if enabled:
		local_mode_check.button_pressed = false
		print("Переключено на облачный режим")

func _on_local_mode_toggled(enabled):
	if enabled:
		cloud_mode_check.button_pressed = false
		print("Переключено на локальный режим")

func _on_cloud_settings_pressed():
	if cloud_settings_window == null:
		cloud_settings_window = preload("res://addons/analytics_plugin/ui/cloud_settings.tscn").instantiate()
		add_child(cloud_settings_window)
		cloud_settings_window.settings_saved.connect(_on_cloud_settings_saved)
	cloud_settings_window.load_settings()
	cloud_settings_window.popup_centered()

func _on_cloud_settings_saved(settings):
	var analytics = _get_analytics()
	if analytics and analytics.has_method("apply_config"):
		analytics.apply_config(settings, false)
	print("📊 Облачные настройки применены")

func _on_local_settings_pressed():
	print("Открыть настройки локального режима")

func _on_add_event_pressed():
	var event_name = "custom_event_" + str(events_list.item_count + 1)
	events_list.add_item(event_name)

func _on_edit_event_pressed():
	var selected = events_list.get_selected_items()
	if selected.size() > 0:
		var event_name = events_list.get_item_text(selected[0])
		events_list.set_item_text(selected[0], event_name + "_edited")

func _on_delete_event_pressed():
	var selected = events_list.get_selected_items()
	if selected.size() > 0:
		events_list.remove_item(selected[0])

func _on_add_critical_point_pressed():
	var metric_name = critical_point_name_input.text.strip_edges()
	if metric_name.is_empty():
		return
	var metric = {
		"name": metric_name,
		"weight": float(critical_point_weight_spin.value)
	}
	critical_points.append(metric)
	critical_point_name_input.text = ""
	_redraw_critical_points()

func _on_delete_critical_point_pressed():
	var selected = critical_points_list.get_selected_items()
	if selected.size() == 0:
		return
	var index = selected[0]
	if index >= 0 and index < critical_points.size():
		critical_points.remove_at(index)
		_redraw_critical_points()

func _on_add_archetype_pressed():
	var archetype_id = archetype_name_input.text.strip_edges().to_lower()
	if archetype_id.is_empty():
		return
	if archetypes.has(archetype_id):
		return
	archetypes.append(archetype_id)
	archetype_name_input.text = ""
	_redraw_archetypes()

func _on_delete_archetype_pressed():
	var selected = archetypes_list.get_selected_items()
	if selected.size() == 0:
		return
	var index = selected[0]
	if index >= 0 and index < archetypes.size():
		archetypes.remove_at(index)
		_redraw_archetypes()

func _on_save_ml_profile_pressed():
	_save_ml_profile()
	_apply_ml_profile_to_analytics()
	print("ML профиль сохранен")

func _redraw_critical_points():
	critical_points_list.clear()
	for item in critical_points:
		critical_points_list.add_item("%s (w=%.2f)" % [item.get("name", "unknown"), float(item.get("weight", 1.0))])

func _redraw_archetypes():
	archetypes_list.clear()
	for archetype_id in archetypes:
		archetypes_list.add_item(str(archetype_id))

func _serialize_ml_profile() -> Dictionary:
	return {
		"critical_points": critical_points,
		"archetypes": archetypes
	}

func _save_ml_profile():
	var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_serialize_ml_profile(), "\t"))
		file.close()

func _load_ml_profile():
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if not file:
		return
	var raw = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(raw) != OK:
		return
	var data: Dictionary = json.data
	critical_points = data.get("critical_points", [])
	archetypes = data.get("archetypes", [])

func _get_analytics() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop.root.get_node_or_null("Analytics")
	return null

func _apply_ml_profile_to_analytics():
	var analytics = _get_analytics()
	if analytics == null:
		return
	analytics.config["critical_points"] = critical_points.duplicate(true)
	analytics.config["archetypes"] = archetypes.duplicate()
	analytics._save_config()

func _on_send_now_pressed():
	var analytics = _get_analytics()
	if analytics:
		analytics.sync_now()

func _on_view_logs_pressed():
	print("Просмотр логов")

func _on_reset_stats_pressed():
	var analytics = _get_analytics()
	if analytics:
		analytics.event_buffer.clear()
	update_stats()

func update_stats():
	var analytics = _get_analytics()
	if analytics:
		var stats = analytics.get_stats()
		session_id_value.text = stats.get("session_id", "sess_unknown")
		buffer_count_value.text = str(stats.get("buffer_size", 0))
	else:
		session_id_value.text = "sess_demo"
		buffer_count_value.text = "0"

func _process(_delta):
	if _get_analytics():
		update_stats()
