@tool
extends Panel

# Ссылки на элементы интерфейса
@onready var cloud_mode_check = $MainMargin/MainVBox/ModeHBox/RadioContainer/CloudModeCheck
@onready var local_mode_check = $MainMargin/MainVBox/ModeHBox/RadioContainer/LocalModeCheck
@onready var cloud_settings_btn = $MainMargin/MainVBox/SettingsButtonsHBox/CloudSettingsBtn
@onready var local_settings_btn = $MainMargin/MainVBox/SettingsButtonsHBox/LocalSettingsBtn
@onready var events_list = $MainMargin/MainVBox/EventsList
@onready var add_event_btn = $MainMargin/MainVBox/EventButtonsHBox/AddEventBtn
@onready var edit_event_btn = $MainMargin/MainVBox/EventButtonsHBox/EditEventBtn
@onready var delete_event_btn = $MainMargin/MainVBox/EventButtonsHBox/DeleteEventBtn
@onready var session_id_value = $MainMargin/MainVBox/StatsGrid/SessionIdValue
@onready var buffer_count_value = $MainMargin/MainVBox/StatsGrid/BufferCountValue
@onready var send_now_btn = $MainMargin/MainVBox/ActionButtonsHBox/SendNowBtn
@onready var view_logs_btn = $MainMargin/MainVBox/ActionButtonsHBox/ViewLogsBtn
@onready var reset_stats_btn = $MainMargin/MainVBox/ActionButtonsHBox/ResetStatsBtn

# Список событий (для примера)
var events = ["dialog_choice", "item_pickup", "location_change", "combat_start"]
var cloud_settings_window = null
func _ready():
	# Заполняем список событий
	for event in events:
		events_list.add_item(event)
	
	# Подключаем сигналы
	cloud_mode_check.toggled.connect(_on_cloud_mode_toggled)
	local_mode_check.toggled.connect(_on_local_mode_toggled)
	cloud_settings_btn.pressed.connect(_on_cloud_settings_pressed)
	local_settings_btn.pressed.connect(_on_local_settings_pressed)
	add_event_btn.pressed.connect(_on_add_event_pressed)
	edit_event_btn.pressed.connect(_on_edit_event_pressed)
	delete_event_btn.pressed.connect(_on_delete_event_pressed)
	send_now_btn.pressed.connect(_on_send_now_pressed)
	view_logs_btn.pressed.connect(_on_view_logs_pressed)
	reset_stats_btn.pressed.connect(_on_reset_stats_pressed)
	
	# Обновляем статистику
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
	print("Открыть настройки облачного режима")
	
	# Если окно ещё не создано - создаём
	if cloud_settings_window == null:
		cloud_settings_window = preload("res://addons/analytics_plugin/ui/cloud_settings.tscn").instantiate()
		add_child(cloud_settings_window)
		cloud_settings_window.settings_saved.connect(_on_cloud_settings_saved)
	
	# Обновляем настройки и показываем окно
	cloud_settings_window.load_settings()
	cloud_settings_window.popup_centered()

func _on_cloud_settings_saved(settings):
	print("Настройки облачного режима сохранены:", settings)
	
	# Применяем настройки к Analytics
	if Engine.has_singleton("Analytics"):
		var analytics = Engine.get_singleton("Analytics")
		# Обновляем конфиг
		for key in settings:
			analytics.config[key] = settings[key]
		
		# Пересоздаём cloud_sender с новыми настройками
		if analytics.cloud_sender:
			analytics.cloud_sender.queue_free()
		analytics._init_cloud_sender()
		
		# Сохраняем конфиг в файл
		analytics._save_config(analytics.config_path)

func _on_local_settings_pressed():
	print("Открыть настройки локального режима")
	# TODO: открыть окно настроек локального режима

func _on_add_event_pressed():
	# TODO: открыть диалог добавления события
	print("Добавить событие")

func _on_edit_event_pressed():
	var selected = events_list.get_selected_items()
	if selected.size() > 0:
		var event_name = events_list.get_item_text(selected[0])
		print("Редактировать событие: ", event_name)
		# TODO: открыть диалог редактирования

func _on_delete_event_pressed():
	var selected = events_list.get_selected_items()
	if selected.size() > 0:
		var event_name = events_list.get_item_text(selected[0])
		events_list.remove_item(selected[0])
		print("Удалено событие: ", event_name)

func _on_send_now_pressed():
	print("Ручная отправка данных")
	# TODO: вызвать Analytics.sync_now()

func _on_view_logs_pressed():
	print("Просмотр логов")
	# TODO: открыть окно с логами

func _on_reset_stats_pressed():
	print("Сброс статистики")
	# TODO: сбросить статистику

func update_stats():
	# Получаем данные из Analytics, если доступно
	if Engine.has_singleton("Analytics"):
		var stats = Analytics.get_stats()
		session_id_value.text = stats.get("session_id", "sess_unknown")
		buffer_count_value.text = str(stats.get("buffer_size", 0))
	else:
		session_id_value.text = "sess_demo"
		buffer_count_value.text = "0"

func _process(delta):
	# Обновляем статистику в реальном времени (если нужно)
	if Engine.has_singleton("Analytics"):
		update_stats()
