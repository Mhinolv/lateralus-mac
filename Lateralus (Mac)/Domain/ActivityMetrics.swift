import Foundation

/// Activity math shared by Today, Journal, and Insights. "Active day" means
/// at least one saved entry (Diary included) on that local calendar day.
struct ActivityMetrics {
    let entryDays: [Date]
    let now: Date
    let calendar: Calendar
    let total: Int
    /// Practice entries per discipline. Diary is intentionally absent.
    let disciplineCounts: [Exercise: Int]

    init(entries: [(date: Date, exercise: Exercise)], now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        self.now = now
        self.calendar = calendar
        self.total = entries.count
        self.entryDays = entries.map { calendar.startOfDay(for: $0.date) }

        var counts: [Exercise: Int] = [:]
        for entry in entries where entry.exercise != .diary {
            counts[entry.exercise, default: 0] += 1
        }
        self.disciplineCounts = counts
    }

    /// Consecutive active days ending today — or ending yesterday, so the
    /// streak isn't shown as broken before today's entry exists.
    var streak: Int {
        let activeDays = Set(entryDays)
        var day = calendar.startOfDay(for: now)
        if !activeDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  activeDays.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var run = 0
        while activeDays.contains(day) {
            run += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return run
    }

    /// Entries inside the user's current calendar week.
    var thisWeek: Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return entryDays.count { week.contains($0) }
    }

    /// Entry counts for the trailing seven local calendar days, oldest first.
    var lastSevenDays: [(day: Date, count: Int)] {
        let today = calendar.startOfDay(for: now)
        var histogram: [Date: Int] = [:]
        for day in entryDays {
            histogram[day, default: 0] += 1
        }
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day: day, count: histogram[day] ?? 0)
        }
    }

    /// Practice disciplines with at least one entry.
    var disciplinesTried: Int {
        Exercise.practice.count { disciplineCounts[$0, default: 0] > 0 }
    }

    /// The most-practiced discipline, or nil before any practice entry. A
    /// tie goes to the first in catalog order, so the mark does not move
    /// from one redraw to the next.
    var leadingDiscipline: Exercise? {
        var leader: Exercise?
        var best = 0
        for exercise in Exercise.practice {
            let count = disciplineCounts[exercise, default: 0]
            if count > best {
                leader = exercise
                best = count
            }
        }
        return leader
    }

    /// Filled dots in a balance row of `slots` dots: the count scaled to
    /// the leader's count and rounded, with at least one dot for any
    /// count above zero.
    static func balanceDots(count: Int, max leaderCount: Int, slots: Int = 6) -> Int {
        guard count > 0, leaderCount > 0 else { return 0 }
        let scaled = (Double(slots * count) / Double(leaderCount)).rounded()
        return min(slots, max(1, Int(scaled)))
    }
}
