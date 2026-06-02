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
	
	# Убираем автозагрузку
	_remove_autoload()
	
	# Убираем панель
	_remove_main_panel()

func _add_autoload():
	var script_path = "res://addons/analytics_plugin/core/analytics.gd"
	add_autoload_singleton("Analytics", script_path)
	print("📌 Analytics синглтон зарегистрирован")

func _remove_autoload():
	remove_autoload_singleton("Analytics")
	print("📌 Analytics синглтон удален")

func _add_main_panel():
	# Загружаем сцену панели
	var panel_scene = preload("res://addons/analytics_plugin/ui/main_panel.tscn")
	main_panel_instance = panel_scene.instantiate()
	
	# Добавляем панель в нижнюю часть редактора
	add_control_to_bottom_panel(main_panel_instance, "Analytics")
	print("📌 Панель Analytics добавлена в редактор")

func _remove_main_panel():
	if main_panel_instance:
		remove_control_from_bottom_panel(main_panel_instance)
		main_panel_instance.queue_free()
		print("📌 Панель Analytics удалена из редактора")
