# ABYSSAL GENESIS — технические требования

**Версия 0.1** · 27 ноября 2026

Документ описывает, **как** реализуются механики из `docs/GDD.md` и сюжет из `docs/NARRATIVE_BIBLE.md`. Этапы и приёмка — в `docs/ROADMAP.md`.

**Статус:** проект. Кода ABYSSAL GENESIS ещё нет. Всё ниже — требования к этапам 02–11.

---

## 1. Платформа и ограничения

| | |
|---|---|
| Движок | Godot 4.7.1-stable, GDScript |
| Рендер | GL Compatibility, холст 1280×720, stretch `canvas_items` |
| Цель | Windows x64 (Steam), позже Linux (Steam Deck) |
| Производительность | 60 FPS при 150 существах, 40 врагах и 60 органах на карте 64×48 клеток на среднем ПК; симуляция ≤ 4 мс на кадр |
| Детерминизм | одинаковый seed + версия генератора + одинаковые команды игрока дают одинаковый забег |

### 1.1. Соглашения кода (из CLAUDE.md, обязательны)

- `const X = preload(...)` вместо `class_name`.
- Системы не делают preload `run.gd`; `var run` без типа.
- Не использовать `:=` для значений из Dictionary.
- Все строки для игрока — через `Loc.t("English")`, русский перевод — в `tools/ru_strings.py`.
- Любое видимое событие испускает fx (`RunState.fx`).
- Данные и баланс живут в данных, а не в коде систем.

---

## 2. Архитектура

### 2.1. Ветка и сосуществование

- Новое ядро пишется в ветке `abyssal-genesis` (вариант B из аудита).
- Fallen Below остаётся рабочим до слияния: коммит `1c4cbc2`, локальный тег `fallen-below-v0.4`.
- Новые модули лежат в отдельных папках и не ломают старые сцены, пока владелец не согласует удаление (решения KEEP/ADAPT/REWRITE/DEFER из аудита, раздел 3).

### 2.2. Модули (AG-01…AG-15)

| ID | Модуль | Файлы (план) | Основа из Fallen Below |
|---|---|---|---|
| AG-01 | Run Manager | `scripts/ag/run/sprout.gd` (корень сцены, часы, ввод), `sprout_state.gd` (RefCounted) | `run.gd`, `run_state.gd` — схема «корень + состояние + системы» |
| AG-02 | Dungeon | `scripts/ag/systems/grid_system.gd`, `map_gen.gd` | генератор `_random_region` (DEFER), идеи проверок размещения |
| AG-03 | Organs | `organ_system.gd`, `channel_system.gd` | `card_system.gd` (превью, правила размещения) |
| AG-04 | Resources | `economy_system.gd` | полоса ресурсов HUD |
| AG-05 | Creatures | `creature_system.gd`, `creature_ai.gd` (FSM), `AStarGrid2D` | `warden_system.gd` → Нулевой |
| AG-06 | Breeding | `breeding_system.gd` | — |
| AG-07 | Evolution | `evolution_system.gd`, `threat_log.gd` | — |
| AG-08 | Combat | `combat_rules.gd` (чистые функции), `command_system.gd` | `combat_system.gd`, статусы, `fire_system.gd` |
| AG-09 | Enemy AI | `invasion_system.gd`, `enemy_ai.gd` | `hero_system.gd` (отряды, прогноз → Сенсор) |
| AG-10 | Boss | `boss_system.gd` + фазы в данных | `hero_system.boss_tick` |
| AG-11 | Narrative | `scripts/ag/narrative/story_state.gd`, `ending_evaluator.gd`, `scene_scheduler.gd` | `run.beat()`, `Meta.first_time`, `scenes/story.tscn` |
| AG-12 | Meta | `scripts/ag/meta/archive.gd` | Логово, Книга Павших |
| AG-13 | Save | `scripts/autoload/save_manager.gd` | `Meta` (сохранение) |
| AG-14 | UI/UX | `scripts/ag/ui/*` | UI-кит, подсказки, перетаскивание, пауза, иконки |
| AG-15 | Audio/Visual | `Music` (состояния), `Sfx`, `art.gd` | всё переиспользуется |

