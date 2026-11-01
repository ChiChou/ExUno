#!/usr/bin/env python3
"""Build Ex Uno's grammar courses (ExUno/Resources/Packs/grammar-<code>.json).

Run Scripts/prepare_data.sh, or by hand after build_packs.py:
  python3 Scripts/fetch_sources.py
  python3 Scripts/build_packs.py
  python3 Scripts/build_grammar.py

A course is a list of units written by hand in Scripts/grammar/<code>.json (title,
level, a short note, a reference table) plus fill-in-the-blank items found in
Tatoeba sentence pairs (via OPUS). Each unit says which word forms compete for a
slot ("grids"); a sentence becomes an item when one of its words is a cell of a
grid, and the other cells of that grid supply the wrong options. Grids come from
the unit file (closed sets such as articles), from UniMorph paradigms (Romance
verbs, Latin nouns), or from the same Latin rules as LatinConjugator.swift.

Course format (schema 1):
  {"code","schema":1,"license","attribution","levels":[...],
   "units":[{"id","level","title","en","note","table"?:{"cols":[...],"rows":[[...]]},
             "items":[{"x","a","o":[...],"e","h"?,"g","k"}]}]}
  x = sentence with "___" for the gap, a = answer, o = options (answer included),
  e = English translation, h = lemma hint, g = label of the answer's cell,
  k = machine key of the cell ("<row id>/<column index>")
"""
import argparse, hashlib, json, os, re, unicodedata, zipfile
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PERSONS = ["1;SG", "2;SG", "3;SG", "1;PL", "2;PL", "3;PL"]
EXCLUDE_TAGS = {"FORM", "NEG", "LGSPEC2"}
WORD = re.compile(r"[^\W\d_]+['’]?")
YOU = re.compile(r"\byou(?:r|rs|rself|rselves)?\b", re.I)
YOUR = re.compile(r"\byours?\b", re.I)
IMPERATIVE = re.compile(r"^(?:let's|let us)\b", re.I)
# How English translations of statements and questions begin. A verb-first sentence whose translation
# starts some other way ("Wait here.", "Use a calculator.") is taken as an imperative.
ENGLISH_STARTS = set("""i you he she it we they there this that these those what who whom whose where when why how which
do does did doesn didn can could couldn will won would wouldn shall should shouldn may might must mustn
is isn are aren am was wasn were weren have haven has hasn had hadn my your his her our their its the a an
nobody everybody everyone someone somebody nothing everything something no not one all both some many tom mary""".split())
SUBJECTS = set("i you he she it we they this that these those there tom mary anyone anybody everyone everybody someone the a an my your his her our their".split())
ITEMS_PER_UNIT = 40
MAX_PER_FORM = 2
MAX_PER_LEMMA = 4

ATTRIBUTION = ("Sentences: Tatoeba (tatoeba.org) contributors, CC BY 2.0 FR, via OPUS Tatoeba v2026-07-08 (J. Tiedemann, LREC 2012). "
               "Paradigms: UniMorph (CC BY-SA 3.0, from English Wiktionary). Unit notes and tables: Ex Uno.")
LATIN_ATTRIBUTION = ATTRIBUTION.replace("Paradigms: UniMorph", "Noun paradigms: UniMorph") + \
    " Verb forms: Ex Uno's rules with DCC Latin Core Vocabulary principal parts (CC BY-SA)."


def fold(s):
    """Lowercase, strip accents and macrons."""
    s = unicodedata.normalize("NFD", s.lower().replace("’", "'"))
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def keyer(code):
    """Spelling key for matching words. Latin sentences rarely mark vowel length and may write j for i."""
    if code == "la":
        return lambda w: fold(w).replace("j", "i")
    return lambda w: w.lower().replace("’", "'")


def stable(*parts):
    return int(hashlib.sha256("|".join(parts).encode()).hexdigest()[:12], 16)


# ---------- sources

