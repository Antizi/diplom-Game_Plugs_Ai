@tool
extends Panel

const PROFILE_PATH = "user://ml_profile.json"
const CRITICAL_POINT_DIALOG_SCENE = preload("res://addons/analytics_plugin/ui/critical_point_dialog.tscn")
const EVENT_EDIT_DIALOG_SCENE = preload("res://addons/analytics_plugin/ui/event_edit_dialog.tscn")
const LOGS_VIEWER_SCENE = preload("res://addons/analytics_plugin/ui/logs_viewer.tscn")
const AnalyticsResolver = preload("res://addons/analytics_plugin/editor/analytics_resolver.gd")
@onready var connection_settings_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/NetworkButtons/ConnectionSettingsBtn
@onready var check_server_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/NetworkButtons/CheckServerBtn
@onready var server_status_label = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/StatusPanel/StatusMargin/StatusVBox/ServerStatusLabel
@onready var status_label = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/StatusPanel/StatusMargin/StatusVBox/StatusLabel
@onready var send_now_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/ActionGrid/SendNowBtn
@onready var view_logs_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/ActionGrid/ViewLogsBtn
@onready var flush_pending_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/ActionGrid/FlushPendingBtn
@onready var reset_stats_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Подключение/ConnectionVBox/ActionGrid/ResetStatsBtn
@onready var events_list = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/EventsBlock/EventsList
@onready var add_event_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/EventsBlock/EventButtonsHBox/AddEventBtn
@onready var edit_event_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/EventsBlock/EventButtonsHBox/EditEventBtn
@onready var delete_event_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/EventsBlock/EventButtonsHBox/DeleteEventBtn
@onready var copy_snippet_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/EventsBlock/EventButtonsHBox/CopySnippetBtn
@onready var add_critical_point_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/CriticalBlock/CriticalPointButtonsHBox/AddCriticalPointBtn
@onready var edit_critical_point_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/CriticalBlock/CriticalPointButtonsHBox/EditCriticalPointBtn
@onready var critical_points_list = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/CriticalBlock/CriticalPointsList
@onready var delete_critical_point_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/CriticalBlock/CriticalPointButtonsHBox/DeleteCriticalPointBtn
@onready var archetype_name_input = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/ArchetypeBlock/ArchetypeInputHBox/ArchetypeNameInput
@onready var add_archetype_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/ArchetypeBlock/ArchetypeInputHBox/AddArchetypeBtn
@onready var archetypes_list = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/ArchetypeBlock/ArchetypesList
@onready var delete_archetype_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/ArchetypeBlock/DeleteArchetypeBtn
@onready var save_ml_profile_btn = $ScrollContainer/MainMargin/MainVBox/TabContainer/Профиль/ProfileVBox/SaveMlProfileBtn
@onready var session_id_value = $ScrollContainer/MainMargin/MainVBox/TabContainer/Мониторинг/MonitorVBox/StatsPanel/StatsMargin/StatsGrid/SessionIdValue
@onready var buffer_count_value = $ScrollContainer/MainMargin/MainVBox/TabContainer/Мониторинг/MonitorVBox/StatsPanel/StatsMargin/StatsGrid/BufferCountValue
@onready var pending_count_value = $ScrollContainer/MainMargin/MainVBox/TabContainer/Мониторинг/MonitorVBox/StatsPanel/StatsMargin/StatsGrid/PendingCountValue
@onready var adaptation_value = $ScrollContainer/MainMargin/MainVBox/TabContainer/Мониторинг/MonitorVBox/AdaptationPanel/AdaptationMargin/AdaptationValue

var events = ["dialog_choice", "item_pickup", "location_change", "combat_start"]
var critical_points: Array = []
var archetypes: Array = []
var cloud_settings_window = null
var critical_point_dialog = null
var event_edit_dialog = null
var logs_viewer_window = null
var _stats_timer: Timer = null

