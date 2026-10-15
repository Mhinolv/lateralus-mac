import SwiftData
import SwiftUI

/// Practice stats: streak, volume, the week's rhythm, and per-discipline
/// balance. Behavioral numbers only — nothing here grades creativity.
struct InsightsView: View {
    @Environment(\.appNow) private var appNow
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    private var metrics: ActivityMetrics {
        ActivityMetrics(entries: entries.map { (date: $0.date, exercise: $0.exercise) }, now: appNow)
    }

    private var topDiscipline: Exercise? {
        metrics.disciplineCounts.max { $0.value < $1.value }?.key
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                header
                statRow
                weekChart
                disciplineBalance
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
            .padding(.bottom, 56)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        Text("Your practice patterns.")
            .font(Theme.display(32))
            .foregroundStyle(Theme.ink)
    }

    private var statRow: some View {
        HStack(spacing: 16) {
            statTile(value: "\(metrics.streak)", label: "Streak", emphasize: true)
            statTile(value: "\(metrics.total)", label: "Entries total", emphasize: false)
            statTile(value: "\(metrics.thisWeek)", label: "This week", emphasize: false)
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

    /// Seven bars, no axes, no gridlines. There is no scale worth reading
    /// here — the question is "did I show up," and a bar chart drawn by hand
    /// answers it better than a plotted one: a day with no entries keeps a
    /// visible stub rather than collapsing to nothing, which is the whole
    /// point of showing the week.
    private var weekChart: some View {
        let week = metrics.lastSevenDays
        let peak = max(week.map(\.count).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 days")
                .font(Theme.ui(14, .semibold))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(week, id: \.day) { item in
                    VStack(spacing: 8) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.count > 0 ? Theme.accent : Theme.surfaceSunken)
                            .frame(height: barHeight(count: item.count, peak: peak))
                            .accessibilityLabel(
                                "\(item.day.formatted(.dateTime.weekday(.wide))): \(item.count) entr\(item.count == 1 ? "y" : "ies")"
                            )
                        Text(item.day.formatted(.dateTime.weekday(.narrow)))
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
    }

    /// Active days start from a floor rather than from zero, so one entry
    /// still reads as a bar and not as a smear.
    private func barHeight(count: Int, peak: Int) -> CGFloat {
        guard count > 0 else { return 8 }
        let span: CGFloat = 76
        return 24 + span * CGFloat(count) / CGFloat(peak)
    }

    /// Practice distribution across the twelve disciplines. Rather than a
    /// unique hue per row, the system spends its one accent on whichever
    /// discipline leads and renders the rest in neutral gray — restraint
    /// over a color key. Diary entries count toward activity but not
    /// balance.
    private var disciplineBalance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discipline balance")
                .font(Theme.ui(14, .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 4)
            ForEach(Exercise.practice) { exercise in
                let count = metrics.disciplineCounts[exercise, default: 0]
                let isTop = count > 0 && exercise == topDiscipline
                HStack(spacing: 14) {
                    Text(exercise.title)
                        .font(Theme.ui(13, isTop ? .semibold : .regular))
                        .foregroundStyle(isTop ? Theme.accentStrong : Theme.inkSecondary)
                        .frame(width: 130, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surfaceSunken)
                            Capsule()
                                .fill(isTop ? Theme.accent : Theme.inkQuaternary)
                                .frame(width: geo.size.width * barFraction(count))
                        }
                    }
                    .frame(height: 8)
                    Text("\(count)")
                        .font(Theme.mono(13, .medium))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    private func barFraction(_ count: Int) -> CGFloat {
        let maxCount = max(metrics.disciplineCounts.values.max() ?? 1, 1)
        return CGFloat(count) / CGFloat(maxCount)
    }
}
