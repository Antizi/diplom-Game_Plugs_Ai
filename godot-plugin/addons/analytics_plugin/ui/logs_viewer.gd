@tool
extends Window

const LOG_PATH = "user://analytics_logs.jsonl"
const AnalyticsResolver = preload("res://addons/analytics_plugin/editor/analytics_resolver.gd")

@onready var logs_text: TextEdit = $MainMargin/MainVBox/LogsText
@onready var refresh_btn: Button = $MainMargin/MainVBox/ButtonsHBox/RefreshBtn
@onready var close_btn: Button = $MainMargin/MainVBox/ButtonsHBox/CloseBtn

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_bind_signals()

func _bind_signals() -> void:
	if not refresh_btn.pressed.is_connected(_on_refresh_pressed):
		refresh_btn.pressed.connect(_on_refresh_pressed)
	if not close_btn.pressed.is_connected(_on_close_pressed):
		close_btn.pressed.connect(_on_close_pressed)
	if not close_requested.is_connected(_on_close_pressed):
		close_requested.connect(_on_close_pressed)

func open_viewer() -> void:
	if not is_node_ready():
		await ready
	_bind_signals()
	_ensure_editor_popup_parent()
	refresh_logs()
	show()
	popup_centered(Vector2i(640, 420))


func _ensure_editor_popup_parent() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.root
	if root and get_parent() != root:
		reparent(root)

func _on_refresh_pressed() -> void:
	refresh_logs()

func _on_close_pressed() -> void:
	hide()

func refresh_logs() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Буфер Analytics (текущая сессия) ===")
	lines.append("")

	var analytics = _get_analytics()
	if analytics:
		var buffer: Array = analytics.event_buffer
		if buffer.is_empty():
			lines.append("(пусто)")
		else:
			for i in range(buffer.size()):
				lines.append("[%d] %s" % [i + 1, JSON.stringify(buffer[i], "\t")])
	else:
		lines.append("Autoload Analytics не найден")

	lines.append("")
	lines.append("=== Файл логов (%s) ===" % LOG_PATH)
	lines.append("")

	if FileAccess.file_exists(LOG_PATH):
		var file = FileAccess.open(LOG_PATH, FileAccess.READ)
		if file:
			var tail = file.get_as_text()
			file.close()
			if tail.strip_edges().is_empty():
				lines.append("(пусто)")
			else:
				lines.append(tail.strip_edges())
	else:
		lines.append("(файл ещё не создан)")

	var text_edit: TextEdit = logs_text if logs_text else get_node_or_null("MainMargin/MainVBox/LogsText") as TextEdit
	if text_edit:
		text_edit.text = "\n".join(lines)

func _get_analytics() -> Node:
	return AnalyticsResolver.resolve(self)
