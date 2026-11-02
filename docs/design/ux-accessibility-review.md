# Ex Uno: learner UX and accessibility review

Reviewed: 2026-11-02. This is a handoff for a separate implementation agent; no application code was changed during the review.

## Product intent: preserve Roam

The owner clarified that **Roam is intentionally the first/default option**. It supports opening the phone, casually reading, swiping, and learning incidentally without committing to a study session. Preserve this low-pressure use case. Do not add mandatory grading, daily-goal obligations, or a tutorial gate to Roam.

The problem is the entrance from **Today**, not Roam itself. A Start button underneath a daily progress counter promises an activity that advances that counter.

Recommended entrance organization, discussed with the owner:

- **Cards:** retain Roam as the first option and preserve the casual browsing entrance.
- **Flashcard widget:** continue into Roam from the selected word, without grading it.
- **Today → Start today's practice:** explicitly enter a tracked Flow or Recall session.
- Entering practice from Today should not permanently overwrite the learner's casual browsing preference. Preserve the distinction between a navigation request and a saved mode preference.

## Evidence and limits

- Built the current worktree successfully and ran it on a fresh iPhone 17 simulator, iOS 27.2, named `ExUno UX Review`.
- Selected Italian, A1 / Just starting, and a 10-card daily goal.
- Browsed Roam; completed a tracked 10-review Cards session including a real-life ticket; completed 10 grammar questions; explored Words/My Deck and word details; used price conversion and a listening drill; switched to Latin and back.
- Wrong answers were deliberately submitted to inspect correction and completion states. The resulting grammar score is not evidence of actual learner ability or overall course difficulty.
- Checked light and dark appearance across the main tabs and Settings. Exercised the largest accessibility text size on Today, Cards, Words, and grammar. Also checked dark appearance with Increase Contrast enabled.
- Accessibility findings combine rendered screens, the exposed accessibility tree, and source inspection. This was **not** a complete spoken VoiceOver, Switch Control, or physical-device audit.
- Did not verify airplane-mode behavior, all language courses, all real-life object types, every converter, widgets at runtime, or every device size.
- Restored the review simulator to light appearance, `large` (normal) content size, and Increase Contrast disabled.
- Existing uncommitted changes were present in `ExUnoApp.swift`, `CardsView.swift`, `DeckEngine.swift`, and `README.md`. Preserve that work; recheck the current tree before patching.

## Priority 1: entrance and accessibility defects

### 1. Today starts an untracked activity

**Observed:** On the fresh install, Today showed 0/10. Its Start button opened Roam. After advancing three cards and returning to Today, progress remained 0/10. Switching manually to Recall enabled tracked progress.

**Cause:** `TodayView.sessionCard` only sets `router.tab = .cards`; Cards defaults to the persisted `cards.roaming` state.

**Change:** Route an explicit study request from Today, retaining the Roam behavior described above. Make the button wording identify practice.

**Acceptance:** With Roam selected, Today Start/Continue enters tracked practice; completing a response advances the relevant goal; ordinary browsing and widget entrances still open Roam without recording grades. Check both when Cards is already mounted and when it is opened for the first time.

**Files:** `ExUno/Features/Today/TodayView.swift`, `ExUno/App/ExUnoApp.swift` (`Router`, `RootTabs`), `ExUno/Features/Cards/CardsView.swift`, `ExUno/Features/Cards/DeckEngine.swift`.

### 2. Shared speaker control has insufficient contrast

**Observed:** Idle speaker icons on clock/converter readouts are difficult to see in dark mode. Active speaker icons lose contrast in both themes. Increase Contrast did not resolve the readout problem.

Calculated from the configured colors, compositing the translucent button background over the slab:

| Element/state | Light | Dark |
| --- | ---: | ---: |
| Idle speaker on a readout | 8.33:1 | **2.19:1** |
| Active speaker | **2.31:1** | **1.71:1** |
| Primary button label | 5.23:1 | 7.33:1 |
| Secondary text on the main surface | 5.66:1 | 7.30:1 |

The broader palette does not need indiscriminate replacement. One smaller issue: the light-mode gender tag is approximately **4.49:1**, narrowly below the 4.5:1 small-text benchmark.

**Cause:** `SpeakButton.foreground` uses `Theme.bg` for idle `onDark` controls and `Theme.ink` on the active amber background. Those adaptive colors are unsuitable for these backgrounds in some appearances.

**Change:** Define suitable foreground/background pairs for idle and active speech controls. Adjust the gender tag pair slightly.

