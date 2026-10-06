#!/usr/bin/env bash
# Ставит Godot 4.7.2 в облачной сессии Claude Code (вызывается SessionStart-хуком).
# Локально ничего не делает — там используйте свой Godot.
set -euo pipefail
if [[ "${CLAUDE_CODE_REMOTE:-}" != "true" ]] && [[ "${1:-}" != "--force" ]]; then
  exit 0
fi
VERSION="4.7.2-stable"
BIN="/opt/godot/Godot_v${VERSION}_linux.x86_64"
if [[ ! -x "$BIN" ]]; then
  mkdir -p /opt/godot
  curl -sSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -o -q /tmp/godot.zip -d /opt/godot
  rm -f /tmp/godot.zip
fi
ln -sf "$BIN" /usr/local/bin/godot
# Первичный импорт, чтобы скрипты с class_name были известны движку.
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  godot --headless --path "$CLAUDE_PROJECT_DIR" --import >/dev/null 2>&1 || true
fi
echo "Godot: $(godot --version)"
