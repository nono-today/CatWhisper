import SwiftUI

@main
struct CatWhisperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    appState.setupFnKeyMonitor()
                }
        } label: {
            StatusItemIcon(state: appState.state)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("歡迎使用 CatWhisper", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
        .windowResizability(.contentSize)
    }

    init() {
        // Hide dock icon — menu bar only app
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
