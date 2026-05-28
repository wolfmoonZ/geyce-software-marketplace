#!/usr/bin/env bash
# release.sh — publica una nueva versión del plugin geyce en el marketplace geyce-software.
#
# Uso:
#   ./release.sh <plugin> <nueva_version> [--no-tag] [--no-push]
#
# Ejemplo:
#   ./release.sh geyce 0.2.0
#
# Lo que hace:
#   1. Comprueba que el árbol de Git esté limpio.
#   2. Actualiza la "version" en plugins/<plugin>/.claude-plugin/plugin.json.
#   3. Actualiza la "version" del plugin correspondiente en .claude-plugin/marketplace.json.
#   4. Hace commit y crea el tag <plugin>-v<version>.
#   5. (Opcional) Hace push del commit y del tag al remoto.

set -euo pipefail

PLUGIN="${1:-}"
NEW_VERSION="${2:-}"
DO_TAG=1
DO_PUSH=1
shift 2 2>/dev/null || true
for arg in "$@"; do
  case "$arg" in
    --no-tag)  DO_TAG=0  ;;
    --no-push) DO_PUSH=0 ;;
    *) echo "Argumento desconocido: $arg" >&2; exit 2 ;;
  esac
done

if [[ -z "$PLUGIN" || -z "$NEW_VERSION" ]]; then
  echo "Uso: $0 <plugin> <nueva_version> [--no-tag] [--no-push]" >&2
  exit 2
fi

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: la versión debe ser semver MAJOR.MINOR.PATCH (recibido: $NEW_VERSION)" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_JSON="$ROOT/plugins/$PLUGIN/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "ERROR: no encuentro $PLUGIN_JSON" >&2; exit 1
fi
if [[ ! -f "$MARKETPLACE_JSON" ]]; then
  echo "ERROR: no encuentro $MARKETPLACE_JSON" >&2; exit 1
fi

if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  echo "ERROR: hay cambios sin commitear. Limpia el árbol antes de publicar." >&2
  exit 1
fi

OLD_VERSION="$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])")"
echo "→ Plugin '$PLUGIN': $OLD_VERSION → $NEW_VERSION"

python3 - "$PLUGIN_JSON" "$NEW_VERSION" <<'PY'
import json, sys
path, new_version = sys.argv[1], sys.argv[2]
with open(path) as f: data = json.load(f)
data["version"] = new_version
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

python3 - "$MARKETPLACE_JSON" "$PLUGIN" "$NEW_VERSION" <<'PY'
import json, sys
path, plugin, new_version = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f: data = json.load(f)
found = False
for p in data.get("plugins", []):
    if p.get("name") == plugin:
        p["version"] = new_version
        found = True
        break
if not found:
    raise SystemExit(f"ERROR: el plugin '{plugin}' no está listado en marketplace.json")
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

git -C "$ROOT" add "$PLUGIN_JSON" "$MARKETPLACE_JSON"
git -C "$ROOT" commit -m "release($PLUGIN): v$NEW_VERSION"

if [[ "$DO_TAG" -eq 1 ]]; then
  TAG="$PLUGIN-v$NEW_VERSION"
  git -C "$ROOT" tag -a "$TAG" -m "Release $PLUGIN v$NEW_VERSION"
  echo "→ Tag creado: $TAG"
fi

if [[ "$DO_PUSH" -eq 1 ]]; then
  git -C "$ROOT" push
  if [[ "$DO_TAG" -eq 1 ]]; then
    git -C "$ROOT" push --tags
  fi
  echo "→ Cambios subidos al remoto."
else
  echo "→ Cambios listos en local. Recuerda hacer 'git push' y 'git push --tags' cuando estés conforme."
fi

echo "✓ Plugin '$PLUGIN' publicado con versión $NEW_VERSION."
