# Lateralus for Mac — Structure & Feature Reference

**Redesign brief.** A native macOS app for practicing lateral thinking. One featured challenge a day, twelve practice disciplines, and a private journal that never leaves the machine. This document inventories every surface, control, and constraint in the app as it exists today — the starting point for a redesign.

| | |
|---|---|
| **Platform** | macOS · SwiftUI |
| **Surfaces** | 6 + persistent chrome |
| **Default window** | 1120 × 720 pt |
| **Minimum window** | 900 × 620 pt |
| **Appearance** | Light only |
| **Network** | None |
| **Prepared** | 27 July 2026 — reflects the app as currently built |

---

## Contents

1. [The premise](#01--the-premise)
2. [Navigation model](#02--navigation-model)
3. [Screen inventory](#03--screen-inventory)
4. [Persistent chrome](#04--persistent-chrome)
5. [The twelve disciplines](#05--the-twelve-disciplines)
6. [Response tools](#06--response-tools)
7. [The content engine](#07--the-content-engine)
8. [Current visual system](#08--current-visual-system)
9. [Dialogs & states](#09--dialogs--states)
10. [Data & privacy](#10--data--privacy)
11. [Gaps & open questions](#11--gaps--open-questions)
12. [What can't move](#12--what-cant-move)

---

## 01 · The premise

Lateralus is a creative-thinking practice app, not a puzzle game. Nothing is graded, scored, ranked, or compared against anyone. The only numbers in the product are behavioural: how many days in a row you showed up, and which disciplines you've been avoiding.

**The daily loop.** Open the app → read today's challenge → answer it by typing, sketching, or speaking → it lands in the journal. Two to five minutes. The app opens on **Today** every launch.

**The practice loop.** Pick any of the twelve disciplines from the sidebar and deal yourself fresh prompts as many times as you like (⌘R). Same response tools, no daily limit, no streak pressure.

**The archive loop.** Everything saved goes to **Journal** — chronological, searchable, filterable by discipline, with a reading pane. Diary (⌘N) is a prompt-free entry that uses the same tools.

**The reflection loop.** **Insights** shows streak, totals, the current week, a trailing seven-day chart, and how balanced practice is across the twelve disciplines. That's the whole of it.

> **Tone to preserve.** The product's voice is dry, confident, and unsentimental — *"Think sideways,"* *"Quantity first — the tenth idea is usually stranger than the first."* No gamification confetti, no encouragement copy, no mascot. Streaks exist as information, not as a threat.

---

## 02 · Navigation model

A single window with a permanently visible custom sidebar (not a system split view) and one detail pane. There is no page stack and no tabs — the detail pane swaps wholesale. The only exceptions are the Journal's internal split and two overlays.

```
SIDEBAR ─────────────► S-01  Today            (default)
(always present,       S-03  Journal
 collapsible)          S-04  Insights
                       S-02  Practice session × 12 (one per discipline)

TODAY ───────────────► S-02  Session, daily variant
(daily card click)           replaces the pane, gains a "← Today" back button

JOURNAL ─────────────► S-03b Entry reading view
(list selection)             right side of an internal draggable split

OVERLAY LAYER ───────► S-05  Diary composer      (sheet, ⌘N)
(above everything)           Confirmation dialogs & alerts (7 variants)

LAUNCH FAILURE ──────► S-06  Recovery screen
(store won't open)           replaces the entire window
```

> **The one piece of navigation friction.** A practice session lives *inside* the detail pane, so clicking any sidebar item while a response is half-written destroys it. The app intercepts this with a "Discard this response?" dialog. Any redesign that keeps sessions in the main pane inherits this problem — worth deciding early whether sessions should become their own window, a sheet, or stay inline with the guard.

---

## 03 · Screen inventory

Six surfaces. In the wireframes below, `███` marks the primary action or focal region and dashed regions are conditional.

### S-01 · Today
*Default view · ⌘1*

```
┌──────────────────────────────────────────────────┐
│  Header — "Think sideways."          [streak pill]│
├──────────────┬──────────────┬────────────────────┤
│   Streak     │  This week   │     All time       │
├──────────────┴──────────────┴────────────────────┤
│ ███  DAILY CHALLENGE CARD                     ███│
│ ███  kicker · headline · detail · [Begin]      ███│
├──────────────────────────────────────────────────┤
│ ┄ Practice hint line ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
├──────────────────────────────────────────────────┤
│  Recent entries (3)              "View journal" →│
└──────────────────────────────────────────────────┘
Single scrolling column, content capped at 760 pt and centred in the pane.
```

**What it does.** Presents the one featured challenge for the current calendar day and gets the user into it in a single click. Everything else on the page is context.

- Header shows the date and a streak pill; large display headline reads "Think sideways."
- Three stat tiles: day streak (accent-coloured), this week, all time.
- The daily card is one big button — discipline kicker, prompt headline, optional labelled detail block, and a **Begin** button. Once answered today, it gains a *Done* tag and the button becomes **Answer Again**.
- A one-line pointer to the Practice list in the sidebar.
- The three most recent journal entries, each a discipline tag + first line + relative timestamp. Hidden entirely when the journal is empty.

> **Redesign hook.** This screen currently repeats the stat row that also opens Insights, and the daily card duplicates layout the Session screen shows again one click later. There's an obvious consolidation opportunity here.

---

### S-02 · Session
*Two variants — daily & practice*

```
┌──────────────────────────────────────────────────┐
│ ← Today │ ◈ Discipline title │      [New Prompt] │
├────────────────────────┬─────────────────────────┤
│ Directive banner       │ ███                  ███│
├────────────────────────┤ ███  RESPONSE STUDIO ███│
│ ▓ Prompt card          │ ███  text editor     ███│
│ ▓ headline + detail    │ ███  media bar       ███│
├────────────────────────┤ ███  sketch canvas   ███│
│ Response guide         │ ███  [Save ⌘S]       ███│
│ 3 steps + stretch      │ ███                  ███│
└────────────────────────┴─────────────────────────┘
Two equal columns: prompt & guidance left, input right. Scrolls as one page.
```

**What it does.** The workhorse screen. Holds one prompt and everything needed to answer it. Same component for the daily challenge and for practice — only the header controls differ.

- **Left column:** a coloured directive banner (the standing rule of the discipline), the prompt card, and a numbered three-step response guide with an optional "Stretch" line for extra difficulty.
- **Right column:** the input card — plain text editor with placeholder, a live word count, the media bar, an expandable sketch canvas, and **Save to Journal** (⌘S, disabled until there's something to save).
- **Daily variant** gets a ← *Today* back button; after saving, a *Done* button.
- **Practice variant** gets a *New Prompt* dice button (⌘R) instead; after saving, *New Prompt* becomes the primary action.
- On save, the input card animates out and a **saved card** takes its place: a confirmation seal, the response text, a voice-note player, the sketch, and *Answer Again* / *Done*.

> **Special case.** *Common Thread* adds a dedicated single-word "Connecting word…" field above the text editor, strips whitespace from it as you type, and shrinks the body editor. Its prompt headline is also set larger. It's the only discipline with bespoke input.

---

### S-03 · Journal
*⌘2 · ⌘F focuses search*

```
┌────────────────────────┬─────────────────────────┐
│ Search field  [filter] │ ▓ Tag · Daily · time · 🗑│
├────────────────────────┼─────────────────────────┤
│ GROUPED ENTRY LIST     │ ▓ Prompt recap card     │
│  day header            ├─────────────────────────┤
│   · tag, headline,     │ ███                  ███│
│     ♪ ✎ glyphs,        │ ███  RESPONSE TEXT   ███│
│     snippet            │ ███                  ███│
│  day header            ├─────────────────────────┤
│   · …                  │ ┄ voice player · sketch ┄│
└────────────────────────┴─────────────────────────┘
Draggable split. List min 320 / ideal 380 pt; reading pane min 320 pt,
content capped at 720.
```

**What it does.** The private archive. Every saved response, newest first, grouped by day.

- **Search** matches response text, prompt headline, prompt detail, and discipline name. Clearable inline.
- **Filter** is a single menu: All Exercises, or one of the twelve disciplines, or Diary. The icon fills with accent when a filter is active.
- **Rows** carry a discipline tag, the prompt headline, a *Daily* badge, waveform and scribble glyphs for attachments, and a one-line response snippet.
- **Reading pane** shows the entry in full: prompt recap in an accent wash (suppressed for Diary), response text, voice note player, sketch. A trash button sits in its header.
- Delete is available three ways — row context menu, ⌫ on selection, reading-pane trash — and always confirms.
- Two empty states: "No entries yet" (with a New Diary Entry action) and search-no-results; plus "No entry selected" in the reading pane.

> **Known defect.** A Favorites feature was built and then pulled: the star button in the reading pane header would not respond to clicks, while a structurally identical trash button beside it worked. The `isFavorite` column is still in the database, reserved. If favourites come back in the redesign, this is unfinished business.

---

### S-04 · Insights
*⌘3*

```
┌──────────────────────────────────────────────────┐
│  Header — "Your practice patterns."              │
├──────────────┬──────────────┬────────────────────┤
│   Streak     │Entries total │     This week      │
├──────────────┴──────────────┴────────────────────┤
│ ▓ LAST 7 DAYS — bar chart                        │
├──────────────────────────────────────────────────┤
│ ███  DISCIPLINE BALANCE — 12 labelled bars    ███│
│ ███  leader in accent, other 11 neutral grey  ███│
└──────────────────────────────────────────────────┘
Single column, capped at 760 pt. Same tile component as Today, reordered.
```

**What it does.** Behavioural statistics only. Nothing here evaluates the quality of an answer.

- Three stat tiles — streak, entries total, this week — with animated numeric transitions.
- A seven-day bar chart; days with zero entries render in neutral grey rather than disappearing.
- **Discipline balance:** all twelve disciplines listed with a horizontal bar and a count. Rather than twelve colours, the leading discipline gets the accent and the other eleven stay neutral grey.
- Diary entries count toward streak, totals, and the week — but deliberately not toward discipline balance.
- **Streak rule:** a streak counts consecutive active days ending today *or yesterday*, so it isn't shown as broken before you've had a chance to practise today.

> **Redesign hook.** Twelve bars is the densest data display in the app and the one place a designer has real room. There's no month view, no calendar heatmap, and no per-discipline drill-down today.

---

### S-05 · Diary composer
*Modal sheet · ⌘N*

```
┌──────────────────────────────────────────────────┐
│  ✎ Diary                                  [Close]│
├──────────────────────────────────────────────────┤
│ ███                                           ███│
│ ███  FREE TEXT EDITOR                         ███│
│ ███  "Whatever's on your mind…"               ███│
├──────────────────────────────────────────────────┤
│  Media bar · record · sketch toggle              │
├──────────────────────────────────────────────────┤
│ ┄ Sketch canvas (expanded) ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
├──────────────────────────────────────────────────┤
│ ▓                            [Save to Journal ⌘S]│
└──────────────────────────────────────────────────┘
Sheet, 560 pt min / 620 ideal wide × 460 min tall. Not resizable to full window.
```

**What it does.** A prompt-free entry with the identical response tools. Reachable from anywhere via ⌘N, the sidebar button, or the empty-journal state.

- Text editor is focused on open — the sheet expects you to start typing immediately.
- Same media bar and canvas component as a session.
- Cannot be dismissed by click-away while it holds unsaved content; Esc routes through a discard confirmation.
- Saves as a `diary` entry, which is filterable in the Journal and excluded from discipline balance.

> **Redesign hook.** The Diary is currently the only surface presented as a sheet — a modal in an otherwise fully inline app. It's also the button with the strongest visual weight in the sidebar (solid accent fill), which arguably overstates it relative to the daily challenge.

---

### S-06 · Recovery
*Failure state · replaces the whole window*

```
┌──────────────────────────────────────────────────┐
│                                                  │
│              ▓ Journal unavailable               │
│      Reassurance copy — nothing was deleted      │
│                 ███ Try Again ███                │
│      ┄ Technical detail (selectable) ┄           │
│                                                  │
└──────────────────────────────────────────────────┘
Centred, 640 × 420 pt minimum. No sidebar, no menu actions.
```

**What it does.** Shown when the local journal store fails to open. It explicitly promises that nothing was deleted to "fix" the launch, offers a retry, and exposes the underlying error as selectable text for support.

All model-mutating menu commands automatically disable themselves on this screen, because it publishes no app model to the menu bar.

> **Redesign hook.** This is the app's only failure surface and currently uses stock system components — the one screen carrying none of the product's visual identity.

---

## 04 · Persistent chrome

### Sidebar

264 pt fixed width, custom-drawn — not an `NSSplitView` sidebar. Top to bottom: the **LATERALUS** wordmark, three main destinations (Today / Journal / Insights), a "Practice" section label, a scrolling list of all twelve disciplines, a divider, and a full-width solid-accent **New Diary Entry** button pinned to the bottom.

Selection state is a filled surface plus accent text and icon; hover darkens by 5%.

### Window & title bar

The title bar is hidden. Two consequences the redesign must handle:

- The traffic lights float over the sidebar's top-left — the wordmark carries 40 pt of top padding purely to clear them.
- The sidebar background is the *only* window-drag surface. When the sidebar is collapsed (⌃⌘S), the app inserts an invisible 36 pt drag strip at the top of the detail pane so the window stays movable.

### Menu bar & keyboard shortcuts

| Menu | Command | Shortcut | Notes |
|---|---|---|---|
| File | New Diary Entry | ⌘N | Opens the sheet from any screen |
| File | New Window | ⇧⌘N | Multi-window; each window has its own navigation state |
| Edit | Find in Journal | ⌘F | Navigates to Journal, then focuses search |
| View | Hide / Show Sidebar | ⌃⌘S | Preference persists across launches |
| Go | Today | ⌘1 | |
| Go | Journal | ⌘2 | |
| Go | Insights | ⌘3 | |
| Go | 12 disciplines | — | Listed individually, no shortcuts — a 15-item menu |
| In-screen | New Prompt | ⌘R | Practice sessions only |
| In-screen | Save to Journal | ⌘S | Session and Diary |
| In-screen | Undo last stroke | ⇧⌘Z | Sketch canvas only |
| In-screen | Delete entry | ⌫ | Journal list selection |

> **Flag for review.** Sketch undo is bound to ⇧⌘Z, which on macOS conventionally means *redo*. There is no ⌘Z. Worth correcting in the redesign.

---

## 05 · The twelve disciplines

These are the app's content taxonomy. All twelve appear in the sidebar, in the Go menu, in the journal filter, and as twelve rows on Insights — so label length and icon legibility matter at small sizes. Each carries a one-line blurb, a standing directive, a three-step response guide, and an optional "stretch" constraint.

| Discipline | What it asks | Second element | Prompt space |
|---|---|---|---:|
| Alternate Uses | Push a familiar object past its job description. | — | 72 |
| Twisted Uses | Invent uses after the rules of the object change. | The Twist | 1,728 |
| Reality Shift | Follow the consequences of a broken law of reality. | — | 64 |
| Fusion | Weld two strangers into one working idea. | Fuse With | 400 |
| Backstory | Explain how a strange moment came to be. | — | 64 |
| Perspective Flip | Answer from a point of view that isn't yours. | Your Vantage | 768 |
| Redefine | Give an old concept a sharper, stranger meaning. | — | 64 |
| Coin a Word | Name a feeling language forgot to cover. | — | 64 |
| Common Thread | Find the hidden bridge between distant ideas. | — | 1,770 |
| Positive Spin | Mine something difficult for honest upside. | — | 64 |
| Inventions | Design a thing the world quietly needs. | The Catch | 512 |
| Mini Mythology | Write the tiny myth behind an ordinary thing. | — | 64 |
| Diary | Free writing, no prompt, no rules. | — | n/a |

Four disciplines carry a labelled second element that renders as its own block under the prompt headline. Any prompt layout has to work both with and without it.

---

## 06 · Response tools

Three input modes, freely combinable in a single entry, shared identically between Session and Diary. A response is saveable as soon as *any one* of them has content.

**Text.** Plain multi-line editor on a bordered well. Placeholder copy differs per context. Live word count appears once typing starts. Minimum height 240 pt (140 for Common Thread, which has its own word field above).

**Voice note.** One recording per entry, capped at five minutes, AAC mono. Controls: Record → Stop with a live mm:ss counter → play/pause + discard. Re-recording replaces. The microphone is the only permission the app ever requests, and only at first record; a denied state shows inline recovery copy pointing at System Settings.

**Sketch.** A vector canvas revealed by a toggle. Six pens (ink, crimson, cobalt, forest, marigold, plum), three nib sizes (1.5 / 3 / 7 pt), a stroke eraser, undo, and clear. Minimum 260 pt tall, drawn on a warmer "paper" surface than the app chrome so it reads as a separate sheet. Mouse and trackpad only — no pressure, no tilt.

**Saved presentation.** Saved sketches render scaled-to-fit inside their padded bounding box, capped at 320 pt tall, in both the session's saved card and the journal reading pane. Voice notes become a single play/pause row; if the file is ever missing, the player is replaced by a quiet "file is missing" line rather than an error.

> **Design opportunity.** The three modes currently sit in a flat horizontal bar with the text editor dominating. Nothing signals that sketching or speaking is as legitimate as typing — a designer could rebalance which mode the screen invites first, and per discipline.

---

## 07 · The content engine

Understanding this explains several UI decisions that otherwise look arbitrary.

**The daily challenge is deterministic.** The same calendar day always deals the same challenge, computed from the date alone — no server, no storage. Two people on the same day get the same prompt. The day rolls over live with the clock, with timezone changes, and whenever the app is reactivated.

**Practice is random.** Practice prompts are drawn freshly each round, which is why only practice has a *New Prompt* control. Today has no reroll — that's the point of a daily.

**Every 12 days covers everything.** The schedule deals all twelve disciplines exactly once per twelve-day block, in a per-block shuffled order. A daily-only user sees the full catalogue inside a fortnight.

**Nothing repeats for two years.** No discipline-and-content combination repeats within a 730-day window, across a pool of **5,634** distinct authored prompts.

> **Hard product contract.** The published daily schedule is treated as immutable history. Adding or reordering prompt content shifts every future day's challenge, so content changes must ship behind an explicit version bump, and an automated test fails the build if the schedule drifts silently. Practically: **prompt copy is not freely editable during a redesign.** Rewording a prompt is a content-version change.

---

## 08 · Current visual system

The existing look is deliberately "Modernist": flat light surfaces, one confident indigo accent, a heavy grotesque display voice, and sharp unrounded edges everywhere. Reproduced here as the baseline to react against — not as a constraint.

### Palette

| Token | Hex | Role |
|---|---|---|
| Background | `#F3F2F2` | Ground |
| Surface | `#EAE9E9` | Cards, inputs, selected rows |
| Ink | `#201E1D` | Primary text — also used at 68% and 42% |
| Accent | `#3A4FB0` | The app's one hue |
| Accent strong | `#232F73` | Kickers, large numbers |
| Accent soft | `#E3E6F7` | Light washes |
| Neutral 300 | `#D7D3D3` | De-emphasised chart bars |
| Neutral 500 | `#9B9797` | Inactive states |
| Sketch paper | `#FAF9F6` | Canvas only — warmer than app chrome |

### Rules the system holds itself to

- **One hue.** No per-discipline colours — the twelve disciplines all share the single accent. Where one item must be singled out (Insights' balance chart), it contrasts accent against neutral grey rather than introducing a second colour.
- **Corner radius is zero.** One value, one source of truth, applied to every card, chip, button, and input. The sharp edge is the identity marker.
- **Ink at three opacities** — 100% / 68% / 42% — carries the entire text hierarchy. Dividers are ink at 40%.
- **Elevation is a four-step ink-tinted shadow ramp**, used sparingly; most cards sit flat.

### Type & motifs

- No custom font is bundled. Display type is the system face at *heavy* weight with negative tracking, standing in for a grotesque display face — an obvious place to introduce a real typeface.
- Display sizes in use: 32 (Today headline), 28 (Insights), 24 (prompt), 19 (session title, entry headline).
- The **uppercase kicker** — 11 pt bold, 1.4 tracking, accent-coloured — is the one recurring structural motif, sitting above nearly every headline and card.
- The **outlined tag** is the single chip style, reused for discipline labels, the Daily badge, and the streak pill.
- Numerals are monospaced wherever they're counted or compared.
- Hover is a 5% ink wash, hand-rolled because the app draws its own controls.

> **Locked to light.** The app forces light appearance at the window level — there is no dark mode, and the theme has no dark tokens at all. On a Mac in 2026 that's the most conspicuous omission in the visual system, and it's a from-scratch job rather than an inversion.

---

## 09 · Dialogs & states

Every destructive or lossy action confirms. There are more of these than the screen count suggests, and they're a real part of the experience.

| Trigger | Prompt | Actions |
|---|---|---|
| Navigating away mid-response | Discard this response? | Discard Response / Keep Editing |
| ⌘R with unsaved work | Deal a new prompt and discard this response? | Discard and Continue / Keep This Response |
| ← Back with unsaved work | Discard this response? | Discard Response / Keep Editing |
| Closing Diary with unsaved work | Discard this diary entry? | Discard Entry / Keep Editing |
| Deleting a journal entry | Delete this entry? — names the attachments that go with it | Delete Entry / Cancel |
| Save failure | Couldn't Save — surfaces the underlying reason | OK |
| Delete failure | Journal Update Failed | OK |

Beyond dialogs: empty journal, empty search results, no-entry-selected, microphone denied, recording failed, missing voice-note file, and the daily-already-answered variant of the Today card. Nine non-happy-path states in total.

---

## 10 · Data & privacy

No account, no analytics, no network calls, no AI. This is a positioning decision as much as a technical one, and it should be legible in the design.

- Entries live in a local database inside the app sandbox; voice notes live as files in a managed Application Support directory.
- Attachments are transactional — a recording only becomes permanent when the entry saves, deleting an entry deletes its files, and orphaned files are swept at launch.
- The microphone is the only permission ever requested, and only at the moment of first recording.
- There is currently **no export, no backup, no sync, and no print.** A journal that "never leaves your Mac" also can't leave your Mac.

> **Design opportunity.** The privacy stance is one of the product's strongest differentiators and appears nowhere in the interface — no onboarding, no about screen, no settings copy. It exists only in the README.

---

## 11 · Gaps & open questions

Things that don't exist today. Several are natural redesign scope; listed so the absence is a decision rather than an oversight.

| Missing | Status | Note |
|---|---|---|
| Dark mode | Absent | Window forces light appearance; no dark tokens exist |
| Settings / Preferences | Absent | No Settings scene at all — nothing is configurable |
| Onboarding / first run | Absent | A new user lands on Today with an empty journal and no explanation |
| Notifications / reminders | Absent | Streaks exist but nothing prompts a return visit |
| Export / share / print | Absent | Entries can't leave the app in any form |
| Editing a saved entry | Absent | Entries are write-once; "Answer Again" creates a second entry |
| Favourites | Pulled | Removed over an unresolved click bug; database column reserved |
| Custom typeface | Stubbed | Display type is system-heavy standing in for a real grotesque |
| Per-discipline visual identity | Deliberate | Icons differentiate; colour intentionally does not |
| App icon | Exists | Full size set present; worth revisiting alongside any identity work |

---

## 12 · What can't move

Everything visual is open. These four are product-level commitments that a redesign should route around rather than through.

- **The daily schedule is fixed history.** Prompt wording and prompt ordering are versioned content, not copy that can be freely polished.
- **Nothing gets scored.** No ratings, no quality feedback, no leaderboards, no AI evaluation of a response. Metrics stay behavioural.
- **Local only.** No account, no network, no telemetry. Any feature requiring a server is out of scope by design.
- **Mac-native, not a port.** This app was built ground-up for macOS — sidebar, menu bar, keyboard shortcuts, resizable window, pointer-driven canvas. It should not converge on a phone layout in a window.
