# Analytics Plugin (Godot 4)

Плагин телеметрии и адаптивного геймплея для Godot 4. В игровой проект переносится **только папка аддона** — без `project.godot`, без `.godot/`, без `prototip-plugina-1/`.

**Требования:** Godot **4.2+** (рекомендуется 4.3), для cloud-режима — запущенный backend ([docker compose](../docker-compose.yml) из корня репозитория).

---

## Что копировать в новый проект

| Копировать | Не копировать |
|------------|----------------|
| `godot-plugin/addons/analytics_plugin/` целиком | `godot-plugin/prototip-plugina-1/` (локальный демо-проект) |
| По желанию: `godot-plugin/examples/*.gd` в **свои** скрипты | `godot-plugin/.godot/`, чужой `project.godot` |

Целевая структура в **вашем** проекте:

```text
ваш_проект/
├── project.godot
├── addons/
│   └── analytics_plugin/          ← сюда
│       ├── plugin.cfg
│       ├── plugin.gd
│       ├── core/
│       ├── cloud/
│       ├── editor/
│       ├── game/
│       └── ui/
└── scenes/ ...                    ← ваша игра
```

### Windows (PowerShell)

```powershell
# из корня репозитория DiplicsTM
$Src = "godot-plugin\addons\analytics_plugin"
$Dst = "C:\path\to\your_game\addons\analytics_plugin"

New-Item -ItemType Directory -Force -Path (Split-Path $Dst)
Copy-Item -Path $Src -Destination $Dst -Recurse -Force
```

### Linux / macOS

```bash
cp -r godot-plugin/addons/analytics_plugin /path/to/your_game/addons/
```

После копирования откройте **ваш** `project.godot` в Godot — редактор сам пересоздаст `.uid` для скриптов при первом импорте.

---

## Установка по шагам

### 1. Включить плагин

1. **Project → Project Settings → Plugins**
2. Найдите **Analytics Plugin** → переключатель **Enable**
3. Внизу редактора появится вкладка **Analytics**

Плагин **сам** добавит autoload `Analytics` → `res://addons/analytics_plugin/core/analytics.gd` в `project.godot`.  
Ручной дублирующий autoload не нужен. Если `Analytics` уже был в проекте — плагин его не перезапишет.

### 2. Поднять backend (для облачного режима)

Из корня репозитория:

```powershell
docker compose up --build -d
```

Проверка: http://localhost:8000/docs и `GET http://localhost:8000/health`.

### 3. Настроить облако в редакторе

1. Вкладка **Analytics** → **Настроить облачный режим**
2. **URL ingest:** `http://localhost:8000/telemetry/ingest`
3. При необходимости: размер буфера, интервал автоотправки, retry, кэш при offline
4. **Сохранить**

Настройки пишутся в `user://analytics_config.json` (на диске Godot, не в репозитории игры).

### 4. ML-профиль (для адаптации)

На вкладке **Analytics → Профиль**:

1. Добавьте **события** (имена для `Analytics.track(...)`)
2. **Критические точки** — поля метрик, например `time_sec`, `hints_used`, `deaths`, `score`
3. **Архетипы** — например `explorer`, `achiever`, `socializer`, `killer`
4. **Сохранить ML профиль** — локально `user://ml_profile.json` и синхронизация `PUT /game/profile` на сервер

Сквозной тест цепочки: [docs/E2E.md](../docs/E2E.md).

### 5. Код в игре

Минимальная интеграция — в любом узле или autoload:

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

Имена событий и поля `track()` должны совпадать с тем, что задано в панели **Профиль**.

---

## Варианты интеграции в игру

### A. Минимум (только `Analytics`)

Вызовы `initialize` / `start_new_game` / `track` / `end_game` из своего менеджера. Адаптацию обрабатывайте через сигнал:

```gdscript
func _ready() -> void:
    Analytics.initialize()
    Analytics.adaptation_received.connect(_on_adaptation)

func _on_adaptation(adaptation: Dictionary) -> void:
    var p = adaptation.get("parameters", {})
    # применить difficulty, enemy_density, loot_multiplier к геймплею
```

### B. Autoload `GameManager` (шаблон)

В аддоне уже есть `res://addons/analytics_plugin/game/game_manager.gd` с `class_name GameManager`.

1. **Project → Project Settings → Autoload**
2. Добавьте путь `res://addons/analytics_plugin/game/game_manager.gd`, имя **GameManager**
3. Вызывайте `GameManager.start_new_game()`, `GameManager.track_event(...)`

