#!/bin/sh
set -eu
cd "$(dirname "$0")"
SKYWARD_GODOT="${SKYWARD_GODOT:-}"
if [ -z "$SKYWARD_GODOT" ]; then
  for candidate in godot godot4 /Applications/Godot.app/Contents/MacOS/Godot; do
    if command -v "$candidate" >/dev/null 2>&1; then
      SKYWARD_GODOT="$(command -v "$candidate")"
      break
    fi
  done
fi
if [ -z "$SKYWARD_GODOT" ] || ! command -v "$SKYWARD_GODOT" >/dev/null 2>&1; then
  echo 'Install Godot 4.7.2, add godot to PATH, or set SKYWARD_GODOT to its executable.' >&2
  echo 'You can also import project.godot from the Godot Project Manager.' >&2
  exit 1
fi
if [ ! -d .godot/imported ]; then
  "$SKYWARD_GODOT" --headless --editor --path . --import
fi
exec "$SKYWARD_GODOT" --path . "$@"
