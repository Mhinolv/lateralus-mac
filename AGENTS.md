# AGENTS.md — Lateralus (Mac)

Read this file before you change code. `README.md` and `DESIGN_BRIEF.md` hold the full spec.

## Product overview

Lateralus (Mac) is a native macOS app for practice in lateral thinking. It gives one daily challenge, twelve practice disciplines and a private local journal.

- Build for the Mac only. Do not port iOS code or iOS UI. Use Mac idioms: sidebar, menu bar commands, keyboard shortcuts, pointer input.
- Privacy is a product rule: no account, no network, no analytics, no AI. The only permission is the microphone.
- Nothing is graded, scored or ranked.

## Architecture map

| Area | Files |
|---|---|
| App entry, menu commands | `Lateralus (Mac)/LateralusApp.swift` |
| Exercise catalog, prompts | `Domain/Exercise.swift`, `Domain/Prompt.swift`, `Domain/ContentPools.swift` |
| Daily schedule | `Domain/PromptEngine.swift` |
| Streaks and Insights data | `Domain/ActivityMetrics.swift` |
| Storage | `Data/JournalEntry.swift` (versioned SwiftData schema), `Data/PersistenceController.swift` |
| Attachments | `Data/AttachmentStore.swift`, `Data/EntryRepository.swift` |
| Sketch, voice notes | `Media/Sketch.swift`, `Media/VoiceNotes.swift` |
| Window, navigation | `UI/RootView.swift`, `UI/SideBar.swift`, `UI/AppModel.swift` |
| Screens | `UI/TodayView.swift`, `UI/SessionView.swift`, `UI/JournalView.swift`, `UI/EntryDetailView.swift`, `UI/InsightsView.swift`, `UI/DiaryComposer.swift` |
| Visual system | `UI/Theme.swift`, `UI/Fonts.swift`, `Resources/Fonts/` |
| Unit tests | `Lateralus (Mac)Tests/` |
| UI tests (local only, they drive the desktop) | `Lateralus (Mac)UITests/` |

## Rules that protect users

- **Schedule stability is a contract.** The daily schedule is a pure function of (local day, `PromptEngine.contentVersion`). If you change `ContentPools` or engine mixing, bump `contentVersion`. `testScheduleStabilityPin` must pass.
- **Saved data must still load.** If you change `JournalEntry`, add a new schema version and a migration. Entries saved before the change must still open.
- **Attachments are transactional.** Save files and the entry together through `EntryRepository`. Do not leave orphan files.
- **Theme only.** Take every color, radius and shared component from `UI/Theme.swift`. Use one hue. Every color is a light/dark pair, and the app follows the system appearance. Do not force a color scheme. In light mode, do not use lime as text color. Do not tint a shadow with `ink`.
- **Favorites are deferred.** Keep the `isFavorite` column. Do not add Favorites UI without an issue.
- SwiftUI previews: use `PreviewProvider`, not the `#Preview` macro.

## Build and test

```sh
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -configuration Debug -destination platform=macOS -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= LATERALUS_ID_SUFFIX=.team build
xcodebuild -project "Lateralus (Mac).xcodeproj" -scheme "Lateralus (Mac)" -configuration Debug -destination platform=macOS -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= LATERALUS_ID_SUFFIX=.team -only-testing "Lateralus (Mac)Tests" test
```

Agents use ad-hoc signing because they have no keychain access. `LATERALUS_ID_SUFFIX=.team` gives team builds their own bundle ID, so tests never open the owner's real journal container. CI runs the same unit-test command on `macos-26` with Xcode 26.2.

## Team Roadmap Workflow (multi-agent, GitHub)

A multi-agent team works the release milestone in GitHub (`Mhinolv/lateralus-mac`). GitHub Issues are the single source of truth; every change ships as a pull request into `main`. Everyone writes in ASD-STE100 Simplified Technical English with hard length budgets (see the product-team skill, `~/.claude/writing_standard.md`). Roles:

| Role | Responsibility | Output |
|---|---|---|
| Orchestrator | Supervises, prioritizes, creates issue branches, commits/pushes for the engineer, opens PRs, final approver | Merges PRs, closes issues |
| Product Research | Competitor analysis and gap finding | `research.md` |
| Product Manager | Turns gaps/requests into issues (Problem, Scope & Boundaries, Acceptance criteria) | Issues + `**PM review**` comments |
| UI/UX | `## Design notes` section of each issue | Body section + `**UX notes**` comment |
| Engineer | Implements one issue on its linked branch; regression test first for bugs | Changes + `PR BODY` / `COMMIT FILES` blocks |
| QA | Reviews the PR against the issue's acceptance criteria, design notes and owner decisions | Inline review comments + `QA RESULT: PASS/FAIL` PR comment |

Issue flow labels (exactly one at a time): `needs-pm` → `needs-ux` → `ready` → `in-progress` → `in-review` → (`needs-owner-check`) → closed. Also: `bug`/`feature`, `P0`–`P3`, `owner-request`, `redesign`, `blocked`; PR labels `qa-pass`/`qa-fail`.

Rules:
- Issue bodies use the sections `## Problem / Request`, `## Scope & Boundaries`, `## Acceptance criteria`, `## Design notes`, `## Owner decisions`. Edit one section at a time; never drop the others.
- Product-owner decisions are posted as `**Owner decision:** …` comments and mirrored in `## Owner decisions`; they override earlier wording.
- One issue = one branch (`<n>-<slug>`, created with `gh issue develop`) = one PR into `main`. Commits: `#<n>: <summary>`. Stage only the files changed for that issue. Never `git add -A`. Never commit to main.
- PRs must satisfy the PR template (Issue / What changed / How it was tested / Screenshots). `Refs #n` instead of `Closes #n` while the owner still has to check it.
- CI (build + tests) and the PR-template check must be green before merge.
- The Engineer does not commit, push, open PRs or close issues. QA does not modify source. Only the Orchestrator merges PRs and closes issues.
- For this milestone, **QA PASS + green CI + Orchestrator approval replaces the manual user-test gate** (delegated by the product owner), except issues labelled `needs-owner-check`.
- No agent may use browser/Chrome/computer-use/GUI automation tools.