def load_tatoeba(path, code):
    """Return [(sentence, english)], one per distinct sentence, shortest translation kept."""
    with zipfile.ZipFile(path) as z:
        tgt = z.read(f"Tatoeba.en-{code}.{code}").decode("utf-8").splitlines()
        eng = z.read(f"Tatoeba.en-{code}.en").decode("utf-8").splitlines()
    if len(tgt) != len(eng):
        raise SystemExit(f"{path}: {len(tgt)} {code} lines but {len(eng)} English lines")
    best = {}
    for s, e in zip(tgt, eng):
        s, e = s.strip(), e.strip()
        if not s or not e:
            continue
        if s not in best or len(e) < len(best[s]):
            best[s] = e
    return sorted(best.items())


def load_unimorph(path):
    """lemma → list of (form, tagset) in file order."""
    out = defaultdict(list)
    with open(path, encoding="utf-8") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) < 3 or not p[1]:
                continue
            tags = set(re.split(r"[;.]", p[2]))
            out[unicodedata.normalize("NFC", p[0])].append((unicodedata.normalize("NFC", p[1]), tags))
    return out


def um_form(paradigm, want):
    need = set(re.split(r"[;.]", want))
    for form, tags in paradigm:
        if need <= tags and not (tags & EXCLUDE_TAGS):
            return form
    return None


# ---------- Latin verbs: the same rules as LatinConjugator.swift

LATIN_IRREGULAR = {
    "sum": {"PRS": "sum es est sumus estis sunt", "IPFV": "eram erās erat erāmus erātis erant",
            "FUT": "erō eris erit erimus eritis erunt", "PRF": "fuī fuistī fuit fuimus fuistis fuērunt"},
    "possum": {"PRS": "possum potes potest possumus potestis possunt", "IPFV": "poteram poterās poterat poterāmus poterātis poterant",
               "FUT": "poterō poteris poterit poterimus poteritis poterunt", "PRF": "potuī potuistī potuit potuimus potuistis potuērunt"},
    "eō": {"PRS": "eō īs it īmus ītis eunt", "IPFV": "ībam ībās ībat ībāmus ībātis ībant",
           "FUT": "ībō ībis ībit ībimus ībitis ībunt", "PRF": "iī īstī iit iimus īstis iērunt"},
    "ferō": {"PRS": "ferō fers fert ferimus fertis ferunt", "IPFV": "ferēbam ferēbās ferēbat ferēbāmus ferēbātis ferēbant",
             "FUT": "feram ferēs feret ferēmus ferētis ferent", "PRF": "tulī tulistī tulit tulimus tulistis tulērunt"},
    "volō": {"PRS": "volō vīs vult volumus vultis volunt", "IPFV": "volēbam volēbās volēbat volēbāmus volēbātis volēbant",
             "FUT": "volam volēs volet volēmus volētis volent", "PRF": "voluī voluistī voluit voluimus voluistis voluērunt"},
    "dō": {"PRS": "dō dās dat damus datis dant", "IPFV": "dabam dabās dabat dabāmus dabātis dabant",
           "FUT": "dabō dabis dabit dabimus dabitis dabunt", "PRF": "dedī dedistī dedit dedimus dedistis dedērunt"},
}


def latin_class(cls):
    if cls.startswith("1st"): return 1
    if cls.startswith("2nd"): return 2
    if "-iō" in cls: return 5
    if cls.startswith("3rd"): return 3
    if cls.startswith("4th"): return 4
    return None


def latin_resolve(part, lemma, stem):
    if not part.startswith("-"):
        return part
    p = part[1:]
    if not p:
        return None
    if fold(p[0]) in "aeiou":
        return stem + p
    for cut in range(len(lemma) - 1, 0, -1):
        if fold(lemma[cut]) == fold(p[0]):
            return lemma[:cut] + p
    return stem + p