func _ready():
	_stats_timer = Timer.new()
	_stats_timer.wait_time = 0.5
	_stats_timer.timeout.connect(update_stats)
	add_child(_stats_timer)
	_stats_timer.start()

	_load_ml_profile()
	_redraw_events()
	_apply_ml_profile_to_analytics()
	_redraw_critical_points()
	_redraw_archetypes()
	call_deferred("_connect_profile_sync_signal")

	connection_settings_btn.pressed.connect(_on_connection_settings_pressed)
	check_server_btn.pressed.connect(_on_check_server_pressed)
	add_event_btn.pressed.connect(_on_add_event_pressed)
	copy_snippet_btn.pressed.connect(_on_copy_snippet_pressed)
	edit_event_btn.pressed.connect(_on_edit_event_pressed)
	delete_event_btn.pressed.connect(_on_delete_event_pressed)
	add_critical_point_btn.pressed.connect(_on_add_critical_point_pressed)
	edit_critical_point_btn.pressed.connect(_on_edit_critical_point_pressed)
	delete_critical_point_btn.pressed.connect(_on_delete_critical_point_pressed)
	add_archetype_btn.pressed.connect(_on_add_archetype_pressed)
	delete_archetype_btn.pressed.connect(_on_delete_archetype_pressed)
	save_ml_profile_btn.pressed.connect(_on_save_ml_profile_pressed)
	send_now_btn.pressed.connect(_on_send_now_pressed)
	flush_pending_btn.pressed.connect(_on_flush_pending_pressed)
	view_logs_btn.pressed.connect(_on_view_logs_pressed)
	reset_stats_btn.pressed.connect(_on_reset_stats_pressed)

	call_deferred("_bind_analytics_signals")
	update_stats()


func _bind_analytics_signals() -> void:
	var analytics = _get_analytics()
	if analytics == null:
		return
	if not analytics.stats_changed.is_connected(update_stats):
		analytics.stats_changed.connect(update_stats)
	if not analytics.adaptation_received.is_connected(_on_adaptation_received):
		analytics.adaptation_received.connect(_on_adaptation_received)
	if analytics.cloud_sender and not analytics.cloud_sender.server_available_changed.is_connected(_on_server_available_changed):
		analytics.cloud_sender.server_available_changed.connect(_on_server_available_changed)


func _on_adaptation_received(adaptation: Dictionary) -> void:
	_update_adaptation_display(adaptation)
	update_stats()


func _on_server_available_changed(is_available: bool) -> void:
	server_status_label.text = "Сервер: " + ("доступен" if is_available else "недоступен")


func _on_check_server_pressed() -> void:
	var analytics = _get_analytics()
	if analytics == null:
		_set_status("Analytics не найден", true)
		return
	if not _ensure_analytics_ready(analytics):
		return
	server_status_label.text = "Сервер: проверка..."
	analytics.check_server_health()
	await get_tree().create_timer(0.6).timeout
	update_stats()
	if analytics.cloud_sender:
		_on_server_available_changed(analytics.cloud_sender.server_available)


func _on_copy_snippet_pressed() -> void:
	var selected = events_list.get_selected_items()
	var event_name = "puzzle_completed"
	if not selected.is_empty():
		event_name = events_list.get_item_text(selected[0])
	var analytics = _get_analytics()
	var snippet = "Analytics.track(\"%s\", {\"score\": 0.0, \"time_sec\": 0.0})" % event_name
	if analytics and analytics.has_method("get_track_snippet"):
		snippet = analytics.get_track_snippet(event_name)
	DisplayServer.clipboard_set(snippet)
	_set_status("Скопировано в буфер: " + snippet)


func _on_flush_pending_pressed() -> void:
	var analytics = _get_analytics()
	if analytics == null:
		_set_status("Analytics не найден", true)
		return
	if not _ensure_analytics_ready(analytics):
		return
	var count = analytics.flush_pending_from_disk() if analytics.has_method("flush_pending_from_disk") else 0
	if count == 0:
		_set_status("Offline-очередь пуста")
	else:
		_set_status("Загружено из offline: %d, отправка..." % count)
	update_stats()


func _redraw_events() -> void:
	events_list.clear()
	for event_name in events:
		events_list.add_item(str(event_name))


