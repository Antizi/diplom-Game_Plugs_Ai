# Analytics Plugin (Godot 4)

Распространяется **только папка аддона** — без `project.godot` и без `.godot/`.

## Установка в проект разработчика

1. Скопируйте каталог `addons/analytics_plugin/` в `ваш_проект/addons/analytics_plugin/`.
2. Godot → **Project → Project Settings → Plugins** → включите **Analytics Plugin**.
3. Плагин сам добавит autoload `Analytics` (`res://addons/analytics_plugin/core/analytics.gd`).
4. Панель **Analytics** внизу редактора → **Настроить облачный режим**:
   - URL ingest: `http://localhost:8000/telemetry/ingest`
   - Сохранить (конфиг: `user://analytics_config.json`).

Стек API: из корня репозитория `docker compose up --build -d`.

## Минимальный код в игре

```gdscript
func _ready() -> void:
    Analytics.initialize()

func _on_new_game_pressed() -> void:
    Analytics.start_new_game("1.0.0")

func _on_level_done() -> void:
    Analytics.track("level_complete", {"time_sec": 120.0, "deaths": 2})

func _on_quit_to_menu() -> void:
    Analytics.end_game()
```

Шаблон менеджера: [examples/game_manager.gd](examples/game_manager.gd).

## Структура аддона

```text
addons/analytics_plugin/
├── plugin.cfg
├── plugin.gd              # EditorPlugin, autoload, панель
├── core/analytics.gd      # Autoload API
├── cloud/cloud_sender.gd  # HTTP → backend
└── ui/                    # Панель редактора + настройки cloud
```

## Что ещё доработать (плагин)

| Задача | Статус |
|--------|--------|
| Синхронизация ML-профиля → `PUT /game/profile` при сохранении в редакторе | ✅ |
| Локальный режим: буфер SQLite + offline ONNX | не сделано |
| Очередь повторной отправки при сетевых ошибках | частично |
| Применение `adaptation.parameters` в игре | ✅ пример в `examples/game_manager.gd` |
| Экспорт/импорт профиля в репозиторий (опционально `*.json.example`) | опционально |

## Тестирование без своей игры

1. Создайте пустой Godot 4 проект локально (`.godot` не коммитится).
2. Скопируйте `addons/analytics_plugin/`.
3. Включите плагин, настройте URL, повесьте [examples/test_integration.gd](examples/test_integration.gd) на Node в сцене.
