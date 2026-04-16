@tool
extends Window

signal settings_saved(settings)

@onready var url_input = $MainVBox/UrlHBox/UrlInput
@onready var api_input = $MainVBox/ApiHBox/ApiInput
@onready var buffer_spin = $MainVBox/BufferHBox/BufferSizeSpin
@onready var interval_spin = $MainVBox/IntervalHBox/IntervalSpin
@onready var retry_check = $MainVBox/RetryCheck
@onready var cache_check = $MainVBox/CacheCheck
@onready var save_btn = $MainVBox/ButtonsHBox/SaveBtn
@onready var cancel_btn = $MainVBox/ButtonsHBox/CancelBtn

var current_settings = {}

func _ready():
	# Подключаем кнопки
	save_btn.pressed.connect(_on_save_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	
	# Загружаем текущие настройки
	load_settings()

func load_settings():
	# Получаем настройки из Analytics, если доступно
	if Engine.has_singleton("Analytics"):
		var analytics = Engine.get_singleton("Analytics")
		if analytics and analytics.config:
			current_settings = analytics.config.duplicate()
			_update_ui_from_settings()

func _update_ui_from_settings():
	url_input.text = current_settings.get("cloud_url", "http://localhost:8000/analytics")
	api_input.text = current_settings.get("api_key", "")
	buffer_spin.value = current_settings.get("buffer_size", 100)
	interval_spin.value = current_settings.get("auto_send_interval", 30)
	retry_check.button_pressed = current_settings.get("retry_on_error", true)
	cache_check.button_pressed = current_settings.get("cache_when_offline", false)

func _update_settings_from_ui():
	current_settings["cloud_url"] = url_input.text
	current_settings["api_key"] = api_input.text
	current_settings["buffer_size"] = int(buffer_spin.value)
	current_settings["auto_send_interval"] = int(interval_spin.value)
	current_settings["retry_on_error"] = retry_check.button_pressed
	current_settings["cache_when_offline"] = cache_check.button_pressed

func _on_save_pressed():
	_update_settings_from_ui()
	emit_signal("settings_saved", current_settings)
	hide()

func _on_cancel_pressed():
	hide()
