@tool
extends Window

signal settings_saved(settings)

const CONFIG_PATH = "user://analytics_config.json"
const AnalyticsResolver = preload("res://addons/analytics_plugin/editor/analytics_resolver.gd")

@onready var url_input = $MainMargin/MainVBox/UrlHBox/UrlInput
@onready var api_input = $MainMargin/MainVBox/ApiHBox/ApiInput
@onready var buffer_spin = $MainMargin/MainVBox/BufferHBox/BufferSizeSpin
@onready var interval_spin = $MainMargin/MainVBox/IntervalHBox/IntervalSpin
@onready var retry_check = $MainMargin/MainVBox/OptionsVBox/RetryCheck
@onready var cache_check = $MainMargin/MainVBox/OptionsVBox/CacheCheck
@onready var save_btn = $MainMargin/MainVBox/ButtonsHBox/SaveBtn
@onready var cancel_btn = $MainMargin/MainVBox/ButtonsHBox/CancelBtn

var current_settings = {}
var _signals_bound = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_bind_signals()

func _bind_signals() -> void:
	if _signals_bound:
		return
	_signals_bound = true
	if not save_btn.pressed.is_connected(_on_save_pressed):
		save_btn.pressed.connect(_on_save_pressed)
	if not cancel_btn.pressed.is_connected(_on_cancel_pressed):
		cancel_btn.pressed.connect(_on_cancel_pressed)
	if not close_requested.is_connected(_on_cancel_pressed):
		close_requested.connect(_on_cancel_pressed)

func open_window() -> void:
	if not is_node_ready():
		await ready
	_bind_signals()
	load_settings()
	_ensure_editor_popup_parent()
	show()
	popup_centered(Vector2i(480, 420))


func _ensure_editor_popup_parent() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.root
	if root and get_parent() != root:
		reparent(root)

func _get_analytics() -> Node:
	return AnalyticsResolver.resolve(self)

func _load_settings_from_disk() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(raw) != OK:
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}

func _save_settings_to_disk(settings: Dictionary) -> bool:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать " + CONFIG_PATH)
		return false
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	print("📊 Настройки сохранены в ", CONFIG_PATH)
	return true

func load_settings():
	current_settings = _load_settings_from_disk()

	var analytics = _get_analytics()
	if analytics and analytics.config:
		for key in analytics.config:
			current_settings[key] = analytics.config[key]

	_update_ui_from_settings()

func _update_ui_from_settings():
	url_input.text = str(current_settings.get("cloud_url", ""))
	api_input.text = str(current_settings.get("api_key", ""))
	buffer_spin.value = int(current_settings.get("buffer_size", 100))
	interval_spin.value = int(current_settings.get("auto_send_interval", 30))
	retry_check.button_pressed = bool(current_settings.get("retry_on_error", true))
	cache_check.button_pressed = bool(current_settings.get("cache_when_offline", false))

func _update_settings_from_ui():
	current_settings["cloud_url"] = url_input.text.strip_edges()
	current_settings["api_key"] = api_input.text
	current_settings["buffer_size"] = int(buffer_spin.value)
	current_settings["auto_send_interval"] = int(interval_spin.value)
	current_settings["retry_on_error"] = retry_check.button_pressed
	current_settings["cache_when_offline"] = cache_check.button_pressed

func _on_save_pressed():
	_update_settings_from_ui()

	if str(current_settings.get("cloud_url", "")).is_empty():
		push_warning("URL сервера пустой — заполните поле перед сохранением")
		return

	var merged = _load_settings_from_disk()
	for key in current_settings:
		merged[key] = current_settings[key]
	current_settings = merged

	if not _save_settings_to_disk(current_settings):
		return

	var analytics = _get_analytics()
	if analytics and analytics.has_method("apply_config"):
		analytics.apply_config(current_settings, false)

	emit_signal("settings_saved", current_settings)
	hide()

func _on_cancel_pressed():
	hide()
