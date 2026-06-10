@tool
extends EditorPlugin

var main_panel_instance = null

func _enter_tree():
	print("✅ Analytics Plugin загружен!")
	
	# Добавляем Analytics как автозагружаемый синглтон
	_add_autoload()
	
	# Создаем и добавляем главную панель
	_add_main_panel()

func _exit_tree():
	print("❌ Analytics Plugin выгружен!")
	_remove_main_panel()

func _add_autoload():
	var script_path = "res://addons/analytics_plugin/core/analytics.gd"
	if not ProjectSettings.has_setting("autoload/Analytics"):
		add_autoload_singleton("Analytics", script_path)
		print("📌 Analytics autoload добавлен в project.godot")
	else:
		print("📌 Analytics autoload уже есть в project.godot")


func get_analytics_node() -> Node:
	var base: Control = get_editor_interface().get_base_control()
	if base == null:
		return null
	var tree: SceneTree = base.get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("Analytics")

func _add_main_panel():
	# Загружаем сцену панели
	var panel_scene = preload("res://addons/analytics_plugin/ui/main_panel.tscn")
	main_panel_instance = panel_scene.instantiate()
	main_panel_instance.set_meta("editor_plugin", self)
	main_panel_instance.set_meta("get_analytics", Callable(self, "get_analytics_node"))
	main_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	add_control_to_bottom_panel(main_panel_instance, "Analytics")
	print("📌 Панель Analytics добавлена в редактор")

func _remove_main_panel():
	if main_panel_instance:
		remove_control_from_bottom_panel(main_panel_instance)
		main_panel_instance.queue_free()
		print("📌 Панель Analytics удалена из редактора")
