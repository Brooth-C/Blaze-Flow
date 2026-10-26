import Foundation

enum FocusConfiguration {
    // The entitlement substitutes the same build setting in both targets.
    static var appGroup: String {
        Bundle.main.object(forInfoDictionaryKey: "FocusAppGroup") as! String
    }
    static let activityName = "blaze.focus.session"
    static let settingsName = "blaze.focus.shield"
    static let stateKey = "focus.state.v1"
}

struct FocusSession: Codable, Identifiable, Equatable {
    var id = UUID()
    let startedAt: Date
    let endsAt: Date
    var stoppedAt: Date?

    var finishedAt: Date { min(stoppedAt ?? endsAt, endsAt) }
    var completed: Bool { stoppedAt == nil }

    func seconds(on day: Date, calendar: Calendar = .current) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return max(0, min(finishedAt, interval.end).timeIntervalSince(max(startedAt, interval.start)))
    }
}

struct FocusData: Codable {
    var dailyGoalMinutes = 60
    var activeSession: FocusSession?
    var history: [FocusSession] = []

    func minutes(on day: Date, calendar: Calendar = .current) -> Int {
        Int(history.reduce(0) { $0 + $1.seconds(on: day, calendar: calendar) } / 60)
    }

    func streak(asOf today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        // Yesterday's streak stays visible until today's goal has been reached.
        if minutes(on: day, calendar: calendar) < dailyGoalMinutes {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while minutes(on: day, calendar: calendar) >= dailyGoalMinutes {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}