### 2.3. Потоки данных

- **Состояние** — только в `SproutState` (забег) и `CampaignState` (кампания). Вид и HUD читают его и вызывают методы систем.
- **Event Bus** (autoload `Bus`): типизированные сигналы `organ_damaged`, `creature_died`, `mind_released`, `invasion_started`, `boss_phase`, `decision_made`, `memory_found`. Системы подписываются; прямые ссылки между системами только через `run`.
- **fx**: остаётся сигнал `fx(kind, target, amount)` → Sfx + визуальные эффекты.
- **Время:** фиксированный тик симуляции 10 Гц; отрисовка интерполирует. Пауза (`time_stopped()`) останавливает тик, команды и строительство работают.

### 2.4. Реестр определений

- Все определения (органы, виды, мутации, фракции, враги, боссы, события, сцены, решения) хранятся как данные с **постоянным строковым ID** (`organ.stomach`, `species.bone_crawler`, `decision.Z1`).
- ID никогда не переиспользуется; переименование ID — только с записью в таблицу миграции сохранений.
- **Определение** (неизменяемое) и **экземпляр** (изменяемое состояние в забеге) разделены.
- Проверка реестра при запуске в debug: дубликаты ID, битые ссылки, пустые `Loc`-ключи.

### 2.5. Случайность

- Один `RandomNumberGenerator` на поток: `map`, `combat`, `ai`, `events`, `breeding`.
- Seed и состояние каждого потока сохраняются в SproutState (сохранение посреди забега восстанавливает тот же будущий результат).
- Запрещено: `randi()`/`randf()` глобально в системах ABYSSAL GENESIS.

---

## 3. Контракты данных (игровые)

Поля — минимальный набор для среза. Типы — GDScript.

**OrganDefinition**: `id`, `category`, `footprint: Array[Vector2i]`, `cost: Dictionary`, `max_hp`, `upkeep: Dictionary`, `needs_channel: bool`, `passive: StringName`, `active: StringName`, `mutation_slots: int`, `resist: Dictionary`, `weak: Dictionary`, `name`, `desc`.

**OrganInstance**: `uid`, `def_id`, `cell`, `hp`, `state` (Normal/Active/Damaged/Critical/Disabled/Recovering/Destroyed), `mutations: Array[StringName]`, `connected: bool`, `cooldowns`.

**Cell**: `surface`, `walkable`, `occupant_uid`, `organ_uid`, `damage`, `tissue` (tissue/bone/water/ash/crystal), `channel: bool`.

**SpeciesDefinition**: `id`, `role`, `base_stats`, `traits`, `breeding` (тип, время, стоимость), `diet`, `name`, `desc`.

**CreatureInstance**: `uid`, `species_id`, `stats`, `genome: GeneticProfile`, `state` (FSM), `target`, `path`, `statuses`.

**GeneticProfile**: `traits: Array[StringName]`, `mutations`, `defects`, `generation: int`, `parents: Array[int]`.

**MutationDefinition**: `id`, `targets` (organ/species/both), `slot_cost`, `cost`, `effect`, `drawback`, `requires`, `excludes`.

**InheritanceRule**: `required`, `dominant`, `incompatible`, `rare_combo → result`. Правила детерминированы: при одинаковых родителях и одном потоке RNG результат одинаков. Найденный результат записывается в Архив как рецепт.

**ThreatRecord**: `kind` (fire/poison/physical/holy/swarm), `amount`, `source_faction`, `time`. Evolution читает скользящее окно и предлагает адаптации с полями `reason`, `bonus`, `drawback`, `cost`.

**EnemyDefinition / Squad**: `faction`, `goal` (heart/organ/sample/scout), `stats`, `abilities`, `counters` (что выжигает или крадёт), `knows_hidden: bool`.

**BossDefinition**: `phases: Array` — каждая фаза: `hp_threshold`, `abilities`, `telegraph_time`, `line_id`.

**EventDefinition**: `id`, `conditions`, `weight`, `cooldown`, `choices: Array` (`text`, `cost`, `effects`, `flags`).

