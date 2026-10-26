import SwiftUI

@main
struct BlazeFlowApp: App {
    @State private var store = FocusStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.orange)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refresh() }
                }
        }
    }
}
