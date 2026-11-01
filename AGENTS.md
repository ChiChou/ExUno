# Notes for coding agents

## Offline first

Ex Uno must work completely offline, for example on a flight. Every screen has to keep working without a network connection.

- Ship study data inside the app. Vocabulary packs and grammar courses are built ahead of time by `Scripts/prepare_data.sh` and bundled, never fetched at runtime.
- An online API is acceptable only when it directly supports language study, as the Wiktionary definitions in Words do. It has to be optional, opened by the user, and must show a clear offline state instead of failing.
- Don't add online features that aren't about language study. The ECB/Frankfurter currency estimate in the Prices tool was removed for this reason.
- A planned exception: language packs may later be downloadable and updatable. The app must still run on the packs it already has.
- List every runtime network call on the in-app *Data & licenses* screen, in `ATTRIBUTIONS.md` ("Online services") and in `docs/LICENSING.md`.
