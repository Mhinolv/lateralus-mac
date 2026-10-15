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

Night Shift: a blue-black night desk with a lime highlighter in dark mode, warm paper with an olive accent in light mode. The app follows the system light or dark setting. Everything lives in `UI/Theme.swift` — palette, radii, elevation, and the shared components (kicker, tag, badge, streak pill, discipline monogram, primary/secondary buttons, empty state). Nothing outside `Theme` should hard-code a color or a corner.

| Token | Light | Dark | Role |
|---|---|---|---|
| `background` | `#F5F3EC` | `#111318` | Window ground, input wells |
| `surface` | `#FFFFFF` | `#191C23` | Cards, secondary buttons |
| `surfaceSunken` | `#ECE9DF` | `#222630` | Chart tracks, monogram tiles, disabled fills |
| `sidebar` | `#EDEAE1` | `#0C0E12` | Sidebar column |
| `ink` | `#111318` | `#F2EFE7` | Text — also at 68% / 42% / 24% |
| `accent` | `#4A6300` | `#D4F25A` | The app's one hue |
| `accentStrong` | `#3F5600` | `#D4F25A` | Text on accent washes |
| `accentSoft` | `#E9F7B0` | `#D4F25A` at 14% | Selection, washes, the streak pill |
| `mark` / `onMark` | `#DDF57A` / `#111318` | `#D4F25A` / `#111318` | Highlighter fill and its text |
| `primaryFill` / `primaryLabel` | `#111318` / `#DDF57A` | `#D4F25A` / `#111318` | Primary action capsule and its label |
| `sketchPaper` | `#FFFFFF` | `#1B1F27` | Sketch canvas and viewer |

Rules the system holds itself to:

- **One hue.** No per-discipline colors. Where one item must be singled out (Insights' balance chart), it contrasts accent against faint ink rather than introducing a second color.
- **Every color is a light/dark pair.** Build tokens with `Theme.adaptive` (`NSColor(name:dynamicProvider:)`). Do not force a color scheme and do not add an appearance menu.
- **Lime is never text in light mode.** In light mode, lime is only a fill behind ink. Light accent text is `#4A6300`.
- **Three radii and a pill** — 8 / 14 / 22 / capsule. Inputs and rows take the small step, controls and tiles the medium, cards and sheets the large. Buttons are capsules.
- **Ink at four opacities** carries the entire text hierarchy. Hairlines are ink at 11% (6% between text blocks).
- **Shadows are never ink.** Light mode uses `#111318`. Dark mode uses black, because dark-mode ink is light and would glow.
- **Type is bundled, not borrowed.** Source Serif 4 for writing (wordmark, headlines, prompts, entry recaps), Work Sans for interface, system monospace for anything counted. `UI/Fonts.swift` registers the faces into the process at first use and `Theme.display`/`Theme.ui` fall back to system faces if that ever fails, so a repackaged bundle degrades quietly.

## Building and testing

Open `Lateralus (Mac).xcodeproj` in Xcode 26+ and run, or:

```sh
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -destination "platform=macOS" build
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -destination "platform=macOS" test
```

Unit tests cover the engine (determinism, non-repeat window, schedule pin), metrics, and repository/attachment consistency. `CoreFlowsUITests` walks the full loop end-to-end against an in-memory store (`--ui-test-in-memory`), so tests never touch a real journal.
