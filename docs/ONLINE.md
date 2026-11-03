# Online APIs for language study

This page reviews online services that could add study features to Ex Uno. The candidate integrations below are research for planning; the implemented readers are listed separately below. Checked on 2026-11-01 by calling each API and reading its published terms. It is an engineering review, not legal advice.

## The rule

From [`AGENTS.md`](../AGENTS.md): Ex Uno must work fully offline. An online API is allowed only if it

1. directly supports language study,
2. is optional and opened by the user (a button, never on launch or in the background),
3. shows a clear offline state instead of failing, and
4. is listed on the *Data & licenses* screen, in `ATTRIBUTIONS.md` ("Online services") and in [`LICENSING.md`](LICENSING.md).

Content and API terms follow `LICENSING.md`: non-commercial (NC), no-derivatives (ND) or unclear terms are a reject. An API that needs a secret key is also a reject. Ex Uno is distributed as source, so a key would either be committed to a public repository or have to be supplied by everyone who builds the app.

Current runtime readers are the Wiktionary REST definitions sheet (`WiktionaryView` in `ExUno/Features/Words/WordsView.swift`) and the optional Wikipedia year article sheet (`YearWikipediaSheet` in `ExUno/Features/Tools/YearWikipediaSheet.swift`). Wiktionary sends `User-Agent: ExUno/<version> (https://github.com/ChiChou/ExUno)` and shows "Could not reach Wiktionary." when offline. Wikipedia opens `https://{language}.wikipedia.org/wiki/{year}` only after a tap in Years, loads the original page and Wikimedia assets in a nonpersistent web view, and shows a connection message with Retry if unavailable offline. Spanish and Portuguese regional packs share their language's Wikipedia edition. No article is prefetched; following a link inside the sheet loads that destination.

## Summary

| Candidate | Would enable | Where | Key? | Content license | Call |
| --- | --- | --- | --- | --- | --- |
| Wikimedia Commons audio (Lingua Libre and Shtooka recordings, found via Wiktionary) | Native-speaker recording of a word | Words detail, Wiktionary sheet; later the back of a card in Cards | No | Per file; mostly CC BY-SA 4.0 or CC BY 3.0, must be filtered | **Recommend** |
| Wiktionary IPA (`page/html`) | IPA transcription next to the word | Wiktionary sheet in Words | No | CC BY-SA 4.0 | **Recommend** |
| Tatoeba API, `/v1/sentences` | More example sentences with translations | Words detail ("More examples") | No | Sentences CC BY 2.0 FR (some CC0) | **Recommend** (text only) |
| Tatoeba sentence audio | Recorded example sentences | Same | No | Per recording; many are CC BY-NC or "permission only" | Reject unless filtered to free licenses; defer |
| Wiktionary inflection tables | Full paradigms | Words detail | No | CC BY-SA 4.0 | Reject: the app already conjugates offline from UniMorph and its own rules |
| Wikidata Lexemes | Forms, senses, IPA, audio as data | Words detail | No | CC0 | Reject for now: patchy coverage, no gain over Wiktionary |
| Latin Wiktionary (la.wiktionary.org) | Latin definitions written in Latin | Wiktionary sheet | No | CC BY-SA 4.0 | Reject: 38k pages against 46k Latin lemmas on English Wiktionary, which the app already uses |
| Perseus / Logeion | Lewis & Short and other Latin dictionaries | Words (Latin) | — | L&S is CC BY-SA 4.0 at Perseus; Logeion has no public API or terms | Reject online; **bundle L&S offline instead** |
| LanguageTool public API | Checking a typed sentence | A future writing exercise in Grammar | No (free tier) | No content; proprietary service | Reject for now |
| Forvo | Recorded words | — | Yes, paid | Forvo's own license; free plan non-commercial | Reject |
| DeepL API | Machine translation | — | Yes, secret | Proprietary | Reject |
| LibreTranslate (libretranslate.com) | Machine translation | — | Yes, paid ($14+/month) | — | Reject |

## Candidates in detail

### Wikimedia Commons audio (Lingua Libre, Shtooka)