**Acceptance:** Verify all speech-button variants, including small buttons, on slabs and ordinary surfaces, idle and playing, in both appearances. Aim for at least 3:1 for meaningful control icons and 4.5:1 for ordinary small text. Recalculate after changes; inspect the actual rendered states too.

**Files:** `ExUno/Support/Theme.swift` (`SpeakButton`, `Tag`), `Shared/Palette.swift`.

### 3. Dynamic Type enlarges the wrong parts of the learning hierarchy

**Observed:** At maximum accessibility size, English translations and progress counters enlarge substantially, while target-language examples, answer options, headings, badges, and primary buttons often stay small. The counter in the Cards header wraps while the fixed-width mode selector consumes most of the row.

**Cause:** Many views use fixed `.system(size:)` fonts, including `Theme.display` and `Theme.mono`, alongside scalable semantic styles. Several controls assume a fixed horizontal layout.

**Change:** Use scalable fonts for learning content and controls; adapt crowded rows at accessibility sizes. Keep the target language at least as readable as its translation. Review fixed-size grading labels and their scale-down behavior too.

**Acceptance:** At normal, XXXL, and the largest accessibility size, inspect Today, Cards in every mode, grammar rules/practice, word details/conjugations, Settings, and tools. Essential content must enlarge and remain reachable without overlapping controls. Use scrolling/reflow where necessary rather than shrinking essential text.

**Files:** `Shared/Palette.swift`, `ExUno/Support/Theme.swift`, the feature views under `ExUno/Features/`.

### 4. Words topic grid truncates at accessibility sizes

**Observed in both themes:** The three-column grid persists at maximum text size. “Animali” becomes “Ani- / mali”; “Abbigliamento” becomes “Ab- / bigli…”. Counts become visually dominant while level labels stay small.

**Change:** Use fewer columns or a single-column list at accessibility sizes. Allow meaningful labels to wrap without truncation.

**Acceptance:** Long topic names and level counts are readable in full at the largest supported size, including on narrower phones.

**File:** `ExUno/Features/Words/WordsView.swift` (level/topic grids).

### 5. Hidden listening transcript is exposed to accessibility

**Observed:** Before Show text was activated, the accessibility tree already contained the full blurred transcript in the daily challenge and a price listening drill.

**Cause:** `DrillPrompt` visually blurs `Text(item.spoken)` but leaves it exposed to accessibility.

**Change:** Remove or hide the transcript from accessibility until the learner reveals it or submits the answer. Keep an accessible, optional transcript action.

**Acceptance:** Neither ordinary accessibility navigation nor reading the exercise container exposes the transcript before reveal. Revealing it makes it accessible; checking the answer still reveals the correction normally.

**File:** `ExUno/Features/Today/TodayView.swift` (`DrillPrompt`, shared with tools).

## Priority 2: labels, controls, and the learning loop

### 6. Improve accessible names, state, and touch targets

Observed/source-confirmed issues:

- Settings pickers have empty labels and expose bare values such as “10” or “Automatic,” separately from the visible row label.
- Multiple buttons are simply “Listen,” with no distinction between a word, example, or conversion. Their action label stays “Listen” during playback.
- The transcript button remains “Show text” after the text is visible, although its icon changes to `eye.slash`.
- Answer/conversion fields rely on placeholders or values rather than explicit purpose labels.
- Several defined control areas are small: 32×32 pt small speakers and Settings, 40×40 pt regular speakers, and 34 pt-high chips/compact pills.

**Change:** Give controls contextual names and values, use “Stop playback” and “Hide text” when appropriate, and supply persistent field labels. Increase tappable areas to at least 44×44 pt while retaining smaller visual icons if desired. Verify actual hit regions, not just apparent icon size.

**Files:** `ExUno/Support/Theme.swift`, `ExUno/Features/Settings/SettingsView.swift`, `ExUno/Features/Today/TodayView.swift`, other `SpeakButton` call sites.

### 7. Beginner onboarding promises need clearer follow-through

**Observed:** English onboarding immediately switches navigation/actions into Italian after choosing Italian, including Inizia, Esercitati, and Mostra. Latin similarly uses Latin navigation. Selecting A1 enabled A1–A2; the first Roam cards included A2. The day's Italian challenge started with **86,997**, spoken as *ottantaseimilanovecentonovantasette*.

**Recommendations, subject to product choice:** Offer an independent interface-language preference, initially English; start true beginners with foundational vocabulary and smaller numbers; explain any intentional inclusion of the next level. Preserve optional immersion rather than assuming every learner wants it immediately.

**Files:** `ExUno/Features/Onboarding/OnboardingView.swift`, `Shared/Language/UIStrings.swift`, challenge generation in the language engines, `ExUno/Features/Today/TodayView.swift`.

### 8. Explain modes without burdening Roam

**Observed:** Roam and Flow both show answers, but only Flow records study progress. The labels alone do not explain this distinction.

**Change:** Add a lightweight explanation near the mode choice or in optional help, not a mandatory gate. Suggested meanings: Roam = browse without grading; Flow = answers visible, mark difficult items; Recall = reveal and self-grade. Keep Roam first.

**File:** `ExUno/Features/Cards/CardsView.swift`.

### 9. Grammar corrections need explanations and focused recovery

**Observed:** Wrong-answer feedback such as “Era il” and “m. sing.” supplies the answer but little explanation. An intentionally unsuccessful round ended with a score and Again, without a focused mistake review.

**Change:** Explain the specific rule in beginner-friendly language, e.g. “Use il because caffè is masculine singular and starts with a consonant.” Offer Review mistakes, Read the rule, and Retry. Make correctness and selected-answer state understandable without relying on color alone; verify feedback announcements with actual VoiceOver.

**Files:** `ExUno/Features/Grammar/GrammarView.swift`, grammar course generation/data definitions.

### 10. Session completion and progress terminology are ambiguous

**Observed:** The Cards summary displayed “8 +”; source inspection identifies this as eight new words. Continue simply returned to more cards. There was no dedicated finish-for-today action or focused retry of the missed ticket exercise. The existing summary can list vocabulary still scheduled for today; it is not entirely missing a review list.

The goal also needs a consistent definition: onboarding says real-life cards come “on top,” but real-life answers increment the shared reviews count. Grammar answers also increased the Today counter, which is labeled as cards. Settings shows Daily goal and New words per day without explaining their relationship.

**Change:** Label New words explicitly; offer Finish for today, Review difficult items, and Keep studying. Decide and explain what contributes to the daily goal, then align onboarding, counters, settings, and summaries. Do not make Roam count as graded study merely to simplify the counter.

**Files:** `ExUno/Features/Cards/CardsView.swift` (`SessionSummaryView`), `ExUno/Data/Progress.swift`, `ExUno/Data/Grammar.swift`, Today, onboarding, and Settings.

### 11. Connect My Deck to review

**Observed:** My Deck provides saved words and useful details, but no visible Due/Difficult/New status or action to start a focused review of that selection. Word details have no visible Close button.

**Change:** Expose useful review status and a review entrance for saved/filtered words. Add an explicit dismissal action to the word detail sheet. Keep dictionary browsing available independently.

**File:** `ExUno/Features/Words/WordsView.swift`, related deck routing/scheduling.

## Lower-priority visual improvements

- Consider moving the Today practice card above the clock/date readout so the main action is easier to find.
- Rebalance large flashcards: substantial unused space separates content from the grading controls at normal text size. Preserve room for text growth and scrolling.
- Recall currently offers an inline reveal button and a bottom reveal button. Consider one clearer primary action.
- Replace listening statistics such as `0 / 0 · 0 · 0` with understandable labels.

## Preserve what works

- Warm palette, readable default typography, bilingual examples, and conjugation tables.
- Real-life ticket/receipt-style exercises as a distinctive part of the app.
- Straightforward tools: entering `3.50` correctly produced Italian wording for €3.50; the listening drill displayed the correct price after an error.
- Per-language progress: Italian progress survived switching to Latin and back.
- Offline-first architecture and bundled study data. Follow `AGENTS.md`; none of these recommendations requires a new runtime network service.

## Patch verification checklist

- [ ] Preserve casual Roam and widget browsing; verify explicit Today practice routing without changing the casual preference.
- [ ] Check contrast in both appearances, including playing/idle speech states and Increase Contrast.
- [ ] Check normal, XXXL, and maximum accessibility text; test a narrower phone as well as the review device.
- [ ] Verify transcript concealment/reveal, contextual control labels, field labels, selected/correct answer state, and result announcements with VoiceOver.
- [ ] Verify touch targets and explicit sheet dismissal.
- [ ] Exercise wrong answers, retries, finish-for-today, and returning to Today; ensure counters and explanations agree.
- [ ] Keep every core screen functional offline. Do not add runtime data fetching to solve content or layout issues.
- [ ] Build and run appropriate existing checks; add focused coverage for changed routing/scheduling behavior where useful.

Contrast references: [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [WCAG non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). These are benchmarks for the findings, not a claim of a complete conformance audit.
