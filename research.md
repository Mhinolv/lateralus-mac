# Product research — Lateralus for Mac

Research date: 15 October 2026. Code reference: `72f95d8`.

## Executive Summary

- Prioritize control of saved work: text edits, archive export, archive restore, and sketch undo/redo.
- Lateralus already combines daily challenges, twelve disciplines, text, sketches, voice notes, search, and activity metrics.
- The strongest adjacent competitors provide better archive tools. Direct competitors mainly provide creative prompts.
- Privacy alone does not separate Lateralus from every competitor. Diarly supports offline use without an account. Oblique Strategies SE advertises offline use.[S1][S4]
- Keep the distinction: structured creative practice, a local journal, and no scores or AI.
- The ten proposals below need no backend, account, network access, or additional permission.

This report uses live web search and source inspection. No competitor app received a hands-on test. Vendor claims remain vendor claims.
“Main competitors” means the closest workflow alternatives in this sample. Market share and customer demand remain unverified.

The supplied issue list contains only **#1: Team setup: CI, PR template and AGENTS.md**.
This report excludes that work. The orchestrator must check for new issues before it creates feature issues.

I read `AGENTS.md`, `README.md`, `DESIGN_BRIEF.md`, and `.github/pull_request_template.md`.
No separate release or review document appeared in the repository file search.
The design brief has stale visual details. Current code confirms bundled fonts and multiple windows, so neither is a gap.

## Competitors

Prices use US dollars where the source provides a US price. Store prices can differ by region and offer.
Relative weaknesses below are product-fit assessments, not defect reports.

| Product and relationship | Platform | Price | Target user | Standout features | Weakness relative to Lateralus |
|---|---|---|---|---|---|
| Brainsparker — direct creative practice [S1] | iPhone, iPad, Watch, Vision. The compatibility list does not include Mac. | Free download. VIP: $6.99/month, $39.99/year, or $79.99 lifetime. | People who need ideas, writers, and workshop hosts. | Card decks, daily challenges, short courses, and an optional AI coach. | No listed Mac support. Its AI offer conflicts with our product rules. A comparable local response journal is unverified. |
| Oblique Strategies SE — direct lateral prompts [S2] | iPhone, iPad, Watch, Vision. Compatible with Apple silicon Macs on macOS 14+. | $3.99 once. | Artists, designers, musicians, and writers with a creative block. | Random strategy cards, offline access, and interactive mobile widgets. | The app is designed for iPad. Twelve practice disciplines and a text/sketch/voice journal are unverified. |
| Day One — adjacent prompt journal [S3, S8–S12] | Mac, iPhone, iPad, Watch, Android, web, and Windows. | Basic: free. Silver: $49.99/year. Gold price: unverified in this report. | People who keep a personal journal and revisit past entries. | Prompts, templates, filters, media, export, anniversary views, and a Mac menu bar composer. | Audio requires a paid tier. Its broader service and AI offer exceed our local practice scope. |
| Diarly — adjacent prompt journal [S4, S13, S14] | Mac, iPhone, iPad, Watch. | Free tier. Premium has monthly/yearly plans. Exact current regional price: unverified. | People who want a private diary with structure. | Templates, calendar, automatic save, Markdown export, and optional paid PDF export. | No verified equivalent to our twelve creative disciplines. Premium includes cloud and AI features that we exclude. |
| Apple Journal — adjacent built-in journal [S5–S7] | Mac, iPhone, iPad. | Included with supported Apple systems. | People who want a general personal journal. | Entry edits, recovery of deleted entries, PDF export, and print on Mac. | No verified equivalent to our fixed daily lateral challenge or twelve disciplines. |
| Lumosity — adjacent daily brain exercise [S15, S16] | Web on Mac, iOS, Android. | Limited free access and paid subscriptions. Current checkout price: unverified. | People who want cognitive games and progress feedback. | Daily game sets, adaptive difficulty, and score reports. | Scores and performance feedback conflict with our ungraded practice. It is not a native Mac creative journal. |
| Sketchbook Pro — adjacent visual idea journal [S17–S20] | Mac and Windows desktop editions. Separate iOS and Android apps. | Mac: $24.99 once. Other platform prices: unverified. | Artists and people who develop ideas through sketches. | Layers, brushes, undo/redo, image export, and configurable shortcuts. | A daily prompt schedule and text/voice response archive are unverified. Its art tools exceed our brief practice scope. |