def latin_verb(lemma, forms, cls):
    """{tense: [6 forms]} for a regular DCC verb, or None."""
    if lemma in LATIN_IRREGULAR:
        return {t: f.split() for t, f in LATIN_IRREGULAR[lemma].items()}
    conj = latin_class(cls or "")
    if conj is None or "Deponent" in (cls or ""):
        return None
    stem = lemma[:-2] if conj in (2, 4, 5) else lemma[:-1]
    s = stem
    if conj == 1:
        t = {"PRS": [lemma, s + "ās", s + "at", s + "āmus", s + "ātis", s + "ant"],
             "IPFV": [s + e for e in ["ābam", "ābās", "ābat", "ābāmus", "ābātis", "ābant"]],
             "FUT": [s + e for e in ["ābō", "ābis", "ābit", "ābimus", "ābitis", "ābunt"]]}
    elif conj == 2:
        t = {"PRS": [lemma, s + "ēs", s + "et", s + "ēmus", s + "ētis", s + "ent"],
             "IPFV": [s + e for e in ["ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant"]],
             "FUT": [s + e for e in ["ēbō", "ēbis", "ēbit", "ēbimus", "ēbitis", "ēbunt"]]}
    elif conj == 3:
        t = {"PRS": [lemma, s + "is", s + "it", s + "imus", s + "itis", s + "unt"],
             "IPFV": [s + e for e in ["ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant"]],
             "FUT": [s + e for e in ["am", "ēs", "et", "ēmus", "ētis", "ent"]]}
    elif conj == 5:
        t = {"PRS": [lemma, s + "is", s + "it", s + "imus", s + "itis", s + "iunt"],
             "IPFV": [s + e for e in ["iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant"]],
             "FUT": [s + e for e in ["iam", "iēs", "iet", "iēmus", "iētis", "ient"]]}
    else:
        t = {"PRS": [lemma, s + "īs", s + "it", s + "īmus", s + "ītis", s + "iunt"],
             "IPFV": [s + e for e in ["iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant"]],
             "FUT": [s + e for e in ["iam", "iēs", "iet", "iēmus", "iētis", "ient"]]}
    parts = (forms or "").replace(",", " ").replace(":", " ").split()
    if len(parts) > 1:
        perf = latin_resolve(parts[1].split("/")[0], lemma, stem)
        if perf and perf.endswith("ī"):
            ps = perf[:-1]
            t["PRF"] = [ps + e for e in ["ī", "istī", "it", "imus", "istis", "ērunt"]]
    return t


def latin_declension(paradigm):
    gen = um_form(paradigm, "N;GEN;SG")
    if not gen:
        return None
    g = fold(gen)
    if g.endswith("ei"): return 5
    if g.endswith("ae"): return 1
    if g.endswith("is"): return 3
    if g.endswith("us"): return 4
    if g.endswith("i"): return 2
    return None


# ---------- grids

class Grid:
    """Competing forms: rows × cols of strings (None for gaps)."""
    def __init__(self, gid, rows, cols, lemma=None, you=(), you_rows=(), corpus=False):
        self.id, self.rows, self.cols, self.lemma = gid, rows, cols, lemma   # rows: [(row id, row label, [forms])]
        self.you, self.you_rows = set(you), set(you_rows)
        self.corpus = corpus    # forms from UniMorph or rules rather than hand-checked
        self.elsewhere = set()
        self.kind = "noun" if cols and cols[0].startswith("n") and lemma and len(cols) == 5 else "verb"

    def cells(self):
        for r, (_, _, forms) in enumerate(self.rows):
            for c, f in enumerate(forms):
                if f:
                    yield r, c, f


def person_rows(spec_rows, lookup, lemma):
    rows = []
    for rid, label, tag in spec_rows:
        forms = lookup(lemma, tag)
        if not forms or not any(forms):
            return None
        rows.append((rid, label, forms))
    return rows


