# Ex Uno: Latin & Romance

<img src="ExUno/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="Ex Uno app icon" width="128" height="128">

*Out of one, many.*

Learn a language the way you meet it: on receipts, clocks, train tickets and stone inscriptions. A native iOS app (SwiftUI, iOS 18+) for English speakers learning **Italian, Spanish, French, Portuguese or Latin**, with home-screen widgets and iCloud sync.

## What's in it

- **First run** asks for a language, a starting level and a daily goal. Switch language any time from the badge on Today; every language keeps its own progress. The gear next to it opens Settings.
- **Today**: the time and date said in the language (Latin: today's Roman date, *ante diem III Nōnās Novembrēs*), today's session, the next grammar lesson, a five-item listening challenge that's the same all day, and your streak and last two weeks.
- **Cards**: *Roam* (a shuffled list of words with their meanings; swipe back and forth, nothing recorded), *Flow* (answer visible, swipe, mark hard ones) or *Recall* (tap to flip, flick sideways to move on, pull down to see it again soon). Undo restores the previous review and its schedule. Every fifth card is a real-life object: a receipt, a clock, a ticket, a deli tag; in Latin a carved inscription or a calendar stone. Level range is always contiguous.
- **Grammar**: a short course per language (A1–B1; Latin I–III) with a rule, a table and fill-in-the-blank practice on real sentences, plus the verb conjugator. See [`docs/GRAMMAR.md`](docs/GRAMMAR.md).
- **Tools**: a preview card for each converter, with examples in the selected language. Italian, Spanish, French and Portuguese: numbers (cardinal, ordinal, percent, degrees, floor), prices, time, dates, phone numbers, market quantities, years and centuries. Latin: numerals (words ↔ Roman), the Roman calendar, years *ab urbe conditā*. Hear each result with pronunciation playback; market quantities offer g, kg, ml, cl and L, plus Italian etti and French/Portuguese dl, with decimal input and quantity-preserving unit changes. Listening practice lives in Today's daily challenge.
- **Regional editions**: Spain Spanish, broad Latin American Spanish, European Portuguese, and Brazilian Portuguese have separate progress and voices. Latin American Spanish teaches tú/usted/ustedes; its default voice is Mexican Spanish, with other installed Spanish voices selectable in Settings. Prices currently teach euros across all editions.
- **Portuguese (European)**: 8,470 vocabulary entries, 11 grammar units with 436 exercises, and 3,999 bundled verb paradigms. Speech uses `pt-PT`.
- **Words**: search both directions, or browse my deck, all words, phrases and topics, sorted A–Z by the bare word with a letter index to slide along; Wiktionary definitions when you're online.
- **Level range**: one range per language, set from Settings, the Cards options or the badge on Words. Cards, the Flashcard widget and the Words directories follow it; search, my deck and the grammar course show every level.
- **Widgets**: *Clock* (time in the language, small/medium/lock screen) and *Flashcard* (a random word from your levels with its meaning, a new one every half hour; tap it to roam on from that word in Cards, nothing is recorded).
- **Quick actions**: long-press the app icon to open one of the first four converters.
- **iCloud**: progress and settings sync through iCloud key-value storage on every device signed in to the same Apple ID.

## Roadmap

- Romanian is not planned yet: there is no openly licensed, levelled vocabulary list comparable to the others.

## Build

The vocabulary packs are generated, not committed. Get them once, either prebuilt from the `packs` release or built locally from the public sources (Python 3.9+, standard library only):

```sh
sh Scripts/download_packs.sh   # prebuilt
sh Scripts/prepare_data.sh     # or build them yourself
```

Then open `ExUno.xcodeproj` and run the `ExUno` scheme on iOS 18 or later. To install on your own device:

1. Create `Local.xcconfig` next to `Signing.xcconfig` with `DEVELOPMENT_TEAM = <your team ID>`. It is git-ignored, so your team stays out of the repository.
2. Replace the `me.chichou.ExUno` bundle IDs with your own prefix.
3. Replace the App Group `group.me.chichou.ExUno` with your own, in both `.entitlements` files and in `Shared/WidgetBridge.swift`. The app and the widget share the App Group.

iCloud key-value sync needs a paid Apple Developer membership. Without one, remove the iCloud entry from `ExUno.entitlements`; progress then stays on the device.

Folders are Xcode 16 synchronized groups:

| Folder | Targets |
| --- | --- |
| `ExUno/` | app |
| `Shared/` (language engines, widget bridge, palette) | app + widget |
| `ExUnoWidgets/` | widget extension |
| `ExUnoTests/` | unit tests (number, time, date, calendar and verb rules for all language editions) |

## Data

`Scripts/prepare_data.sh` downloads every input listed in `Scripts/sources.json` (pinned commits, SHA-256 checked). It builds the Italian topic tags from Open Multilingual Wordnet and writes `ExUno/Resources/Packs/{it,es,fr,la}.json` plus the grammar courses `grammar-{it,es,fr,la}.json` ([`docs/GRAMMAR.md`](docs/GRAMMAR.md)). A GitHub workflow runs the same script and publishes the result as the `packs` release. See [`docs/DATA.md`](docs/DATA.md) for the steps and the pack format.

## Licenses

The code is MIT (`LICENSE`). The generated packs are CC BY-SA 4.0 and carry their attribution inside each file. [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md) lists every source; [`docs/LICENSING.md`](docs/LICENSING.md) is the compatibility review, including what is deliberately not used. Upstream license texts are in `LICENSES/`.
