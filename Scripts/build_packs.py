#!/usr/bin/env python3
"""Build Ex Uno's language packs (ExUno/Resources/Packs/<code>.json) from the download cache.

Run Scripts/prepare_data.sh, or by hand:
  python3 Scripts/fetch_sources.py
  python3 Scripts/build_topics.py .cache/sources/decks-italian/italian.json .cache/sources/omw-it/omw-it/omw-it.xml .cache/sources/omw-en/omw-en/omw-en.xml .cache/topics-it.json
  python3 Scripts/build_packs.py

Italian, Spanish and French come from Language-Learning-decks; Latin from the DCC
Latin Core Vocabulary; Italian topics from MultiWordNet (build_topics.py).

Pack format (schema 2):
  {"code","schema":2,"license","attribution","levels":[...],"defaultLevels":[...],"topics":[{"id","name","icon"}],
   "entries":[{"i","w","t","l","p","x","e","z", "g"?, "a"?, "k"?, "c"?, "m"?, "v"?}]}
  a = display article, m = dictionary forms (Latin principal parts), v = verb class (Latin)
"""
import argparse, csv, json, math, os, re, unicodedata

TOPICS = ["animals", "body", "clothing", "colors-shapes", "communication", "family", "feelings", "food-drink", "home",
          "ideas-learning", "music", "nature-weather", "people-work", "places", "sports-games", "time", "transport"]
ICONS = {"animals": "pawprint.fill", "body": "figure.arms.open", "clothing": "tshirt.fill", "colors-shapes": "paintpalette.fill",
         "communication": "bubble.left.and.bubble.right.fill", "family": "person.3.fill", "feelings": "heart.fill",
         "food-drink": "fork.knife", "home": "house.fill", "ideas-learning": "book.fill", "music": "music.note",
         "nature-weather": "leaf.fill", "people-work": "person.2.fill", "places": "mappin.and.ellipse",
         "sports-games": "sportscourt.fill", "time": "clock.fill", "transport": "tram.fill"}
NAMES = {
 "it": ["Animali", "Corpo", "Abbigliamento", "Colori e forme", "Comunicazione", "Famiglia", "Sentimenti", "Cibo e bevande", "Casa",
        "Idee e studio", "Musica", "Natura e meteo", "Persone e lavoro", "Luoghi", "Sport e giochi", "Tempo e calendario", "Trasporti"],
 "es": ["Animales", "Cuerpo", "Ropa", "Colores y formas", "Comunicación", "Familia", "Sentimientos", "Comida y bebida", "Casa",
        "Ideas y estudio", "Música", "Naturaleza y clima", "Gente y trabajo", "Lugares", "Deportes y juegos", "Tiempo y calendario", "Transporte"],
 "fr": ["Animaux", "Corps", "Vêtements", "Couleurs et formes", "Communication", "Famille", "Sentiments", "Cuisine et boissons", "Maison",
        "Idées et savoir", "Musique", "Nature et météo", "Gens et travail", "Lieux", "Sports et jeux", "Temps et calendrier", "Transports"],
}
CEFR = ["A1", "A2", "B1", "B2", "C1", "C2"]
POS = {"adj": "adjective", "adv": "adverb", "verbs": "verb"}

def topics_for(code):
    return [{"id": t, "name": n, "icon": ICONS[t]} for t, n in zip(TOPICS, NAMES[code])]

def gloss_key(t, pos):
    first = re.split(r"[;,(]", t)[0].strip().lower()
    first = re.sub(r"^to ", "", first)
    return (first, pos)

def write(path, pack):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(pack, f, ensure_ascii=False, separators=(",", ":"))
    print(os.path.basename(path), len(pack["entries"]), f"{os.path.getsize(path)/1e6:.1f} MB")

IT_M = r"(?:il|lo|un|uno|del|dello|al|allo|nel|nello|sul|sullo|questo|quel|quello|mio|tuo|suo|nostro|vostro)"
IT_F = r"(?:la|una|della|alla|nella|sulla|questa|quella|mia|tua|sua|nostra|vostra)"

def italian_gender(word, sentence):
    w = re.escape(word.lower()); s = sentence.lower()
    if re.search(rf"\b{IT_F}\s+{w}\b", s) or re.search(rf"\bun'{w}\b", s): return "f"
    if re.search(rf"\b{IT_M}\s+{w}\b", s): return "m"
    return None