func _set_status(msg: String, is_warning: bool = false) -> void:
	status_label.text = msg
	_panel_message(msg, is_warning)

func _ensure_critical_point_dialog() -> void:
	if critical_point_dialog != null:
		return
	critical_point_dialog = CRITICAL_POINT_DIALOG_SCENE.instantiate()
	add_child(critical_point_dialog)
	critical_point_dialog.point_saved.connect(_on_critical_point_saved)

func _on_connection_settings_pressed():
	if cloud_settings_window == null:
		cloud_settings_window = preload("res://addons/analytics_plugin/ui/cloud_settings.tscn").instantiate()
		add_child(cloud_settings_window)
		if has_meta("editor_plugin"):
			cloud_settings_window.set_meta("editor_plugin", get_meta("editor_plugin"))
		if has_meta("get_analytics"):
			cloud_settings_window.set_meta("get_analytics", get_meta("get_analytics"))
		if not cloud_settings_window.settings_saved.is_connected(_on_cloud_settings_saved):
			cloud_settings_window.settings_saved.connect(_on_cloud_settings_saved)
	if cloud_settings_window.has_method("open_window"):
		cloud_settings_window.open_window()
	else:
		cloud_settings_window.load_settings()
		cloud_settings_window.popup_centered()

func _on_cloud_settings_saved(settings):
	var analytics = _get_analytics()
	if analytics and analytics.has_method("apply_config"):
		analytics.apply_config(settings, false)
	print("📊 Настройки подключения применены")

func _on_add_event_pressed():
	var event_name = "custom_event_" + str(events.size() + 1)
	events.append(event_name)
	_redraw_events()

func _ensure_event_edit_dialog() -> void:
	if event_edit_dialog != null:
		return
	event_edit_dialog = EVENT_EDIT_DIALOG_SCENE.instantiate()
	add_child(event_edit_dialog)
	event_edit_dialog.name_saved.connect(_on_event_name_saved)

func _on_edit_event_pressed():
	var selected = events_list.get_selected_items()
	if selected.is_empty():
		push_warning("Выберите событие для редактирования")
		return
	var list_index: int = selected[0]
	var event_name = events_list.get_item_text(list_index)
	_ensure_event_edit_dialog()
	event_edit_dialog.set_meta("edit_list_index", list_index)
	event_edit_dialog.open_for_edit(event_name)

func _on_event_name_saved(event_name) -> void:
	var list_index: int = int(event_edit_dialog.get_meta("edit_list_index", -1))
	if list_index < 0 or list_index >= events_list.item_count:
		return
	events_list.set_item_text(list_index, event_name)
	if list_index >= 0 and list_index < events.size():
		events[list_index] = event_name

func _on_delete_event_pressed():
	var selected = events_list.get_selected_items()
	if selected.is_empty():
		return
	var list_index: int = selected[0]
	if list_index >= 0 and list_index < events.size():
		events.remove_at(list_index)
	_redraw_events()

func _on_add_critical_point_pressed():
	_ensure_critical_point_dialog()
	critical_point_dialog.open_for_create()

func _on_edit_critical_point_pressed():
	var selected = critical_points_list.get_selected_items()
	if selected.size() == 0:
		return
	var index: int = selected[0]
	if index < 0 or index >= critical_points.size():
		return
	_ensure_critical_point_dialog()
	critical_point_dialog.open_for_edit(critical_points[index], index)

func _on_critical_point_saved(point: Dictionary) -> void:
	var index: int = -1
	if critical_point_dialog:
		index = critical_point_dialog.get_edit_index()
	if index >= 0 and index < critical_points.size():
		critical_points[index] = point
	else:
		critical_points.append(point)
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
	var analytics = _get_analytics()
	if analytics == null:
		push_warning("Analytics autoload не найден — профиль сохранён только локально")
		return
	if str(analytics.config.get("cloud_url", "")).strip_edges().is_empty():
		print("📊 Профиль сохранён локально (URL не задан — синхронизация с сервером пропущена)")
		return
	if analytics.has_method("sync_game_profile"):
		analytics.sync_game_profile()
	else:
		print("Профиль сохранён локально")


