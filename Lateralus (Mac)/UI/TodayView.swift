import SwiftData
import SwiftUI

/// The featured daily challenge and the door into it.
struct TodayView: View {
    @Environment(\.appNow) private var appNow
    @Environment(AppModel.self) private var appModel
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var activeSession: Prompt?

    private var daily: Prompt { PromptEngine.daily(for: appNow) }

    private var dailyDone: Bool {
        entries.contains {
            $0.isDaily && Calendar.autoupdatingCurrent.isDate($0.date, inSameDayAs: appNow)
        }
    }

    private var metrics: ActivityMetrics {
        ActivityMetrics(entries: entries.map { (date: $0.date, exercise: $0.exercise) }, now: appNow)
    }

    var body: some View {
        content
            .navigationTitle(activeSession?.exercise.title ?? SidebarItem.today.title)
    }

    @ViewBuilder
    private var content: some View {
        if let prompt = activeSession {
            SessionView(
                prompt: prompt,
                isDaily: true,
                onDone: { activeSession = nil },
                onBack: { activeSession = nil }
            )
            .id(prompt.id)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    statRow
                    dailyCard
                    practiceHint
                    recentEntries
                }
                .padding(.horizontal, 32)
                .padding(.top, 56)
                .padding(.bottom, 56)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Date first and small, headline second and large — the screen states
    /// when you are before it states what to do.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(appNow.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.inkTertiary)
                Text("Think sideways.")
                    .font(Theme.display(36))
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 16)
            StreakPill(days: metrics.streak)
        }
    }

    private var statRow: some View {
        HStack(spacing: 16) {
            statTile(value: "\(metrics.streak)", label: "Streak", emphasize: true)
            statTile(value: "\(metrics.thisWeek)", label: "This week", emphasize: false)
            statTile(value: "\(metrics.total)", label: "All time", emphasize: false)
        }
    }

    private func statTile(value: String, label: String, emphasize: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.ui(12))
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(Theme.mono(26))
                .foregroundStyle(emphasize ? Theme.accent : Theme.ink)
                .contentTransition(.numericText())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    private var dailyCard: some View {
        Button {
            activeSession = daily
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    SectionLabel(text: daily.exercise.title)
                    if dailyDone {
                        Badge(text: "Done")
                    }
                }
                .padding(.bottom, 14)

                Text(daily.headline)
                    .font(Theme.display(26, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = daily.detail {
                    Text(detailLine(label: daily.detailLabel, detail: detail))
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }

                Text(dailyDone ? "Answer Again" : "Begin")
                    .font(Theme.ui(15, .semibold))
                    .foregroundStyle(Theme.primaryLabel)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Theme.primaryFill, in: .rect(cornerRadius: Theme.radiusMedium))
                    .padding(.top, 22)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .outlinedCard()
            .hoverHighlight(cornerRadius: Theme.radiusLarge)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            dailyDone
                ? "Answer today's challenge again: \(daily.exercise.title)"
                : "Begin today's challenge: \(daily.exercise.title)"
        )
        .accessibilityIdentifier("daily-challenge-card")
    }

    /// The labelled second element reads as one sentence here rather than a
    /// separate block — Today is a summary, the session gets the full form.
    private func detailLine(label: String?, detail: String) -> String {
        guard let label, !label.isEmpty else { return detail }
        return "\(label): \(detail)"
    }

    /// Set between two hairlines rather than in a card: it's an aside about
    /// the sidebar, and giving it a surface would make it compete with the
    /// challenge above it.
    private var practiceHint: some View {
        Text("Want more? Every discipline is in the sidebar under **Practice** — fresh prompts every round.")
            .font(Theme.ui(14))
            .foregroundStyle(Theme.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.dividerSoft).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.dividerSoft).frame(height: 1)
            }
    }

    @ViewBuilder
    private var recentEntries: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent entries")
                        .font(Theme.ui(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button {
                        appModel.select(.journal)
                    } label: {
                        Text("View journal →")
                            .font(Theme.ui(13))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(3))) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Tag(text: entry.exercise.title)
                                .frame(width: 116, alignment: .leading)
                            Text(entry.responseText.isEmpty ? entry.promptHeadline : entry.responseText)
                                .font(Theme.ui(14))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(entry.date, format: .relative(presentation: .named))
                                .font(Theme.ui(12))
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.dividerSoft).frame(height: 1)
                        }
                    }
                }
            }
        }
    }
}
