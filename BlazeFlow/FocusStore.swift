import DeviceActivity
import FamilyControls
import ManagedSettings
import Observation
import Foundation

@MainActor @Observable
final class FocusStore {
    private(set) var data = FocusData()
    private(set) var selection = FamilyActivitySelection()
    private(set) var authorized = false
    private(set) var requestingAccess = false
    var errorMessage: String?

    private let defaults: UserDefaults?
    private let center = DeviceActivityCenter()
    private let settings = ManagedSettingsStore(named: .init(FocusConfiguration.settingsName))
    private let activity = DeviceActivityName(FocusConfiguration.activityName)

    init() {
        defaults = UserDefaults(suiteName: FocusConfiguration.appGroup)
        do {
            if let stored = defaults?.data(forKey: FocusConfiguration.stateKey) {
                data = try JSONDecoder().decode(FocusData.self, from: stored)
            }
            if let stored = defaults?.data(forKey: "focus.selection") {
                selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: stored)
            }
        } catch {
            errorMessage = "Saved focus data could not be read. Your previous data has not been overwritten."
        }
        refresh()
    }

    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    func requestAccess() async {
        requestingAccess = true
        defer { requestingAccess = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
        } catch {
            errorMessage = "Screen Time access was not granted. You can try again when you're ready."
        }
    }

    func updateSelection(_ value: FamilyActivitySelection) {
        guard data.activeSession == nil else { return }
        do {
            let encoded = try JSONEncoder().encode(value)
            defaults?.set(encoded, forKey: "focus.selection")
            selection = value
        } catch { errorMessage = error.localizedDescription }
    }

    func setGoal(_ minutes: Int) {
        data.dailyGoalMinutes = min(240, max(15, minutes))
        save()
    }

    func start(minutes: Int) {
        refresh()
        guard authorized, data.activeSession == nil, selectedCount > 0 else { return }
        guard (15...120).contains(minutes) else { return }
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FocusConfiguration.appGroup) != nil else {
            errorMessage = "The shared app group is unavailable. Check signing and App Groups in Xcode."
            return
        }
        let now = Date()
        let end = now.addingTimeInterval(Double(minutes * 60))
        var calendar = Calendar.current
        calendar.timeZone = .current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: now),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        do {
            // Register expiry before shielding, so a scheduling failure cannot leave apps blocked.
            try center.startMonitoring(activity, during: schedule)
            data.activeSession = FocusSession(startedAt: now, endsAt: end)
            save()
            settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        } catch {
            settings.clearAllSettings()
            errorMessage = "Couldn't start app blocking: \(error.localizedDescription)"
        }
    }

    func stop() {
        finish(early: true)
    }

    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        guard let session = data.activeSession else {
            settings.clearAllSettings()
            return
        }
        if !authorized { finish(early: true) }
        else if session.endsAt <= Date() { finish(early: false) }
    }

    private func finish(early: Bool) {
        settings.clearAllSettings()
        center.stopMonitoring([activity])
        guard var session = data.activeSession else { return }
        if early { session.stoppedAt = min(Date(), session.endsAt) }
        data.history.append(session)
        data.activeSession = nil
        save()
    }

    private func save() {
        do { defaults?.set(try JSONEncoder().encode(data), forKey: FocusConfiguration.stateKey) }
        catch { errorMessage = "Your progress couldn't be saved: \(error.localizedDescription)" }
    }
}
