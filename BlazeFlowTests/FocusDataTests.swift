import XCTest
@testable import BlazeFlow

final class FocusDataTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testSessionSpanningMidnightSplitsAcrossDays() {
        let session = FocusSession(startedAt: date(25, 23, 45), endsAt: date(26, 0, 15))
        XCTAssertEqual(session.seconds(on: date(25), calendar: calendar), 900)
        XCTAssertEqual(session.seconds(on: date(26), calendar: calendar), 900)
        XCTAssertEqual(session.seconds(on: date(27), calendar: calendar), 0)
    }

    func testEarlyStopOnlyCreditsElapsedTime() {
        let session = FocusSession(startedAt: date(26, 9), endsAt: date(26, 10), stoppedAt: date(26, 9, 12))
        var data = FocusData()
        data.history = [session]
        XCTAssertEqual(data.minutes(on: date(26), calendar: calendar), 12)
        XCTAssertFalse(session.completed)
    }

    func testUnfinishedSessionDoesNotCountTowardGoal() {
        var data = FocusData()
        data.activeSession = FocusSession(startedAt: date(26, 9), endsAt: date(26, 10))
        XCTAssertEqual(data.minutes(on: date(26), calendar: calendar), 0)
    }

    func testStreakIncludesYesterdayWhileTodayIsInProgress() {
        var data = FocusData()
        data.history = [24, 25].map { FocusSession(startedAt: date($0, 9), endsAt: date($0, 10)) }
        XCTAssertEqual(data.streak(asOf: date(26), calendar: calendar), 2)
        data.history.append(FocusSession(startedAt: date(26, 9), endsAt: date(26, 10)))
        XCTAssertEqual(data.streak(asOf: date(26), calendar: calendar), 3)
        XCTAssertEqual(data.streak(asOf: date(28), calendar: calendar), 0)
    }

    func testSeveralSessionsCombineForDailyGoal() {
        var data = FocusData()
        data.history = [
            FocusSession(startedAt: date(26, 9), endsAt: date(26, 9, 30)),
            FocusSession(startedAt: date(26, 10), endsAt: date(26, 10, 30))
        ]
        XCTAssertEqual(data.minutes(on: date(26), calendar: calendar), 60)
        XCTAssertEqual(data.streak(asOf: date(26), calendar: calendar), 1)
    }

    func testPersistenceRoundTripPreservesActiveSessionAndHistory() throws {
        var data = FocusData()
        data.activeSession = FocusSession(startedAt: date(26, 9), endsAt: date(26, 10))
        data.history = [FocusSession(startedAt: date(25, 9), endsAt: date(25, 10))]
        let restored = try JSONDecoder().decode(FocusData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(restored.activeSession, data.activeSession)
        XCTAssertEqual(restored.history, data.history)
        XCTAssertEqual(restored.dailyGoalMinutes, 60)
    }
}
