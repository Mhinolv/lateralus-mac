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
| `Resources/Fonts/` | Source Serif 4 and Work Sans variable fonts (OFL, licenses included) |

**Schedule stability is a product contract.** The daily schedule is a pure function of (local day, `PromptEngine.contentVersion`). Any change to `ContentPools` or engine mixing must ship with a `contentVersion` bump; `testScheduleStabilityPin` fails if the published schedule drifts silently.

## Visual system

Lamplight: warm parchment with a terracotta accent in light mode, a lamp-lit brown desk with a coral accent in dark mode. The app follows the system light or dark setting. Everything lives in `UI/Theme.swift`: palette, radii, elevation, and the shared components (kicker, tag, badge, discipline monogram, primary and secondary buttons, empty state). Nothing outside `Theme` hard-codes a color or a corner.

| Token | Light | Dark | Role |
|---|---|---|---|
| `background` | `#F8F2E8` | `#1C1813` | Window ground, input wells |
| `surface` | `#F1E9DC` | `#26201A` | Cards, secondary buttons |
| `surfaceSunken` | `#EAE0CE` | `#30281F` | Search field, chart tracks, monogram tiles, disabled fills |
| `sidebar` | `#EFE6D7` | `#211C16` | Sidebar column |
| `ink` | `#2B2419` | `#EFE6D6` | Text. Also at 68% / 45% (dark 70% / 46%) and 24% |
| `accent` | `#B5502E` | `#E07A52` | The app's one hue |
| `accentStrong` | `#7A3A1F` | `#F2A585` | Text on accent washes |
| `accentSoft` | `#F0DCC9` | `#3D271B` | Selection and washes |
| `accentText` | `#7A3A1F` | `#E07A52` | Accent-colored text, such as `Tag` |
| `mark` / `onMark` | `#F0DCC9` / `#7A3A1F` | `#3D271B` / `#F2A585` | Prompt highlight fill and its text |
| `primaryFill` / `primaryLabel` | `#B5502E` / `#FFFFFF` | `#E07A52` / `#1C1813` | Primary action and its label |
| `sketchPaper` | `#FDF9F1` | `#E8DDC9` | Sketch canvas and viewer |

Rules the system holds itself to:

- **One hue.** No per-discipline colors. If one item must stand out (Insights' balance chart), it uses the accent against faint ink.
- **Every color is a light/dark pair.** Build tokens with `Theme.adaptive` (`NSColor(name:dynamicProvider:)`). Do not force a color scheme and do not add an appearance menu.
- **Text meets 4.5:1.** Light `accent` is about 4.2:1 on `surface`, so accent-colored text uses `accentText`. `ThemeTests` checks the text pairs.
- **Three radii** — 6 / 10 / 16. Inputs, rows, icon controls and monogram tiles take the small step. Buttons, the search field and panes take the medium step. Cards and sheets take the large step. Only `Badge` is a capsule.
- **Ink at four opacities** carries the text hierarchy. Hairlines are ink at 12% (7% between text blocks).
- **Shadows are never ink.** Light mode uses the literal `#2B2419`. Dark mode uses black, because dark-mode ink is light and would glow.
- **The sketch paper stays light.** In dark mode the paper is `#E8DDC9`, so pens draw their saved colors in both appearances.
- **Type is bundled, not borrowed.** Source Serif 4 for writing (wordmark, headlines, prompts, entry recaps), Work Sans for interface, the system monospace for counts and error detail. Both bundled faces are variable fonts. `UI/Fonts.swift` registers them at first use and sets weight and optical size on the axes. The Source Serif optical size follows the point size (8–60). `Theme.ui(italic: true)` uses Work Sans Italic. Each family falls back to its system face if it fails to load.

## Building and testing

Open `Lateralus (Mac).xcodeproj` in Xcode 26+ and run, or:

```sh
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -destination "platform=macOS" build
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -destination "platform=macOS" test
```

Unit tests cover the engine (determinism, non-repeat window, schedule pin), metrics, and repository/attachment consistency. `CoreFlowsUITests` walks the full loop end-to-end against an in-memory store (`--ui-test-in-memory`), so tests never touch a real journal.