**CombatRules** — чистые функции без состояния:
```
damage(attacker, defender, kind) -> {amount, crit, blocked, reason}
apply_status(target, status, stacks)
```
`reason` — строка для боевого журнала: «освящённый клинок × уязвимость к свету».

---

## 4. Сюжетные контракты (NARR-01…NARR-08)

Правила — `docs/NARRATIVE_BIBLE.md`, разделы 11, 14, 15. Эталон логики — `tools/narrative_check.py`: код обязан давать те же результаты.

### NARR-01. StoryState (в CampaignState)

```
act: int (0 = пролог … 5)
rooted: Array[StringName]          # укоренённые биомы
decisions: Dictionary              # "Z1" -> "let_speak", ...
flags: Dictionary                  # одноразовые события, найденные улики
names_found: Array[StringName]     # линия «Двенадцать» (12)
notes_found: int                   # 7 нот
endings_seen: Array[StringName]
canon_ending: StringName           # первая концовка профиля
echo_depth_max: int
```
Решение записывается один раз. Повтор (Echoes «Перед решением») пишет в копию StoryState эха, а не в канон.

### NARR-02. RelationshipState

Состояния **вычисляются** из `decisions` и склонностей, а не хранятся отдельно (нет рассинхрона):
- `aurelia_state()`, `zero_state()`, `zero_form()`, `voss_state()`, `archon_exposed()` — один в один с `narrative_check.py`.
- Склонности: `H` (доля сохранённых сознаний за кампанию → low/mid/high), `ZF` (доля отданных Нулевому → starved/balanced/gorged). Пороги — в данных; при изменении обновить скрипт.

### NARR-03. SceneScheduler

- Очередь сцен с приоритетом: `mandatory` (обязательная при укоренении) > `decision` > `optional`.
- Не больше **2 крупных сцен за росток**. Обязательная сцена укоренения проигрывается всегда, даже если лимит исчерпан (она последняя в ростке).
- Мелкие реплики (шёпоты, записки, барки) лимитом не ограничены, но не чаще одной в 20 секунд игры.
- Сцена не начинается во время боя с боссом и при атаке на Сердце; ждёт затишья (сцена ставит паузу).
- Сцены «пока ты спал» показываются между ростками и не входят в лимит.

### NARR-04. EndingEvaluator

```
available_endings(story) -> Array[{id, variant}]
locked_hints(story) -> Array[{id, hint_key}]   # сюжетная подсказка, не цифры
```
Инварианты (проверяются unit-тестом на тех же наборах, что и скрипт):
- «Идеальный организм» и «Последнее человечество» доступны всегда;
- всегда ≥ 2 концовок;
- «Колыбельная» доступна тогда и только тогда, когда Аурелия жива;
- «Второе сердце» недоступно при Сопернике.

Скрытый эпилог: `names_found.size() == 12 and notes_found == 7 and flags.voss_omega`.

### NARR-05. Память персонажей о поступках

`deeds: Dictionary` — `character_id -> Array[{deed_id, act, sprout}]`. Реплики выбирают вариант по наличию `deed_id`. В Архиве показываются последние 3. Поступки только добавляются (журнал).

### NARR-06. MemoryRecord (Архив Памяти)

```
id, source (human/voss/ren/root), date, version: int,
conflicts_with: Array[StringName], chosen: bool,
unlock_flags, text_key
```
Конфликт: две записи с общим `conflict_id`; выбор игрока пишет `decisions["mem.<conflict_id>"]` и может быть пересмотрен при новой улике (`version` растёт).

### NARR-07. Тексты и озвучка

- Строки сцен — `Loc`-ключи; длинные сцены лежат в `data/story/*.json` (сцена → массив реплик `{speaker, text_key, voice_id?, choice?}`).
- `voice_id` у озвучиваемых реплик (40–60 шт.). Нет файла — показываются субтитры с «тембром» (короткий звук без слов).
- Громкость голоса — отдельный ползунок.

### NARR-08. Атмосфера меню и Архива

