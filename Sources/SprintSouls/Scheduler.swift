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

    /// 1-based number of the sprint containing `now` (sprint 1 starts at the
    /// anchor). Before the anchor this is 1, the upcoming first sprint.
    func sprintNumber(asOf now: Date) -> Int {
        guard let boundary = currentBoundary(asOf: now), intervalDays > 0 else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: anchor, to: boundary).day ?? 0
        return days / intervalDays + 1
    }
}
