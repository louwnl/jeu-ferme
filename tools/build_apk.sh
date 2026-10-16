#!/usr/bin/env bash
# Fabrique l'APK signé à partir de la version écrite dans project.godot.
# Usage : GODOT=/chemin/godot SIGNER=/chemin/uber-apk-signer.jar tools/build_apk.sh
# Le numéro de version Android (version/code) est calculé à partir de la version :
# 0.3.2 donne 302, pour que chaque version installe par-dessus la précédente.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?indique le chemin de Godot 4.3 dans GODOT}"
: "${SIGNER:?indique le chemin de uber-apk-signer.jar dans SIGNER}"

VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
IFS=. read -r MAJOR MINOR PATCH <<< "$VERSION"
CODE=$((MAJOR * 10000 + MINOR * 100 + PATCH))
sed -i "s/^version\/code=.*/version\/code=$CODE/; s/^version\/name=.*/version\/name=\"$VERSION\"/" export_presets.cfg

rm -rf build && mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Android" build/non-signe.apk
# Toujours la même clé de test (celle intégrée à uber-apk-signer), pour que
# chaque nouvelle version puisse s'installer par-dessus l'ancienne.
java -jar "$SIGNER" -a build/non-signe.apk -o build/signe
mv build/signe/*-aligned-debugSigned.apk "build/ferme-refuge-$VERSION.apk"
echo "build/ferme-refuge-$VERSION.apk"