## Feature Matrix

**Yes** means that the cited source confirms the capability. **U** means unverified, not absent.
**No** applies only to code-confirmed Lateralus gaps or an explicit product distinction.
Competitor features can vary by platform and tier. The matrix identifies those limits where they matter.

| Product | Daily stimulus | Structured practice | Text / sketch / voice | Find and revisit | Export or restore | Mac access | Local privacy fit |
|---|---|---|---|---|---|---|---|
| Lateralus | Fixed daily prompt | 12 disciplines and guides | Yes / Yes / Yes | Text search, exercise filter, recent entries | No | Native app, shortcuts, multiple windows | No account, network, or AI |
| Brainsparker [S1] | VIP challenges | Cards and courses | Response archive: U | Archive tools: U | U | Not in compatibility list | AI coach offered |
| Oblique Strategies SE [S2] | Random cards. fixed daily schedule: U | Strategy cards | U / U / U | Response archive: U | U | Apple silicon compatibility | Offline. no ads or tracker, per vendor |
| Day One [S3, S8–S12] | Daily prompt | Prompt library and templates | Yes / paid, Mac parity U / paid | Filters and On This Day | JSON, text, PDF. JSON import | Native app and menu bar composer | Cloud service. Gold adds AI |
| Diarly [S4, S13, S14] | Templates. daily challenge: U | Templates | Yes / U / paid | Calendar and On This Day | Markdown. paid PDF. import | Native Mac app | Offline without account. optional cloud and AI |
| Apple Journal [S5–S7] | Suggestions. fixed schedule: U | Lateral disciplines: U | Yes / Mac parity U / U | Entry edits and deleted-entry recovery | PDF and print on Mac | Native Mac app | Broader Apple services. no-network mode: U |
| Lumosity [S15, S16] | Daily game set | Cognitive games | Creative response journal: U | Score reports | Journal export: U | Web | Account service and scores |
| Sketchbook [S17–S20] | U | Art tools | Journal text U / Yes / U | Art documents. journal search: U | PNG, JPG, TIFF, PSD | Native Mac app and shortcuts | Local documents. full no-network contract: U |

## Gap Analysis

Paths below are relative to `Lateralus (Mac)/`. Line numbers refer to the code reference above.
Each gap has both competitor evidence and a check of the relevant implementation.
The proposed benefits are hypotheses. This research did not interview Lateralus users.

| ID | Verified gap and competitor evidence | Code evidence |
|---|---|---|
| G1 | Users cannot edit saved response text. Apple Journal supports entry edits.[S6] | `UI/EntryDetailView.swift:16` renders `Text`. `Data/EntryRepository.swift:16` inserts entries, with no update operation. |
| G2 | Users cannot export the journal. Day One exports structured data and media.[S8] | `LateralusApp.swift:38` defines commands without export. A source-wide search found no export panel or exporter. |
| G3 | Users cannot restore an archive. Day One supports JSON import.[S9] | `Data/PersistenceController.swift:19` retries the existing store. No archive importer exists in the source. |
| G4 | Sketch undo cannot restore erased or cleared strokes. Redo is absent. Sketchbook supports both.[S20] | `Media/Sketch.swift:141` removes the last stroke. Line 150 binds Shift-Command-Z. Line 154 clears all strokes. |
| G5 | The journal has no date filter. Diarly provides a calendar view.[S4] | `UI/JournalView.swift:19` filters text and exercise. Line 30 groups entries by day without date selection. |
| G6 | Diary text has no durable draft. Diarly advertises automatic save.[S14] | `UI/DiaryComposer.swift:10` keeps text in `@State`. Line 130 saves only through an explicit action. |
| G7 | Saved sketches have no image export. Sketchbook supports PNG export.[S19] | `UI/EntryDetailView.swift:28` shows `SketchImage`. `Media/Sketch.swift:27` encodes model data, not an export image. |
| G8 | The system menu bar has no quick composer. Day One provides one.[S10] | `LateralusApp.swift:12` defines a main window group. Its commands open the diary sheet. No `MenuBarExtra` exists. |
| G9 | Diary templates are absent. Day One and Diarly provide templates.[S11, S13] | `UI/DiaryComposer.swift:10` starts with empty text. The composer has no template selector or template store. |
| G10 | The app does not select anniversary entries. Day One and Diarly provide On This Day.[S12, S4] | `UI/TodayView.swift:183` selects only `entries.prefix(3)`. No anniversary query exists. |

