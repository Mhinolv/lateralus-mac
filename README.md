# Lateralus for Mac

A native macOS app for practicing lateral thinking. One featured challenge a day, twelve practice disciplines, and a private journal that never leaves your Mac.

Built ground-up for the Mac — sidebar navigation, menu bar commands, keyboard shortcuts, mouse/trackpad sketching — from the behavioral spec in `Lateralus_Feature_Inventory_and_Market_Opportunities` (P0 feature inventory). It is not a port of the iOS Lateralus app.

## The core loop

- **Today** — a deterministic daily challenge: the same local calendar day always deals the same challenge, and no (discipline, content) combination repeats inside a 730-day window. The day rolls over with the clock, timezone changes, and app activation.
- **Practice** — all twelve disciplines in the sidebar (Alternate Uses, Twisted Uses, Reality Shift, Fusion, Backstory, Perspective Flip, Redefine, Coin a Word, Common Thread, Positive Spin, Inventions, Mini Mythology), with fresh prompts every round (⌘R).
- **Respond** — type, sketch (native canvas: pens, nibs, eraser, undo), or record a voice note up to five minutes; any combination. Nothing is graded, scored, or ranked.
- **Journal** — chronological archive with search, per-exercise filters, attachment indicators, and a reading pane. Diary (⌘N) is a prompt-free entry with the same tools. (Favorites are deferred for now; the schema keeps the column.)
- **Insights** — streak, totals, current week, trailing 7-day chart, and discipline balance (Diary counts toward activity, not balance).

## Privacy stance

No account, no analytics, no network, no AI. Everything is stored locally (SwiftData + a managed voice-notes directory in Application Support), inside the app sandbox. The only permission the app ever asks for is the microphone, and only when you record.

## Architecture

| Layer | Contents |
|---|---|
| `Domain/` | `Exercise` catalog, `Prompt`, `ContentPools` (authored content, versioned), `PromptEngine` (seeded deterministic scheduling), `ActivityMetrics` |
| `Data/` | `JournalEntry` (versioned SwiftData schema), `PersistenceController` (recovery-first startup), `AttachmentStore` + `EntryRepository` (transactional attachment handling) |
| `Media/` | `Sketch` model + canvas + renderer, `VoiceNoteRecorder`/`Player` |
| `UI/` | `RootView` (split view + unsaved-work navigation guard), Today, Session, Journal, Entry detail, Insights, Diary, Theme, Fonts |
| `Resources/Fonts/` | Source Serif 4 and Work Sans (OFL, licenses included) |

**Schedule stability is a product contract.** The daily schedule is a pure function of (local day, `PromptEngine.contentVersion`). Any change to `ContentPools` or engine mixing must ship with a `contentVersion` bump; `testScheduleStabilityPin` fails if the published schedule drifts silently.

## Visual system

Warm paper, one terracotta accent, a serif display voice against a humanist grotesque interface voice, softly rounded edges. Everything lives in `UI/Theme.swift` — palette, radii, elevation, and the shared components (kicker, tag, badge, streak pill, discipline monogram, primary/secondary buttons, empty state). Nothing outside `Theme` should hard-code a color or a corner.

| Token | Value | Role |
|---|---|---|
| `background` | `#F8F2E8` | Window ground, input wells |
| `surface` | `#F1E9DC` | Cards, sidebar |
| `surfaceSunken` | `#EAE0CE` | Chart tracks, monogram tiles, disabled fills |
| `ink` | `#2B2419` | Text — also at 68% / 42% / 24% |
| `accent` | `#B5502E` | The app's one hue |
| `accentStrong` | `#7A3A1F` | Text on accent washes |
| `accentSoft` | `#F0DCC9` | Selection, washes, the streak pill |

Rules the system holds itself to:

- **One hue.** No per-discipline colors. Where one item must be singled out (Insights' balance chart), it contrasts accent against faint ink rather than introducing a second color.
- **Three radii and a pill** — 6 / 10 / 16 / capsule. Inputs and rows take the small step, controls and tiles the medium, cards and sheets the large.
- **Ink at four opacities** carries the entire text hierarchy. Hairlines are ink at 12% (7% between text blocks).
- **Type is bundled, not borrowed.** Source Serif 4 for writing (wordmark, headlines, prompts, entry recaps), Work Sans for interface, system monospace for anything counted. `UI/Fonts.swift` registers the faces into the process at first use and `Theme.display`/`Theme.ui` fall back to system faces if that ever fails, so a repackaged bundle degrades quietly.
- **Still light-only.** The window forces light appearance and the palette has no dark tokens — a from-scratch job, not an inversion.

## Building and testing

Open `Lateralus (Mac).xcodeproj` in Xcode 26+ and run, or:

```sh
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -destination "platform=macOS" build
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -destination "platform=macOS" test
```

Unit tests cover the engine (determinism, non-repeat window, schedule pin), metrics, and repository/attachment consistency. `CoreFlowsUITests` walks the full loop end-to-end against an in-memory store (`--ui-test-in-memory`), so tests never touch a real journal.
