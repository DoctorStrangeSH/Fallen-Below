# Fallen Below

*Loop Hero in reverse: build the dungeon, kill the heroes, raise them as your army. Only the dead remember who they were.*

Roguelite с непрямым управлением на **Godot 4.7**. Полный дизайн: [docs/GDD.md](docs/GDD.md).

## Как запустить

1. Скачай Godot 4.7: https://godotengine.org/download (обычная версия, не .NET).
2. Запусти Godot → **Import** → выбери `project.godot` из этой папки.
3. Нажми **F5** (Run Project).

## Как играть (прототип M0)

- Герои входят через **GATE** и идут по кольцу. Каждый полный круг означает, что они крадут золото из твоего **Сердца**.
- Нажми карту внизу, потом клетку:
  - **Crypt / Spider Nest / Spikes** кладутся на тропу.
  - **Dark Altar** кладётся рядом с тропой.
  - **Soul Jar** срабатывает сразу.
- Когда герой погибает, ты выбираешь: **Raise** (поднять как нежить на этом тайле), **Absorb** (эссенция) или **Interrogate** (карты).
- Нежить бьёт свою бывшую пати ×1.5, но может её **предать**. Друзья поднятого становятся мстителями (**!**).
- Сбежавшие герои возвращаются как **немезиды** (красная обводка).
- Шкала **Threat** на 100% призывает босса. Убей его, чтобы победить.
- ПКМ отменяет выбор карты.

## Меню и Логово

- Игра стартует с главного меню: **New Run**, **The Lair**, **Quit**.
- В конце забега ты получаешь **Bones** (дни × 3 + убийства, +25 за победу).
- В **Логове** Bones тратятся на постройки: больше HP Сердца, стартовые склянки, карты, эссенция и открытие карты Graveyard.
- Прогресс сохраняется в `user://save.json`. На Windows это `%APPDATA%\Godot\app_userdata\Fallen Below\`.

## Структура

```
docs/GDD.md                  дизайн-документ
scenes/                      main_menu, lair, run
scripts/autoload/meta.gd     мета-прогресс и сохранения (autoload "Meta")
scripts/data/game_data.gd    все данные и баланс: карты, герои, черты, постройки
scripts/run/run.gd           корень забега: часы, ввод, связывает системы
scripts/run/run_state.gd     состояние забега + запросы
scripts/run/run_view.gd      отрисовка карты (пока примитивы)
scripts/run/run_hud.gd       интерфейс забега
scripts/systems/             hero / combat / card / soul системы
scripts/menu/                главное меню и Логово
scripts/ui/ui_style.gd       общие стили UI
```

Баланс правится в одном месте: `scripts/data/game_data.gd`.
