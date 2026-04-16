extends Node

func _ready():
	print("🧪 Тестовый скрипт запущен")
	
	# Проверяем, доступен ли Analytics
	if Analytics:
		print("✅ Analytics найден!")
		
		# Инициализируем
		Analytics.initialize()
		
		# Отправляем тестовое событие
		Analytics.track("test_event", {"message": "hello"})
		
		# Устанавливаем состояние
		Analytics.set_state("test_mode", true)
		
		# Проверяем статистику
		print(Analytics.get_stats())
	else:
		print("❌ Analytics НЕ найден!")