- **What.** Wiktionary pronunciation sections link recordings stored on Commons. For example `parlare` links `It-parlare.ogg` (Shtooka, CC BY 3.0 US). Lingua Libre recordings are uploaded to Commons as `LL-Q652 (ita)-<speaker>-<word>.wav`, by default under CC BY-SA 4.0. Commons category sizes today: French 439,592 Lingua Libre files, Spanish 19,178, Italian 12,638, Latin 213.
- **License and terms.** Each file has its own license, read from `imageinfo` → `extmetadata` (`LicenseShortName`, `Artist`). Allow only CC0, public domain, CC BY and CC BY-SA, and drop anything else. Playing a file unmodified needs attribution: show the speaker, the license and a link to the file page. API use falls under the Wikimedia [Terms of Use](https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use) and [API access policy](https://www.mediawiki.org/wiki/Wikimedia_APIs/Access_policy).
- **Key, limits.** No key. Since 2026 Wikimedia [enforces rate limits](https://www.mediawiki.org/wiki/Wikimedia_APIs/Rate_limits): 200 requests per minute for clients with a compliant User-Agent (the app's already is), 10 per minute without one, at most 3 concurrent requests, and `Retry-After` on 429. One tap is 1–2 requests.
- **Privacy.** The word looked up, the device's IP address and the User-Agent go to Wikimedia. No account or identifier.
- **Feature and UI.** A "Recording" button beside the existing `SpeakButton` in the word detail and the Wiktionary sheet. It plays the native recording and keeps the device voice as the default.
- **iOS detail.** `AVPlayer` does not play Ogg or WAV from Commons reliably. Request `videoinfo` with `viprop=derivatives` and play the `audio/mpeg` transcode (`…/transcoded/…/<file>.mp3`). Both test files above had one.
- **Offline.** The button stays visible. Tapping it without a connection shows "Recordings need a connection. The device voice still works." and speaks with the device voice.
- **Call: recommend.** A real study gain, especially for French and Spanish, with no new host or privacy surface.

### Wiktionary IPA

- **What.** The definition endpoint returns no pronunciation. `GET https://en.wiktionary.org/api/rest_v1/page/html/<term>` returns the rendered page, where IPA sits in `<span class="IPA">` (for `parlare`: `/parˈla.re/`). Take the first IPA span inside the target language's section.
- **License and terms.** CC BY-SA 4.0. The sheet already credits Wiktionary contributors and links the page.
- **Key, limits, privacy.** As for Commons: same host, same request, same rate limits.
- **Feature and UI.** One line under the headword in the Wiktionary sheet. The HTML covers every language on the page, from about 50 kB (`maison`) to over 500 kB (`amo`), so fetch it only when the sheet opens, not per list row.
- **Offline.** Already handled by the sheet's "Could not reach Wiktionary." state.
- **Stability.** The REST API runs on RESTBase, which Wikimedia has been [deprecating](https://www.mediawiki.org/wiki/RESTBase/deprecation) since 2019. The definition endpoint is still labelled experimental. Both still answer today. The Action API (`action=parse&prop=text`) is the fallback for HTML if the REST routes go.
- **Call: recommend.** Cheap to add to the sheet that already exists.

### Tatoeba API

- **What.** `GET https://api.tatoeba.org/v1/sentences?lang=ita&q=casa&trans:lang=eng&sort=relevance&limit=5`. The API's OpenAPI description says `/v1` endpoints are stable and `/unstable` ones may change; sentence search and single sentences are already under `/v1`. Each result carries `license`, `owner` and `is_unapproved`, and its translations do too.
- **License and terms.** Sentences are CC BY 2.0 FR, a few CC0, the same terms as the bundled grammar courses. Credit the owner and link `https://tatoeba.org/sentences/show/<id>`. Skip `is_unapproved` sentences. The API is public, read-only and needs no key; there's no published rate limit, and the [terms of use](https://tatoeba.org/en/terms_of_use) put no restriction on API reads.
- **Audio.** Recordings have their own licenses. One test sentence's audio was CC BY-NC 4.0, and the terms say some audio is under no Creative Commons license at all. Only recordings marked CC0, CC BY or CC BY-SA could be played. Leave audio out of the first version.
- **Privacy.** The search word and the IP address go to tatoeba.org.
- **Feature and UI.** "More examples" in the word detail, under the bundled example: three to five sentences with translations, each with a `SpeakButton` (device voice) and the owner's name.
- **Offline.** "More examples need a connection." The bundled example stays.
- **Call: recommend** (text only). The decks have one machine-generated example per word; Tatoeba adds real ones under a license the project already uses.

### Wiktionary inflection tables

The HTML from `page/html` contains full conjugation and declension tables. The app already shows conjugations offline (UniMorph-derived data and its own rules, including Latin), so fetching them online adds a dependency for little gain. **Reject.** It could serve as a check against the offline tables during development.

### Wikidata Lexemes

CC0 structured data with forms and senses: `L58445` (`parlare`) has 51 forms but no IPA or audio statements. Coverage of pronunciation and translations is thin next to Wiktionary. **Reject for now.** CC0 makes it a candidate for build-time data later.

### Latin Wiktionary

la.wiktionary.org has about 38,000 pages, with definitions written in Latin. English Wiktionary has 46,149 Latin lemmas plus macron headwords and full paradigms, and the app already calls it. **Reject.**

### Perseus and Logeion

Logeion (University of Chicago) has no documented public API and publishes no terms for one. **Reject.** Its dictionaries are available at the source, though: the [PerseusDL/lexica](https://github.com/PerseusDL/lexica) repository holds Lewis & Short as TEI XML under CC BY-SA 4.0, with credit to the Perseus Digital Library. That fits the offline-first rule better than any online Latin dictionary: `Scripts/prepare_data.sh` could build a trimmed Lewis & Short for the DCC core words, or the whole dictionary, into the Latin pack. That's a data task, not an online feature.

### LanguageTool public API

- **Terms.** `POST https://api.languagetool.org/v2/check`, free and without a key, limited to 20 requests per IP per minute as a peak, 75 KB per minute and 20 KB per request ([public API page](https://dev.languagetool.org/public-http-api)). The page says: don't send automated requests; there are no guarantees and behaviour changes without warning; the app must tell users how their text is handled; and it must show a visible link back to languagetool.org. Italian, Spanish and French are supported. Latin is not.
- **Privacy.** The whole sentence the learner typed goes to LanguageTool, now part of Learneo. Its [privacy policy](https://languagetool.org/legal/privacy) is a broad company policy covering tracking and session replay on its own sites.
- **Fit.** Ex Uno has no free-writing exercise. Grammar practice is tap-to-choose, and the only text field in a drill takes numbers. Grammar errors in a learner's sentence would need a new exercise type first.
- **Call: reject for now.** Revisit only if a writing exercise is planned, and then compare it with a self-hosted LanguageTool server (LGPL), which a source-built app can't assume either.

### Forvo

The API needs an account and a key. The cheapest plan is $2/month for 500 requests a day with commercial use not allowed ([plans](https://api.forvo.com/plans-and-pricing)). Forvo dropped its CC BY-NC-SA terms in 2019 for its own license. **Reject:** paid, keyed, non-commercial. Commons covers the same need under free licenses.

### Machine translation: DeepL, LibreTranslate

- **DeepL API Free.** It needs an account, a card for verification and a secret authentication key; it has 500,000 characters a month and no Latin. A key can't ship in a public source repository.
- **LibreTranslate.** The hosted API at libretranslate.com needs a paid key ($14–58 a month, no free tier). The software (AGPL) can be self-hosted, but a source-built iOS app can't assume a server. Argos models have no Latin.
- **Fit.** Free-text translation is a general tool rather than a study feature. The packs and Tatoeba already pair every word and example with English. Apple's on-device Translation framework covers it offline for Italian, Spanish and French if it's ever wanted.
- **Call: reject both.**

## What to build next

1. **Native recordings** from Commons, reached through the word's Wiktionary page or a Lingua Libre file-name search. Filter to free licenses, play the MP3 transcode and credit the speaker, with the device voice as the offline fallback. Biggest gain for listening practice, especially French with 440k Lingua Libre files.
2. **IPA in the Wiktionary sheet**, from `page/html` on the same host the app already calls. Use the same macron-free Latin title as the definitions lookup (below).
3. **More Tatoeba examples** in the word detail, text only, from the stable `/v1/sentences` endpoint, with owner credit.

Each needs the same new rows in *Data & licenses*, `ATTRIBUTIONS.md` and `LICENSING.md` (Wikimedia Commons; Tatoeba API), a `Retry-After`-aware single request per tap, and the offline message from the sections above. Also consider bundling Lewis & Short for Latin at build time (see Perseus above); it isn't an online feature.

## Found in passing

The Wiktionary sheet used to fail for most Latin words. It looked up `entry.word`, which carries macrons from DCC (`nōn`, `quī`), but English Wiktionary titles Latin pages without them: `page/definition/nōn` returns 404 and `page/definition/non` returns 200. Fixed: for Latin, `WiktionaryView` now folds diacritics (`nōn` → `non`, `aër` → `aer`) before the request and in the link back. The sheet still shows the word with macrons.
