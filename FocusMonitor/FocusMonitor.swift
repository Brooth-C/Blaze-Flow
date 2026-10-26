import DeviceActivity
import ManagedSettings
import Foundation

final class FocusMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == FocusConfiguration.activityName else { return }
        let settings = ManagedSettingsStore(named: .init(FocusConfiguration.settingsName))
        let defaults = UserDefaults(suiteName: FocusConfiguration.appGroup)
        // Ignore a delayed callback from a previous session if a new one is active.
        if let encoded = defaults?.data(forKey: FocusConfiguration.stateKey),
           let data = try? JSONDecoder().decode(FocusData.self, from: encoded),
           let active = data.activeSession,
           active.endsAt > Date().addingTimeInterval(2) {
            return
        }
        settings.clearAllSettings()
        // The app reconciles progress on next activation; this extension only owns expiry.
    }
}
