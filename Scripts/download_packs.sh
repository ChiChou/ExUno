#!/bin/sh
# Install the prebuilt language packs from the repository's "packs" release
# instead of building them locally:  sh Scripts/download_packs.sh
set -eu
cd "$(dirname "$0")/.."
REPO=${EXUNO_REPO:-ChiChou/ExUno}
BASE="https://github.com/$REPO/releases/download/packs"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL -o "$TMP/exuno-packs.zip" "$BASE/exuno-packs.zip"
curl -fsSL -o "$TMP/exuno-packs.zip.sha256" "$BASE/exuno-packs.zip.sha256"
expected=$(cut -d' ' -f1 "$TMP/exuno-packs.zip.sha256")
actual=$(shasum -a 256 "$TMP/exuno-packs.zip" 2>/dev/null || sha256sum "$TMP/exuno-packs.zip")
actual=$(echo "$actual" | cut -d' ' -f1)
[ "$expected" = "$actual" ] || { echo "checksum mismatch" >&2; exit 1; }

unzip -q "$TMP/exuno-packs.zip" -d "$TMP"
for file in pt.json grammar-pt.json verbs-pt.json es-419.json grammar-es-419.json pt-BR.json grammar-pt-BR.json; do
    [ -f "$TMP/exuno-packs/$file" ] || {
        echo "The packs release predates the regional language packs. Run sh Scripts/prepare_data.sh or use an updated packs release." >&2
        exit 1
    }
done
mkdir -p ExUno/Resources/Packs
cp "$TMP"/exuno-packs/*.json ExUno/Resources/Packs/
${PYTHON:-python3} Scripts/apply_pack_metadata.py
echo "Installed packs (CC BY-SA 4.0, see ATTRIBUTIONS.md) into ExUno/Resources/Packs."
