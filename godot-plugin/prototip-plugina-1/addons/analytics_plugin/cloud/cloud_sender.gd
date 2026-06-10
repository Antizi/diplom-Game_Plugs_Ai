extends Node
class_name CloudSender

signal send_successful(response)
signal send_failed(error_message)
signal server_available_changed(is_available)
signal ingest_completed(response)
signal batch_finished(success: bool, events: Array, response: Dictionary, error_message: String)

var config = {
	"cloud_url": "http://localhost:8000/telemetry/ingest",
	"api_key": "",
	"timeout": 30.0,
	"retry_count": 3,
	"retry_delay_sec": 1.0,
	"retry_on_error": true,
}

var pending_queue: Array = []
var is_sending = false
var server_available = true

var http_request: HTTPRequest = null
var _retry_timer: Timer = null
var _active_batch: Array = []
var _active_metadata: Dictionary = {}
var _last_send_metadata: Dictionary = {}
var _retry_attempt: int = 0


func _init(custom_config: Dictionary = {}) -> void:
	for key in custom_config:
		config[key] = custom_config[key]


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = float(config.get("timeout", 30.0))
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	add_child(_retry_timer)
	_retry_timer.timeout.connect(_on_retry_timeout)


func update_config(patch: Dictionary) -> void:
	for key in patch:
		config[key] = patch[key]
	if http_request:
		http_request.timeout = float(config.get("timeout", 30.0))


func send_events(events_array: Array, metadata: Dictionary = {}) -> bool:
	if events_array.is_empty():
		return false
	if is_sending:
		pending_queue.append_array(events_array)
		return true
	_active_batch = events_array.duplicate(true)
	_active_metadata = metadata.duplicate(true)
	_last_send_metadata = _active_metadata.duplicate(true)
	_retry_attempt = 0
	return _dispatch_active_batch()


func _dispatch_active_batch() -> bool:
	if _active_batch.is_empty():
		is_sending = false
		return false
	is_sending = true
	var ingest_events: Array = []
	for ev in _active_batch:
		ingest_events.append({
			"session_id": ev.get("session_id", ""),
			"player_id": ev.get("player_id", ""),
			"event_name": ev.get("event_name", "unknown_event"),
			"timestamp": ev.get("timestamp", 0),
			"game_time": ev.get("game_time", 0.0),
			"parameters": ev.get("parameters", {}),
			"state": ev.get("state", {}),
		})
	var ingest_payload = {
		"events": ingest_events,
		"metadata": _active_metadata,
	}
	var json_string = JSON.new().stringify(ingest_payload)
	var headers = ["Content-Type: application/json"]
	var api_key = str(config.get("api_key", ""))
	if not api_key.is_empty():
		headers.append("X-API-Key: " + api_key)
	if not _http_is_idle(http_request):
		_finish_batch(false, {}, "HTTP busy")
		return false
	var err = http_request.request(
		str(config.get("cloud_url", "")),
		headers,
		HTTPClient.METHOD_POST,
		json_string
	)
	if err != OK:
		_finish_batch(false, {}, "HTTP request error: " + str(err))
		return false
	return true


func _on_request_completed(result, response_code, _headers, body) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_failure("Network error: " + str(result), response_code >= 500)
		return
	if response_code >= 200 and response_code < 300:
		var response_data: Dictionary = {}
		if body.size() > 0:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
				response_data = json.data
		_finish_batch(true, response_data, "")
		return
	_handle_failure("Server HTTP " + str(response_code), response_code >= 500)


func _handle_failure(message: String, mark_unavailable: bool) -> void:
	var retry_on = bool(config.get("retry_on_error", true))
	var max_retries = int(config.get("retry_count", 3))
	if retry_on and _retry_attempt < max_retries:
		_retry_attempt += 1
		var delay = float(config.get("retry_delay_sec", 1.0))
		_retry_timer.start(delay)
		print("🌩️ Повтор отправки ", _retry_attempt, "/", max_retries, " через ", delay, " с")
		return
	if mark_unavailable:
		server_available = false
		emit_signal("server_available_changed", false)
	_finish_batch(false, {}, message)


func _on_retry_timeout() -> void:
	_dispatch_active_batch()


func _finish_batch(success: bool, response: Dictionary, error_message: String) -> void:
	is_sending = false
	var sent_events = _active_batch.duplicate(true)
	_active_batch.clear()
	_active_metadata.clear()
	_retry_attempt = 0
	if success:
		if not server_available:
			server_available = true
			emit_signal("server_available_changed", true)
		emit_signal("ingest_completed", response)
		emit_signal("send_successful", response)
		emit_signal("batch_finished", true, sent_events, response, "")
		if not pending_queue.is_empty():
			var next_batch = pending_queue.duplicate(true)
			pending_queue.clear()
			send_events(next_batch, _last_send_metadata)
	else:
		emit_signal("send_failed", error_message)
		emit_signal("batch_finished", false, sent_events, {}, error_message)


func check_server_availability() -> void:
	var ping_request = HTTPRequest.new()
	add_child(ping_request)
	ping_request.request_completed.connect(_on_ping_completed.bind(ping_request))
	var headers: PackedStringArray = []
	var api_key = str(config.get("api_key", ""))
	if not api_key.is_empty():
		headers.append("X-API-Key: " + api_key)
	ping_request.request(_get_health_url(), headers, HTTPClient.METHOD_GET)


func _get_health_url() -> String:
	var url: String = str(config.get("cloud_url", ""))
	var scheme_idx = url.find("://")
	if scheme_idx == -1:
		return "http://localhost:8000/health"
	var host_start = scheme_idx + 3
	var path_idx = url.find("/", host_start)
	if path_idx != -1:
		return url.substr(0, path_idx) + "/health"
	return url + "/health"


func _on_ping_completed(result, response_code, _headers, _body, ping_request: HTTPRequest) -> void:
	ping_request.queue_free()
	var was_available = server_available
	server_available = (result == HTTPRequest.RESULT_SUCCESS and response_code > 0 and response_code < 500)
	if server_available != was_available:
		emit_signal("server_available_changed", server_available)


func get_queue_size() -> int:
	return pending_queue.size() + (_active_batch.size() if is_sending else 0)


func clear_queue() -> void:
	pending_queue.clear()


func _http_is_idle(req: HTTPRequest) -> bool:
	if req == null:
		return true
	return req.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED
