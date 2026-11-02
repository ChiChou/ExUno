# Ex Uno: Latin & Romance

<img src="ExUno/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="Ex Uno app icon" width="128" height="128">

*Out of one, many.*

Learn a language the way you meet it: on receipts, clocks, train tickets and stone inscriptions. A native iOS app (SwiftUI, iOS 18+) for English speakers learning **Italian, Spanish, French or Latin**, with home-screen widgets and iCloud sync.

## What's in it

- **First run** asks for a language, a starting level and a daily goal. Switch language any time from the badge on Today; every language keeps its own progress. The gear next to it opens Settings.
- **Today**: the time and date said in the language (Latin: today's Roman date, *ante diem III Nōnās Novembrēs*), today's session, the next grammar lesson, a five-item listening challenge that's the same all day, and your streak and last two weeks.
- **Cards**: *Roam* (a shuffled list of words with their meanings; swipe back and forth, nothing recorded), *Flow* (answer visible, swipe, mark hard ones) or *Recall* (hide, say it, grade yourself). Every fifth card is a real-life object: a receipt, a clock, a ticket, a deli tag; in Latin a carved inscription or a calendar stone. Level range is always contiguous.
- **Grammar**: a short course per language (A1–B1; Latin I–III) with a rule, a table and fill-in-the-blank practice on real sentences, plus the verb conjugator. See [`docs/GRAMMAR.md`](docs/GRAMMAR.md).
- **Tools**: one row per converter. Italian, Spanish and French: numbers (cardinal, ordinal, percent, degrees, floor), prices, time, dates, phone numbers, market quantities, years and centuries. Latin: numerals (words ↔ Roman), the Roman calendar, years *ab urbe conditā*. Each converter also has a listening drill.
- **Words**: search both directions, or browse my deck, phrases, levels and topics; Wiktionary definitions when you're online.
- **Widgets**: *Clock* (time in the language, small/medium/lock screen) and *Flashcard* (a random word from your levels with its meaning, a new one every half hour; tap it to roam on from that word in Cards, nothing is recorded).
- **Quick actions**: long-press the app icon to open one of the first four converters.
- **iCloud**: progress and settings sync through iCloud key-value storage on every device signed in to the same Apple ID.

## Roadmap

- **Portuguese** is the next language. The same upstream deck has Brazilian and European Portuguese lists under MIT, so it can follow the Spanish and French pipeline; it needs a number, time and date engine and a conjugator.
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
| `ExUnoTests/` | unit tests (number, time, date, calendar and verb rules for all four languages) |

## Data

`Scripts/prepare_data.sh` downloads every input listed in `Scripts/sources.json` (pinned commits, SHA-256 checked). It builds the Italian topic tags from Open Multilingual Wordnet and writes `ExUno/Resources/Packs/{it,es,fr,la}.json` plus the grammar courses `grammar-{it,es,fr,la}.json` ([`docs/GRAMMAR.md`](docs/GRAMMAR.md)). A GitHub workflow runs the same script and publishes the result as the `packs` release. See [`docs/DATA.md`](docs/DATA.md) for the steps and the pack format.

## Licenses

The code is MIT (`LICENSE`). The generated packs are CC BY-SA 4.0 and carry their attribution inside each file. [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md) lists every source; [`docs/LICENSING.md`](docs/LICENSING.md) is the compatibility review, including what is deliberately not used. Upstream license texts are in `LICENSES/`.
