#!/usr/bin/env bash
# Полная проверка проекта: импорт, загрузка всех ресурсов, автопрохождение пролога.
#   tools/check.sh                 — без графики (headless)
#   tools/check.sh --screenshots   — с рендером через xvfb и снимками в docs/screenshots/
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

echo "== Импорт ресурсов"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== Headless-запуск (godot --headless --path . --quit)"
out="$("$GODOT" --headless --path . --quit 2>&1)"
echo "$out" | grep -E "ERROR|SCRIPT ERROR|WARNING" && { echo "Есть ошибки/предупреждения"; exit 1; } || echo "OK"

echo "== Загрузка всех скриптов, сцен и ресурсов"
"$GODOT" --headless --path . -s res://tools/ci/check_all.gd

echo "== Автопрохождение пролога"
log="$(mktemp)"
if [[ "${1:-}" == "--screenshots" ]]; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --audio-driver Dummy \
    --path . -s res://tools/ci/playthrough.gd -- --screenshots 2>&1 | tee "$log"
else
  "$GODOT" --headless --path . -s res://tools/ci/playthrough.gd 2>&1 | tee "$log"
fi
status=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$log"; then
  echo "Во время прохождения были ошибки скриптов"; status=1
fi
rm -f "$log"
exit "$status"
