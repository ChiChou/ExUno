#!/usr/bin/env python3
"""Bundle complete Portuguese finite paradigms from pinned UniMorph por (CC BY-SA 3.0).

No runtime source access. Include all attested lemmas, not just vocabulary headwords,
so typing a verb in the reference tool works independently of deck filters.
"""
import json
from pathlib import Path
from build_grammar import load_unimorph, um_form, PERSONS

ROOT = Path(__file__).resolve().parent.parent
TENSES = {'prs': 'IND;PRS', 'pfv': 'IND;PST;PFV', 'ipfv': 'IND;PST;IPFV',
          'fut': 'IND;FUT', 'cond': 'COND', 'sbjv': 'SBJV;PRS'}


def main():
    source = ROOT / '.cache/sources/unimorph-por/por'
    verbs = {}
    for lemma, paradigm in load_unimorph(source).items():
        tenses = {}
        for key, tag in TENSES.items():
            forms = [um_form(paradigm, f'V;{tag};{person}') for person in PERSONS]
            if all(forms) and all(' ' not in f for f in forms):
                tenses[key] = forms
        if tenses:
            verbs[lemma] = tenses
    if not all(v in verbs and len(verbs[v]) == len(TENSES) for v in ['ser', 'estar', 'ter', 'ir', 'falar', 'comer', 'partir']):
        raise SystemExit('Portuguese paradigms missing a required core verb/tense')
    pack = {'code': 'pt', 'schema': 1, 'license': 'CC BY-SA 4.0',
            'attribution': 'UniMorph por (source: Wikipedia), CC BY-SA 3.0; adapted to six-person finite tables by Ex Uno. https://github.com/unimorph/por',
            'verbs': verbs}
    out = ROOT / 'ExUno/Resources/Packs/verbs-pt.json'
    out.write_text(json.dumps(pack, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(out.name, len(verbs), 'verbs', out.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
