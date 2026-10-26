import SwiftUI

struct SettingsView: View {
    @Environment(FocusStore.self) private var store

    var body: some View {
        Form {
            Section("Your daily intention") {
                Stepper(value: Binding(
                    get: { store.data.dailyGoalMinutes },
                    set: { store.setGoal($0) }
                ), in: 15...240, step: 15) {
                    Label("\(store.data.dailyGoalMinutes) minutes", systemImage: "target")
                }
                Text("Start with something achievable. You can change your goal anytime.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("App blocking") {
                LabeledContent("Screen Time access", value: store.authorized ? "Allowed" : "Not allowed")
                if !store.authorized {
                    Button("Allow Screen Time access") {
                        Task { await store.requestAccess() }
                    }
                    .disabled(store.requestingAccess)
                }
                Text("Blaze Flow uses Apple's Screen Time controls. You choose what to shield, and you can end a session early. Individual authorization is voluntary and can be revoked in iPhone Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Private by design") {
                Label("No account or cloud sync", systemImage: "person.crop.circle.badge.checkmark")
                Label("No ads or analytics", systemImage: "hand.raised")
                Text("Your selections and focus history are saved locally. Apple provides private selection tokens rather than revealing your selected apps to this app. Deleting the app removes its local history.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Text("Blaze Flow · Make room for what matters.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear { store.refresh() }
    }
}