func _connect_profile_sync_signal() -> void:
	call_deferred("_bind_analytics_signals")
	var analytics = _get_analytics()
	if analytics and not analytics.profile_sync_completed.is_connected(_on_profile_sync_completed):
		analytics.profile_sync_completed.connect(_on_profile_sync_completed)


func _on_profile_sync_completed(sync_ok, sync_message):
	if sync_ok:
		print("Profile synced on server")
	else:
		push_warning("Profile sync failed: " + str(sync_message))

func _format_critical_point_label(item: Dictionary) -> String:
	var source_labels = {
		"function": "func",
		"scene": "scene",
		"node": "node"
	}
	var source_type = str(item.get("source_type", "function"))
	var source_label = source_labels.get(source_type, source_type)
	var source_path = str(item.get("source_path", ""))
	if source_path.length() > 28:
		source_path = source_path.substr(0, 25) + "..."
	var collect = item.get("collect", {})
	var metrics = []
	if bool(collect.get("duration", false)):
		metrics.append("время")
	if bool(collect.get("count", false)):
		metrics.append("счётчик")
	if bool(collect.get("value", false)):
		metrics.append("значение")
	if bool(collect.get("enter_exit", false)):
		metrics.append("вход/выход")
	var props: Array = collect.get("custom_properties", [])
	if typeof(props) == TYPE_ARRAY and props.size() > 0:
		metrics.append("свойства")
	var metrics_text = ", ".join(PackedStringArray(metrics))
	if metrics.size() == 0:
		metrics_text = "-"
	return "%s [%s: %s] -> %s" % [
		item.get("name", "unknown"),
		source_label,
		source_path,
		metrics_text
	]

func _redraw_critical_points():
	critical_points_list.clear()
	for item in critical_points:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		critical_points_list.add_item(_format_critical_point_label(item))

func _redraw_archetypes():
	archetypes_list.clear()
	for archetype_id in archetypes:
		archetypes_list.add_item(str(archetype_id))

