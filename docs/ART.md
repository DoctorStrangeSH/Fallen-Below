# Fallen Below — Арт

## Как это работает

Игра сама ищет картинки в папке `art/`. Положи туда PNG с нужным именем (например `art/traveler_hunter.png`), открой проект в Godot, и спрайт появится в игре. Если картинки нет, рисуется примитив. Можно добавлять по одной, ничего не ломается.

- Формат: **PNG с прозрачным фоном**.
- Размер: **32×32** (игра растянет без размытия: в проекте стоит фильтр Nearest). Сердце, Стражи, боссы и мини-боссы можно делать **48×48** или **64×64**.
- Вид: сверху под небольшим углом (3/4), как в Loop Hero.

## Стиль

- **Тёмное фэнтези, пиксель-арт, ограниченная палитра** (около 32 цветов, например *Resurrect 64* или *Sweetie 16* как основа).
- **Подземелье холодное:** фиолетовый, сине-зелёный, костяной, тёмный камень.
- **Путники тёплые и яркие:** золото, охра, белый, красный. С первого взгляда видно, кто чужой.
- **Нежить** = спрайт путника, перекрашенный в холодную палитру, со светящимися голубыми глазами.
- Без сглаживания, контур в 1 пиксель тёмного цвета (не чёрного).

## Как генерировать

1. **Nano Banana / Midjourney** для концепта и стиля: сначала сделай 3–4 референса и выбери один стиль.
2. **Pixelab** для спрайтов: загрузи выбранный референс как стиль и генерируй по списку ниже с одним и тем же шаблоном.
3. **Aseprite** для чистки: убрать мусорные пиксели, выровнять палитру, проверить прозрачность.

### Шаблон промпта (добавлять к каждому)
```
pixel art, 32x32 sprite, top-down 3/4 view, dark fantasy dungeon, limited palette,
crisp pixels, no anti-aliasing, 1px dark outline, transparent background, single object, centered
```

## Список спрайтов

### Тайлы (32×32)
| Файл | Промпт |
|---|---|
| `tile_floor.png` | dark cracked stone dungeon floor tile, subtle purple moss, seamless |
| `tile_path.png` | worn stone corridor floor tile, lighter path, seamless |
| `tile_side.png` | narrow dark side passage floor tile, cobwebs, seamless |
| `tile_gate.png` | heavy wooden door in rock with stairs going up, warm light leaking through |
| `heart.png` (64×64) | living pulsing dark red heart of stone and flesh, veins spreading, glowing |

### Карты (тайл на карте и иконка карты, 32×32)
| Файл | Промпт |
|---|---|
| `card_crypt.png` | small crypt with open stone coffins, skeleton hand reaching out |
| `card_spider.png` | spider nest, thick webs, egg sacs |
| `card_queen.png` | giant spider queen lair, huge web, glowing green eggs |
| `card_spikes.png` | floor spike trap, rusty iron spikes with blood |
| `card_grinder.png` | meat grinder trap, rotating bloody blades |
| `card_chest.png` | cursed treasure chest, gold glow, faint purple runes |
| `card_mimic.png` | mimic chest with teeth and tongue, gold coins |
| `card_altar.png` | dark altar with candles and purple flame |
| `card_spire.png` | tall unholy spire of black stone, magenta glow |
| `card_graveyard.png` | small graveyard with crooked tombstones, mist |
| `card_catacomb.png` | catacomb walls with skull niches |
| `card_necropolis.png` | necropolis gate with bone arch, green glow |
| `card_jar.png` | glass soul jar with a swirling blue soul inside |

### Монстры подземелья (32×32)
| Файл | Промпт |
|---|---|
| `monster_skeleton.png` | skeleton warrior with rusty sword |
| `monster_spider.png` | giant black spider, red eyes |
| `monster_queen.png` (48×48) | spider queen, bloated abdomen, crown of chitin |
| `monster_golem.png` (48×48) | bone golem made of many skeletons, glowing green core |
| `monster_mimic.png` | mimic chest monster, open jaws, tongue |

### Путники (тёплая палитра, 32×32)
| Файл | Промпт |
|---|---|
| `traveler_seeker.png` | treasure hunter with lantern and backpack, gold coins, leather hood |
| `traveler_hunter.png` | monster hunter in armor with greatsword, scars |
| `traveler_pilgrim.png` | pilgrim in white robes with holy candle and staff |
| `traveler_mage.png` | arcanist scholar in blue robes with glowing tome |
| `boss_aurelia.png` (48×48) | radiant female paladin saint, golden armor, halo of light, white cape |

### Нежить (холодная палитра, светящиеся голубые глаза, 32×32)
| Файл | Промпт |
|---|---|
| `undead_seeker.png` | shade of a treasure hunter, translucent, blue glowing eyes |
| `undead_hunter.png` | death knight, corroded armor, blue glowing eyes |
| `undead_pilgrim.png` | hollow saint, torn white robes, blue flame candle |
| `undead_mage.png` | lich scholar, skeletal, blue glowing tome |

### Стражи (48×48 или 64×64)
| Файл | Промпт |
|---|---|
| `warden_bone.png` (Марроугрейв) | hulking monster made of fused bones, hollow chest with faint blue light, glowing cyan eyes |
| `warden_brood.png` (Веш'ка) | broodmother, huge spider-woman hybrid, egg sacs, green glow |
| `warden_mimic.png` (Златозуб) | mimic king, giant living treasure chest with crown, teeth, gold spilling |
| `warden_saint.png` (Сестра Эшен) | hollow saint, tall undead nun with candle halo, empty eyes glowing white |

## Порядок

1. Сначала **4 путника + Костяной Страж + tile_path + tile_floor**. Уже с ними игра будет выглядеть совсем иначе, и можно делать первые гифки.
2. Потом карты (13).
3. Потом монстры, нежить, остальные Стражи, босс.

## Следующие шаги по арту (после спрайтов)
- Анимации: 2–4 кадра ходьбы и атаки.
- Иконки вещей по типам.
- Рамки интерфейса в стиле «живого подземелья»: кость, вены, камень.
