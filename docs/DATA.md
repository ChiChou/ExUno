# Language data

The app bundles one JSON pack per language in `ExUno/Resources/Packs/`. The packs are generated from openly licensed public sources and are not committed. There are two ways to get them.

## Option A: download the prebuilt packs

```sh
sh Scripts/download_packs.sh
```

This fetches `exuno-packs.zip` from the repository's [`packs` release](https://github.com/ChiChou/ExUno/releases/tag/packs), checks its SHA-256, and copies the packs into place. The `Language packs` GitHub workflow (`.github/workflows/packs.yml`) rebuilds that release with the scripts below whenever `Scripts/` changes on `main`, or when you run it by hand. The zip includes `ATTRIBUTIONS.md` and `LICENSES/`, as the upstream licenses require.

## Option B: build them yourself

```sh
sh Scripts/prepare_data.sh
```

This needs Python 3.9 or later (standard library only) and access to `raw.githubusercontent.com` and `github.com`. It downloads about 15 MB into `.cache/` and writes four packs:

| Pack | Entries | Size |
| --- | --- | --- |
| `it.json` | 16,887 | 3.1 MB |
| `es.json` | 16,392 | 3.0 MB |
| `fr.json` | 17,578 | 3.3 MB |
| `la.json` | 997 | 0.1 MB |

Run it again any time; verified downloads are reused. Delete `.cache/` to start from scratch.

### 1. Fetch: `Scripts/fetch_sources.py`

Reads `Scripts/sources.json`. Every source has a URL pinned to a commit or release, a SHA-256 checksum, and its license. Files are saved to `.cache/sources/<id>/`. A file whose checksum differs is deleted and the run fails, so a changed upstream file can't slip into a pack unnoticed.

| id | What | License |
| --- | --- | --- |
| `decks-italian`, `decks-spanish`, `decks-french` | Language-Learning-decks lists | MIT; wordfreq data CC BY-SA 4.0 |
| `dcc-latin` | DCC Latin Core Vocabulary, CSV copy | CC BY-SA |
| `omw-it` | Open Multilingual Wordnet 2.0, Italian (MultiWordNet) | CC BY 3.0 |
| `omw-en` | Open Multilingual Wordnet 2.0, English (Princeton WordNet 3.0) | WordNet 3.0 license |

Options:

- `--only <id>` fetches one source.
- `--force` downloads again.
- `--local <id>=<path>` uses a file you already have.

### 2. Topics: `Scripts/build_topics.py`

Tags Italian words with 17 learner topics (Animals, Food & Drink, Transport and so on). The script looks up each word in MultiWordNet by lemma and part of speech. It keeps only the senses whose English synonyms match the word's translation, and maps those synsets to topics through WordNet lexicographer files and a few hyponym subtrees. 4,234 Italian words get a topic.

### 3. Packs: `Scripts/build_packs.py`

| Language | What the script derives |
| --- | --- |
| Italian | Gender only when the deck's example shows a determiner before the noun, then the article from gender and spelling (*il, lo, la, l'*). Topics from step 2. |
| Spanish | Gender and article only when the deck's example shows a determiner before the noun. Topics projected from Italian through the same English gloss and part of speech. |
| French | Article and gender from `article_with_word`; for *l'*, gender from *un/une* in the example. Topics as for Spanish. |
| Latin | Lemma and principal parts split from the headword, gender from *m./f./n.*, four levels by frequency rank (I: 1–250 … IV: 751–1000), and 13 topic groups. |

Every pack carries `"license": "CC BY-SA 4.0"` and an `"attribution"` string, so the notice travels with the file.

## Pack format (schema 2)

```json
{
  "code": "it", "schema": 2, "license": "CC BY-SA 4.0", "attribution": "…",
  "levels": ["A1", "A2", "B1", "B2", "C1", "C2"], "defaultLevels": ["A1", "A2"],
  "topics": [{"id": "food-drink", "name": "Cibo e bevande", "icon": "fork.knife"}],
  "entries": [{"i": 19, "w": "anno", "t": "year", "l": "A1", "p": "noun", "x": "Buon anno!", "e": "Happy New Year!", "z": 6.18, "c": ["time"]}]
}
```

| Key | Meaning |
| --- | --- |
| `i` | stable id within the pack (progress is keyed on it) |
| `w`, `t` | word, English translation |
| `l`, `p` | level, part of speech |
| `x`, `e` | example sentence and its translation (empty for Latin) |
| `z` | frequency on a Zipf-like scale, derived from the frequency rank |
| `g`, `a` | gender (`m`, `f`, `mf`, `n`) and display article |
| `k` | `"p"` for phrases |
| `c` | topic ids |
| `m`, `v` | Latin principal parts and verb class |

Ids come from the upstream order. When you bump a source, check that ids stay stable, or users' progress will point at other words.

## Updating a source

1. Change the commit in the source's URL in `Scripts/sources.json`.
2. Run `python3 Scripts/fetch_sources.py --only <id> --force`. It fails and prints the new checksum.
3. Review the upstream diff and its license, paste the new `sha256`, and run `prepare_data.sh`.
4. Update `ATTRIBUTIONS.md` if anything about the source changed.

## Adding a language (Portuguese next)

1. Add the deck to `sources.json`. Language-Learning-decks has `portuguese/brazilian_portuguese` and `portuguese/european_portuguese`, both MIT.
2. Add a `decks(...)` call and topic names to `build_packs.py`.
3. Add a `LanguageCode` and a `LanguageEngine` (numbers, time, dates, conjugator) under `Shared/Language/`.
