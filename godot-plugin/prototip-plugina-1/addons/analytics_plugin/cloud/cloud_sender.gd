extends Node
class_name CloudSender

# Сигналы для оповещения о результатах
signal send_successful(count)
signal send_failed(error_message)
signal server_available_changed(is_available)

# Настройки
var config = {
	"cloud_url": "http://localhost:8000/analytics",
	"api_key": "",
	"timeout": 5,
	"retry_count": 3
}

# Очередь событий для повторной отправки
var pending_queue = []
var is_sending = false
var server_available = true

# HTTP клиент
var http_request = null

func _init(custom_config = {}):
	# Обновляем конфиг переданными значениями
	for key in custom_config:
		if key in config:
			config[key] = custom_config[key]
	
	# Создаем HTTP клиент
	http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Подключаем сигналы
	http_request.request_completed.connect(_on_request_completed)

func send_events(events_array, metadata := {}):
	"""Отправка массива событий на сервер"""
	if events_array.is_empty():
		return false
	
	if not server_available:
		print("🌩️ Сервер недоступен, сохраняем в очередь:", events_array.size(), "событий")
		pending_queue.append_array(events_array)
		emit_signal("send_failed", "Сервер недоступен")
		return false
	
	# Если уже отправляем, добавляем в очередь
	if is_sending:
		print("🌩️ Отправка уже выполняется, добавляем в очередь:", events_array.size(), "событий")
		pending_queue.append_array(events_array)
		return true
	
	# Backend ожидает TelemetryIngestIn на POST /telemetry/ingest:
	# { events: [ {session_id, player_id, event_name, timestamp, game_time, parameters, state} ],
	#   metadata: { critical_points?, archetypes?, model_mode?, feature_schema_version? } }
	var ingest_events: Array = []
	for ev in events_array:
		ingest_events.append({
			"session_id": ev.get("session_id", ""),
			"player_id": ev.get("player_id", ""),
			"event_name": ev.get("event_name", "unknown_event"),
			"timestamp": ev.get("timestamp", 0),
			"game_time": ev.get("game_time", 0.0),
			"parameters": ev.get("parameters", {}),
			"state": ev.get("state", {})
		})

	var ingest_payload = {
		"events": ingest_events,
		"metadata": metadata
	}

	var json_string = JSON.new().stringify(ingest_payload)
	
	# Создаем заголовки
	var headers = ["Content-Type: application/json"]
	if config.api_key:
		headers.append("X-API-Key: " + config.api_key)
	
	print("🌩️ Отправляем ", events_array.size(), " событий на ", config.cloud_url)
	
	# Отправляем запрос
	is_sending = true
	var error = http_request.request(config.cloud_url, headers, HTTPClient.METHOD_POST, json_string)
	
	if error != OK:
		print("❌ Ошибка HTTP запроса:", error)
		is_sending = false
		emit_signal("send_failed", "Ошибка HTTP запроса")
		return false
	
	return true

func _on_request_completed(result, response_code, headers, body):
	is_sending = false
	
	# Проверяем результат
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_network_error("Сетевая ошибка: " + str(result))
		return
	
	# Проверяем код ответа
	if response_code >= 200 and response_code < 300:
		_handle_success(response_code, body)
	else:
		_handle_server_error(response_code, body)

func _handle_success(response_code, body):
	print("✅ Успешно отправлено на сервер! Код:", response_code)
	
	# Если сервер был недоступен, теперь он доступен
	if not server_available:
		server_available = true
		emit_signal("server_available_changed", true)
	
	# Отправляем сигнал об успехе
	emit_signal("send_successful", "отправлено")
	
	# Проверяем, есть ли ещё события в очереди
	if not pending_queue.is_empty():
		print("🌩️ Отправляем оставшиеся из очереди:", pending_queue.size(), "событий")
		var to_send = pending_queue.duplicate()
		pending_queue.clear()
		send_events(to_send)

func _handle_network_error(message):
	print("❌ Сетевая ошибка:", message)
	server_available = false
	emit_signal("server_available_changed", false)
	emit_signal("send_failed", message)
	
	# Сохраняем отправляемые события в очередь для повтора
	# (в реальном коде нужно сохранять именно те события, которые не отправились)

func _handle_server_error(response_code, body):
	var error_message = "Сервер вернул ошибку " + str(response_code)
	print("❌ ", error_message)
	
	# Пытаемся прочитать тело ответа
	if body.size() > 0:
		var body_string = body.get_string_from_utf8()
		print("Тело ответа:", body_string)
	
	# 5xx ошибки - сервер временно недоступен
	if response_code >= 500:
		server_available = false
		emit_signal("server_available_changed", false)
	
	emit_signal("send_failed", error_message)

func check_server_availability():
	"""Проверка доступности сервера (ping)"""
	var ping_request = HTTPRequest.new()
	add_child(ping_request)
	ping_request.request_completed.connect(_on_ping_completed.bind(ping_request))
	
	var headers = []
	if config.api_key:
		headers.append("X-API-Key: " + config.api_key)
	
	# /telemetry/ingest — POST endpoint, поэтому проверяем базовый /health
	var health_url = _get_health_url()
	ping_request.request(health_url, headers, HTTPClient.METHOD_GET)

func _get_health_url() -> String:
	var url: String = str(config.cloud_url)
	var scheme_idx := url.find("://")
	if scheme_idx == -1:
		return "/health"
	var host_start := scheme_idx + 3
	var path_idx := url.find("/", host_start)
	var origin := url if path_idx == -1 else url.substr(0, path_idx)
	return origin + "/health"

func _on_ping_completed(result, response_code, headers, body, ping_request):
	ping_request.queue_free()
	
	var was_available = server_available
	server_available = (result == HTTPRequest.RESULT_SUCCESS and response_code < 500)
	
	if server_available != was_available:
		emit_signal("server_available_changed", server_available)
		print("🌩️ Доступность сервера изменилась:", server_available)

func get_queue_size():
	"""Размер очереди на отправку"""
	return pending_queue.size()

func clear_queue():
	"""Очистить очередь"""
	pending_queue.clear()
	print("🌩️ Очередь очищена")
