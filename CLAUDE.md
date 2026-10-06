# Пепел и кровь — инструкции для Claude

Godot 4.x (проект на 4.7.2), GDScript 2.0 (НЕ Godot 3 синтаксис). Статическая типизация обязательна:
в `project.godot` предупреждение `untyped_declaration` поднято до ошибки — нетипизированный код не скомпилируется.

Бинарник: `godot` (в облаке: `/usr/local/bin/godot` → `/opt/godot/Godot_v4.7.2-stable_linux.x86_64`,
ставится `tools/setup_godot.sh`; в облачных сессиях это делает SessionStart-хук из `.claude/settings.json`).
Локально — путь к своему Godot 4.7+.

Проверка ошибок: `godot --headless --path . --quit`
Полная проверка: `tools/check.sh` — импорт, загрузка всех скриптов/сцен/ресурсов и автопрохождение пролога ботом.
Скриншоты: `tools/check.sh --screenshots` (нужен xvfb), результат в `docs/screenshots/`.

## Структура
scenes/    — сцены (.tscn), собираю сам в редакторе
scripts/   — скрипты
resources/ — данные (.tres), кастомные Resource (классы — в `resources/types/`)
autoload/  — только GameState, AudioManager, EventBus
assets/    — графика, звук, шрифты (генерируются `tools/assets/*.py`, руками не правим)
tools/     — пайплайн ассетов (Python), проверки и бот-прохождение (`tools/ci/`)
docs/      — сюжет (`story.md`), формат диалогов (`dialogue_format.md`), скриншоты

## Правила
- Связь между объектами через сигналы (EventBus), без длинных путей get_node: только `$Child` / `%Unique` внутри своей сцены
- Числа баланса в Resource (`resources/balance/*.tres`) или `@export`, не хардкод
- .tscn редактировать только если я попросил
- После изменений запускай headless-проверку; если трогал сюжет, диалоги или квесты — ещё и `tools/check.sh`

## Как устроено
- Прогресс — флаги, счётчики, инвентарь и задания в `GameState`. Условия — строки:
  `flag`, `!flag`, `item:coin>=3`, `quest:id` (активно), `done:id` (выполнено), `counter:rats_killed>=4`,
  `chapter:2`, `chapter>=2`, `time:night` (см. `GameState.check`).
- Диалоги — `resources/dialogues/*.tres` (`DialogueData.script_text`, формат — `docs/dialogue_format.md`).
  NPC берёт первый диалог из своего списка, у которого выполнены `requires`.
- Сюжетные сцены и смена глав — `scripts/main/story_director.gd`, реагирует на `!event <имя>` из диалогов.
- NPC, враги и предметы появляются по сюжету через `visible_when` (компонент `ConditionGate`).
- Новый предмет/задание/персонаж/глава: создать `.tres` и добавить в `resources/game_database.tres`.
- Персонажи LPC: рецепт в `tools/assets/build_characters.py` → `python3 tools/assets/build_characters.py <id>`.