func _serialize_ml_profile() -> Dictionary:
	var analytics = _get_analytics()
	var bootstrap = 10
	var model_version = "default"
	if analytics:
		bootstrap = int(analytics.config.get("bootstrap_actions", 10))
		model_version = str(analytics.config.get("model_version", "default"))
	return {
		"events": events.duplicate(),
		"critical_points": critical_points,
		"archetypes": archetypes,
		"bootstrap_actions": bootstrap,
		"model_version": model_version
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
	critical_points = _normalize_critical_points(data.get("critical_points", []))
	archetypes = data.get("archetypes", [])
	var loaded_events = data.get("events", [])
	if typeof(loaded_events) == TYPE_ARRAY and loaded_events.size() > 0:
		events = []
		for entry in loaded_events:
			events.append(str(entry))
	var analytics = _get_analytics()
	if analytics:
		if data.has("bootstrap_actions"):
			analytics.config["bootstrap_actions"] = int(data["bootstrap_actions"])
		if data.has("model_version"):
			analytics.config["model_version"] = str(data["model_version"])

func _normalize_critical_points(raw: Array) -> Array:
	var result: Array = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = entry.duplicate(true)
		if not point.has("source_type"):
			point["source_type"] = "function"
		if not point.has("source_path"):
			point["source_path"] = ""
		if not point.has("collect"):
			point["collect"] = {
				"duration": false,
				"count": true,
				"value": false,
				"enter_exit": false,
				"custom_properties": []
			}
		if not point.has("weight"):
			point["weight"] = 1.0
		result.append(point)
	return result

func _get_analytics() -> Node:
	return AnalyticsResolver.resolve(self)

func _apply_ml_profile_to_analytics():
	var analytics = _get_analytics()
	if analytics == null:
		return
	analytics.config["critical_points"] = critical_points.duplicate(true)
	analytics.config["archetypes"] = archetypes.duplicate()
	var profile_data = _serialize_ml_profile()
	if profile_data.has("bootstrap_actions"):
		analytics.config["bootstrap_actions"] = profile_data["bootstrap_actions"]
	if profile_data.has("model_version"):
		analytics.config["model_version"] = profile_data["model_version"]
	analytics._save_config()

func _panel_message(msg: String, as_warning: bool = false) -> void:
	if as_warning:
		push_warning(msg)
	print("📊 [Analytics] ", msg)


func _ensure_analytics_ready(analytics: Node) -> bool:
	if not analytics.initialized and analytics.has_method("initialize"):
		analytics.initialize()
	if str(analytics.config.get("cloud_url", "")).strip_edges().is_empty():
		_panel_message("Укажите URL ingest: «Настроить облачный режим» → http://localhost:8000/telemetry/ingest", true)
		return false
	return true


func _on_send_now_pressed():
	var analytics = _get_analytics()
	if analytics == null:
		_panel_message("Autoload Analytics не найден. Перезагрузите плагин в Project Settings.", true)
		return
	if not _ensure_analytics_ready(analytics):
		return
	var pending: int = analytics.event_buffer.size()
	if pending == 0:
		_panel_message(
			"Буфер пуст — нечего отправлять. Сначала вызовите track() в игре.",
			true
		)
		return
	if not analytics.game_session_active and analytics.has_method("start_new_game"):
		analytics.start_new_game("editor-panel")
	analytics.sync_now()
	update_stats()
	_panel_message("Отправка %d событий… результат в Output (и на сервере, если backend запущен)." % pending)


func _ensure_logs_viewer() -> void:
	if logs_viewer_window != null:
		return
	logs_viewer_window = LOGS_VIEWER_SCENE.instantiate()
	get_tree().root.add_child(logs_viewer_window)

func _on_view_logs_pressed():
	_ensure_logs_viewer()
	if not logs_viewer_window.is_node_ready():
		await logs_viewer_window.ready
	if logs_viewer_window.has_method("open_viewer"):
		logs_viewer_window.open_viewer()
	else:
		logs_viewer_window.show()
		logs_viewer_window.popup_centered()

func _on_reset_stats_pressed():
	var analytics = _get_analytics()
	if analytics == null:
		_panel_message("Analytics не найден.", true)
		return
	if analytics.has_method("reset_local_stats"):
		analytics.reset_local_stats(true)
	else:
		analytics.event_buffer.clear()
	update_stats()
	_panel_message("Буфер и файл analytics_logs.jsonl сброшены.")

func update_stats() -> void:
	var analytics = _get_analytics()
	if analytics:
		var stats = analytics.get_stats()
		var sid = str(stats.get("session_id", ""))
		if sid.length() > 20:
			sid = sid.substr(0, 17) + "..."
		session_id_value.text = sid if not sid.is_empty() else "(нет)"
		buffer_count_value.text = str(stats.get("buffer_size", 0))
		if stats.get("inflight_size", 0) > 0:
			buffer_count_value.text += " (+" + str(stats.get("inflight_size")) + " отправка)"
		pending_count_value.text = str(stats.get("pending_disk", 0))
		_update_adaptation_display(stats.get("last_adaptation", {}))
		if analytics.cloud_sender:
			server_status_label.text = "Сервер: " + (
				"доступен" if analytics.cloud_sender.server_available else "недоступен"
			)
	else:
		session_id_value.text = "(autoload нет)"
		buffer_count_value.text = "0"
		pending_count_value.text = "0"


func _update_adaptation_display(adaptation: Variant) -> void:
	if typeof(adaptation) != TYPE_DICTIONARY or adaptation.is_empty():
		adaptation_value.text = "Пока нет данных от ML."
		return
	var params = adaptation.get("parameters", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	var archetype = str(adaptation.get("predicted_archetype", adaptation.get("archetype", "")))
	var lines: PackedStringArray = []
	if not archetype.is_empty():
		lines.append("Архетип: " + archetype)
	if not params.is_empty():
		lines.append("Параметры: " + JSON.stringify(params))
	else:
		lines.append(JSON.stringify(adaptation))
	adaptation_value.text = "\n".join(lines)
