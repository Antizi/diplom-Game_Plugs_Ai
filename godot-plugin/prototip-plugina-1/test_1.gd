extends Node

func _ready():
	print("🧪 Тестовый скрипт запущен")
	
	# Проверяем, доступен ли Analytics
	if Analytics:
		print("✅ Analytics найден!")
		
		# Настройка плагина (один раз на приложение)
		Analytics.initialize()
		# Старт новой игры — TODO: перенести в GameManager / «Новая игра»
		Analytics.start_new_game("test_1.0")
		
		# Отправляем тестовое событие
		Analytics.track("test_event", {"message": "hello"})
		
		# Устанавливаем состояние
		Analytics.set_state("test_mode", true)
		
		# Проверяем статистику
		print(Analytics.get_stats())
	else:
		print("❌ Analytics НЕ найден!")
