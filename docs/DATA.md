# Language data

The app bundles one JSON pack per language in `ExUno/Resources/Packs/`, plus a grammar course per language (`grammar-<code>.json`, see [`GRAMMAR.md`](GRAMMAR.md)). The packs are generated from openly licensed public sources and are not committed. There are two ways to get them.

## Option A: download the prebuilt packs

```sh
sh Scripts/download_packs.sh
```

This fetches `exuno-packs.zip` from the repository's [`packs` release](https://github.com/ChiChou/ExUno/releases/tag/packs), checks its SHA-256, and copies the packs into place. The `Language packs` GitHub workflow (`.github/workflows/packs.yml`) rebuilds that release with the scripts below whenever `Scripts/` changes on `main`, or when you run it by hand. The zip includes `ATTRIBUTIONS.md` and `LICENSES/`, as the upstream licenses require.

## Option B: build them yourself

```sh
sh Scripts/prepare_data.sh
```

This needs Python 3.9 or later (standard library only) and access to `raw.githubusercontent.com` and `github.com`. It downloads about 160 MB into `.cache/` (15 MB for the vocabulary, the rest for the grammar courses' UniMorph paradigms and Tatoeba sentences) and writes seven packs, seven grammar courses and Portuguese verb tables (70–80 kB each):

| Pack | Entries | Size |
| --- | --- | --- |
| `it.json` | 16,887 | 3.1 MB |
| `es.json` | 16,392 | 3.0 MB |
| `fr.json` | 17,578 | 3.3 MB |
| `la.json` | 997 | 0.1 MB |
| `pt.json` (European Portuguese) | 8,470 | 1.5 MB |
| `es-419.json` (broad Latin American Spanish) | 16,392 | 3.0 MB |
| `pt-BR.json` (Brazilian Portuguese) | 15,250 | 2.8 MB |

Run it again any time; verified downloads are reused. Delete `.cache/` to start from scratch.

### 1. Fetch: `Scripts/fetch_sources.py`

Reads `Scripts/sources.json`. Every source has a URL pinned to a commit or release, a SHA-256 checksum, and its license. Files are saved to `.cache/sources/<id>/`. A file whose checksum differs is deleted and the run fails, so a changed upstream file can't slip into a pack unnoticed.

| id | What | License |
| --- | --- | --- |
| `decks-italian`, `decks-spanish`, `decks-french`, `decks-portuguese` | Language-Learning-decks lists | MIT; wordfreq data CC BY-SA 4.0 |
| `dcc-latin` | DCC Latin Core Vocabulary, CSV copy | CC BY-SA |
| `omw-it` | Open Multilingual Wordnet 2.0, Italian (MultiWordNet) | CC BY 3.0 |
| `omw-en` | Open Multilingual Wordnet 2.0, English (Princeton WordNet 3.0) | WordNet 3.0 license |
| `tatoeba-it`, `-es`, `-fr`, `-la`, `-pt` | Tatoeba English sentence pairs, OPUS release v2026-07-08 (grammar courses) | CC BY 2.0 FR |
| `unimorph-ita`, `-spa`, `-fra`, `-lat`, `-por` | UniMorph paradigms (grammar courses) | CC BY-SA 3.0 |

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
| Portuguese | The upstream shared-plus-European list, kept in its pinned order for stable ids. Article and gender only when an overt determiner appears before the noun in the source example. Topics projected through English gloss and part of speech. |
| Latin | Lemma and principal parts split from the headword, gender from *m./f./n.*, four levels by frequency rank (I: 1–250 … IV: 751–1000), and 13 topic groups. |

Every pack carries `"license": "CC BY-SA 4.0"` and an `"attribution"` string, so the notice travels with the file.

`Scripts/pack_metadata.json` supplies authored per-pack settings. Its ordered `marketUnits` list controls the Market unit wheel: shared metric units, Italian `etto`, and French `dl`. `build_packs.py` embeds this metadata, and `download_packs.sh` applies it to prebuilt packs through `apply_pack_metadata.py`. No runtime download is involved. The language engines still own pronunciation and grammatical forms; shared code handles exact decimal scaling. Older packs without this optional field keep the legacy g/ml choices; unknown future unit IDs are ignored.

### 4. Grammar courses: `Scripts/build_grammar.py`

Reads the unit files in `Scripts/grammar/<code>.json` (notes, tables and which word forms compete in each unit, written for Ex Uno), the vocabulary packs from step 3, UniMorph and Tatoeba. Each unit gets up to 40 fill-in-the-blank items from real sentences, with English translations and wrong options from the same paradigm. The method, the filters and the format are described in [`GRAMMAR.md`](GRAMMAR.md).

## Pack format (schema 2)

```json
{
  "code": "it", "schema": 2, "license": "CC BY-SA 4.0", "attribution": "…",
  "levels": ["A1", "A2", "B1", "B2", "C1", "C2"], "defaultLevels": ["A1", "A2"],
  "marketUnits": ["g", "etto", "kg", "ml", "cl", "l"],
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

## Adding a language

1. Add the deck to `sources.json`. Language-Learning-decks has `portuguese/brazilian_portuguese` and `portuguese/european_portuguese`, both MIT.
2. Add a `decks(...)` call, topic names, and reviewed article/gender handling to `build_packs.py`; add authored metadata to `pack_metadata.json`.
3. Add a `LanguageCode` and a `LanguageEngine` (numbers, time, dates, conjugator) under `Shared/Language/`.

## Portuguese details

The first pack is European Portuguese (`pt`, speech locale `pt-PT`). The pinned upstream file combines 8,129 shared and 341 European entries; upstream translations and examples are machine-generated and can contain regional inconsistencies or errors. It is not a Brazilian course. Market units are authored in pack metadata (`g`, `kg`, `ml`, `cl`, `dl`, `l`).

`build_portuguese_verbs.py` bundles 3,999 complete verb paradigms in `verbs-pt.json` from pinned UniMorph `por`, with six finite tenses. Incomplete tenses are omitted; unknown verbs return no conjugation rather than a guessed form. `portuguese_overrides.json` corrects malformed core cells in the source and is applied to both verb tables and grammar generation. Corrections were checked against [Infopédia estar](https://www.infopedia.pt/dicionarios/verbos-portugueses/estar), [ir](https://www.infopedia.pt/dicionarios/verbos-portugueses/ir), and [haver](https://www.infopedia.pt/dicionarios/verbos-portugueses/haver). The dictionary is a verification reference, not a scraped data source.

The Portuguese grammar course uses the same pinned OPUS Tatoeba release as other courses. Tatoeba does not label each sentence by Portuguese variety. Generation excludes common distinctly Brazilian vocabulary and `estar` + gerund examples; this is a practical filter, not a guarantee that every sentence is exclusively European. Article/contraction gaps require a following known noun or adjective and exclude hyphenated clitics. Conjuntivo examples require `que` or `talvez`.

## Regional packs and stable progress

The original ids `es` and `pt` retain their Spain and European behavior, files and daily-challenge seed positions. New ids `es-419` and `pt-BR` are appended to `LanguageCode`; they keep separate progress files and speech preferences. The Latin American Spanish vocabulary retains base Spanish entry ids, with reviewed noun/example overrides in `regional_overrides.json`. It uses broadly shared vocabulary and tú/usted/ustedes rather than country slang or a claim to cover every local voseo paradigm. Its default `es-MX` speech voice is identified in Settings; users may choose another installed Spanish voice. Brazilian Portuguese uses its own pinned shared-plus-Brazilian list and `pt-BR` voice.

Grammar specs use `corpus` to reuse pinned es/pt sentence pairs and `personIndices` to select regional agreement forms, including clitics and option tables. Brazilian first-person-plural past -ámos is adapted to -amos. Verb reference tables and exercises apply the same person mappings. The shared Tatoeba corpus is not certified by region. Prices deliberately remain euro lessons in every edition; a language variety does not select a local currency.