Source checks included these commands:

```sh
rg -n 'archive|backup|restore|NSSavePanel|NSOpenPanel|fileExporter|fileImporter|MenuBarExtra|UndoManager|redo|template|draft|dateFilter|DatePicker' 'Lateralus (Mac)' -g '*.swift'
rg -n 'draft|@State|save|discard' 'Lateralus (Mac)/UI/SessionView.swift' 'Lateralus (Mac)/UI/DiaryComposer.swift'
```

I inspected matching code and the complete repository, entry model, journal view, entry detail, and app commands.
Prompt text that contains “archive” or “redo” does not implement those capabilities.

Existing features excluded from the proposals:

- Search, exercise filters, attachment indicators, and multiple windows already exist.
- Response guides, stretch prompts, streaks, and discipline balance already exist.
- The app has a store-open recovery screen. It does not have archive restore.
- Sketch undo already exists in limited form. G4 concerns reversible operations and correct shortcuts.

Excluded product directions:

- Favorites remain deferred. Dark appearance conflicts with the light-only rule.
- Accounts, cloud sync, AI, analytics, and iOS ports remain outside scope.
- Notification reminders would add a permission. They conflict with the microphone-only rule.
- Spotlight can expose private text outside the app. Defer it until the owner defines the exposure policy.
- Widgets, Services, full art layers, and custom prompt collections need separate scope research.
- Deleted-entry recovery needs attachment retention and schema changes. Archive restore is the narrower first recovery feature.

## Recommended Features

Priority order follows data control, correction, retrieval, then convenience.
**P1** means next release work. **P2** means follow-on work. **P3** means optional improvement.
**S** means one small surface. **M** means a focused UI and data change. **L** means several coordinated subsystems.
All proposals below are S or M. Each proposal is one focused PR for one engineer.
Effort classes are estimates, not delivery dates. New files are marked “new”.

### 1. Edit saved response text — P1 / M

- **Problem:** A typo or incomplete thought requires another entry. **Evidence:** Apple Journal.[S6] Gap G1.
- **Behavior:** Add Edit, Save, and Cancel to the entry detail. Change only response text.
- **Boundary:** Preserve the date, prompt, ID, sketch, and voice note. Defer attachment edits and revision history.
- **Files:** `UI/EntryDetailView.swift`, `Data/EntryRepository.swift`, `UI/EntryTextEditor.swift` (new), `EntryRepositoryTests.swift`.
- **Check:** A failed save preserves the original text. Cancel changes nothing. An edit does not add activity.

### 2. Export a complete local archive — P1 / M

- **Problem:** Users cannot keep an independent copy of their work. **Evidence:** Day One.[S8] Gap G2.
- **Behavior:** Export all entries to a user-selected folder with versioned JSON, original sketch data, and voice files.
- **Boundary:** Include IDs, dates, prompt text, discipline, and flags. Use a manifest and file checksums. Exclude scheduled backups and PDF.
- **Files:** `Data/JournalArchive.swift` (new), `Data/AttachmentStore.swift`, `LateralusApp.swift`, `UI/AppModel.swift`, `JournalArchiveTests.swift` (new).
- **Check:** Stage the archive before final output. A missing attachment produces a clear failure, not a false success.

### 3. Restore a local archive into an empty journal — P1 / M

- **Problem:** An exported archive cannot yet restore a lost journal. **Evidence:** Day One JSON import.[S9] Gap G3.
- **Behavior:** Validate the archive, show its entry count, and import it only into an empty, open journal.
- **Boundary:** Depends on feature 2. Exclude merge, third-party import, and repair of a store that cannot open.
- **Files:** `Data/JournalArchive.swift`, `Data/EntryRepository.swift`, `Data/AttachmentStore.swift`, `LateralusApp.swift`, `JournalArchiveTests.swift`.
- **Check:** Reject unsupported versions, unsafe paths, invalid checksums, and duplicate IDs before writes. Roll back files and entries on failure.

### 4. Complete sketch undo and redo — P1 / M

- **Problem:** Erase, Clear, and mistaken undo can destroy sketch work. **Evidence:** Sketchbook.[S20] Gap G4.
- **Behavior:** Use Command-Z and Shift-Command-Z for stroke, erase, and clear operations when the canvas has focus.
- **Boundary:** Keep a bounded history for the current canvas. Preserve normal text-editor undo. Exclude saved sketch edits.
- **Files:** `Media/Sketch.swift`, `Media/SketchHistory.swift` (new), `SketchHistoryTests.swift` (new).
- **Check:** Undo and redo reproduce every supported operation. A fresh operation clears the redo history.

### 5. Filter the journal by date — P2 / S

- **Problem:** Users must scroll when they remember a date but not the text. **Evidence:** Diarly calendar.[S4] Gap G5.
- **Behavior:** Add optional start and end dates beside the exercise filter. Combine all filters and provide Clear Dates.
- **Boundary:** Use local calendar days. Exclude a new calendar screen and changes to Insights.
- **Files:** `UI/JournalView.swift`, `Domain/JournalDateRange.swift` (new), `JournalDateRangeTests.swift` (new).
- **Check:** Include both boundary days. Check changes to daylight time and an empty result.

### 6. Recover diary text drafts — P2 / M

- **Problem:** The discard guard cannot recover text after a process failure. **Evidence:** Diarly automatic save.[S14] Gap G6.
- **Behavior:** Save diary text to a local draft file after edits. Offer recovery when the user next opens Diary.
- **Boundary:** Text only. Use separate draft IDs for each composer. Keep the existing media discard guard and state the text-only recovery limit.
- **Files:** `UI/DiaryComposer.swift`, `Data/DiaryDraftStore.swift` (new), `DiaryDraftStoreTests.swift` (new).
- **Check:** Successful save or explicit discard removes the draft. Two windows cannot overwrite each other's drafts. Drafts do not affect activity.

### 7. Export one saved sketch as PNG — P2 / S

- **Problem:** Users cannot reuse a visual idea in another document. **Evidence:** Sketchbook.[S19] Gap G7.
- **Behavior:** Add Export Sketch to entry detail when a sketch exists. Save a PNG through a native file panel.
- **Boundary:** Export only the sketch with a paper background. Exclude batch export, PDF, and new art tools.
- **Files:** `UI/EntryDetailView.swift`, `Media/Sketch.swift`, `Media/SketchExport.swift` (new).
- **Check:** The image includes the complete sketch without clipped strokes. Cancel leaves the journal unchanged.

### 8. Add a menu bar text composer — P2 / M

- **Problem:** A brief idea requires a full app window. **Evidence:** Day One.[S10] Gap G8.
- **Behavior:** Provide an optional menu bar item with a text field, Save, and Open Lateralus.
- **Boundary:** Text-only diary entries. No global shortcut, login item, or new permission. Reuse the existing persistence container and repository.
- **Files:** `LateralusApp.swift`, `UI/QuickDiaryView.swift` (new), `Data/EntryRepository.swift`.
- **Check:** Save works with all main windows closed. Empty text cannot save. A failed save preserves the text.

### 9. Add three diary templates — P3 / S

- **Problem:** A blank diary gives no structure for reflection. **Evidence:** Day One and Diarly.[S11, S13] Gap G9.
- **Behavior:** Offer three static templates: observation, assumption check, and next experiment. Insert the selected questions into an empty diary.
- **Boundary:** Preserve blank Diary as the default. Exclude template editors, custom collections, and changes to daily content.
- **Files:** `UI/DiaryComposer.swift`, `Domain/DiaryTemplate.swift` (new).
- **Check:** A template never overwrites text. Entries remain ordinary diary entries. The daily schedule pin remains unchanged.

### 10. Revisit entries from this date — P3 / S

