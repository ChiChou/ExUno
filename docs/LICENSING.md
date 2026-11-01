# License compatibility review

This page checks every piece of third-party material in Ex Uno against the project's license plan. It is a careful engineering review, not legal advice.

Ex Uno is distributed as source: anyone who wants the app builds it with Xcode and their own Apple ID. Nothing here depends on an App Store release. The last section lists what to revisit if that changes.

## The plan

| Part | License | Why |
| --- | --- | --- |
| Source code: app, widget, tests, scripts | **MIT** | Original work. |
| Generated vocabulary packs | **CC BY-SA 4.0** | The strictest upstream terms are share-alike (wordfreq frequencies, DCC). |
| Topic tags inside the packs | CC BY 3.0 + WordNet 3.0 license | Both permissive, and compatible with CC BY-SA 4.0 output. |

Code and data are separate works. The app reads the packs as data, so share-alike does not reach the Swift code. The repository ships no data at all, only the scripts that download and build it from pinned, publicly available sources.

## Source by source

| Source | Its license | Used for | Compatible? |
| --- | --- | --- | --- |
| Language-Learning-decks (it, es, fr), © 2025 GENERAL NEURO | MIT | Words, translations, CEFR levels, examples, POS | Yes. Keep the MIT notice. |
| wordfreq frequency data (the decks' `word_frequency`) | CC BY-SA 4.0 | Frequency order (`z`) | Yes. This is why the packs are CC BY-SA 4.0. The wordfreq code (Apache 2.0) is not used. |
| Machine-generated translations and examples in the decks | Released by the deck authors under MIT | Translations, examples | Yes. |
| DCC Latin Core Vocabulary | CC BY-SA (version not stated) | Latin pack | Yes. BY-SA lets adaptations use a later version, so the pack can be BY-SA 4.0. |
| sjhuskey/latin-vocabulary | no license file | Download location of DCC's CSV only | Yes. We use DCC's data, not the mirror owner's own files (his Wheelock merge is not used). |
| MultiWordNet via OMW 2.0 | CC BY 3.0 | Topic tags | Yes (attribution). |
| Princeton WordNet 3.0 via OMW 2.0 | WordNet 3.0 license (BSD-like) | Topic hierarchy | Yes. Keep the notice; Princeton's name may not be used in advertising. |
| Wiktionary REST API (runtime) | CC BY-SA 4.0 | Definitions shown with a link back | Yes. Nothing is bundled. |
| Frankfurter / ECB rates (runtime) | Free reuse with the source acknowledged | Currency estimate | Yes. Credited in the app. |
| Apple system voices, SF Symbols, system fonts | Apple SDK terms | Speech, icons, type | Yes, for apps on Apple platforms. Symbols are referenced by name; none are in the repository. |

## Deliberately not used

The project uses no material under a non-commercial (NC) or no-derivatives (ND) license. This keeps the data usable by anyone, including a possible App Store release later. Examples of attractive sources that are excluded for this reason:

- KELLY Italian/European word lists (CC BY-NC-SA)
- XDailyDialog (CC BY-NC-SA)
- Several open textbook grammar courses (CC BY-NC)

When adding a source, check its license first. The source's NC/ND status decides, not where the file is hosted.

## Attribution checklist

- The in-app *Data & licenses* screen names each source, its license and a link.
- Each generated pack carries `"license"` and `"attribution"` fields.
- `ATTRIBUTIONS.md` has the full notices and citations.
- `LICENSES/` has the upstream license texts.

## If the app is ever published to the App Store

1. **CC BY-SA 4.0 and DRM.** Section 2(a)(5)(C) forbids technical measures that restrict recipients' rights. App Store encryption covers the executable, not the bundled JSON. The identical data is freely rebuildable from this repository. Add a custom license note in App Store Connect saying the vocabulary data is CC BY-SA 4.0.
2. **DCC's "free educational use" wording.** The license itself allows commercial use, but a free app is the closest fit, and DCC asks to be told how the material is used.
3. **Name.** "Ex Uno" is a Latin phrase others use outside language learning; check the App Store and trademark registers first.
