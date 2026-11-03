#!/bin/sh
# Download, verify and build every language pack:  sh Scripts/prepare_data.sh
# Extra arguments go to fetch_sources.py (see its --help).
set -eu
cd "$(dirname "$0")/.."
PY=${PYTHON:-python3}
CACHE=.cache/sources

"$PY" Scripts/fetch_sources.py "$@"
"$PY" Scripts/build_topics.py "$CACHE/decks-italian/italian.json" "$CACHE/omw-it/omw-it/omw-it.xml" "$CACHE/omw-en/omw-en/omw-en.xml" .cache/topics-it.json
"$PY" Scripts/build_packs.py
"$PY" Scripts/build_portuguese_verbs.py
"$PY" Scripts/build_grammar.py
echo "Packs and grammar courses written to ExUno/Resources/Packs. Build the app in Xcode."
