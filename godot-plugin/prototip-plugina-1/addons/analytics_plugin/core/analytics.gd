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

# Флаги жизненного цикла
var initialized := false
var game_session_active := false
var server_session_ready := false
var session_http: HTTPRequest = null
var _pending_game_version := ""

# Константы
const CONFIG_PATH = "user://analytics_config.json"
const PLAYER_ID_PATH = "user://player_id.txt"
var cloud_sender = null

## Однократная настройка плагина (конфиг, player_id, CloudSender, таймер).
## Не создаёт игровую сессию — для этого используйте start_new_game().
func initialize(config_path = CONFIG_PATH) -> bool:
	if initialized:
		return true

	print("📊 Analytics: инициализация плагина...")
	_load_config(config_path)
	_load_or_create_player_id()
	_setup_auto_send()
	_init_cloud_sender()
	initialized = true
	print("✅ Analytics готов. Вызовите start_new_game() при старте новой игры. Режим:", config.mode)
	return true


## Старт новой игровой сессии: новый session_id, сброс буфера и состояния.
## TODO(интеграция): вызывать при начале новой игры, не из _ready() тестовой сцены.
## Перенести в GameManager / кнопку «Новая игра» / загрузку run или первого уровня.
func start_new_game(game_version: String = "") -> bool:
	if not initialized:
		print("❌ Сначала вызовите Analytics.initialize()")
		return false

	print("📊 Старт новой игровой сессии...")
	_pending_game_version = game_version
	event_buffer.clear()
	current_state.clear()
	session_id = ""
	server_session_ready = false
	game_session_active = true

	if config.mode == "cloud" and not str(config.get("cloud_url", "")).strip_edges().is_empty():
		_start_server_session()
	else:
		_generate_local_session_id()

	return true


## Завершение текущей игровой сессии.
## TODO(интеграция): вызывать при выходе в меню / game over — PATCH /game/session/{id}/end
func end_game() -> void:
	if not game_session_active:
		return
	game_session_active = false
	server_session_ready = false
	session_id = ""
	print("📊 Игровая сессия завершена")
func apply_config(patch: Dictionary, persist: bool = true) -> void:
	for key in patch:
		if key in config:
			config[key] = patch[key]
	if persist:
		_save_config()
	_refresh_cloud_sender()

func _refresh_cloud_sender() -> void:
	if cloud_sender:
		cloud_sender.queue_free()
		cloud_sender = null
	var url := str(config.get("cloud_url", "")).strip_edges()
	if url.is_empty():
		print("📊 cloud_url не задан — укажите URL в настройках облачного режима")
		return
	_init_cloud_sender()

func _init_cloud_sender():
	if str(config.get("cloud_url", "")).strip_edges().is_empty():
		return
	if cloud_sender != null:
		return
	cloud_sender = CloudSender.new({
		"cloud_url": config.cloud_url,
		"api_key": config.api_key,
		"timeout": 5,
		"retry_count": 3
	})
	add_child(cloud_sender)
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
func _generate_local_session_id():
	var timestamp = str(Time.get_unix_time_from_system())
	var random = str(randi() % 10000)
	session_id = "sess_" + timestamp + "_" + random
	server_session_ready = false
	print("📊 Локальная сессия: ", session_id)

func _get_api_base_url() -> String:
	var url := str(config.get("cloud_url", "")).strip_edges()
	var marker := "/telemetry"
	var idx := url.find(marker)
	if idx > 0:
		return url.substr(0, idx)
	var last_slash := url.rfind("/")
	if last_slash > 7:
		return url.substr(0, last_slash)
	return url

func _is_uuid(value: String) -> bool:
	if value.length() != 36:
		return false
	var regex := RegEx.new()
	regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return regex.search(value) != null

func _start_server_session() -> void:
	server_session_ready = false
	if session_http == null:
		session_http = HTTPRequest.new()
		add_child(session_http)
		session_http.request_completed.connect(_on_session_start_completed)
	var base_url := _get_api_base_url()
	var start_url := base_url + "/game/session/start?player_id=" + player_id.uri_encode()
	print("📊 Запрашиваем session_id у сервера...")
	session_http.request(start_url, [], HTTPClient.METHOD_POST)

func _on_session_start_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("❌ Не удалось создать серверную сессию, код:", response_code)
		server_session_ready = false
		return
	var body_text := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(body_text) != OK:
		print("❌ Не удалось разобрать ответ /game/session/start")
		server_session_ready = false
		return
	var data: Dictionary = json.data
	if not data.has("session_id"):
		print("❌ В ответе нет session_id")
		server_session_ready = false
		return
	session_id = str(data["session_id"])
	server_session_ready = true
	print("📊 Серверная сессия: ", session_id)
	if not _pending_game_version.is_empty():
		print("📊 Версия игры:", _pending_game_version)
	_update_buffered_session_ids()
	if len(event_buffer) > 0:
		sync_now()

func _update_buffered_session_ids() -> void:
	for event in event_buffer:
		event["session_id"] = session_id

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
		print("📊 Конфиг не найден: ", path)
		print("📊 Используйте настройки плагина и сохраните URL сервера вручную")

func _save_config(path = CONFIG_PATH):
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
		print("❌ Analytics не инициализирован! Вызовите initialize()")
		return false
	if not game_session_active:
		print("❌ Нет активной игровой сессии! Вызовите start_new_game()")
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
	
	if config.mode == "cloud" and str(config.get("cloud_url", "")).strip_edges().is_empty():
		print("❌ cloud_url пустой — события возвращены в буфер")
		event_buffer = events_to_send + event_buffer
		return false

	if config.mode == "cloud" and not server_session_ready:
		print("📊 session_id ещё не получен с сервера, отложим отправку")
		event_buffer = events_to_send + event_buffer
		_start_server_session()
		return false

	for event in events_to_send:
		event["session_id"] = session_id

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
