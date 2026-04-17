extends Node
class_name AnalyticsPlugin

# Конфигурация
var config = {
	"mode": "cloud",
	"buffer_size": 100,
	"auto_send_interval": 30,
	"cloud_url": "",
	"api_key": "",
	"local_db_path": "user://analytics.db",
	"ml_model_path": "",
	"game_id": "default_game",
	"critical_points": [],
	"archetypes": []
}

# Буфер событий
var event_buffer = []

# Идентификаторы
var session_id = ""
var player_id = ""

# Состояния
var current_state = {}

# Таймер
var send_timer = null

# Флаг инициализации
var initialized = false
# Облачный отправитель

# Константы
const CONFIG_PATH = "user://analytics_config.json"
const PLAYER_ID_PATH = "user://player_id.txt"
var cloud_sender = null
func _init():
	# Генерируем session_id при создании
	_generate_session_id()

func initialize(config_path = "res://analytics_config.json"):
	print("📊 Analytics: инициализация...")
	
	# Загружаем конфиг
	_load_config(config_path)
	
	# Загружаем или создаем player_id
	_load_or_create_player_id()
	
	# Создаем таймер для автоотправки
	_setup_auto_send()
	
	# СОЗДАЕМ CLOUD SENDER (НОВОЕ)
	_init_cloud_sender()
	
	initialized = true
	print("✅ Analytics инициализирован! Режим: ", config.mode)
	return true
func _init_cloud_sender():
	# Создаем отправитель только если он ещё не создан
	if cloud_sender == null:
		cloud_sender = CloudSender.new({
			"cloud_url": config.cloud_url,
			"api_key": config.api_key,
			"timeout": 5,
			"retry_count": 3
		})
		add_child(cloud_sender)
		
		# Подключаем сигналы
		cloud_sender.send_successful.connect(_on_cloud_send_successful)
		cloud_sender.send_failed.connect(_on_cloud_send_failed)
		cloud_sender.server_available_changed.connect(_on_server_available_changed)
		
		print("📡 CloudSender создан, URL:", config.cloud_url)

func _on_cloud_send_successful(count):
	print("✅ Облачная отправка успешна")

func _on_cloud_send_failed(error_message):
	print("❌ Облачная отправка не удалась:", error_message)

func _on_server_available_changed(is_available):
	print("📡 Сервер ", "доступен" if is_available else "недоступен")
func _generate_session_id():
	# Генерируем уникальный ID сессии
	# Используем timestamp + случайное число
	var timestamp = str(Time.get_unix_time_from_system())
	var random = str(randi() % 10000)
	session_id = "sess_" + timestamp + "_" + random
	print("📊 Новая сессия: ", session_id)

func _load_or_create_player_id():
	# Пробуем загрузить существующий player_id
	if FileAccess.file_exists(PLAYER_ID_PATH):
		var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.READ)
		player_id = file.get_line()
		file.close()
		print("📊 Загружен player_id: ", player_id)
	else:
		# Создаем новый
		var timestamp = str(Time.get_unix_time_from_system())
		var random = str(randi() % 100000)
		player_id = "player_" + timestamp + "_" + random
		
		# Сохраняем
		var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.WRITE)
		file.store_line(player_id)
		file.close()
		print("📊 Создан новый player_id: ", player_id)

func _load_config(path):
	# Пытаемся загрузить конфиг из JSON
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var loaded_config = json.data
			# Обновляем только те поля, которые есть в загруженном конфиге
			for key in loaded_config:
				if key in config:
					config[key] = loaded_config[key]
			print("📊 Конфиг загружен из ", path)
		else:
			print("❌ Ошибка парсинга конфига")
	else:
		print("📊 Конфиг не найден, используются настройки по умолчанию")
		# Создаем пример конфига
		_save_default_config(path)

func _save_default_config(path):
	var default_config = {
		"mode": "cloud",
		"buffer_size": 100,
		"auto_send_interval": 30,
		"cloud_url": "http://localhost:8000/analytics",
		"api_key": "",
		"local_db_path": "user://analytics.db",
		"ml_model_path": "",
		"game_id": "default_game",
		"critical_points": [],
		"archetypes": []
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.new().stringify(default_config, "\t"))
	file.close()
	print("📊 Создан конфиг по умолчанию: ", path)
func _save_config(path = "res://analytics_config.json"):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(config, "\t"))
		file.close()
		print("📊 Конфиг сохранён в ", path)
func _setup_auto_send():
	if config.auto_send_interval > 0:
		send_timer = Timer.new()
		send_timer.wait_time = config.auto_send_interval
		send_timer.timeout.connect(_on_auto_send_timeout)
		send_timer.one_shot = false
		add_child(send_timer)
		send_timer.start()
		print("📊 Автоотправка каждые ", config.auto_send_interval, " сек")

func _on_auto_send_timeout():
	if len(event_buffer) > 0:
		print("📊 Автоотправка: ", len(event_buffer), " событий")
		sync_now()

func track(event_name: String, parameters: Dictionary = {}):
	if not initialized:
		print("❌ Analytics не инициализирован!")
		return false
	
	# Создаем полный объект события
	var event = {
		"session_id": session_id,
		"player_id": player_id,
		"event_name": event_name,
		"timestamp": Time.get_unix_time_from_system(),
		"game_time": _get_game_time(),
		"parameters": parameters,
		"state": current_state.duplicate()  # Копируем текущее состояние
	}
	
	# Добавляем в буфер
	event_buffer.append(event)
	
	print("📊 Событие добавлено: ", event_name, " (буфер: ", len(event_buffer), "/", config.buffer_size, ")")
	
	# Если буфер переполнен - отправляем
	if len(event_buffer) >= config.buffer_size:
		print("📊 Буфер заполнен, отправляем...")
		sync_now()
	
	return true

func set_state(key: String, value):
	current_state[key] = value
	print("📊 Состояние: ", key, " = ", value)

func sync_now():
	if len(event_buffer) == 0:
		print("📊 Нет событий для отправки")
		return true
	
	print("📊 Синхронизация ", len(event_buffer), " событий...")
	
	# Копируем события и очищаем буфер
	var events_to_send = event_buffer.duplicate()
	event_buffer.clear()
	
	# Отправляем в зависимости от режима
	if config.mode == "cloud" and cloud_sender:
		var metadata = {
			"game_id": config.get("game_id", "default_game"),
			"critical_points": config.get("critical_points", []),
			"archetypes": config.get("archetypes", [])
		}
		cloud_sender.send_events(events_to_send, metadata)
	elif config.mode == "local":
		# TODO: сохранить в SQLite
		print("📊 Локальный режим: сохранение в БД (пока не реализовано)")
	else:
		# Заглушка - просто очищаем
		print("📊 Отправлено ", len(events_to_send), " событий (демо-режим)")
	
	return true

func get_stats():
	var stats = {
		"buffer_size": len(event_buffer),
		"session_id": session_id,
		"player_id": player_id,
		"mode": config.mode,
		"auto_send_interval": config.auto_send_interval,
		"state_keys": current_state.keys()
	}
	
	# Добавляем информацию об облачной очереди
	if cloud_sender:
		stats["cloud_queue"] = cloud_sender.get_queue_size()
		stats["server_available"] = cloud_sender.server_available
	
	return stats

func _get_game_time():
	# Возвращает время от начала игры (в секундах)
	if Engine.get_main_loop():
		# В Godot 4 время можно получить через Time
		return Time.get_ticks_msec() / 1000.0  # конвертируем миллисекунды в секунды
	return 0.0