- **Problem:** The recent-entry list gives little help with older work. **Evidence:** Day One and Diarly.[S12, S4] Gap G10.
- **Behavior:** Show past-year entries with today's month and day in a small Today section. Open the selected entry in Journal.
- **Boundary:** Hide the section without matches. Define February 29 as an exact-date match. Exclude notifications and quality comparisons.
- **Files:** `UI/TodayView.swift`, `UI/JournalView.swift`, `UI/AppModel.swift`, `Domain/JournalAnniversary.swift` (new), `JournalAnniversaryTests.swift` (new).
- **Check:** Exclude current-year entries. Respect the existing unsaved-work guard before navigation.

Shared implementation constraints:

- Reuse `UI/Theme.swift` for shared visual values and controls.
- Route journal writes and attachment operations through `EntryRepository`.
- Preserve the V1 schema. Add a schema version and migration if final scope requires new model fields.
- Preserve the daily schedule. None of these proposals needs a change to `ContentPools` or engine mixing.
- Use native file panels for user-directed export. Do not request broad filesystem access.
- Add each proposed test under `Lateralus (Mac)Tests/`.

## Sources

All sources were retrieved through built-in web search on 15 October 2026.
Some pages exposed only search excerpts. Source S9 supports JSON import through such an excerpt.
The current Diarly price page supersedes older search excerpts about its free tier.

- **S1:** [Brainsparker US App Store listing](https://apps.apple.com/us/app/brainsparker-creativity-coach/id694087970) — features, compatibility, and purchases.
- **S2:** [Oblique Strategies SE US App Store listing](https://apps.apple.com/us/app/oblique-strategies-se/id1104927011) — price, offline claim, and Mac compatibility.
- **S3:** [Day One plans](https://dayoneapp.com/plans/) — free and Silver features and prices.
- **S4:** [Diarly plans](https://diarly.app/pricing.html) — platforms, free features, paid features, and regional price policy.
- **S5:** [Apple: macOS Tahoe announcement](https://www.apple.com/ph/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever/) — Journal for Mac and free system update.
- **S6:** [Apple: edit or delete a journal entry on Mac](https://support.apple.com/en-mide/guide/journal/dev7c1z9b800/mac) — edits and recovery.
- **S7:** [Apple: print and export journal entries on Mac](https://support.apple.com/en-ie/guide/journal/dev883fc2329/mac) — PDF and print.
- **S8:** [Day One: export entries](https://dayoneapp.com/guides/tips-and-tutorials/exporting-entries/) — formats and platform limits.
- **S9:** [Day One: import data from JSON files](https://dayoneapp.com/blog/help_guides/importing-data-from-json-files/) — JSON import.
- **S10:** [Day One: menu bar quick entry](https://dayoneapp.com/guides/day-one-for-mac/menu-bar-quick-entry/) — Mac quick composer.
- **S11:** [Day One: templates](https://dayoneapp.com/guides/tips-and-tutorials/templates/) — templates and Mac support.
- **S12:** [Day One: On This Day](https://dayoneapp.com/guides/day-one-for-android/on-this-day-view/) — includes Mac instructions.
- **S13:** [Diarly: templates](https://diarly.app/help/templates) — template controls.
- **S14:** [Diarly: mindfulness journal](https://diarly.app/mindfulness-journal.html) — automatic save claim.
- **S15:** [Lumosity](https://www.lumosity.com/en/) — daily games, adaptive practice, and scores.
- **S16:** [Lumosity: free games](https://help.lumosity.com/hc/en-us/articles/31154507402647-Where-are-the-free-games) and [payment policy](https://www.lumosity.com/en/payment-policy/) — access, mobile platforms, and subscription model.
- **S17:** [Sketchbook apps](https://www.sketchbook.com/apps) — platforms and art tools.
- **S18:** [Sketchbook Pro US Mac App Store listing](https://apps.apple.com/us/app/sketchbook-pro/id1570472288?mt=12) — $24.99 price and Mac features.
- **S19:** [Sketchbook: image export](https://help.sketchbook.com/docs/exporting-images) — image export capabilities.
- **S20:** [Sketchbook: undo and redo](https://help.sketchbook.com/docs/undoing-and-redoing) — reversible sketch operations.
