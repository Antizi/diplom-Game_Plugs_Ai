# Примеры интеграции (не часть аддона)

Скрипты **не входят** в `addons/analytics_plugin/`. Скопируйте нужный файл в свой проект (например `res://scripts/` или `res://autoload/`) и при необходимости измените `class_name`.

Перед использованием выполните [установку аддона](../README.md): папка `addons/analytics_plugin/`, плагин включён, URL ingest настроен.

| Файл | Назначение |
|------|------------|
| [game_manager.gd](game_manager.gd) | Шаблон менеджера: `initialize`, `start_new_game`, `end_game`, `track`, обработка адаптации |
| [adaptation_bridge.gd](adaptation_bridge.gd) | Тот же сценарий, что встроенный `AdaptationBridge` в аддоне — для справки |
| [test_integration.gd](test_integration.gd) | Smoke-тест: 12 событий, проверка cloud и адаптации (F6) |

**Встроено в аддон** (можно не копировать examples):

- `res://addons/analytics_plugin/game/game_manager.gd` — `class_name GameManager`
- `res://addons/analytics_plugin/game/adaptation_bridge.gd` — `class_name AdaptationBridge`

Контракт API: [docs/integration.md](../../docs/integration.md).  
Сквозной тест: [docs/E2E.md](../../docs/E2E.md).
