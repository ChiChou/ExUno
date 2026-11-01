#!/usr/bin/env python3
"""Tag Italian vocabulary with learner topics derived from MultiWordNet.

Each word is looked up in MultiWordNet by lemma and part of speech; only senses
whose English synonyms match the word's translation are kept, and those synsets
are mapped to topics through WordNet lexicographer files and a few hyponym
subtrees.

Inputs:
  vocabulary       JSON list of {"word", "pos", "english_translation"} records
  italian_wordnet  omw-it.xml from Open Multilingual Wordnet 2.0 (MultiWordNet, CC BY 3.0)
  english_wordnet  omw-en.xml from Open Multilingual Wordnet 2.0 (Princeton WordNet 3.0)
  output           topics JSON: {"source", "categories", "tags": {word: [topic ids]}}

The output is a derived work of MultiWordNet (CC BY 3.0) and Princeton WordNet 3.0;
keep their notices with it (see ATTRIBUTIONS.md).
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import unicodedata
import xml.etree.ElementTree as ET
from collections import defaultdict, deque
from pathlib import Path


CATEGORIES = [
    {"id": "animals", "name": "Animals", "symbol": "pawprint.fill"},
    {"id": "body", "name": "Body", "symbol": "figure.arms.open"},
    {"id": "clothing", "name": "Clothing", "symbol": "tshirt.fill"},
    {"id": "colors-shapes", "name": "Colors & Shapes", "symbol": "paintpalette.fill"},
    {"id": "communication", "name": "Communication", "symbol": "bubble.left.and.bubble.right.fill"},
    {"id": "family", "name": "Family", "symbol": "person.3.fill"},
    {"id": "feelings", "name": "Feelings", "symbol": "heart.fill"},
    {"id": "food-drink", "name": "Food & Drink", "symbol": "fork.knife"},
    {"id": "home", "name": "Home", "symbol": "house.fill"},
    {"id": "ideas-learning", "name": "Ideas & Learning", "symbol": "book.fill"},
    {"id": "music", "name": "Music", "symbol": "music.note"},
    {"id": "nature-weather", "name": "Nature & Weather", "symbol": "leaf.fill"},
    {"id": "people-work", "name": "People & Work", "symbol": "person.2.fill"},
    {"id": "places", "name": "Places", "symbol": "mappin.and.ellipse"},
    {"id": "sports-games", "name": "Sports & Games", "symbol": "sportscourt.fill"},
    {"id": "time", "name": "Time & Calendar", "symbol": "clock.fill"},
    {"id": "transport", "name": "Transport & Movement", "symbol": "car.fill"},
]

LEXFILE_CATEGORIES = {
    "noun.animal": {"animals"},
    "noun.body": {"body"},
    "noun.cognition": {"ideas-learning"},
    "noun.communication": {"communication"},
    "noun.feeling": {"feelings"},
    "noun.food": {"food-drink"},
    "noun.location": {"places"},
    "noun.person": {"people-work"},
    "noun.plant": {"nature-weather"},
    "noun.phenomenon": {"nature-weather"},
    "noun.shape": {"colors-shapes"},
    "noun.time": {"time"},
    "verb.cognition": {"ideas-learning"},
    "verb.communication": {"communication"},
    "verb.competition": {"sports-games"},
    "verb.emotion": {"feelings"},
    "verb.motion": {"transport"},
    "verb.weather": {"nature-weather"},
}

# Princeton WordNet 3.0 synset offsets whose hyponym trees define a topic.
SUBTREE_ROOTS = {
    "clothing": {"03051540-n"},
    "family": {"10235549-n", "10236304-n", "07970406-n", "08078020-n"},
    "food-drink": {"00322847-v", "01168468-v", "01170052-v", "01664172-v", "01665638-v"},
    "home": {"03405725-n", "03544360-n", "04105893-n"},
    "music": {"00543233-n", "03800933-n", "05718556-n", "05718935-n", "07020895-n"},
    "sports-games": {"00455599-n", "00523513-n"},
    "transport": {"00295701-n", "04524313-n"},
}

SOURCE_POS = {
    "noun": {"n"},
    "verb": {"v"},
    "verbs": {"v"},
    "adjective": {"a", "s"},
    "adj": {"a", "s"},
    "adverb": {"r"},
    "adv": {"r"},
    "adverbial phrase": {"r"},
}

CATEGORY_MIN_SENSE_SUPPORT = 0.34

BASIC_COLOR_TRANSLATIONS = {
    "azure", "beige", "black", "blue", "brown", "cyan", "gold", "golden",
    "gray", "green", "grey", "indigo", "light blue", "lime", "magenta",
    "navy blue", "orange", "pink", "purple", "red", "silver", "teal",
    "turquoise", "violet", "white", "yellow",
}


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).casefold()
    return " ".join(text.replace("_", " ").replace("’", "'").split())


def synset_key(identifier: str) -> str:
    parts = identifier.rsplit("-", 2)
    return f"{parts[-2]}-{parts[-1]}"


def parse_english_wordnet(path: Path):
    lexfiles: dict[str, str] = {}
    children: dict[str, set[str]] = defaultdict(set)
    similarity: dict[str, set[str]] = defaultdict(set)
    attributes: dict[str, set[str]] = defaultdict(set)
    lemmas: dict[str, set[str]] = defaultdict(set)

    for _, element in ET.iterparse(path, events=("end",)):
        if element.tag == "LexicalEntry":
            lemma = element.find("Lemma")
            if lemma is not None:
                forms = {normalize(lemma.attrib.get("writtenForm", ""))}
                forms.update(normalize(form.attrib.get("writtenForm", "")) for form in element.findall("Form"))
                for sense in element.findall("Sense"):
                    lemmas[synset_key(sense.attrib["synset"])].update(forms)
            element.clear()
        elif element.tag == "Synset":
            current = synset_key(element.attrib["id"])
            lexfiles[current] = element.attrib.get("lexfile", "")
            for relation in element.findall("SynsetRelation"):
                target = synset_key(relation.attrib["target"])
                relation_type = relation.attrib.get("relType")
                if relation_type in {"hyponym", "instance_hyponym"}:
                    children[current].add(target)
                elif relation_type in {"hypernym", "instance_hypernym"}:
                    children[target].add(current)
                elif relation_type in {"similar", "also"}:
                    similarity[current].add(target)
                    similarity[target].add(current)
                elif relation_type == "attribute":
                    attributes[current].add(target)
            element.clear()

    return lexfiles, children, similarity, attributes, lemmas


def closure(starts: set[str], graph: dict[str, set[str]]) -> set[str]:
    visited = set(starts)
    queue = deque(starts)
    while queue:
        current = queue.popleft()
        for neighbor in graph.get(current, ()):
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return visited


def build_synset_categories(lexfiles, children, similarity, attributes) -> dict[str, set[str]]:
    categories: dict[str, set[str]] = defaultdict(set)
    for synset, lexfile in lexfiles.items():
        categories[synset].update(LEXFILE_CATEGORIES.get(lexfile, ()))

    for category, roots in SUBTREE_ROOTS.items():
        for synset in closure(roots, children):
            categories[synset].add(category)

    color_nouns = closure({"04956594-n"}, children)
    color_adjective_roots = {synset for synset, targets in attributes.items() if targets.intersection(color_nouns)}
    for synset in color_nouns | closure(color_adjective_roots, similarity):
        categories[synset].add("colors-shapes")

    return categories


def parse_italian_lemmas(path: Path) -> dict[tuple[str, str], set[str]]:
    senses: dict[tuple[str, str], set[str]] = defaultdict(set)
    for _, element in ET.iterparse(path, events=("end",)):
        if element.tag != "LexicalEntry":
            continue
        lemma = element.find("Lemma")
        if lemma is not None:
            key = normalize(lemma.attrib.get("writtenForm", ""))
            part_of_speech = lemma.attrib.get("partOfSpeech", "")
            for sense in element.findall("Sense"):
                senses[(key, part_of_speech)].add(synset_key(sense.attrib["synset"]))
        element.clear()
    return senses


def load_vocabulary(path: Path) -> list[dict]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as handle:
        return json.load(handle)


def build(vocabulary_path: Path, italian_path: Path, english_path: Path, output_path: Path) -> None:
    vocabulary = load_vocabulary(vocabulary_path)

    lexfiles, children, similarity, attributes, english_lemmas = parse_english_wordnet(english_path)
    synset_categories = build_synset_categories(lexfiles, children, similarity, attributes)
    italian_senses = parse_italian_lemmas(italian_path)

    tags: dict[str, list[str]] = {}
    counts: dict[str, int] = defaultdict(int)
    matched_wordnet = 0
    matched_translation = 0

    for record in vocabulary:
        word = record["word"]
        normalized_word = normalize(word)
        expected_parts = SOURCE_POS.get(record.get("pos", ""), {"n", "v", "a", "s", "r"})
        synsets: set[str] = set()
        for part in expected_parts:
            synsets.update(italian_senses.get((normalized_word, part), ()))
        synsets = {
            (synset[:-1] + "s")
            if synset.endswith("-a") and synset not in english_lemmas and synset[:-1] + "s" in english_lemmas
            else synset
            for synset in synsets
        }
        if synsets:
            matched_wordnet += 1

        translations = {normalize(value) for value in re.split(r"[;/]", record.get("english_translation", "")) if value.strip()}
        translations.update(translation[3:] for translation in list(translations) if translation.startswith("to "))
        translations.update(re.sub(r"\s*\([^)]*\)\s*", "", translation).strip() for translation in list(translations))
        synsets = {synset for synset in synsets if translations.intersection(english_lemmas.get(synset, ()))}
        if synsets:
            matched_translation += 1

        support: dict[str, int] = defaultdict(int)
        for synset in synsets:
            for category in synset_categories.get(synset, ()):
                support[category] += 1
        word_categories = sorted(
            category for category, category_count in support.items()
            if category_count / len(synsets) >= CATEGORY_MIN_SENSE_SUPPORT
        )
        if "people-work" in word_categories and "animals" in word_categories:
            word_categories.remove("animals")
        if translations.intersection(BASIC_COLOR_TRANSLATIONS) and "colors-shapes" not in word_categories:
            word_categories.append("colors-shapes")
            word_categories.sort()
        if word_categories:
            tags[word] = word_categories
            for category in word_categories:
                counts[category] += 1

    output = {
        "source": {
            "name": "MultiWordNet (Italian) and Princeton WordNet 3.0, via Open Multilingual Wordnet 2.0",
            "url": "https://github.com/omwn/omw-data/releases/tag/v2.0",
            "license": "CC BY 3.0 (MultiWordNet); WordNet 3.0 license (Princeton)",
            "license_url": "https://creativecommons.org/licenses/by/3.0/",
        },
        "matched_wordnet_entries": matched_wordnet,
        "matched_translation_entries": matched_translation,
        "categories": [{**category, "count": counts[category["id"]]} for category in CATEGORIES if counts[category["id"]] > 0],
        "tags": tags,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as output_file:
        json.dump(output, output_file, ensure_ascii=False, separators=(",", ":"))
        output_file.write("\n")

    print(f"topics: matched {matched_wordnet:,} by lemma/POS, {matched_translation:,} by translation; tagged {len(tags):,}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("vocabulary", type=Path)
    parser.add_argument("italian_wordnet", type=Path)
    parser.add_argument("english_wordnet", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    build(arguments.vocabulary, arguments.italian_wordnet, arguments.english_wordnet, arguments.output)
