import SwiftUI
import FamilyControls

struct RootView: View {
    @Environment(FocusStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView {
            NavigationStack { FocusView() }
                .tabItem { Label("Focus", systemImage: "flame") }
            NavigationStack { ProgressView() }
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .alert("Something needs attention", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .task {
            while !Task.isCancelled {
                store.refresh()
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
            }
        }
    }
}

struct FocusView: View {
    @Environment(FocusStore.self) private var store
    @State private var duration = 25
    @State private var pickerPresented = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var confirmingEnd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("BLAZE FLOW", systemImage: "flame.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(.orange)
                    Text(store.data.activeSession == nil ? "Make room for\nwhat matters." : "One thing\nat a time.")
                        .font(.largeTitle.bold())
                    Text("A little less scrolling. A little more living.")
                        .foregroundStyle(.secondary)
                }

                if let session = store.data.activeSession {
                    activeSession(session)
                } else {
                    sessionSetup
                }

                DailyGoalCard()
                Label("Your focus history stays on this iPhone.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickerPresented) {
            NavigationStack {
                FamilyActivityPicker(selection: $draftSelection)
                    .navigationTitle("Choose distractions")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { pickerPresented = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.updateSelection(draftSelection)
                                pickerPresented = false
                            }
                        }
                    }
            }
        }
        .confirmationDialog("End this focus session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End session and unblock apps", role: .destructive) { store.stop() }
        } message: {
            Text("Time already focused will count toward your daily goal.")
        }
    }

    private var sessionSetup: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Your next quiet moment", systemImage: "sparkles")
                .font(.headline)
            Picker("Session length", selection: $duration) {
                ForEach([15, 25, 45, 60, 90, 120], id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("sessionDuration")

            if store.authorized {
                Button {
                    draftSelection = store.selection
                    pickerPresented = true
                } label: {
                    HStack {
                        Label("Choose distractions", systemImage: "apps.iphone")
                        Spacer()
                        Text("\(store.selectedCount) selected").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("chooseApps")
                Button { store.start(minutes: duration) } label: {
                    Label("Start focusing", systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.selectedCount == 0)
                .accessibilityIdentifier("startFocus")
                Text("Selected apps, categories, and websites will be shielded until the session ends. You can end a session early.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Allow Screen Time access to choose apps and block distractions during your sessions.")
                    .foregroundStyle(.secondary)
                Button {
                    Task { await store.requestAccess() }
                } label: {
                    Text(store.requestingAccess ? "Requesting access…" : "Enable app blocking")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).disabled(store.requestingAccess)
            }
        }
        .focusCard()
    }

    private func activeSession(_ session: FocusSession) -> some View {
        VStack(spacing: 24) {
            Label("FOCUS IN PROGRESS", systemImage: "leaf.fill")
                .font(.caption.weight(.bold)).foregroundStyle(.green)
            Text(timerInterval: session.startedAt...session.endsAt, countsDown: true)
                .font(.system(size: 56, weight: .light, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.5)
                .accessibilityLabel("Time remaining")
            Text("Your distractions are shielded.\nTake this time for yourself.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("End session", role: .destructive) { confirmingEnd = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity).focusCard()
    }
}

struct DailyGoalCard: View {
    @Environment(FocusStore.self) private var store

    var body: some View {
        let minutes = store.data.minutes(on: Date())
        let goal = store.data.dailyGoalMinutes
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's intention").font(.headline)
                Spacer()
                Image(systemName: minutes >= goal ? "checkmark.seal.fill" : "sun.max")
                    .foregroundStyle(.orange)
            }
            Text("\(minutes) / \(goal) min").font(.title2.bold()).monospacedDigit()
            SwiftUI.ProgressView(value: Double(min(minutes, goal)), total: Double(goal))
            Text(minutes >= goal ? "You made space for your goal today." : "\(goal - minutes) more minutes to reach your goal.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Progress updates when a session ends.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .focusCard()
    }
}

extension View {
    func focusCard() -> some View {
        padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}
