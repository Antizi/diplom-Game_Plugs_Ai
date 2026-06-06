@tool
extends Node

signal adaptation_received(adaptation)
signal game_session_started(session_id)
signal profile_sync_completed(sync_ok, sync_message)
signal stats_changed

# Конфигурация
var config = {
	"buffer_size": 100,
	"auto_send_interval": 30,
	"cloud_url": "",
	"api_key": "",
	"local_db_path": "user://analytics.db",
	"ml_model_path": "",
	"game_id": "default_game",
	"critical_points": [],
	"archetypes": [],
	"feature_schema_version": 1,
	"model_version": "default",
	"bootstrap_actions": 10,
	"retry_on_error": true,
	"cache_when_offline": true,
	"retry_count": 3,
	"retry_delay_sec": 1.0,
	"http_timeout": 30.0,
	"debug_verbose": false
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
var initialized = false
var game_session_active = false
var server_session_ready = false
var session_http: HTTPRequest = null
var session_end_http: HTTPRequest = null
var profile_sync_http: HTTPRequest = null
var _pending_game_version = ""
var _session_start_in_progress = false
var _session_end_in_progress = false
var last_adaptation: Dictionary = {}
var _inflight_events: Array = []
var _sync_in_progress: bool = false
var _session_start_ticks: int = 0

# Константы
const CONFIG_PATH = "user://analytics_config.json"
const PLAYER_ID_PATH = "user://player_id.txt"
const LOG_PATH = "user://analytics_logs.jsonl"
const PENDING_PATH = "user://pending_telemetry.jsonl"
const MAX_LOG_BYTES = 1048576
var cloud_sender = null


func _ready() -> void:
	# Только в простое редактора (не во время F5) — иначе дублируется с initialize() в игре.
	if Engine.is_editor_hint() and not _is_running_game() and not initialized:
		call_deferred("_bootstrap_in_editor")


func _is_running_game() -> bool:
	var st: SceneTree = get_tree()
	return st != null and st.current_scene != null


func _bootstrap_in_editor() -> void:
	if initialized or _is_running_game():
		return
	initialize()


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
	call_deferred("_restore_pending_from_disk")
	print("✅ Analytics готов. Вызовите start_new_game() при старте новой игры. Режим: cloud")
	emit_signal("stats_changed")
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
	_session_start_in_progress = false
	game_session_active = true
	_session_start_ticks = Time.get_ticks_msec()

	if not str(config.get("cloud_url", "")).strip_edges().is_empty():
		if session_http and not _http_is_idle(session_http):
			session_http.cancel_request()
		_start_server_session()
	else:
		_generate_local_session_id()

	return true


## Завершение текущей игровой сессии (сброс буфера + PATCH /game/session/{id}/end на сервере).
func end_game() -> void:
	if not game_session_active:
		return

	if event_buffer.size() > 0:
		sync_now()

	var ending_session_id: String = session_id
	if _is_uuid(ending_session_id):
		_end_server_session(ending_session_id)

	game_session_active = false
	server_session_ready = false
	session_id = ""
	last_adaptation = {}
	print("📊 Игровая сессия завершена")
func apply_config(patch: Dictionary, persist: bool = true) -> void:
	for key in patch:
		config[key] = patch[key]
	if persist:
		_save_config()
	_refresh_cloud_sender()
	emit_signal("stats_changed")

func _refresh_cloud_sender() -> void:
	if cloud_sender:
		cloud_sender.queue_free()
		cloud_sender = null
	var url = str(config.get("cloud_url", "")).strip_edges()
	if url.is_empty():
		print("📊 cloud_url не задан — укажите URL в настройках облачного режима")
		return
	_init_cloud_sender()

func _init_cloud_sender() -> void:
	if str(config.get("cloud_url", "")).strip_edges().is_empty():
		return
	if cloud_sender != null:
		return
	cloud_sender = CloudSender.new()
	add_child(cloud_sender)
	_apply_cloud_sender_config()
	if not cloud_sender.batch_finished.is_connected(_on_cloud_batch_finished):
		cloud_sender.batch_finished.connect(_on_cloud_batch_finished)
	if not cloud_sender.ingest_completed.is_connected(_on_ingest_completed):
		cloud_sender.ingest_completed.connect(_on_ingest_completed)
	if not cloud_sender.server_available_changed.is_connected(_on_server_available_changed):
		cloud_sender.server_available_changed.connect(_on_server_available_changed)
	_log("CloudSender создан, URL: " + str(config.cloud_url))


func _apply_cloud_sender_config() -> void:
	if cloud_sender == null:
		return
	cloud_sender.update_config({
		"cloud_url": config.cloud_url,
		"api_key": config.api_key,
		"timeout": float(config.get("http_timeout", 30.0)),
		"retry_count": int(config.get("retry_count", 3)),
		"retry_on_error": bool(config.get("retry_on_error", true)),
		"retry_delay_sec": float(config.get("retry_delay_sec", 1.0)),
	})

func _build_telemetry_metadata() -> Dictionary:
	return {
		"critical_points": config.get("critical_points", []),
		"archetypes": config.get("archetypes", []),
		"model_mode": "cloud",
		"feature_schema_version": config.get("feature_schema_version", 1)
	}

func _on_ingest_completed(response: Dictionary) -> void:
	if response.is_empty():
		return
	var adaptation = response.get("adaptation", {})
	if typeof(adaptation) == TYPE_DICTIONARY and not adaptation.is_empty():
		last_adaptation = adaptation
		emit_signal("adaptation_received", adaptation)
		_log("Адаптация получена: " + str(adaptation))
	emit_signal("stats_changed")


func _on_cloud_batch_finished(
	success: bool,
	events: Array,
	_response: Dictionary,
	error_message: String
) -> void:
	_sync_in_progress = false
	if success:
		_inflight_events.clear()
		_log("Облачная отправка успешна, событий: " + str(events.size()))
	else:
		_log("Облачная отправка не удалась: " + str(error_message), true)
		if bool(config.get("cache_when_offline", false)) and not events.is_empty():
			TelemetryPersistence.append_events(PENDING_PATH, events)
			_log("События сохранены в offline-очередь: " + str(events.size()))
		else:
			event_buffer = events + event_buffer
		_inflight_events.clear()
	emit_signal("stats_changed")


func _on_server_available_changed(is_available: bool) -> void:
	_log("Сервер " + ("доступен" if is_available else "недоступен"))
	emit_signal("stats_changed")
func _generate_local_session_id():
	var timestamp = str(Time.get_unix_time_from_system())
	var random = str(randi() % 10000)
	session_id = "sess_" + timestamp + "_" + random
	server_session_ready = false
	print("📊 Локальная сессия: ", session_id)

func _get_api_base_url() -> String:
	var url = str(config.get("cloud_url", "")).strip_edges()
	var marker = "/telemetry"
	var idx = url.find(marker)
	if idx > 0:
		return url.substr(0, idx)
	var last_slash = url.rfind("/")
	if last_slash > 7:
		return url.substr(0, last_slash)
	return url

func _is_uuid(value: String) -> bool:
	if value.length() != 36:
		return false
	var regex = RegEx.new()
	regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return regex.search(value) != null


func _http_is_idle(req: HTTPRequest) -> bool:
	if req == null:
		return true
	# Godot 4.6: у HTTPRequest только get_http_client_status(), не get_status().
	return req.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED


func _start_server_session() -> void:
	if _session_start_in_progress or not _http_is_idle(session_http):
		return
	server_session_ready = false
	if session_http == null:
		session_http = HTTPRequest.new()
		add_child(session_http)
		if not session_http.request_completed.is_connected(_on_session_start_completed):
			session_http.request_completed.connect(_on_session_start_completed)
	var base_url = _get_api_base_url()
	var start_url = base_url + "/game/session/start?player_id=" + player_id.uri_encode()
	if not _pending_game_version.is_empty():
		start_url += "&game_version=" + _pending_game_version.uri_encode()
	print("📊 Запрашиваем session_id у сервера...")
	_session_start_in_progress = true
	var err = session_http.request(start_url, [], HTTPClient.METHOD_POST)
	if err != OK:
		_session_start_in_progress = false
		push_error("Не удалось начать запрос session/start: " + str(err))

func _on_session_start_completed(result, response_code, _headers, body):
	_session_start_in_progress = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("❌ Не удалось создать серверную сессию, код:", response_code)
		server_session_ready = false
		return
	var body_text: String = body.get_string_from_utf8()
	var json = JSON.new()
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
	emit_signal("game_session_started", session_id)
	if not _pending_game_version.is_empty():
		print("📊 Версия игры:", _pending_game_version)
	_update_buffered_session_ids()
	if event_buffer.size() > 0:
		sync_now()

func _update_buffered_session_ids() -> void:
	for event in event_buffer:
		event["session_id"] = session_id

func _end_server_session(ending_session_id: String) -> void:
	if _session_end_in_progress or not _http_is_idle(session_end_http):
		return
	if session_end_http == null:
		session_end_http = HTTPRequest.new()
		add_child(session_end_http)
		if not session_end_http.request_completed.is_connected(_on_session_end_completed):
			session_end_http.request_completed.connect(_on_session_end_completed)
	var url = _get_api_base_url() + "/game/session/" + ending_session_id + "/end"
	print("📊 Завершаем сессию на сервере:", ending_session_id)
	_session_end_in_progress = true
	var err = session_end_http.request(url, [], HTTPClient.METHOD_PATCH)
	if err != OK:
		_session_end_in_progress = false

func _on_session_end_completed(result, response_code, _headers, _body) -> void:
	_session_end_in_progress = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		print("📊 Сессия закрыта на сервере")
	else:
		print("❌ Не удалось закрыть сессию на сервере, код:", response_code)

func get_last_adaptation() -> Dictionary:
	return last_adaptation.duplicate(true)


## Отправляет ML-профиль на backend: PUT /game/profile
func sync_game_profile() -> bool:
	var base_url = _get_api_base_url()
	if base_url.is_empty():
		var msg = "cloud_url не задан — укажите URL ingest в настройках облака"
		push_warning(msg)
		emit_signal("profile_sync_completed", false, str(msg))
		return false

	if profile_sync_http == null:
		profile_sync_http = HTTPRequest.new()
		add_child(profile_sync_http)
		profile_sync_http.request_completed.connect(_on_profile_sync_completed)

	var critical_points: Array = config.get("critical_points", [])
	var archetypes: Array = config.get("archetypes", [])
	var feature_order: Array = []
	for cp in critical_points:
		if typeof(cp) == TYPE_DICTIONARY:
			var point_name = str(cp.get("name", "")).strip_edges()
			if not point_name.is_empty():
				feature_order.append(point_name)

	var payload = {
		"model_version": str(config.get("model_version", "default")),
		"feature_order": feature_order,
		"critical_points": critical_points,
		"archetypes": archetypes,
		"feature_schema_version": int(config.get("feature_schema_version", 1)),
		"bootstrap_actions": int(config.get("bootstrap_actions", 10))
	}

	var headers = ["Content-Type: application/json"]
	var api_key = str(config.get("api_key", ""))
	if not api_key.is_empty():
		headers.append("X-API-Key: " + api_key)

	var url = base_url + "/game/profile"
	var body = JSON.new().stringify(payload)
	print("📊 Синхронизация профиля → PUT ", url)
	var err = profile_sync_http.request(url, headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		var msg = "Ошибка HTTP при синхронизации профиля: " + str(err)
		push_error(msg)
		emit_signal("profile_sync_completed", false, str(msg))
		return false
	return true


func _on_profile_sync_completed(result, response_code, _headers, body) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		var msg = "Сетевая ошибка синхронизации профиля: " + str(result)
		push_error(msg)
		emit_signal("profile_sync_completed", false, str(msg))
		return
	if response_code < 200 or response_code >= 300:
		var error_detail = "HTTP " + str(response_code)
		if body.size() > 0:
			error_detail += ": " + body.get_string_from_utf8()
		push_error("Profile sync failed: " + error_detail)
		emit_signal("profile_sync_completed", false, error_detail)
		return
	print("✅ ML-профиль синхронизирован с сервером (HTTP ", response_code, ")")
	emit_signal("profile_sync_completed", true, "ok")

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
	# В простое редактора таймер не нужен — только во время игры (F5) или после initialize из панели.
	if Engine.is_editor_hint():
		var st: SceneTree = get_tree()
		if st == null or st.current_scene == null:
			return
	if config.auto_send_interval > 0:
		send_timer = Timer.new()
		send_timer.wait_time = config.auto_send_interval
		send_timer.timeout.connect(_on_auto_send_timeout)
		send_timer.one_shot = false
		add_child(send_timer)
		send_timer.start()
		print("📊 Автоотправка каждые ", config.auto_send_interval, " сек")

func _on_auto_send_timeout():
	if event_buffer.size() > 0:
		print("Auto-send: ", event_buffer.size(), " events")
		sync_now()

func track(event_name: String, parameters: Dictionary = {}) -> bool:
	if not initialized:
		_log("Analytics не инициализирован! Вызовите initialize()", true)
		return false
	if not game_session_active:
		_log("Нет активной игровой сессии! Вызовите start_new_game()", true)
		return false
	_validate_track_parameters(parameters)

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
	_append_log_line(event)
	
	_log("Event: " + event_name + " buffer: " + str(event_buffer.size()) + "/" + str(config.buffer_size))
	emit_signal("stats_changed")

	if event_buffer.size() >= int(config.buffer_size):
		_log("Буфер заполнен, отправляем...")
		sync_now()

	return true

func set_state(key: String, value):
	current_state[key] = value
	print("📊 Состояние: ", key, " = ", value)

func sync_now() -> bool:
	if _sync_in_progress:
		_log("Отправка уже выполняется")
		return false
	if event_buffer.is_empty():
		_log("Нет событий для отправки")
		return true

	_log("Sync " + str(event_buffer.size()) + " events...")
	_inflight_events = event_buffer.duplicate(true)
	event_buffer.clear()
	_sync_in_progress = true

	if str(config.get("cloud_url", "")).strip_edges().is_empty():
		_log("cloud_url пустой — события возвращены в буфер", true)
		event_buffer = _inflight_events + event_buffer
		_inflight_events.clear()
		_sync_in_progress = false
		emit_signal("stats_changed")
		return false

	if not server_session_ready:
		_log("session_id ещё не получен, отложим отправку")
		event_buffer = _inflight_events + event_buffer
		_inflight_events.clear()
		_sync_in_progress = false
		if not _session_start_in_progress:
			_start_server_session()
		emit_signal("stats_changed")
		return false

	for event in _inflight_events:
		event["session_id"] = session_id

	if cloud_sender:
		cloud_sender.send_events(_inflight_events, _build_telemetry_metadata())
	else:
		_log("cloud_sender не создан — проверьте настройки облака", true)
		event_buffer = _inflight_events + event_buffer
		_inflight_events.clear()
		_sync_in_progress = false

	emit_signal("stats_changed")
	return true


func flush_pending_from_disk() -> int:
	var pending: Array = TelemetryPersistence.load_all_events(PENDING_PATH)
	if pending.is_empty():
		return 0
	event_buffer.append_array(pending)
	TelemetryPersistence.clear_file(PENDING_PATH)
	_log("Загружено из offline-очереди: " + str(pending.size()))
	emit_signal("stats_changed")
	if game_session_active and server_session_ready:
		sync_now()
	return pending.size()


func _restore_pending_from_disk() -> void:
	flush_pending_from_disk()


func get_pending_disk_count() -> int:
	return TelemetryPersistence.load_all_events(PENDING_PATH).size()


func check_server_health() -> void:
	if cloud_sender:
		cloud_sender.check_server_availability()


func get_track_snippet(event_name: String, sample_params: Dictionary = {}) -> String:
	var params = sample_params.duplicate(true)
	if params.is_empty():
		for cp in config.get("critical_points", []):
			if typeof(cp) == TYPE_DICTIONARY:
				var n = str(cp.get("name", "")).strip_edges()
				if not n.is_empty():
					params[n] = 0.0
	if params.is_empty():
		params = {"score": 0.0, "time_sec": 0.0}
	var parts: PackedStringArray = []
	for key in params:
		var val = params[key]
		if typeof(val) == TYPE_STRING:
			parts.append('"%s": "%s"' % [key, val])
		else:
			parts.append('"%s": %s' % [key, str(val)])
	return 'Analytics.track("%s", {%s})' % [event_name, ", ".join(parts)]


func _validate_track_parameters(parameters: Dictionary) -> void:
	for cp in config.get("critical_points", []):
		if typeof(cp) != TYPE_DICTIONARY:
			continue
		var point_name = str(cp.get("name", "")).strip_edges()
		if point_name.is_empty():
			continue
		if not parameters.has(point_name):
			push_warning(
				"Analytics.track(): нет поля '%s' из critical_points — ML может не увидеть метрику"
				% point_name
			)


func _log(message: String, as_error: bool = false) -> void:
	if as_error:
		push_warning(message)
		return
	if bool(config.get("debug_verbose", false)):
		print("📊 ", message)

## Сброс буфера и локального файла логов (панель редактора). Серверную сессию не закрывает.
func reset_local_stats(clear_log_file: bool = true) -> void:
	event_buffer.clear()
	_inflight_events.clear()
	_sync_in_progress = false
	current_state.clear()
	last_adaptation = {}
	TelemetryPersistence.clear_file(PENDING_PATH)
	if clear_log_file and FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
	emit_signal("stats_changed")
	if clear_log_file:
		print("📊 Локальная статистика сброшена: буфер и файл логов")
	else:
		print("📊 Локальная статистика сброшена: буфер")


func get_stats() -> Dictionary:
	var stats = {
		"buffer_size": event_buffer.size(),
		"inflight_size": _inflight_events.size(),
		"pending_disk": get_pending_disk_count(),
		"session_id": session_id,
		"player_id": player_id,
		"mode": "cloud",
		"auto_send_interval": config.auto_send_interval,
		"state_keys": current_state.keys(),
		"last_adaptation": last_adaptation.duplicate(true),
		"sync_in_progress": _sync_in_progress,
	}
	if cloud_sender:
		stats["cloud_queue"] = cloud_sender.get_queue_size()
		stats["server_available"] = cloud_sender.server_available
	return stats

func _append_log_line(event: Dictionary) -> void:
	if FileAccess.file_exists(LOG_PATH):
		var existing = FileAccess.get_file_as_bytes(LOG_PATH)
		if existing.size() > MAX_LOG_BYTES:
			DirAccess.remove_absolute(LOG_PATH)
	var file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.close()

func _get_game_time() -> float:
	if _session_start_ticks == 0:
		return 0.0
	return (Time.get_ticks_msec() - _session_start_ticks) / 1000.0
