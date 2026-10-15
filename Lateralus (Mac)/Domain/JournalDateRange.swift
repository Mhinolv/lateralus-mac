import Foundation

/// An optional From / To limit on the journal list, in local calendar days.
/// Both boundary days are inclusive: an entry at 23:59 on the To day is in.
struct JournalDateRange: Equatable {
    /// Start of the first included day, or nil for no lower limit.
    private(set) var from: Date?
    /// Start of the last included day, or nil for no upper limit.
    private(set) var to: Date?
    let calendar: Calendar

    init(from: Date? = nil, to: Date? = nil, calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.from = from.map(calendar.startOfDay(for:))
        self.to = to.map(calendar.startOfDay(for:))
    }

    var isActive: Bool { from != nil || to != nil }

    /// Sets the first day. A From day later than To moves To to the same day.
    mutating func setFrom(_ date: Date?) {
        from = date.map(calendar.startOfDay(for:))
        if let from, let to, from > to { self.to = from }
    }

    /// Sets the last day. A To day earlier than From moves From to the same day.
    mutating func setTo(_ date: Date?) {
        to = date.map(calendar.startOfDay(for:))
        if let from, let to, from > to { self.from = to }
    }

    mutating func clear() {
        from = nil
        to = nil
    }

    func contains(_ date: Date) -> Bool {
        if let from, date < from { return false }
        // The day after `to` starts the exclusion. Adding a calendar day,
        // not 24 hours, keeps 23- and 25-hour DST days whole.
        if let to, let end = calendar.date(byAdding: .day, value: 1, to: to), date >= end {
            return false
        }
        return true
    }

    /// The one-line summary under the search row, for example
    /// "From Oct 3, 2026", "Until Oct 10, 2026" or "Oct 3 – Oct 10, 2026".
    func summary(locale: Locale = .autoupdatingCurrent) -> String? {
        var full = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar)
        full.timeZone = calendar.timeZone
        var short = Date.FormatStyle(locale: locale, calendar: calendar).month(.abbreviated).day()
        short.timeZone = calendar.timeZone

        switch (from, to) {
        case (nil, nil):
            return nil
        case let (from?, nil):
            return "From \(from.formatted(full))"
        case let (nil, to?):
            return "Until \(to.formatted(full))"
        case let (from?, to?):
            if from == to { return to.formatted(full) }
            let sameYear = calendar.component(.year, from: from) == calendar.component(.year, from: to)
            let start = sameYear ? from.formatted(short) : from.formatted(full)
            return "\(start) – \(to.formatted(full))"
        }
    }
}
