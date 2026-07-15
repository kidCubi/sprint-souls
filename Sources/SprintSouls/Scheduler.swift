import Foundation

struct Scheduler {
    let anchor: Date
    let intervalDays: Int

    /// The most recent sprint boundary at or before `now`, or nil if the anchor is in the future.
    func currentBoundary(asOf now: Date) -> Date? {
        guard intervalDays > 0, now >= anchor else { return nil }
        let calendar = Calendar.current
        var boundary = anchor
        while true {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: boundary),
                  next <= now else {
                return boundary
            }
            boundary = next
        }
    }

    /// The first sprint boundary strictly after `now`.
    func nextBoundary(asOf now: Date) -> Date {
        guard let current = currentBoundary(asOf: now) else { return anchor }
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: current) ?? current
    }
}
