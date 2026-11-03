# Grammar courses

This page records whether Ex Uno could add interactive grammar courses for Italian, Spanish, French and Latin using only openly licensed material, what was chosen, and how it is built. Like `docs/LICENSING.md`, it is an engineering review, not legal advice. Licenses were checked on the sources' own pages or repository files in November 2026.

## Decision

| Language | Call | Course | Why |
| --- | --- | --- | --- |
| Italian | **Go** | 11 units, A1–B1, 440 items | 541k Tatoeba pairs; UniMorph covers most verbs; the core irregulars UniMorph lacks are written into the unit files. |
| Spanish | **Go** | 11 units, A1–B1, 440 items | 229k Tatoeba pairs; the best UniMorph coverage of the four. |
| French | **Go** | 10 units, A1–B1, 400 items | 296k Tatoeba pairs; UniMorph lacks être, faire, prendre and a few others, which are written in. |
| Portuguese (European) | **Go** | 11 units, A1–B1, 436 items | Shared Portuguese Tatoeba corpus with regional filters; UniMorph por and reviewed core corrections, shared with the offline verb reference. |
| Latin | **Go** | 11 units, levels I–III, 440 items | 28.6k Tatoeba pairs; UniMorph covers 94% of the DCC core nouns. Verb forms come from the same rules as `LatinConjugator`, not UniMorph, which has only 9% of the core verbs. |

All five use the same pipeline. What made it viable is the split between two kinds of content. **Explanations** (unit notes, tables, the level each topic sits at) are written for Ex Uno, because no openly licensed grammar inventory exists. **Exercises** come from open data: real sentences with English translations, and the competing forms (*ho / sono / hai…*, *rosa / rosam / rosae…*) from open paradigms.

## Source survey

### Structured data

| Source | License | What it gives | Coverage | Extraction | Verdict |
| --- | --- | --- | --- | --- | --- |
| **Tatoeba** via **OPUS** (`OPUS-Tatoeba/v2026-07-08`, Moses format) | CC BY 2.0 FR (Tatoeba contributors) | Aligned sentence pairs with English | en–it 541k, en–fr 296k, en–es 229k, en–la 28.6k | Easy: two line-aligned text files in a 1–7 MB zip, at a dated URL that never changes | **Used** for every item |
| Tatoeba's own exports (`downloads.tatoeba.org/exports`) | CC BY 2.0 FR (some CC0) | The same sentences, with ids and authors | All languages | Easy, but the files are replaced weekly, so they can't be pinned by SHA-256 | Not used; OPUS's dated release is the pinnable copy |
| **UniMorph** `ita`, `spa`, `fra`, `lat` (GitHub, pinned commits) | CC BY-SA 3.0 (from English Wiktionary) | `lemma ⇥ form ⇥ features` paradigms | Of the top 300 deck verbs: it 76%, es 88%, fr 84%, la 9%. Latin nouns 94%. Italian and French have no nouns or adjectives. | Easy TSV, 13–50 MB per language | **Used** for Romance verbs and Latin nouns; gaps filled by hand-written paradigms |
| Wiktionary via kaikki.org (wiktextract) | CC BY-SA 4.0 + GFDL | Complete inflection tables | Complete | JSONL, about 780 MB for Italian alone; rebuilt weekly, no dated archive | Not used: can't be pinned. Revisit if a dated mirror appears. |
| Universal Dependencies treebanks | Per treebank (below) | Sentences with lemma, features and syntax | Mostly news, Wikipedia and legal text; no English translations except PUD | Easy (CoNLL-U, GitHub releases) | Not used for v1: wrong register for learners, and the main Italian and Latin treebanks are NC |
| UD licenses, it | ISDT and VIT CC BY-NC-SA 3.0; ParTUT and PoSTWITA CC BY-NC-SA 4.0 (rejected). PUD CC BY-SA 3.0; TWITTIRO, Valico, ParlaMint and Old CC BY-SA 4.0; MarkIT CC BY 4.0 (usable). | | | | |
| UD licenses, es | AnCora CC BY 4.0; GSD, COSER CC BY-SA 4.0; PUD CC BY-SA 3.0 (all usable) | | | | |
| UD licenses, fr | GSD, Rhapsodie, ParisStories, ALTS CC BY-SA 4.0; PUD CC BY-SA 3.0 (usable); Sequoia, FQB LGPL-LR (data license, avoid); ParTUT CC BY-NC-SA 4.0 (rejected) | | | | |
| UD licenses, la | PROIEL, ITTB, UDante CC BY-NC-SA 3.0; Perseus CC BY-NC-SA 2.5 (rejected). LLCT, CIRCSE CC BY-SA 4.0 (usable, but medieval charters and Seneca) | | | | |

### Curricula, inventories and textbooks

Each license below was read on the resource's own page (license badge, footer or title-page verso).

