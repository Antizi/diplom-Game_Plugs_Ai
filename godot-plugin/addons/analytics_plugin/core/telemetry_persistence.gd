extends RefCounted
class_name TelemetryPersistence
## JSONL-очередь событий на диске (offline / сбой сети).

static func append_events(path: String, events: Array) -> void:
	if events.is_empty():
		return
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать очередь: " + path)
		return
	file.seek_end()
	for ev in events:
		if typeof(ev) == TYPE_DICTIONARY:
			file.store_line(JSON.stringify(ev))
	file.close()


static func load_all_events(path: String) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(path):
		return result
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json = JSON.new()
		if json.parse(line) == OK and typeof(json.data) == TYPE_DICTIONARY:
			result.append(json.data)
	file.close()
	return result


static func clear_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