Альтернатива: скопируйте логику в свой скрипт из [examples/game_manager.gd](examples/game_manager.gd) (без конфликта имён).

> **Конфликт имён:** если в проекте уже есть `class_name GameManager`, не включайте autoload из аддона — используйте свой класс или переименуйте копию шаблона.

### C. Узел `AdaptationBridge` в сцене

1. Добавьте **Node** на корень игровой сцены
2. Прикрепите скрипт `res://addons/analytics_plugin/game/adaptation_bridge.gd`
3. В инспекторе доступны `@export`: `difficulty`, `enemy_density`, `loot_multiplier` — обновляются при ответе ML

Пример кода: [examples/adaptation_bridge.gd](examples/adaptation_bridge.gd).

### D. Быстрая проверка без своей игры

1. Скопируйте [examples/test_integration.gd](examples/test_integration.gd) в проект (например `res://tests/test_integration.gd`)
2. Повесьте на **Node** в любой сцене
3. Запустите сцену (F6): 12 событий `puzzle_completed`, ожидается `adaptation applied` в Output

Или откройте демо в репозитории: `godot-plugin/prototip-plugina-1/` (только для разработки плагина, в чужую игру не копировать).

---

## Файлы, которые создаёт плагин (runtime)

Все пути `user://` — в папке данных Godot для **вашего** проекта (Windows: `%APPDATA%\Godot\app_userdata\<имя_проекта>\`).

| Файл | Назначение |
|------|------------|
| `user://analytics_config.json` | URL ingest, буфер, retry, offline |
| `user://ml_profile.json` | События, critical points, архетипы |
| `user://player_id.txt` | Стабильный player_id |
| `user://analytics_logs.jsonl` | Локальный лог событий |
| `user://pending_telemetry.jsonl` | Очередь при сбое сети |

В git игры обычно коммитят только `addons/analytics_plugin/`. Файлы `user://` — локальные, в репозиторий не попадают.

---

## Git в игровом проекте

Рекомендуемый `.gitignore` (если ещё нет):

```gitignore
.godot/
*.import
```

Аддон можно:

- **Submodule / копия** — папка `addons/analytics_plugin/` в репозитории игры;
- **Обновление** — заменить папку новой версией из `diplom-Game_Plugs_Ai`, перезапустить Godot, проверить Plugins.

---

## Структура аддона

```text
addons/analytics_plugin/
├── plugin.cfg / plugin.gd       # EditorPlugin, autoload, панель
├── core/
│   ├── analytics.gd             # Autoload API
│   └── telemetry_persistence.gd
├── cloud/cloud_sender.gd        # HTTP → backend
├── editor/analytics_resolver.gd # Analytics в редакторе и при F5
├── game/
│   ├── game_manager.gd          # class_name GameManager (шаблон)
│   └── adaptation_bridge.gd     # class_name AdaptationBridge
└── ui/                          # Панель Analytics, cloud, диалоги
```

---

## Частые проблемы

| Симптом | Что проверить |
|---------|----------------|
| `Analytics` не найден | Plugins → Analytics Plugin **включён**; в Autoload есть `Analytics` |
| Нет панели Analytics | Плагин enabled; перезапуск редактора |
| События не уходят на сервер | URL `http://localhost:8000/telemetry/ingest`, `docker compose ps`, кнопка «Проверить сервер» |
| Нет адаптации | ML-профиль сохранён, critical points совпадают с полями в `track()`, ML-service запущен ([E2E](../docs/E2E.md)) |
| Дубли `class_name GameManager` | Свой менеджер или autoload только из одного скрипта |
| Ошибки после копирования аддона | Удалить `.godot/` в проекте игры, открыть проект заново |

---

## API и примеры

| Документ | Содержание |
|----------|------------|
| [docs/integration.md](../docs/integration.md) | HTTP, JSON ingest, сессии |
| [docs/E2E.md](../docs/E2E.md) | Сквозной тест Godot → API → ML |
| [examples/README.md](examples/README.md) | Скрипты-примеры вне аддона |

## Статус фич плагина

| Задача | Статус |
|--------|--------|
| Синхронизация ML-профиля → `PUT /game/profile` | ✅ |
| Буфер + offline JSONL при ошибке сети | ✅ |
| Retry / cache_when_offline | ✅ |
| События в профиле + snippet `track()` | ✅ |
| Проверка сервера + блок адаптации в панели | ✅ |
| `AdaptationBridge` | ✅ |
| Локальный режим: SQLite + offline ONNX | не сделано |