| Source | License | Verdict |
| --- | --- | --- |
| CEFR and Companion Volume (Council of Europe) | "All rights reserved"; site reuse limited to non-commercial use connected with the CoE's work | Rejected. Ex Uno assigns its own A1–B1 levels. |
| Instituto Cervantes *Plan curricular* (Spanish A1–C2 inventory) | "Reservados todos los derechos" | Rejected, although it is the best-structured inventory |
| *Profilo della lingua italiana*, Beacco *Référentiels* (French) | Commercial books | Rejected |
| British Council/EAQUALS Core Inventory (English) | Copyright, no license | Rejected (used only as an idea of what an inventory looks like) |
| en.wikibooks Spanish, French, Latin, Italian | CC BY-SA 4.0 (+ GFDL) | Usable, but prose in wikitext with custom templates; Italian is 25% complete. Candidate for longer notes later. |
| Tex's French Grammar (UT Austin) | CC BY 4.0 | Usable; about 130 chapters with exercises |
| Français interactif, original site | CC BY 3.0. **The newer Pressbooks edition is CC BY-NC-SA 4.0.** | Original usable; Pressbooks edition rejected |
| Trayectos, Hecho en Texas (Spanish) | CC BY-SA 4.0 | Usable |
| Semillas, ¡Chévere! (Spanish), FREN 101 (French) | CC BY 4.0 | Usable |
| Spanish Grammar in Context (COERLL), Acceso (KU) | CC BY-NC-SA 4.0, CC BY-NC 4.0 | Rejected (NC) |
| Italian open textbooks (Spunti, D'accordo, Piacere!, and others) | All CC BY-NC or BY-NC-SA | Rejected (NC). Only Wikibooks and L-Pack are open for Italian. |
| L-Pack *Italiano per migranti A2*, L-Pack Spanish A2 | CC BY-SA 3.0 | Usable, but PDF only |
| Allen & Greenough, Perseus TEI XML (`PerseusDL/canonical-pdlrefwk`) | CC BY-SA 4.0 | Usable and well structured (numbered sections, 260 tables). Best candidate for Latin reference links later. |
| Allen & Greenough, Alpheios edition | CC BY-NC-SA 3.0 | Rejected |
| D'Ooge *Latin for Beginners*, Bennett *New Latin Grammar* (Project Gutenberg) | Public domain | Usable |
| Wheelock, *Latin via Ovid*, other modern Latin textbooks | Commercial or NC | Rejected |

None of the usable textbooks are structured data. They would help with longer explanations, not with generating exercises, so v1 doesn't use them. Their paragraphs could later be adapted into notes, with attribution and the share-alike carried into the packs.

## One format or several?

**A shared core with per-language extensions.** The app sees one schema for every language:

```json
{"code": "la", "schema": 1, "license": "CC BY-SA 4.0", "attribution": "…", "levels": ["I", "II", "III"],
 "units": [{"id": "la-decl1", "level": "I", "title": "Prīma dēclīnātiō", "en": "First declension nouns", "note": "…",
            "table": {"cols": ["", "puella", "via"], "rows": [["nōm. sg.", "puella", "via"]]},
            "items": [{"x": "Hanc ___ lego.", "a": "epistulam", "o": ["epistulae", "epistulas", "epistula", "epistulam"],
                       "e": "I am reading this letter.", "h": "epistula", "g": "sg. · acc.", "k": "sg/3"}]}]}
```

| Key | Meaning |
| --- | --- |
| `x`, `a`, `o` | sentence with `___`, the answer as spelled in the sentence, options (answer included, at least three) |
| `e` | English translation |
| `h` | lemma hint, for paradigm units |
| `g`, `k` | readable label of the answer's cell, and its machine key `row/column` |

The differences between languages sit in the unit files (`Scripts/grammar/<code>.json`) and the generator, not in the app:

- **Grids.** Every unit says which forms compete for a slot. Romance verb grids are persons × tense or mood. Latin noun grids are number × case, so the case system needs no special app code.
- **Spelling key.** Tatoeba's Latin rarely marks vowel length, so Latin matches ignore macrons and fold *j* to *i*. Options follow the sentence's spelling, and labels list every cell a folded form could be (*rosa*: "sg. · nōm. / sg. · abl.").
- **Person ambiguity.** English "you" can't tell *tu / Lei / voi* (or *tú / usted*, *tu / vous*) apart, so those persons are never offered against each other when the translation says "you". For possessives the trigger is "your".
- **Language rules in the generator:**
  - French: skip forms after an elided word (*j'ai*).
  - Romance: a subjunctive answer needs a trigger before it (*che*, *que*).
  - Spanish: drop tense homographs (*estudiamos*).
  - Latin: drop 1st-person futures in *-am*, which are also present subjunctives.

A Latin-only format, with declension tables as their own item type, wasn't needed: a case is just another grid axis.

## How items are generated

`Scripts/build_grammar.py` runs after `build_packs.py`, because it reads the vocabulary packs for known words, lemma lists and Latin principal parts. For each unit it:

1. **Builds the unit's grids.** These come from one of three places:
   - closed sets in the unit file: articles, contractions, possessives, *essere/avere*, Latin pronouns and demonstratives;
   - UniMorph paradigms of the deck's verbs, plus hand-written paradigms for the irregulars UniMorph lacks;
   - for Latin verbs, a Python port of `LatinConjugator` applied to DCC principal parts.
2. **Scans every Tatoeba sentence of 3–12 words** for a word (or a two- or three-word form like *à la*, *de l'*) that is a cell of exactly one grid.
3. **Applies filters:**
   - clitic pronouns aren't articles (*lo vedo*, *non le menta*);
   - auxiliaries count only before a participle (*ho mangiato*), and participles after an auxiliary aren't present forms;
   - imperatives are skipped (the translation starts "Let's" or with a bare verb, and the sentence starts with the verb);
   - homographs are skipped when the vocabulary lists the spelling as another part of speech (*cena*, *presto*, *canes*).
4. **Picks the wrong options from the same grid.** By default the same column in other rows comes first (*ho* vs *sono*, *es* vs *está*, indicative vs subjunctive). Agreement units go the other way (*il / lo / la*).
5. **Ranks sentences by the share of words the vocabulary knows, then by length.** It keeps 40 per unit, with caps per form and per lemma so one verb doesn't dominate, and balances both sides of contrast units.

The output is deterministic: two runs give byte-identical files.

## App

- **Grammar tab:** its own tab, with units grouped by level and the verb conjugator (moved from Tools) as a reference row at the top. Today shows the next unit not yet passed.
- **Unit screen:** the note and table, then a practice round of 10 items as multiple choice. After answering, it shows the completed sentence, the label (*presente · io*) and a speak button.
- **Rotation:** each round moves to the next 10 items, so four rounds cover a unit.
- **Results:** best scores are stored per unit in the language's progress file (`grammar`, optional, so old files still decode) and merged across devices by taking the maximum. A unit counts as passed at 8/10.
- **Daily goal and streak:** each answer counts toward them, like the real-life cards.

The course is loaded from `ExUno/Resources/Packs/grammar-<code>.json`. If it is missing, the screen says to run `prepare_data.sh` or `download_packs.sh`.

## Verification

- `ExUnoTests/GrammarTests.swift`:
  - decoding, the gap helpers, round rotation and scoring;
  - that old progress files decode, and that grammar results merge;
  - for every bundled course: unique unit ids, ≥10 units, ≥10 items per unit, exactly one gap, the answer among ≥3 options, no two options differing only in accents.
- **Two cross-checks against code the app already ships:**
  - every Latin verb item must equal `LatinConjugator`'s form for that lemma, tense and person;
  - Italian, Spanish and French verb items from UniMorph must agree at least 95% with the app's own conjugators.
- **Results:** all 35 tests in the project pass on the iOS Simulator (iPhone 17), with the generated courses bundled.
- **Item quality:** spot-checked by reading samples of every unit; the filters above are the result.
- **Checked by hand in the simulator (iPhone 18 Pro):** the Tools entry, the course list, the unit screen with its note and table, and answering items (colours, labels). The end-of-round screen was not reached.

## Licensing

- **Sentences:** Tatoeba, CC BY 2.0 FR. CC BY material may be adapted into a CC BY-SA 4.0 work with attribution.
- **Paradigms:** UniMorph, CC BY-SA 3.0. Version 3.0 lets adaptations use a later BY-SA version.
- **The courses** are therefore CC BY-SA 4.0, like the vocabulary packs. The notes and tables are original and live in the MIT-licensed unit files.
- **Attribution:** each course carries an `attribution` string. The *Data & licenses* screen, `ATTRIBUTIONS.md` and `LICENSES/CC-BY-2.0-FR.txt` cover the rest.
- **Tatoeba credit:** the OPUS text release doesn't include sentence ids or authors, so contributors are credited as a group with a link to tatoeba.org. Per-sentence credit would need OPUS's XML release (sentence id and user per sentence). For English that release is a 167 MB download.

## Limitations and follow-ups

- The notes are short and cover A1–B1 (Latin I–III). Longer explanations could adapt Wikibooks (CC BY-SA 4.0) or Allen & Greenough (Perseus, CC BY-SA 4.0).
- Sentences are crowd-written; some are odd, and a few translations are loose. The filters remove systematic errors, not every bad sentence. A way to report an item in the app would help.
- **Wrong labels on spelling coincidences.** Some forms that are spelled the same as another form still get a wrong label. Examples are Italian *-are* verbs whose *tu* form equals the subjunctive, and Latin *hōc* vs *hoc* once macrons are folded. The answer is still the sentence's own word; only the explanation can be wrong.
- **Download size.** The grammar sources add about 145 MB to `prepare_data.sh`, mostly UniMorph's Spanish and Latin files. The built courses are 70–80 kB each.
- **Possible bug in `LatinConjugator`.** It keeps alternative perfects such as *-īvī/-iī* (audiō, sciō) as one string, so the Verbs tool would print forms like *audīvī/-iī*. The generator takes the first alternative, and the cross-check test skips those lemmas.
- **Not yet in the release.** The `packs` release needs one workflow run before `download_packs.sh` includes the courses.