def build_grids(unit, ctx):
    lang = ctx["lang"]
    grids = []
    for n, g in enumerate(unit.get("grids", [])):
        rows = [(r[0], r[1], [f or None for f in r[2]]) for r in g["rows"]]
        grids.append(Grid(f"{unit['id']}:{n}", rows, g["cols"], g.get("lemma"), g.get("you", []), g.get("you_rows", [])))
    src = unit.get("verbs")
    if src:
        rows_spec = src["rows"]
        persons = lang["persons"]
        extra = src.get("extra", {})
        skip = set(src.get("exclude", []))
        for lemma in [v for v in ctx["verbs"] if v not in skip][: src.get("max", 400)]:
            def lookup(lm, tag):
                if lm in extra and tag in extra[lm]:
                    return extra[lm][tag].split()
                if lang["code"] == "la":
                    v = ctx["latin_verbs"].get(lm)
                    return v.get(tag) if v else None
                para = ctx["um"].get(lm)
                if not para:
                    return None
                forms = [um_form(para, f"V;{tag};{p}") for p in PERSONS]
                if any(f and " " in f for f in forms):
                    return None     # pronominal verbs ("mi ami"): the clitic belongs to the sentence, not the slot
                return forms
            rows = person_rows(rows_spec, lookup, lemma)
            if rows:
                g = Grid(f"{unit['id']}:{lemma}", rows, persons, lemma, lang["you"], corpus=lemma not in extra)
                # Spellings this lemma shares with a tense the unit doesn't teach (estudiamos: present and preterite).
                g.elsewhere = {ctx["key"](f) for tag in src.get("notAlso", []) for f in (lookup(lemma, tag) or []) if f}
                grids.append(g)
        for lemma in extra:
            if lemma not in ctx["verbs"]:
                rows = [(rid, label, extra[lemma][tag].split()) for rid, label, tag in rows_spec if tag in extra[lemma]]
                if len(rows) == len(rows_spec):
                    grids.append(Grid(f"{unit['id']}:{lemma}", rows, persons, lemma, lang["you"]))
    src = unit.get("nouns")
    if src:
        cases = ["NOM", "GEN", "DAT", "ACC", "ABL"]
        for lemma in ctx["nouns"]:
            para = ctx["um"].get(lemma)
            if not para or latin_declension(para) not in src["declensions"]:
                continue
            rows = [(num.lower(), label, [um_form(para, f"N;{c};{num}") for c in cases]) for num, label in (("SG", "sg."), ("PL", "pl."))]
            if all(all(r[2]) for r in rows):
                grids.append(Grid(f"{unit['id']}:{lemma}", rows, lang["cases"], lemma, corpus=True))
    return grids


def index_grids(grids, key):
    """word keys → [(grid, row, col)]"""
    idx = defaultdict(list)
    for g in grids:
        for r, c, f in g.cells():
            idx[tuple(key(w) for w in f.split())].append((g, r, c))
    return idx


# ---------- sentences → items

def tokenize(s):
    return [(m.group(0), m.start(), m.end()) for m in WORD.finditer(s)]


def match_case(model, form):
    if model[:1].isupper() and not model[1:2].isupper():
        return form[:1].upper() + form[1:]
    return form


def pick_options(grid, r, c, english, answer_key, key, plain, agree_first=False):
    """Up to three wrong options from the answer's grid. By default the same column in other rows comes
    first (essere vs avere, ser vs estar, indicative vs subjunctive), then the same row; agree_first
    reverses that for agreement units (il/lo/la, mio/mia)."""
    you = bool(YOU.search(english))
    your = bool(YOUR.search(english))
    other_rows = [(rr, c) for rr in range(len(grid.rows)) if rr != r]
    same_row = [(r, cc) for cc in range(len(grid.cols)) if cc != c]
    cands = same_row + other_rows if agree_first else other_rows + same_row
    cands += [(rr, cc) for rr in range(len(grid.rows)) for cc in range(len(grid.cols)) if rr != r and cc != c]
    out, seen = [], {answer_key}
    for rr, cc in cands:
        f = grid.rows[rr][2][cc] if cc < len(grid.rows[rr][2]) else None
        if not f:
            continue
        if (you and c in grid.you and cc in grid.you) or (your and r in grid.you_rows and rr in grid.you_rows):
            continue    # "you" can't tell tu/Lei/voi (or tú/usted, tu/vous) apart
        k = " ".join(key(w) for w in f.split())
        if k in seen:
            continue
        seen.add(k)
        out.append(plain(f))
        if len(out) == 3:
            break
    return out


