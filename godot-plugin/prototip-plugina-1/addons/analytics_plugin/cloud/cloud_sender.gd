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

func send_events(events_array):
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
	
	# Формируем данные для отправки
	var data_to_send = {
		"events": events_array,
		"api_key": config.api_key,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Конвертируем в JSON
	var json_string = JSON.new().stringify(data_to_send)
	
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
	
	# Отправляем GET запрос на проверку
	ping_request.request(config.cloud_url, headers, HTTPClient.METHOD_GET)

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
