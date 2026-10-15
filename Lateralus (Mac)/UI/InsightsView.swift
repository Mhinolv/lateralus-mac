import SwiftData
import SwiftUI

/// Practice stats: streak, volume, the week's rhythm, and per-discipline
/// balance. Behavioral numbers only — nothing here grades creativity.
struct InsightsView: View {
    @Environment(\.appNow) private var appNow
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    /// The pane width, which picks one or two columns.
    @State private var width: CGFloat = 0

    /// Below this pane width the two columns stack.
    static let twoColumnMinWidth: CGFloat = 760

    private var metrics: ActivityMetrics {
        ActivityMetrics(entries: entries.map { (date: $0.date, exercise: $0.exercise) }, now: appNow)
    }

    var body: some View {
        let metrics = metrics
        ScrollView {
            Group {
                if width >= Self.twoColumnMinWidth {
                    HStack(alignment: .top, spacing: 56) {
                        activityColumn(metrics)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        disciplineBalance(metrics)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 48) {
                        activityColumn(metrics)
                        disciplineBalance(metrics)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 40)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    // MARK: - Activity

    private func activityColumn(_ metrics: ActivityMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Your practice patterns")
            streak(metrics.streak)
                .padding(.top, 10)
            counts(metrics)
                .padding(.top, 18)
            weekDots(metrics.lastSevenDays)
                .padding(.top, 34)
        }
    }

    /// The streak is the one large number on the screen.
    private func streak(_ days: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(days)")
                .font(Theme.display(96, weight: .light))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(days == 1 ? "day in a row" : "days in a row")
                .font(Theme.display(30, weight: .regular, italic: true))
                .foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
        .help("Consecutive days with at least one journal entry")
    }

    private func counts(_ metrics: ActivityMetrics) -> some View {
        HStack(alignment: .top, spacing: 36) {
            count(metrics.total, label: "entries")
            count(metrics.thisWeek, label: "this week")
            count(metrics.disciplinesTried, label: "disciplines tried")
        }
    }

    private func count(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(Theme.mono(22, .regular))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.ui(13.5))
                .foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Seven day dots, no axes. The question is "did I show up," so a day
    /// with no entries keeps a visible ring rather than collapsing to
    /// nothing.
    private func weekDots(_ week: [(day: Date, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Last 7 days")
            HStack(spacing: 9) {
                ForEach(week, id: \.day) { item in
                    VStack(spacing: 6) {
                        dayDot(count: item.count)
                        Text(item.day.formatted(.dateTime.weekday(.narrow)))
                            .font(Theme.mono(10, .regular))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(item.day.formatted(.dateTime.weekday(.wide))): \(item.count) entr\(item.count == 1 ? "y" : "ies")"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func dayDot(count: Int) -> some View {
        if count > 0 {
            Circle()
                .fill(Theme.accent.opacity(Self.dayDotOpacity(count: count)))
                .frame(width: 18, height: 18)
        } else {
            Circle()
                .strokeBorder(Theme.divider, lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    /// Accent strength for a day with `count` entries: 55%, 78%, then full
    /// from three entries. A day with no entries is a ring, not a fill.
    static func dayDotOpacity(count: Int) -> Double {
        switch count {
        case ..<1: 0
        case 1: 0.55
        case 2: 0.78
        default: 1
        }
    }

    // MARK: - Balance

    /// Practice distribution across the twelve disciplines. Rather than a
    /// unique hue per row, the system spends its one accent and the
    /// highlighter on whichever discipline leads, and the rest stay ink.
    /// Diary entries count toward activity but not balance.
    private func disciplineBalance(_ metrics: ActivityMetrics) -> some View {
        let leader = metrics.leadingDiscipline
        let leaderCount = leader.map { metrics.disciplineCounts[$0, default: 0] } ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Discipline balance")
            Text("The most-practiced discipline is marked. Nothing here judges an answer.")
                .font(Theme.ui(12.5))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 4)
            ForEach(Exercise.practice) { exercise in
                balanceRow(
                    exercise,
                    count: metrics.disciplineCounts[exercise, default: 0],
                    leaderCount: leaderCount,
                    isLeader: exercise == leader
                )
                .padding(.top, 11)
            }
        }
    }

    private func balanceRow(_ exercise: Exercise, count: Int, leaderCount: Int, isLeader: Bool) -> some View {
        let filled = ActivityMetrics.balanceDots(count: count, max: leaderCount)
        return HStack(spacing: 12) {
            Group {
                if isLeader {
                    Text(exercise.title)
                        .foregroundStyle(Theme.onMark)
                        .padding(.horizontal, 3)
                        .background(Theme.mark, in: .rect(cornerRadius: 3))
                        .padding(.horizontal, -3)
                } else {
                    Text(exercise.title)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .font(Theme.ui(13))
            .lineLimit(1)
            .frame(width: 128, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { slot in
                    if slot < filled {
                        Circle()
                            .fill(isLeader ? Theme.accent : Theme.inkTertiary)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .strokeBorder(Theme.divider, lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                    }
                }
            }

            Text("\(count)")
                .font(Theme.mono(11.5, .regular))
                .foregroundStyle(Theme.inkTertiary)
                .frame(minWidth: 18, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(exercise.title): \(count) entr\(count == 1 ? "y" : "ies")\(isLeader ? ", most practiced" : "")"
        )
    }
}