def fold(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")

def italian_article(word, pos, g):
    if pos != "noun" or g not in ("m", "f"):
        return None
    f = fold(word)
    if not f:
        return None
    vowel = f[0] in "aeiou"
    if g == "f":
        return "l'" if vowel else "la"
    if vowel:
        return "l'"
    if f[0] in "zxy" or f[:2] in ("ps", "gn", "pn") or (f[0] == "s" and len(f) > 1 and f[1] not in "aeiou"):
        return "lo"
    return "il"

def topic_index(it_entries):
    idx = {}
    for r in it_entries:
        if r.get("c"):
            idx.setdefault(gloss_key(r["t"], r["p"]), set()).update(r["c"])
    return idx

ES_M = r"(?:el|un|los|unos|este|ese|aquel|estos|esos|del|al|mi|tu|su|nuestro)"
ES_F = r"(?:la|una|las|unas|esta|esa|aquella|estas|esas|nuestra)"

def spanish_gender(word, sentence):
    w = re.escape(word.lower())
    s = sentence.lower()
    plural = r"(?:s|es)?"
    if re.search(rf"\b{ES_F}\s+{w}{plural}\b", s): return "f"
    if re.search(rf"\b{ES_M}\s+{w}{plural}\b", s): return "m"
    return None

def decks(path, code, it_topics, tags=None):
    data = json.load(open(path, encoding="utf-8"))
    out = []
    for n, e in enumerate(data, start=1):
        if not e.get("useful_for_flashcard", True) or e.get("cefr_level") not in CEFR:
            continue
        pos = POS.get(e["pos"], e["pos"])
        t = e["english_translation"].replace(";", ", ")
        rank = max(1, int(e.get("word_frequency") or n))
        r = {"i": n, "w": e["word"].strip(), "t": t, "l": e["cefr_level"], "p": pos,
             "x": e["example_sentence_native"], "e": e["example_sentence_english"], "z": round(8 - math.log10(rank), 2)}
        if pos == "noun":
            if code == "fr":
                art = (e.get("article_with_word") or "").strip().lower()
                first = art.split(" ")[0] if art else ""
                if first in ("le", "un"): r["g"], r["a"] = "m", "le"
                elif first in ("la", "une"): r["g"], r["a"] = "f", "la"
                elif first.startswith("l'") or first == "l’":
                    r["a"] = "l'"
                    s = e["example_sentence_native"].lower()
                    if re.search(rf"\bune\s+{re.escape(r['w'].lower())}", s): r["g"] = "f"
                    elif re.search(rf"\bun\s+{re.escape(r['w'].lower())}", s): r["g"] = "m"
            elif code == "it":
                g = italian_gender(r["w"], e["example_sentence_native"])
                if g:
                    r["g"] = g
                    art = italian_article(r["w"], pos, g)
                    if art: r["a"] = art
            else:
                g = spanish_gender(r["w"], e["example_sentence_native"])
                if g:
                    r["g"] = g
                    r["a"] = "el" if g == "m" else "la"
        if " " in r["w"].strip(): r["k"] = "p"
        c = tags.get(r["w"]) if tags is not None else it_topics.get(gloss_key(t, pos))
        if c: r["c"] = sorted(c)
        out.append(r)
    out.sort(key=lambda r: (CEFR.index(r["l"]), -r["z"]))
    return out

LATIN_GROUPS = [
  ("tempus", "Tempus", "clock.fill", ["Time", "Lengths of Time"]),
  ("locus", "Locus et iter", "map.fill", ["Place", "Geography", "Travel", "Motion", "Verbs of Transport", "Non-Directional Prepositions"]),
  ("bellum", "Bellum", "shield.fill", ["War and Peace", "Violence"]),
  ("urbs", "Urbs", "building.columns.fill", ["The City", "Justice", "Business/Money", "Social Life"]),
  ("domus", "Domus", "house.fill", ["The Household", "The House", "People", "Love"]),
  ("corpus", "Corpus et sēnsūs", "eye.fill", ["The Body", "Vision", "Other Senses"]),
  ("animus", "Animus", "heart.fill", ["Emotions", "Personality Traits/Characteristics", "Deception"]),
  ("natura", "Nātūra", "leaf.fill", ["Earth and Water", "Air and Fire", "Animals/Plants"]),
  ("sermo", "Sermō et litterae", "text.book.closed.fill", ["Speech/Oratory", "Writing/Poetry", "Education/Knowledge"]),
  ("religio", "Religiō", "sparkles", ["Religion"]),
  ("vita", "Vīta et āctiō", "figure.walk", ["Life and Being", "Making/Doing", "Verbs of Compelling/Directing", "Athletics"]),
  ("mensura", "Mēnsūra", "ruler.fill", ["Measurement"]),
  ("grammatica", "Grammatica", "textformat", ["Conjunctions/Adverbs", "Pronouns/Interrogatives"]),
]

def latin(path):
    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    group = {g: tid for tid, _, _, gs in LATIN_GROUPS for g in gs}
    out = []
    for n, row in enumerate(rows, start=1):
        head = unicodedata.normalize("NFC", row["Headword"].strip())
        head = re.sub(r"\s*\((?:adv|conj|prep|adj)\.\)", "", head)
        parts = head.replace(",", " ").split()
        lemma = parts[0]
        forms = " ".join(parts[1:])
        posfull = row["Part of Speech"]
        p = posfull.split(":")[0].strip().lower()
        p = {"noun": "noun", "verb": "verb", "adjective": "adjective", "adverb": "adverb", "conjunction": "conjunction",
             "preposition": "preposition", "pronoun": "pronoun"}.get(p, p)
        if "Numeral" in posfull: p = "numeral"
        rank = int(row["Frequency Rank"])
        level = "I" if rank <= 250 else "II" if rank <= 500 else "III" if rank <= 750 else "IV"
        r = {"i": n, "w": lemma, "t": row["Definition"].strip(), "l": level, "p": p, "x": "", "e": "", "z": round(8 - math.log10(rank), 2)}
        if forms: r["m"] = forms
        tail = " " + forms + " "
        if p == "noun":
            if " m. " in tail and " f. " in tail: r["g"] = "mf"
            elif " m. " in tail: r["g"] = "m"
            elif " f. " in tail: r["g"] = "f"
            elif " n. " in tail: r["g"] = "n"
        if p == "verb":
            r["v"] = posfull.split(":", 1)[1].strip()
        tid = group.get(row["Semantic Group"])
        if tid: r["c"] = [tid]
        out.append(r)
    out.sort(key=lambda r: (["I", "II", "III", "IV"].index(r["l"]), -r["z"]))
    return out

ATTRIBUTION = {
    "it": "Italian vocabulary: Language-Learning-decks (© 2025 GENERAL NEURO, MIT) with wordfreq data (CC BY-SA 4.0, Robyn Speer). Topics: MultiWordNet (CC BY 3.0) and Princeton WordNet 3.0 via Open Multilingual Wordnet 2.0.",
    "es": "Spanish vocabulary: Language-Learning-decks (© 2025 GENERAL NEURO, MIT) with wordfreq data (CC BY-SA 4.0, Robyn Speer). Topics projected from MultiWordNet (CC BY 3.0) and Princeton WordNet 3.0.",
    "fr": "French vocabulary: Language-Learning-decks (© 2025 GENERAL NEURO, MIT) with wordfreq data (CC BY-SA 4.0, Robyn Speer). Topics projected from MultiWordNet (CC BY 3.0) and Princeton WordNet 3.0.",
    "la": "Latin vocabulary: Dickinson College Commentaries Latin Core Vocabulary (CC BY-SA), https://dcc.dickinson.edu/latin-vocabulary-list.",
}

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", default=os.path.join(root, ".cache", "sources"))
    ap.add_argument("--topics", default=os.path.join(root, ".cache", "topics-it.json"), help="output of build_topics.py")
    ap.add_argument("--out", default=os.path.join(root, "ExUno", "Resources", "Packs"))
    a = ap.parse_args()
    metadata = json.load(open(os.path.join(root, "Scripts", "pack_metadata.json"), encoding="utf-8"))
    src = lambda sid, name: os.path.join(a.cache, sid, name)
    tags = json.load(open(a.topics, encoding="utf-8"))["tags"]
    it = decks(src("decks-italian", "italian.json"), "it", {}, tags)
    idx = topic_index(it)
    def pack(code, levels, default, topics, entries):
        return {"code": code, "schema": 2, "license": "CC BY-SA 4.0", "attribution": ATTRIBUTION[code],
                "levels": levels, "defaultLevels": default, "topics": topics,
                "marketUnits": metadata[code]["marketUnits"], "entries": entries}
    write(os.path.join(a.out, "it.json"), pack("it", CEFR, ["A1", "A2"], topics_for("it"), it))
    write(os.path.join(a.out, "es.json"), pack("es", CEFR, ["A1", "A2"], topics_for("es"), decks(src("decks-spanish", "spanish.json"), "es", idx)))
    write(os.path.join(a.out, "fr.json"), pack("fr", CEFR, ["A1", "A2"], topics_for("fr"), decks(src("decks-french", "french.json"), "fr", idx)))
    write(os.path.join(a.out, "la.json"), pack("la", ["I", "II", "III", "IV"], ["I"],
          [{"id": t, "name": n, "icon": i} for t, n, i, _ in LATIN_GROUPS], latin(src("dcc-latin", "dcc-latin-core-list.csv"))))

if __name__ == "__main__":
    main()