`menu_stage()` = функция от `act`, `zero_state`, `canon_ending` и эпилога → идентификатор сцены фона (`Narrative Bible 20.1`). Фон — расширение `backdrop.gd` слоями; музыка выбирается по тому же стейджу.

### 4.1. Echoes of Genesis

- `EchoModifiers`: список искажений по глубине 1–10, каждое — данные (`id`, `effect`, `reward`).
- Эхо-забег использует копию StoryState; канон не меняется, Книга исходов отмечает увиденное.

---

## 5. Сохранения (AG-13)

| Файл | Содержимое | Когда пишется |
|---|---|---|
| `user://campaign.json` | CampaignState: Архив, открытия, StoryState, deeds, статистика | после ростка, после сцены с решением |
| `user://sprout.json` | SproutState целиком: карта, органы, существа, враги, RNG, таймеры, очередь сцен. Внутри JSON-обёртки — точная двоичная копия (`format: variant64`): обычный JSON теряет последние знаки дробных чисел, и загруженный бой расходился бы с исходным | автосейв каждые 60 с, при выходе, по кнопке |
| `user://settings.cfg` | громкости, клавиши, масштаб UI, язык | при изменении |

- **Атомарная запись:** пишем в `*.tmp`, проверяем чтение, затем переименование; предыдущая версия → `*.bak`.
- **Загрузка:** битый файл → `*.bak` → сообщение игроку; кампания никогда не обнуляется молча.
- **Версия схемы:** `"schema": 3`. Миграция v2 (Fallen Below Meta) → v3: переносятся настройки и статистика; открытия Fallen Below становятся флагом «ветеран» (одна сцена-отсылка), а не прогрессом новой игры.
- **Ironman-правило:** сохранение посреди забега удаляется при загрузке и записывается снова при выходе (без сейв-скама).
- Проверки: юнит-тест «сохранить → загрузить → сравнить хеш состояния»; тест битого файла.

---

## 6. Интерфейс и управление

- Ввод через `InputMap` с переназначением (сохраняется в `settings.cfg`).
- Масштаб UI 80–150%.
- Подсказки на всех элементах (`UI.hover_tip`). Перетаскивание и пауза-планирование — из Fallen Below.
- Панели GDD раздела 15; каждая — отдельная сцена, читает только состояние.
- Доступность: шрифт не меньше 14 px при 100%, цвет не единственный носитель смысла (значки + текст), отключаемая тряска экрана и вспышки.

---

## 7. Аудио и визуал

- `Music`: состояния `grow / explore / invasion / boss / story / menu_<stage>`; переходы по фразам; лейтмотив и колыбельная — `tools/music_gen.py`.
- `Sfx`: лимит одновременных повторов одного звука (4), отдельная шина «окружение».
- Арт: `art.gd` — `res://art/<id>.png`, иначе рисовка кодом. ID ассетов совпадают с ID определений.

---

## 8. Тестирование

| Тип | Что | Инструмент |
|---|---|---|
| Unit | CombatRules, наследование, экономика (прогноз = факт), EndingEvaluator (паритет с `narrative_check.py`), SceneScheduler (лимит 2), сохранения | лёгкий раннер `tests/ag/unit_runner.tscn` (этап 02) |
| Детерминизм | один seed → один хеш карты и одного боя | unit |
| Бот | автоигра ростка: без зависаний, 1 000 стычек, статистика побед | `tests/ag/bot.tscn` (наследник `tests/bot.tscn`) |
| UI | клики, перетаскивание, пауза, Esc | наследник `tests/ui_test.tscn` |
| Скриншоты | xvfb-run, как в CLAUDE.md | существующие харнессы |
| Сюжет | `python3 tools/narrative_check.py` → RESULT: OK | Python |
| Плейтест | критерий среза (GDD 14) | люди |

Правило брифа: пункт не отмечается DONE без проверки.

---

## 9. Сборка

- Пресет «Windows Desktop», встроенный pck, `icon.ico`; включать `*.json` как не-ресурсные файлы (локаль, сюжетные данные).
- Шаблоны экспорта 4.7.1.stable.
- Steam (этап 14): Steamworks через GDExtension, достижения, облачные сохранения (`campaign.json`, `settings.cfg`).
