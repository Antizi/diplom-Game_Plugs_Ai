@tool
extends Window

signal name_saved(event_name)
signal dialog_cancelled

@onready var name_input: LineEdit = $MainMargin/MainVBox/NameInput
@onready var save_btn: Button = $MainMargin/MainVBox/ButtonsHBox/SaveBtn
@onready var cancel_btn: Button = $MainMargin/MainVBox/ButtonsHBox/CancelBtn

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_bind_signals()

func _bind_signals() -> void:
	if not save_btn.pressed.is_connected(_on_save_pressed):
		save_btn.pressed.connect(_on_save_pressed)
	if not cancel_btn.pressed.is_connected(_on_cancel_pressed):
		cancel_btn.pressed.connect(_on_cancel_pressed)
	if not close_requested.is_connected(_on_cancel_pressed):
		close_requested.connect(_on_cancel_pressed)

func open_for_edit(current_name: String) -> void:
	_bind_signals()
	title = "Редактирование события"
	name_input.text = current_name
	popup_centered()
	name_input.grab_focus()

func _on_save_pressed() -> void:
	var event_name = name_input.text.strip_edges()
	if event_name.is_empty():
		push_warning("Укажите название события")
		return
	emit_signal("name_saved", event_name)
	hide()

func _on_cancel_pressed() -> void:
	emit_signal("dialog_cancelled")
	hide()