def cell_label(grid, r, c, same):
    labels = []
    for rr, cc in same:
        rl, cl = grid.rows[rr][1], grid.cols[cc]
        labels.append(" · ".join(x for x in (rl, cl) if x))
    seen = []
    for l in labels:
        if l not in seen:
            seen.append(l)
    return " / ".join(seen)


def is_imperative(keys, i, english, sentence, lang):
    if IMPERATIVE.match(english):
        return True
    if any(k not in lang.get("preverbal", ()) for k in keys[:i]):
        return False
    if sentence.rstrip().endswith("!") and i == 0:
        return True
    words = re.findall(r"[A-Za-z]+", english.lower())
    if not words:
        return False
    if words[0] in ("do", "does", "did") and (len(words) < 2 or words[1] not in SUBJECTS):
        return True     # "Do your job." rather than "Do you know…?"
    return words[0] not in ENGLISH_STARTS


def make_items(unit, grids, sentences, ctx):
    lang = ctx["lang"]
    latin = lang["code"] == "la"
    key = ctx["key"]
    idx = index_grids(grids, key)
    maxlen = max((len(k) for k in idx), default=1)
    cond = unit.get("before")
    ptcp = ctx["participles"]
    skip_after_elision = unit.get("skipAfterElision", lang.get("skipAfterElision", False))
    not_before_verb = unit.get("notBeforeVerb", False)
    contrast = unit.get("contrast", False)
    verbal = "verbs" in unit or unit.get("verbForms", False)
    candidates = []
    for s, e in sentences:
        toks = tokenize(s)
        if not (3 <= len(toks) <= 12) or len(s) > 90:
            continue
        keys = [key(t[0]) for t in toks]
        found = None
        for i in range(len(toks)):
            for n in range(min(maxlen, len(keys) - i), 0, -1):
                hits = idx.get(tuple(keys[i:i + n]))
                if not hits:
                    continue
                if len({h[0].id for h in hits}) > 1:
                    break       # the same spelling belongs to two lexemes: ambiguous, skip
                j = i + n       # index of the next token
                if skip_after_elision and i > 0 and keys[i - 1].endswith("'"):
                    break
                if cond == "participle":
                    k = j
                    while k < len(keys) and keys[k] in lang.get("adverbs", ()):
                        k += 1
                    if k >= len(keys) or keys[k] not in ptcp:
                        break
                if not_before_verb and (j >= len(keys) or (keys[j] in ctx["verbal"] and keys[j] not in ctx["nominal"])):
                    break       # a clitic pronoun (lo vedo, la voglio vedere), not an article
                if not_before_verb and i > 0 and keys[i - 1] in lang.get("negation", ()):
                    break       # non le menta, no la veo, ne le dis pas
                if verbal and i > 0 and keys[i] in ptcp and keys[i - 1] in ctx["finite_aux"]:
                    break       # a participle after an auxiliary (siete cambiate), not a finite form
                if "verbs" in unit and keys[i] in ctx["finite_aux"] and j < len(keys) and keys[j] in ptcp:
                    break       # an auxiliary (he estado) belongs to the perfect units
                if n == 1 and keys[i] in hits[0][0].elsewhere:
                    break
                if n == 1 and hits[0][0].corpus and keys[i] in ctx["homographs"].get(hits[0][0].kind, ()):
                    break       # the vocabulary lists this spelling as another part of speech (cena, stanco, presto)
                if keys[i + n - 1].endswith("'") and j >= len(keys):
                    break
                found = (i, n, hits)
                break
            if found:
                break
        if not found:
            continue
        i, n, hits = found
        if verbal and is_imperative(keys, i, e, s, lang):
            continue    # imperatives look like present or subjunctive forms ("Aspetta!", "Vada a casa.")
        if unit.get("skipAnswers") and re.search(unit["skipAnswers"], " ".join(keys[i:i + n])):
            continue    # e.g. Latin 1st-person futures in -am, which are also present subjunctives (ut vīvam)
        needs = unit.get("rowNeeds", {}).get(hits[0][0].rows[hits[0][1]][0])
        if needs and not any(k in needs for k in keys[:i]):
            continue    # e.g. a subjunctive only after che/que
        grid, r, c = hits[0]
        start, end = toks[i][1], toks[i + n - 1][2]
        answer = s[start:end]
        akey = " ".join(key(w) for w in answer.split())
        # Options follow the sentence's spelling: no macrons unless the sentence uses them.
        plain = (lambda f: f) if not latin or any(ch in s for ch in "āēīōūȳĀĒĪŌŪ") else fold
        opts = pick_options(grid, r, c, e, akey, key, plain, unit.get("agreeFirst", False))
        if len(opts) < 2:
            continue
        if contrast:
            other = [grid.rows[rr][2][c] for rr in range(len(grid.rows)) if rr != r]
            if not any(o and " ".join(key(w) for w in o.split()) != akey for o in other):
                continue
        others = [k for k in keys[:i] + keys[i + n:]]
        unknown = sum(1 for k in others if k not in ctx["known"]) / max(1, len(others))
        candidates.append((unknown, len(toks), s, e, grid, r, c, hits, start, end, answer, opts))
    candidates.sort(key=lambda t: (round(t[0], 1), t[1], stable(unit["id"], t[2])))
    # Spread items over many lexemes; closed sets (articles, auxiliaries) may repeat a form more often.
    few = len(grids) <= 3     # a closed set or one or two paradigms (articles, essere/avere, sum)
    form_cap = max(MAX_PER_FORM, ITEMS_PER_UNIT // max(1, len(idx)) + 2) if few else MAX_PER_FORM
    row_cap = ITEMS_PER_UNIT // max(1, max((len(g.rows) for g in grids), default=1)) if contrast else ITEMS_PER_UNIT
    items, per_form, per_lemma, per_row = [], defaultdict(int), defaultdict(int), defaultdict(int)
    for unknown, _, s, e, grid, r, c, hits, start, end, answer, opts in candidates:
        if unknown > 0.34:
            break
        akey = " ".join(key(w) for w in answer.split())
        if per_form[akey] >= form_cap:
            continue
        if not few and per_lemma[grid.lemma] >= MAX_PER_LEMMA:
            continue
        if per_row[grid.rows[r][0]] >= row_cap:
            continue    # contrast units keep both sides (indicative and subjunctive) in balance
        per_row[grid.rows[r][0]] += 1
        per_form[akey] += 1
        per_lemma[grid.lemma] += 1
        gap = s[:start] + "___" + s[end:]
        options = [answer] + [match_case(answer, o) for o in opts]
        options.sort(key=lambda o: stable(s, o))
        same = [(h[1], h[2]) for h in hits]
        item = {"x": gap, "a": answer, "o": options, "e": e, "g": cell_label(grid, r, c, same), "k": f"{grid.rows[r][0]}/{c}"}
        if grid.lemma:
            item["h"] = grid.lemma
        items.append(item)
        if len(items) >= ITEMS_PER_UNIT:
            break
    return items


def model_table(unit, grids):
    """A reference table from the unit's model lemmas: one column per lemma, one row per person/case."""
    t = unit["table"]
    if "lemmas" not in t:
        return t
    by = {g.lemma: g for g in grids if g.lemma}
    row = t.get("row", 0)
    missing = [l for l in t["lemmas"] if l not in by]
    if missing:
        raise SystemExit(f"{unit['id']}: table lemmas without a paradigm: {missing}")
    first = by[t["lemmas"][0]]
    if "rows" in t:     # several rows of the grid (e.g. tenses) for one lemma
        g = first
        cols = [""] + [lbl for _, lbl, _ in g.rows]
        rows = [[g.cols[c]] + [r[2][c] or "–" for r in g.rows] for c in range(len(g.cols))]
        return {"cols": cols, "rows": rows}
    cols = [""] + t["lemmas"]
    rows = []
    for c, label in enumerate(first.cols):
        rows.append([label] + [by[l].rows[row][2][c] or "–" for l in t["lemmas"]])
    if len(first.rows) > 1 and t.get("both"):
        rows = []
        for rr, (_, rl, _) in enumerate(first.rows):
            for c, label in enumerate(first.cols):
                rows.append([f"{label} {rl}".strip()] + [by[l].rows[rr][2][c] or "–" for l in t["lemmas"]])
    return {"cols": cols, "rows": rows}


# ---------- main

def participles(code, um, deck_verbs, extra, lang_not=()):
    out = set(extra)
    for lemma, para in um.items():
        for form, tags in para:
            if "PTCP" in tags and "PST" in tags and " " not in form:
                out.add(form.lower())
    for v in deck_verbs:
        if code == "it":
            for a, b in (("are", "ato"), ("ere", "uto"), ("ire", "ito")):
                if v.endswith(a): out.add(v[:-3] + b)
        elif code == "es":
            for a, b in (("ar", "ado"), ("er", "ido"), ("ir", "ido")):
                if v.endswith(a): out.add(v[:-2] + b)
        elif code == "fr":
            for a, b in (("er", "é"), ("ir", "i"), ("re", "u")):
                if v.endswith(a): out.add(v[:-2] + b)
    agreed = set()
    for p in out:
        if code == "it" and p.endswith("o"):
            agreed |= {p[:-1] + x for x in "aie"}
        elif code == "fr":
            agreed |= {p + "e", p + "s", p + "es"} if not p.endswith("s") else {p + "e", p + "es"}
    return (out | agreed) - set(lang_not)


def build(code, spec, a):
    src = lambda sid, name: os.path.join(a.cache, sid, name)
    lang = spec["language"]
    pack = json.load(open(os.path.join(a.packs, f"{code}.json"), encoding="utf-8"))
    entries = pack["entries"]
    um = load_unimorph(src(f"unimorph-{lang['unimorph']}", lang["unimorph"]))
    sentences = load_tatoeba(src(f"tatoeba-{code}", f"en-{code}.txt.zip"), code)
    key = keyer(code)
    known = {key(e["w"]) for e in entries}
    verbal, nominal = set(), set()
    for lemma, para in um.items():
        for form, tags in para:
            f = key(form)
            known.add(f)
            if "V" in tags and "PTCP" not in tags:
                verbal.add(f)
            if "N" in tags or "ADJ" in tags:
                nominal.add(f)
    finite = verbal
    for u in spec["units"]:
        for g in u.get("grids", []):
            for r in g["rows"]:
                known.update(key(w) for f in r[2] if f for w in f.split())
                if u.get("verbForms") or u.get("before"):
                    finite.update(key(w) for f in r[2] if f for w in f.split())
        for forms in u.get("verbs", {}).get("extra", {}).values():
            for f in forms.values():
                finite.update(key(w) for w in f.split())
                known.update(key(w) for w in f.split())
    deck_verbs = [e["w"] for e in entries if e["p"] == "verb" and " " not in e["w"]]
    verbal.update(key(v) for v in deck_verbs)
    # Spellings the vocabulary lists under another part of speech; corpus-derived cells with these spellings are skipped.
    homographs = {"verb": {key(e["w"]) for e in entries if e["p"] not in ("verb",)} - {key(v) for v in deck_verbs},
                  "noun": {key(e["w"]) for e in entries if e["p"] not in ("noun",)} - {key(e["w"]) for e in entries if e["p"] == "noun"}}
    aux = {key(w) for w in lang.get("auxiliaries", [])}
    ctx = {"lang": dict(lang, code=code), "key": key, "um": um, "known": known, "verbal": verbal, "nominal": nominal, "finite_aux": aux, "homographs": homographs,
           "verbs": list(dict.fromkeys(deck_verbs)), "nouns": [], "latin_verbs": {},
           "participles": participles(code, um, deck_verbs, lang.get("participles", []), lang.get("notParticiples", []))}
    # A deck noun's or adjective's inflected forms can't be read as verbs, nor a deck verb's forms as nouns (vino, canes, regis).
    for e in entries:
        if e["p"] in ("noun", "adjective") and e["w"] in um:
            homographs["verb"].update(key(f) for f, tags in um[e["w"]] if "N" in tags or "ADJ" in tags)
        if e["p"] == "verb":
            homographs["noun"].update(key(w) for w in (e.get("m") or "").replace(",", " ").split() if not w.startswith("-"))
            if e["w"] in um:
                homographs["noun"].update(key(f) for f, tags in um[e["w"]] if "V" in tags)
    if code == "la":
        by_fold = defaultdict(list)
        for lm in um:
            by_fold[fold(lm)].append(lm)
        nouns = []
        for e in entries:
            if e["p"] != "noun":
                continue
            lm = e["w"] if e["w"] in um else (by_fold.get(fold(e["w"]), [None])[0] if len(by_fold.get(fold(e["w"]), [])) == 1 else None)
            if lm:
                nouns.append(lm)
        ctx["nouns"] = list(dict.fromkeys(nouns))
        ctx["latin_verbs"] = {e["w"]: v for e in entries if e["p"] == "verb" for v in [latin_verb(e["w"], e.get("m"), e.get("v"))] if v}
        homographs["noun"].update(key(f) for v in ctx["latin_verbs"].values() for forms in v.values() for f in forms)
    units = []
    for u in spec["units"]:
        grids = build_grids(u, ctx)
        items = make_items(u, grids, sentences, ctx)
        out = {"id": u["id"], "level": u["level"], "title": u["title"], "en": u["en"], "note": u["note"]}
        if "table" in u:
            out["table"] = model_table(u, grids)
        out["items"] = items
        if len(items) < a.min_items:
            raise SystemExit(f"{u['id']}: only {len(items)} items (need {a.min_items}); widen its grids or levels")
        units.append(out)
        print(f"  {u['id']:<28} {u['level']:<4} {len(grids):>4} grids {len(items):>3} items")
    levels = [l for l in lang["levels"] if any(u["level"] == l for u in units)]
    return {"code": code, "schema": 1, "license": "CC BY-SA 4.0",
            "attribution": LATIN_ATTRIBUTION if code == "la" else ATTRIBUTION, "levels": levels, "units": units}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", default=os.path.join(ROOT, ".cache", "sources"))
    ap.add_argument("--specs", default=os.path.join(ROOT, "Scripts", "grammar"))
    ap.add_argument("--packs", default=os.path.join(ROOT, "ExUno", "Resources", "Packs"), help="vocabulary packs from build_packs.py")
    ap.add_argument("--out", default=os.path.join(ROOT, "ExUno", "Resources", "Packs"))
    ap.add_argument("--only", action="append", default=[], help="language code (repeatable)")
    ap.add_argument("--min-items", type=int, default=12)
    a = ap.parse_args()
    for code in ["it", "es", "fr", "la"]:
        if a.only and code not in a.only:
            continue
        spec = json.load(open(os.path.join(a.specs, f"{code}.json"), encoding="utf-8"))
        print(f"grammar-{code}")
        course = build(code, spec, a)
        path = os.path.join(a.out, f"grammar-{code}.json")
        os.makedirs(a.out, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(course, f, ensure_ascii=False, separators=(",", ":"))
        print(f"grammar-{code}.json", len(course["units"]), "units", sum(len(u["items"]) for u in course["units"]), "items",
              f"{os.path.getsize(path) / 1e3:.0f} kB")


if __name__ == "__main__":
    main()
